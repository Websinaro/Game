#!/usr/bin/env python3
"""FBX (Tripo mesh + Mixamo animation FBXs) -> one skinned, animated .glb.  Needs only numpy + PIL.
Usage: fbx2glb.py MESH.fbx OUT.glb TEX_MAX name=anim.fbx [name=anim.fbx ...]
"""
import sys, os, json, struct, io, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from fbxparse import parse

TICKS = 46186158000.0
TARGET_HEIGHT = 1.8          # metres; mesh is scaled so the character is this tall

def pdict(n):
    d = {}
    p = n.first("Properties70")
    if p:
        for c in p.children:
            d[c.props[0]] = c.props[4:]
    return d

def nm(s):                    # "mixamorig:Hips\x00\x01Model" -> "mixamorig_Hips"
    return s.split("\x00")[0].replace(":", "_")

def rx(a): c, s = math.cos(a), math.sin(a); return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def ry(a): c, s = math.cos(a), math.sin(a); return np.array([[c,0,s],[0,1,0],[-s,0,c]])
def rz(a): c, s = math.cos(a), math.sin(a); return np.array([[c,-s,0],[s,c,0],[0,0,1]])
def euler(v):                 # FBX default order XYZ, degrees
    x, y, z = [math.radians(a) for a in v]
    return rz(z) @ ry(y) @ rx(x)

def mat_to_quat(m):
    t = m[0,0] + m[1,1] + m[2,2]
    if t > 0:
        s = math.sqrt(t + 1) * 2; q = [(m[2,1]-m[1,2])/s, (m[0,2]-m[2,0])/s, (m[1,0]-m[0,1])/s, s/4]
    elif m[0,0] > m[1,1] and m[0,0] > m[2,2]:
        s = math.sqrt(1 + m[0,0] - m[1,1] - m[2,2]) * 2; q = [s/4, (m[0,1]+m[1,0])/s, (m[0,2]+m[2,0])/s, (m[2,1]-m[1,2])/s]
    elif m[1,1] > m[2,2]:
        s = math.sqrt(1 + m[1,1] - m[0,0] - m[2,2]) * 2; q = [(m[0,1]+m[1,0])/s, s/4, (m[1,2]+m[2,1])/s, (m[0,2]-m[2,0])/s]
    else:
        s = math.sqrt(1 + m[2,2] - m[0,0] - m[1,1]) * 2; q = [(m[0,2]+m[2,0])/s, (m[1,2]+m[2,1])/s, s/4, (m[1,0]-m[0,1])/s]
    q = np.array(q); return q / np.linalg.norm(q)

def trs_mat(t, R):
    m = np.eye(4); m[:3,:3] = R; m[:3,3] = t; return m

class Rig:
    """Bones of one FBX file: parent, default local values, curves."""
    def __init__(self, path):
        self.root, _ = parse(path)
        o = self.root.first("Objects"); conn = self.root.first("Connections")
        self.models = {c.props[0]: c for c in o.children if c.name == "Model"}
        self.names = {i: nm(c.props[1]) for i, c in self.models.items()}
        self.bones = {i for i, c in self.models.items() if c.props[2] == "LimbNode"}
        self.parent = {}
        self.cnodes = {}; self.curves = {}
        for c in o.children:
            if c.name == "AnimationCurveNode": self.cnodes[c.props[0]] = c
            if c.name == "AnimationCurve": self.curves[c.props[0]] = c
        self.node_target = {}    # curvenode id -> (model id, prop)
        self.curve_of = {}       # curvenode id -> {axis: curve id}
        for c in conn.children:
            if c.props[0] == "OO" and c.props[1] in self.models and c.props[2] in self.models:
                self.parent[c.props[1]] = c.props[2]
            elif c.props[0] == "OP" and c.props[1] in self.cnodes and c.props[2] in self.models:
                self.node_target[c.props[1]] = (c.props[2], c.props[3])
            elif c.props[0] == "OP" and c.props[1] in self.curves and c.props[2] in self.cnodes:
                self.curve_of.setdefault(c.props[2], {})[c.props[3]] = c.props[1]
        self.byname = {self.names[i]: i for i in self.bones}
        self.props = {i: pdict(self.models[i]) for i in self.bones}
        for p in self.props.values():
            assert "RotationOrder" not in p and "RotationPivot" not in p, "unsupported rotation order/pivot"
        stack = [c for c in o.children if c.name == "AnimationStack"]
        self.stop = pdict(stack[0]).get("LocalStop", [0])[0] if stack else 0
    def pre(self, i):
        v = self.props[i].get("PreRotation"); return euler(v) if v else np.eye(3)
    def default(self, i, prop):
        d = {"Lcl Translation": [0,0,0], "Lcl Rotation": [0,0,0]}[prop]
        v = self.props[i].get(prop); return np.array(v if v else d, float)
    def sample(self, fps):
        """-> n_frames, {bone_id: {'Lcl Rotation': (n,3), 'Lcl Translation': (n,3)}} (degrees / cm)"""
        dur = self.stop / TICKS
        n = max(2, int(round(dur * fps)) + 1)
        times = np.arange(n) / fps
        out = {i: {} for i in self.bones}
        for cn, (mid, prop) in self.node_target.items():
            if mid not in self.bones or prop not in ("Lcl Rotation", "Lcl Translation"): continue
            arr = np.tile(self.default(mid, prop), (n, 1))
            for ax, cid in self.curve_of.get(cn, {}).items():
                k = "XYZ".index(ax[-1])
                c = self.curves[cid]
                kt = np.array(c.first("KeyTime").props[0], float) / TICKS
                kv = np.array(c.first("KeyValueFloat").props[0], float)
                arr[:, k] = np.interp(times, kt, kv)
            out[mid][prop] = arr
        return n, out

# ------------------------------------------------------------------------------------------
def main(mesh_path, out_path, tex_max, anim_args):
    tr = Rig(mesh_path)
    o = tr.root.first("Objects"); conn = tr.root.first("Connections")

    # ---- skeleton order (parents before children) ---------------------------------------------------
    order = []
    def visit(i):
        order.append(i)
        for j in sorted([b for b in tr.bones if tr.parent.get(b) == i], key=lambda b: tr.names[b]): visit(j)
    roots = [b for b in tr.bones if tr.parent.get(b) not in tr.bones]
    assert len(roots) == 1, roots
    visit(roots[0])
    idx = {b: k for k, b in enumerate(order)}

    # ---- bind pose from the clusters' TransformLink (authoritative), converted Z-up -> Y-up ------------
    cl = {c.props[0]: c for c in o.children if c.name == "Deformer" and c.props[2] == "Cluster"}
    skin = [c for c in o.children if c.name == "Deformer" and c.props[2] == "Skin"][0]
    link, tmat, cluster_of_bone = {}, {}, {}
    for c in conn.children:
        if c.props[0] == "OO" and c.props[1] in tr.bones and c.props[2] in cl:
            k = cl[c.props[2]]
            link[c.props[1]] = np.array(k.first("TransformLink").props[0]).reshape(4, 4).T
            tmat[c.props[1]] = np.array(k.first("Transform").props[0]).reshape(4, 4).T
            cluster_of_bone[c.props[1]] = k
    C = np.eye(4); C[:3, :3] = rx(-math.pi / 2)        # Z-up (tripo) -> Y-up
    hips = roots[0]
    assert np.allclose(link[hips][:3, :3], rx(math.pi / 2), atol=1e-4), "unexpected hips bind rotation"
    # local rest transforms
    local_t, local_r = {}, {}
    for b in order:
        local_t[b] = tr.default(b, "Lcl Translation")
        local_r[b] = tr.pre(b) @ euler(tr.default(b, "Lcl Rotation"))
    gh = C @ link[hips]
    local_t[hips] = gh[:3, 3]; local_r[hips] = gh[:3, :3]
    # verify against every cluster bind matrix
    glob = {}
    for b in order:
        m = trs_mat(local_t[b], local_r[b])
        glob[b] = m if tr.parent.get(b) not in tr.bones else glob[tr.parent[b]] @ m
    worst = 0
    for b, L in link.items():
        worst = max(worst, np.abs(glob[b] - C @ L).max())
    print("bind pose check: max abs diff vs TransformLink = %.5f (cm)" % worst)
    assert worst < 0.05, "skeleton does not reproduce bind pose"

    # ---- mesh ------------------------------------------------------------------------------------------
    g = [c for c in o.children if c.name == "Geometry"][0]
    V = np.array(g.first("Vertices").props[0]).reshape(-1, 3)
    PI = np.array(g.first("PolygonVertexIndex").props[0], np.int64)
    ln = g.first("LayerElementNormal"); lu = g.first("LayerElementUV")
    N = np.array(ln.first("Normals").props[0]).reshape(-1, 3)
    Ni = np.array(ln.first("NormalsIndex").props[0]) if ln.first("NormalsIndex") else None
    U = np.array(lu.first("UV").props[0]).reshape(-1, 2)
    Ui = np.array(lu.first("UVIndex").props[0])
    corner_v = np.where(PI < 0, -PI - 1, PI)
    n_corner = len(PI)
    corner_n = N[Ni] if Ni is not None else N[:n_corner]
    corner_u = U[Ui]
    # triangulate polygon fans
    tris = []; start = 0
    for k in range(n_corner):
        if PI[k] < 0:
            poly = list(range(start, k + 1)); start = k + 1
            for a in range(1, len(poly) - 1): tris.append((poly[0], poly[a], poly[a + 1]))
    tris = np.array(tris)
    # unique vertices
    key = np.concatenate([corner_v[:, None].astype(np.float64), np.round(corner_n, 4), np.round(corner_u, 5)], axis=1)
    uniq, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.reshape(-1)
    pos = V[corner_v[first]]; nor = corner_n[first]; uv = corner_u[first].copy(); uv[:, 1] = 1 - uv[:, 1]
    src = corner_v[first]
    indices = inv[tris.reshape(-1)].astype(np.uint32)
    nor = nor / np.maximum(np.linalg.norm(nor, axis=1, keepdims=True), 1e-9)
    # skin weights: top 4 per vertex
    wsum = [[] for _ in range(len(V))]
    for b, k in cluster_of_bone.items():
        ii = k.first("Indexes"); ww = k.first("Weights")
        if ii is None: continue
        for vi, w in zip(ii.props[0], ww.props[0]):
            wsum[vi].append((idx[b], float(w)))
    J = np.zeros((len(V), 4), np.uint16); W = np.zeros((len(V), 4), np.float32)
    for vi, lst in enumerate(wsum):
        lst = sorted(lst, key=lambda t: -t[1])[:4]
        tot = sum(w for _, w in lst)
        if tot <= 0: lst, tot = [(idx[hips], 1.0)], 1.0
        for s, (j, w) in enumerate(lst): J[vi, s] = j; W[vi, s] = w / tot
    J, W = J[src], W[src]
    # scale to metres: tripo mesh is Y-up with height ~100 in its own units
    height = pos[:, 1].max() - pos[:, 1].min()
    S = TARGET_HEIGHT / height
    pos = pos * S
    print("mesh: %d verts, %d tris, height %.2f -> scale %.5f" % (len(pos), len(indices) // 3, height, S))
    for b in order: local_t[b] = local_t[b] * S
    glob = {}
    for b in order:
        m = trs_mat(local_t[b], local_r[b])
        glob[b] = m if tr.parent.get(b) not in tr.bones else glob[tr.parent[b]] @ m
    ibm = [np.linalg.inv(glob[b]) for b in order]
    # sanity: Y-up world bind: feet near y=0
    foot = glob[tr.byname["mixamorig_LeftFoot"]][:3, 3]; print("left foot bind pos (m):", np.round(foot, 3), " hips:", np.round(glob[hips][:3, 3], 3))
    # cross-check IBM with the file's own Transform matrices (scaled)
    Sm = np.diag([S, S, S, 1.0]); worst = 0
    for b, T in tmat.items():
        expect = Sm @ T @ np.linalg.inv(Sm)
        worst = max(worst, np.abs(ibm[idx[b]] - expect).max())
    print("IBM check vs file Transform: max abs diff = %.5f" % worst)

    # ---- texture ----------------------------------------------------------------------------------------
    from PIL import Image
    vid = [c for c in o.children if c.name == "Video" and c.first("Content") and len(c.first("Content").props[0]) > 100][0]
    img = Image.open(io.BytesIO(vid.first("Content").props[0])); print("texture:", img.size, img.mode)
    if max(img.size) > tex_max:
        r = tex_max / max(img.size); img = img.resize((int(img.width * r), int(img.height * r)), Image.LANCZOS)
    img = img.convert("RGB")
    tb = io.BytesIO(); img.save(tb, "JPEG", quality=90); tex_bytes = tb.getvalue()
    print("texture embedded: %s, %d KB" % (img.size, len(tex_bytes) // 1024))

    # ---- animations -----------------------------------------------------------------------------------
    FPS = 30
    anims = []
    nodes_names = [tr.names[b] for b in order]
    for spec in anim_args:
        name, path = spec.split("=", 1)
        ar = Rig(path)
        n, data = ar.sample(FPS)
        times = (np.arange(n) / FPS).astype(np.float32)
        hips_a = ar.byname["mixamorig_Hips"]
        # Y-up cm hips translation -> tripo rig scale; strip horizontal root motion (the game moves the body)
        ht = data[hips_a]["Lcl Translation"].copy()
        vert_scale = (glob[hips][1, 3] / S) / ar.default(hips_a, "Lcl Translation")[1]
        ramp = np.linspace(0, 1, n)[:, None]
        for ax in (0, 2):
            col = ht[:, ax]; col = col - (col[-1] - col[0]) * ramp[:, 0] - col[0]; ht[:, ax] = col
        base = local_t[hips] / S
        hips_t = np.stack([base[0] + ht[:, 0] * vert_scale, ht[:, 1] * vert_scale, base[2] + ht[:, 2] * vert_scale], 1) * S
        chans = []
        chans.append((idx[hips], "translation", times, hips_t.astype(np.float32)))
        for b in order:
            bid = ar.byname[tr.names[b]]
            eul = data[bid].get("Lcl Rotation")
            if eul is None: eul = np.tile(ar.default(bid, "Lcl Rotation"), (n, 1))
            qs = np.array([mat_to_quat(ar.pre(bid) @ euler(e)) for e in eul])
            for k in range(1, n):
                if np.dot(qs[k], qs[k - 1]) < 0: qs[k] = -qs[k]
            if np.abs(qs - qs[0]).max() < 1e-6:
                chans.append((idx[b], "rotation", times[:1], qs[:1].astype(np.float32)))
            else:
                chans.append((idx[b], "rotation", times, qs.astype(np.float32)))
        if name == "idle":   # synthesize a 2 s breathing loop from the first (standing) frame
            N = 61; tt = (np.arange(N) / FPS).astype(np.float32); ph = 2 * math.pi * np.arange(N) / (N - 1)
            new = []
            for node, path, t, v in chans:
                if path == "translation":
                    vv = np.tile(v[0], (N, 1)); vv[:, 1] += 0.004 * np.sin(ph); new.append((node, path, tt, vv.astype(np.float32)))
                else:
                    q0 = v[0]; bn = nodes_names[node]
                    amp = {"mixamorig_Spine1": 1.5, "mixamorig_Spine2": 1.5, "mixamorig_Neck": -1.0}.get(bn, 0.0)
                    if amp == 0.0: new.append((node, path, t[:1], v[:1])); continue
                    qs = []
                    for a_ in ph:
                        h = math.radians(amp * math.sin(a_)) / 2; dq = np.array([math.sin(h), 0, 0, math.cos(h)])
                        x1, y1, z1, w1 = q0; x2, y2, z2, w2 = dq    # q0 * dq
                        qs.append([w1*x2+x1*w2+y1*z2-z1*y2, w1*y2-x1*z2+y1*w2+z1*x2, w1*z2+x1*y2-y1*x2+z1*w2, w1*w2-x1*x2-y1*y2-z1*z2])
                    new.append((node, path, tt, np.array(qs, np.float32)))
            chans = new; n = N
        anims.append((name, chans))
        print("anim %-14s %3d frames %.2fs  <- %s" % (name, n, (n - 1) / FPS, os.path.basename(path)))

    # ---- assemble glTF ----------------------------------------------------------------------------------
    blob = bytearray(); views = []; accs = []
    def add_view(data, target=None):
        while len(blob) % 4: blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), **({"target": target} if target else {})})
        blob.extend(data); return len(views) - 1
    def add_acc(arr, ctype, typ, target=None, minmax=False):
        bv = add_view(np.ascontiguousarray(arr).tobytes(), target)
        a = {"bufferView": bv, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
        if minmax: a["min"] = [float(x) for x in np.atleast_2d(arr).min(0)]; a["max"] = [float(x) for x in np.atleast_2d(arr).max(0)]
        accs.append(a); return len(accs) - 1
    F, US, UI = 5126, 5123, 5125
    a_pos = add_acc(pos.astype(np.float32), F, "VEC3", 34962, True)
    a_nor = add_acc(nor.astype(np.float32), F, "VEC3", 34962)
    a_uv = add_acc(uv.astype(np.float32), F, "VEC2", 34962)
    a_j = add_acc(J, US, "VEC4", 34962)
    a_w = add_acc(W, F, "VEC4", 34962)
    a_i = add_acc(indices.reshape(-1, 1)[:, 0], UI, "SCALAR", 34963)
    ibm_arr = np.array([m.T for m in ibm], np.float32).reshape(-1, 16)       # glTF column-major
    a_ibm = add_acc(ibm_arr, F, "MAT4")
    img_view = add_view(tex_bytes)
    nodes = []
    for b in order:
        q = mat_to_quat(local_r[b])
        nodes.append({"name": tr.names[b], "translation": [float(x) for x in local_t[b]], "rotation": [float(x) for x in q]})
    for b in order:
        kids = [idx[c] for c in order if tr.parent.get(c) == b]
        if kids: nodes[idx[b]]["children"] = kids
    mesh_node = len(nodes)
    nodes.append({"name": "parashurama_mesh", "mesh": 0, "skin": 0})
    gl_anims = []
    for name, chans in anims:
        samplers, channels = [], []
        for node, path, t, v in chans:
            ai = add_acc(t.reshape(-1), F, "SCALAR", None, True)
            ao = add_acc(v, F, "VEC3" if path == "translation" else "VEC4")
            samplers.append({"input": ai, "output": ao, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": path}})
        gl_anims.append({"name": name, "samplers": samplers, "channels": channels})
    gltf = {
        "asset": {"version": "2.0", "generator": "fbx2glb.py (Parashurama project)"},
        "scene": 0, "scenes": [{"name": "Scene", "nodes": [0, mesh_node]}],
        "nodes": nodes,
        "skins": [{"name": "Armature", "joints": list(range(len(order))), "inverseBindMatrices": a_ibm, "skeleton": 0}],
        "meshes": [{"name": "parashurama", "primitives": [{"attributes": {"POSITION": a_pos, "NORMAL": a_nor, "TEXCOORD_0": a_uv, "JOINTS_0": a_j, "WEIGHTS_0": a_w}, "indices": a_i, "material": 0}]}],
        "materials": [{"name": "body", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 0.85}}],
        "textures": [{"source": 0, "sampler": 0}], "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "images": [{"bufferView": img_view, "mimeType": "image/jpeg", "name": "parashurama_basecolor"}],
        "animations": gl_anims, "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(blob)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    while len(js) % 4: js += b" "
    while len(blob) % 4: blob.append(0)
    with open(out_path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(blob), 0x004E4942)); f.write(bytes(blob))
    print("wrote", out_path, os.path.getsize(out_path) // 1024, "KB")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4:])
