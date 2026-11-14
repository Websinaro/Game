#!/usr/bin/env python3
"""Static validator for the Parashurama Godot project (no Godot needed).
Usage: python3 tools/validate_project.py [project_root]
It can NOT replace opening the project in Godot: it only catches mistakes that are visible in text."""
import re, os, sys, json
root = sys.argv[1] if len(sys.argv) > 1 else "."
errs, warn = [], []
files = [os.path.join(d, f) for d, _, fs in os.walk(root) for f in fs if ".git" not in d and ".godot" not in d]
rel = lambda p: os.path.relpath(p, root)
gd = [f for f in files if f.endswith(".gd")]
scn = [f for f in files if f.endswith((".tscn", ".tres"))]
shaders = [f for f in files if f.endswith(".gdshader")]
# files the user supplies themselves; missing is allowed ONLY because scripts guard them at runtime
OPTIONAL = {"Assets/Models/parashurama.glb"}
def exists(path): return os.path.exists(os.path.join(root, path)) or path in OPTIONAL

# 1 resource refs in scenes/resources
for f in scn:
    t = open(f).read()
    for m in re.finditer(r'path="res://([^"]+)"', t):
        if not exists(m.group(1)): errs.append(f"{rel(f)}: missing {m.group(1)}")
    ids = set(re.findall(r'\[ext_resource[^\]]*id="([^"]+)"', t))
    subs = set(re.findall(r'\[sub_resource[^\]]*id="([^"]+)"', t))
    for m in re.finditer(r'ExtResource\("([^"]+)"\)', t):
        if m.group(1) not in ids: errs.append(f"{rel(f)}: undefined ExtResource {m.group(1)}")
    pos = {m.group(1): m.start() for m in re.finditer(r'\[sub_resource[^\]]*id="([^"]+)"', t)}
    for m in re.finditer(r'SubResource\("([^"]+)"\)', t):
        if m.group(1) not in subs: errs.append(f"{rel(f)}: undefined SubResource {m.group(1)}")
        elif pos[m.group(1)] > m.start(): errs.append(f"{rel(f)}: SubResource {m.group(1)} used before declaration")
    m = re.search(r'load_steps=(\d+)', t)
    if m and int(m.group(1)) != len(ids) + len(subs) + 1: warn.append(f"{rel(f)}: load_steps={m.group(1)} but {len(ids)+len(subs)+1} expected (harmless)")
p = open(os.path.join(root, "project.godot")).read()
for m in re.finditer(r'res://[^"]+', p):
    if not exists(m.group(0)[6:]): errs.append("project.godot missing " + m.group(0))

# 2 scripts
classes, autoloads = {}, set(re.findall(r'^(\w+)="\*res', p, re.M))
def strip(t):
    t = re.sub(r'"(?:\\.|[^"\\])*"', '""', t)
    return re.sub(r'#.*', '', t)
for f in gd:
    t = open(f).read()
    m = re.search(r'^class_name (\w+)', t, re.M)
    if m: classes[m.group(1)] = f
    for m in re.finditer(r'(?:load|preload)\("res://([^"]+)"\)', t):
        if not exists(m.group(1)): errs.append(f"{rel(f)}: load missing {m.group(1)}")
    for m in re.finditer(r'"res://([^"]+\.(?:json|tscn|tres|gd|gdshader))"', t):
        if not exists(m.group(1)): errs.append(f"{rel(f)}: path missing {m.group(1)}")
for a in autoloads:
    if a in classes: errs.append(f"autoload {a} also has class_name (Godot refuses this)")
builtin = set("""Vector2 Vector3 Vector2i Vector3i Vector4 Color Transform3D Transform2D Basis Quaternion AABB Plane Node Node3D Node2D Control Label Button Tween Input InputMap Time ProjectSettings Geometry2D Rect2 Rect2i Array Dictionary String StringName NodePath PackedVector3Array PackedFloat32Array PackedColorArray PackedInt32Array PackedStringArray PackedVector2Array ArrayMesh Mesh MultiMesh MultiMeshInstance3D MeshInstance3D StaticBody3D CollisionShape3D BoxShape3D CylinderShape3D SphereShape3D CapsuleShape3D RandomNumberGenerator FastNoiseLite Environment Sky ProceduralSkyMaterial DirectionalLight3D OmniLight3D WorldEnvironment CharacterBody3D Camera3D Label3D BaseMaterial3D StandardMaterial3D ShaderMaterial Material Shader PackedScene Resource FileAccess JSON ResourceLoader GeometryInstance3D Variant Object Font ThemeDB TextServer StyleBoxFlat PanelContainer VBoxContainer ColorRect CanvasLayer Viewport PhysicsDirectSpaceState3D PhysicsRayQueryParameters3D Engine Shape3D InputEvent InputEventKey InputEventScreenTouch InputEventScreenDrag InputEventMouseButton InputEventMouseMotion Callable Signal RefCounted Key Error ConfigFile AnimationPlayer Animation Skeleton3D Texture2D TextureRect GradientTexture2D Gradient CylinderMesh Terrain3D Tween Control""".split())
for f in gd:
    raw = open(f).read(); n = rel(f); t = strip(raw)
    lines = raw.split("\n")
    for i, l in enumerate(lines, 1):
        if re.match(r"^ +\S", l): errs.append(f"{n}:{i}: space indentation")
    for a, b in ["()", "[]", "{}"]:
        if t.count(a) != t.count(b): errs.append(f"{n}: unbalanced {a}{b} {t.count(a)} vs {t.count(b)}")
    for i, l in enumerate(lines, 1):
        c = strip(l)
        if ":=" in c and re.search(r'\.get\(|\.call\(|\.values\(\)|get_meta|get_value|\.pop_|\[[^\]]*\]\s*$', c):
            errs.append(f"{n}:{i}: ':=' on possible Variant: {l.strip()}")
        if re.match(r"^const \w+\s*(:\s*[\w\[\]]+)?\s*=\s*Packed\w+Array\(", c): errs.append(f"{n}:{i}: const with Packed*Array constructor (use typed Array literal)")
        if re.match(r"^\s*signal notification\b", c): errs.append(f"{n}:{i}: signal named 'notification' clashes with Node")
        if re.search(r"\bfunc \w+\(.*\b(?<![_\w])unused\w*:", c): warn.append(f"{n}:{i}: parameter named unused* without leading underscore")
    fn = re.findall(r"^\s*(?:static )?func (\w+)", raw, re.M)
    # nested classes may legitimately repeat names, so only flag top-level duplicates
    top = re.findall(r"^(?:static )?func (\w+)", raw, re.M)
    d = [x for x in set(top) if top.count(x) > 1]
    if d: errs.append(f"{n}: duplicate funcs {d}")
    inner = set(re.findall(r"^class (\w+)", raw, re.M)) | set(re.findall(r"^enum (\w+)", raw, re.M))
    for m in re.finditer(r"(?:\bas |: |-> |\bis |extends )([A-Z]\w+)", t):
        c = m.group(1)
        if c not in classes and c not in builtin and c not in autoloads and c not in inner and not re.match(r"^[A-Z_0-9]+$", c):
            warn.append(f"{n}: unknown type {c}")
    for m in re.finditer(r"\b([A-Z]\w+)\.(?:new|get_|build|height_at|configure|add_|clear|is_|load_json|pick_|apply_)", t):
        c = m.group(1)
        if c not in classes and c not in builtin and c not in autoloads and c not in inner: warn.append(f"{n}: unknown ident {c}")
    # Tuning.X / GameSettings.X references
    for m in re.finditer(r"\bTuning\.([A-Z_0-9]+)", t):
        if not re.search(r"^const " + m.group(1) + r"\b", open(os.path.join(root, "Scripts/Core/Tuning.gd")).read(), re.M):
            errs.append(f"{n}: Tuning.{m.group(1)} does not exist")
    # int division
    for i, l in enumerate(lines, 1):
        c = strip(l)
        if re.search(r"\)\s*/\s*\d+(?!\.)\b", c) and "float(" not in c and "int(" not in c: warn.append(f"{n}:{i}: possible integer division: {l.strip()}")

# 3 scene node paths used by scripts ($Name is relative to the node that owns the script)
def scene_nodes(sc):
    t = open(os.path.join(root, sc)).read(); out = {}
    for m in re.finditer(r'\[node name="([^"]+)"(?: type="[^"]*")?(?: parent="([^"]*)")?[^\]]*\]', t):
        nm, par = m.group(1), m.group(2)
        path = "" if par is None else (nm if par == "." else par + "/" + nm)
        out[path] = nm
    return out
checks = [("Scripts/World/WorldManager.gd", "Scenes/World.tscn", ""), ("Scripts/Player/PlayerController.gd", "Scenes/Player.tscn", ""),
          ("Scripts/Player/CameraController.gd", "Scenes/Player.tscn", "CameraRig/"), ("Scripts/Main.gd", "Scenes/Main.tscn", "")]
for g, s, prefix in checks:
    ns = scene_nodes(s)
    for m in re.finditer(r"\$([\w/]+)", strip(open(os.path.join(root, g)).read())):
        if prefix + m.group(1) not in ns: errs.append(f"{g}: node ${m.group(1)} not in {s}")

# 4 shaders vs materials
for sh in shaders:
    t = open(sh).read(); n = rel(sh)
    if t.count("{") != t.count("}") or t.count("(") != t.count(")"): errs.append(f"{n}: unbalanced brackets")
    if not re.search(r"^shader_type spatial;", t, re.M): errs.append(f"{n}: no shader_type")
    uniforms = set(re.findall(r"^uniform\s+\w+\s+(\w+)", t, re.M))
    for mat in scn:
        mt = open(mat).read()
        if f"res://{n.replace(os.sep, '/')}" in mt:
            for m in re.finditer(r"shader_parameter/(\w+)", mt):
                if m.group(1) not in uniforms: errs.append(f"{rel(mat)}: shader_parameter {m.group(1)} not a uniform of {n}")
    code = re.sub(r"//.*", "", t)
    for bad in re.findall(r"\b(sample|filter|input|output|half|fixed|active|patch|common)\s*[=;,)]", code):
        errs.append(f"{n}: GLSL reserved word used as identifier: {bad}")
for g in gd:
    t = open(g).read()
    for m in re.finditer(r'set_shader_parameter\("(\w+)"', t):
        if not any(m.group(1) in open(s).read() for s in shaders): errs.append(f"{rel(g)}: shader parameter {m.group(1)} in no shader")

# 5 data
for f in files:
    if f.endswith(".json"):
        try: json.load(open(f))
        except Exception as e: errs.append(f"{rel(f)}: invalid JSON {e}")
q = json.load(open(os.path.join(root, "Data/quests.json")))
ids = [o["id"] for o in q["quests"][0]["objectives"]]
ruins = open(os.path.join(root, "Scripts/Environment/AncientRuinsRegion.gd")).read()
for oid in re.findall(r'(?:complete_objective|progress_objective|is_objective_active)\("(\w+)"', "".join(open(g).read() for g in gd)):
    if oid not in ids: errs.append(f"objective id '{oid}' used in scripts but not in quests.json")
print("classes:", len(classes), "scripts:", len(gd), "scenes/resources:", len(scn), "shaders:", len(shaders))
print("ERRORS:", len(errs)); [print(" ", e) for e in errs]
print("WARNINGS:", len(warn)); [print(" ", w) for w in warn]
sys.exit(1 if errs else 0)
