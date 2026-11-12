import re,os,sys,json
root=sys.argv[1]
errs=[];warn=[]
files=[os.path.join(d,f) for d,_,fs in os.walk(root) for f in fs]
def rel(p): return os.path.relpath(p,root)
gd=[f for f in files if f.endswith('.gd')]
scn=[f for f in files if f.endswith(('.tscn','.tres'))]
# 1 resource refs
for f in scn:
    t=open(f).read()
    for m in re.finditer(r'path="res://([^"]+)"',t):
        if not os.path.exists(os.path.join(root,m.group(1))): errs.append(f"{rel(f)}: missing {m.group(1)}")
    # ext ids used exist
    ids=set(re.findall(r'\[ext_resource[^\]]*id="([^"]+)"',t))
    subs=set(re.findall(r'\[sub_resource[^\]]*id="([^"]+)"',t))
    for m in re.finditer(r'ExtResource\("([^"]+)"\)',t):
        if m.group(1) not in ids: errs.append(f"{rel(f)}: undefined ExtResource {m.group(1)}")
    for m in re.finditer(r'SubResource\("([^"]+)"\)',t):
        if m.group(1) not in subs: errs.append(f"{rel(f)}: undefined SubResource {m.group(1)}")
    # sub resource declared before use
    pos={}
    for m in re.finditer(r'\[sub_resource[^\]]*id="([^"]+)"',t): pos[m.group(1)]=m.start()
    for m in re.finditer(r'SubResource\("([^"]+)"\)',t):
        if m.group(1) in pos and pos[m.group(1)]>m.start(): errs.append(f"{rel(f)}: SubResource {m.group(1)} used before declaration")
# project.godot
p=open(os.path.join(root,'project.godot')).read()
for m in re.finditer(r'res://[^"]+',p):
    if not os.path.exists(os.path.join(root,m.group(0)[6:])): errs.append("project.godot missing "+m.group(0))
# 2 load/preload paths in scripts
classes={}
for f in gd:
    t=open(f).read()
    m=re.search(r'^class_name (\w+)',t,re.M)
    if m: classes[m.group(1)]=f
    for m in re.finditer(r'(?:load|preload)\("res://([^"]+)"\)',t):
        if not os.path.exists(os.path.join(root,m.group(1))): errs.append(f"{rel(f)}: load missing {m.group(1)}")
    for m in re.finditer(r'"res://([^"]+\.(?:json|tscn|tres|gd))"',t):
        if not os.path.exists(os.path.join(root,m.group(1))): errs.append(f"{rel(f)}: path missing {m.group(1)}")
# 3 syntax heuristics
autoloads=set(re.findall(r'^(\w+)="\*res',p,re.M))
builtin=set("Vector2 Vector3 Vector2i Color Transform3D Basis Node Node3D Control Label Button Tween Input InputMap Time ProjectSettings Geometry2D Rect2 Array Dictionary String PackedVector3Array PackedFloat32Array PackedColorArray PackedInt32Array PackedStringArray PackedVector2Array PackedInt32Array ArrayMesh Mesh MultiMesh MultiMeshInstance3D MeshInstance3D StaticBody3D CollisionShape3D BoxShape3D CylinderShape3D SphereShape3D CapsuleShape3D RandomNumberGenerator FastNoiseLite Environment Sky ProceduralSkyMaterial DirectionalLight3D OmniLight3D WorldEnvironment CharacterBody3D Camera3D Label3D BaseMaterial3D StandardMaterial3D ShaderMaterial Material Shader PackedScene Resource FileAccess JSON ResourceLoader GeometryInstance3D Vector4 Variant Object Font ThemeDB TextServer StyleBoxFlat PanelContainer VBoxContainer ColorRect CanvasLayer Viewport PhysicsDirectSpaceState3D PhysicsRayQueryParameters3D Engine Shape3D Node2D InputEvent InputEventKey InputEventScreenTouch InputEventScreenDrag InputEventMouseButton InputEventMouseMotion Callable Signal RefCounted Rect2i Vector2i Transform2D Mesh".split())
for f in gd:
    t=open(f).read(); n=rel(f)
    # indentation
    for i,l in enumerate(t.split('\n'),1):
        if re.match(r'^ +\S',l): errs.append(f"{n}:{i}: space indentation")
    # brackets balanced (ignoring strings)
    s=re.sub(r'"(?:\\.|[^"\\])*"','""',t); s=re.sub(r'#.*','',s)
    for a,b in ['()','[]','{}']:
        if s.count(a)!=s.count(b): errs.append(f"{n}: unbalanced {a}{b} {s.count(a)} vs {s.count(b)}")
    # := with likely variant source
    for i,l in enumerate(t.split('\n'),1):
        if ':=' in l and re.search(r'\.get\(|\[".*"\]|\.call\(|\.values\(\)|get_meta',l): warn.append(f"{n}:{i}: ':=' on possible Variant: {l.strip()}")
    # duplicate func names
    fn=re.findall(r'^\s*(?:static )?func (\w+)',t,re.M)
    d=[x for x in set(fn) if fn.count(x)>1]
    if d: errs.append(f"{n}: duplicate funcs {d}")
    # unknown capitalized type refs
    for m in re.finditer(r'(?:\bas |: |-> |\bis |extends )([A-Z]\w+)',t):
        c=m.group(1)
        if c not in classes and c not in builtin and c not in autoloads and not re.match(r'^[A-Z_]+$',c):
            # maybe inner class or enum
            if not re.search(r'class '+c,t): warn.append(f"{n}: unknown type {c}")
    for m in re.finditer(r'\b([A-Z]\w+)\.(?:new|get_|build|height_at|configure|add_|clear|is_|load_json)',t):
        c=m.group(1)
        if c not in classes and c not in builtin and c not in autoloads: warn.append(f"{n}: unknown ident {c}")
# 4 node paths
def nodes(sc):
    t=open(os.path.join(root,sc)).read()
    out=set()
    for m in re.finditer(r'\[node name="([^"]+)"(?: type="[^"]*")?(?: parent="([^"]*)")?',t):
        nm,par=m.group(1),m.group(2)
        out.add(nm if par is None else (nm if par=='.' else par+'/'+nm))
    return out
chk={'Scripts/World/WorldManager.gd':'Scenes/World.tscn','Scripts/Player/PlayerController.gd':'Scenes/Player.tscn','Scripts/Player/CameraController.gd':'Scenes/Player.tscn','Scripts/Main.gd':'Scenes/Main.tscn'}
for g,s in chk.items():
    ns=nodes(s)
    for m in re.finditer(r'\$([\w/]+)',open(os.path.join(root,g)).read()):
        if m.group(1) not in ns: errs.append(f"{g}: node ${m.group(1)} not in {s} ({sorted(ns)})")
print("classes:",len(classes),"scripts:",len(gd),"scenes:",len(scn))
print("ERRORS:",len(errs));[print(" ",e) for e in errs]
print("WARNINGS:",len(warn));[print(" ",w) for w in warn]
