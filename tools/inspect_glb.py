#!/usr/bin/env python3
"""Prints what matters about a .glb for the Parashurama project (stdlib only).
Usage: python3 tools/inspect_glb.py path/to/parashurama.glb
Reports: height / width / depth from mesh accessors (in glTF units = metres), which way the
model faces is NOT detectable here (see README), skeleton + joints, animation names and
lengths, texture sizes and triangle counts."""
import json, struct, sys

def load(path):
    data = open(path, "rb").read()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF": raise SystemExit("not a .glb file")
    off, js, bins = 12, None, b""
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off); off += 8
        chunk = data[off:off + clen]; off += clen
        if ctype == 0x4E4F534A: js = json.loads(chunk.decode("utf8"))
        elif ctype == 0x004E4942: bins = chunk
    return js, bins

def img_size(blob):
    if blob[:8] == b"\x89PNG\r\n\x1a\n": return struct.unpack(">II", blob[16:24])
    if blob[:2] == b"\xff\xd8":
        i = 2
        while i < len(blob):
            if blob[i] != 0xFF: i += 1; continue
            mk = blob[i + 1]
            if 0xC0 <= mk <= 0xCF and mk not in (0xC4, 0xC8, 0xCC):
                h, w = struct.unpack(">HH", blob[i + 5:i + 9]); return (w, h)
            i += 2 + struct.unpack(">H", blob[i + 2:i + 4])[0]
    return None

def main(path):
    g, bins = load(path)
    nodes = g.get("nodes", []); acc = g.get("accessors", [])
    print("file:", path)
    print("asset:", g.get("asset", {}).get("generator", "?"), "| glTF", g.get("asset", {}).get("version"))
    print("up axis: glTF is always +Y up; models are authored facing +Z (Godot forward is -Z => yaw 180 in CharacterModel)")
    # world transform per node (translation/scale only; rotation ignored for bounds, fine for sizes)
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []): parent[c] = i
    def world_scale_trans(i):
        s, t = [1, 1, 1], [0, 0, 0]
        chain = []
        while i is not None: chain.append(i); i = parent.get(i)
        for j in reversed(chain):
            n = nodes[j]; ns = n.get("scale", [1, 1, 1]); nt = n.get("translation", [0, 0, 0])
            t = [t[k] + s[k] * nt[k] for k in range(3)]; s = [s[k] * ns[k] for k in range(3)]
        return s, t
    lo, hi, tris = [1e18] * 3, [-1e18] * 3, 0
    for i, n in enumerate(nodes):
        if "mesh" not in n: continue
        s, t = world_scale_trans(i)
        for prim in g["meshes"][n["mesh"]]["primitives"]:
            a = acc[prim["attributes"]["POSITION"]]
            if "min" in a:
                for k in range(3):
                    v = sorted([a["min"][k] * s[k] + t[k], a["max"][k] * s[k] + t[k]])
                    lo[k] = min(lo[k], v[0]); hi[k] = max(hi[k], v[1])
            if "indices" in prim: tris += acc[prim["indices"]]["count"] // 3
            else: tris += a["count"] // 3
    if lo[0] < 1e17:
        size = [hi[k] - lo[k] for k in range(3)]
        print("bounds min=%s max=%s" % (["%.3f" % x for x in lo], ["%.3f" % x for x in hi]))
        print("size  X(width)=%.3f  Y(height)=%.3f  Z(depth)=%.3f   triangles=%d" % (size[0], size[1], size[2], tris))
        print("pivot: feet are at y=%.3f (need 0), centre x=%.3f z=%.3f" % (lo[1], (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2))
        print("auto-fit scale to 1.8 m would be %.4f" % (1.8 / size[1] if size[1] > 0 else 0))
        if size[2] > size[1] * 1.5: print("WARNING: depth > height: model may be Z-up / lying down (CharacterModel.auto_fix_z_up handles it)")
    skins = g.get("skins", [])
    for s in skins: print("skin: %d joints%s" % (len(s.get("joints", [])), " e.g. " + ", ".join(nodes[j].get("name", "?") for j in s["joints"][:6])))
    if not skins: print("no skin / skeleton")
    for a in g.get("animations", []):
        dur = 0.0
        for smp in a["samplers"]:
            ac = acc[smp["input"]]
            if "max" in ac: dur = max(dur, ac["max"][0])
        print("animation '%s'  %.2f s  %d channels" % (a.get("name", "?"), dur, len(a["channels"])))
    if not g.get("animations"): print("no animations: CharacterModel will use procedural bob/lean/sway")
    views = g.get("bufferViews", [])
    for i, im in enumerate(g.get("images", [])):
        sz = None
        if "bufferView" in im:
            v = views[im["bufferView"]]; sz = img_size(bins[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]])
        print("image %d '%s' %s %s" % (i, im.get("name", ""), im.get("mimeType", im.get("uri", "")), ("%dx%d" % sz) if sz else "(size unknown)"))
        if sz and max(sz) > 2048: print("  WARNING: texture larger than 2048 px; set Import > Size Limit")
    print("materials:", len(g.get("materials", [])), "| meshes:", len(g.get("meshes", [])), "| nodes:", len(nodes))

if __name__ == "__main__":
    if len(sys.argv) < 2: raise SystemExit(__doc__)
    main(sys.argv[1])
