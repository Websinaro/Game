#!/usr/bin/env python3
"""Bakes the Sketchfab "cave_lp" GLB into Assets/Models/cave_lp.glb for the game (needs numpy only).
Usage: python3 tools/bake_cave.py <original cave_lp_9k_free_download-compressed.glb> [output.glb]

What it does (all offline, so Godot loads a plain, ready-to-use mesh):
  1. reads the interleaved vertex data and applies the glTF node rotation (-90 deg about X),
  2. turns the cave around so the doorway faces +Z, floor plane at y = 0, doorway tip at z = 0,
  3. drops everything below the floor and adds a flat, triangulated walkable floor (from the cave outline at FLOOR_Y),
  4. cuts the doorway (an arch in the front wall, DOOR_* below),
  5. writes a new GLB with the original 3 textures and one double-sided material.
Tune: FLOOR_Y (model units, which horizontal slice becomes the floor), DOOR_HALF_W / door ellipse in the cut line.
Model units are scaled in game by CaveRegion.CAVE_SCALE."""
import sys, json, struct
import numpy as np
SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else 'Assets/Models/cave_lp.glb'
d0 = open(SRC, 'rb').read()
cl0, _ = struct.unpack('<II', d0[12:20]); j0 = json.loads(d0[20:20 + cl0]); bin0 = d0[20 + cl0 + 8:]
raw0 = np.frombuffer(bin0, dtype=np.uint8, count=460704, offset=110240).reshape(-1, 48).copy().view(np.float32).reshape(-1, 12)
N = raw0[:, 0:3]; P = raw0[:, 3:6]; TG = raw0[:, 6:10]; UV = raw0[:, 10:12]
I = np.frombuffer(bin0, dtype=np.uint16, count=55119, offset=0).reshape(-1, 3).astype(int)
YF=-1.55           # floor plane (model units, after glTF node rotation)

def rot(v):  # glTF node: -90deg about X  -> (x,y,z)->(x,z,-y); then 180deg about Y -> (-x,y,-z)
    return np.stack([-v[:,0],v[:,2],v[:,1]],1)   # (-x, z, +y)  [= -(-y)]
# check: step1 (x,z,-y) ; step2 flip x and z -> (-x, z, y)
Pw=rot(P);Nw=rot(N)
T3=TG[:,:3];Tw=np.concatenate([rot(T3),TG[:,3:4]],1)
# floor contour at YF
tri=Pw[I]
segs=[]
for t in tri:
    s=t[:,1]-YF;pts=[]
    for a,b in ((0,1),(1,2),(2,0)):
        if (s[a]>0)!=(s[b]>0):
            k=s[a]/(s[a]-s[b]);pts.append(t[a]+k*(t[b]-t[a]))
    if len(pts)==2:segs.append((pts[0][[0,2]],pts[1][[0,2]]))
# chain segments into loops
from collections import defaultdict
key=lambda p:(round(float(p[0]),4),round(float(p[1]),4))
adj=defaultdict(list)
for a,b in segs:
    adj[key(a)].append(key(b));adj[key(b)].append(key(a))
seen=set();loops=[]
for st in list(adj):
    if st in seen:continue
    loop=[st];seen.add(st);cur=st;prev=None
    while True:
        nxt=[n for n in adj[cur] if n!=prev and n not in seen]
        if not nxt:break
        prev=cur;cur=nxt[0];seen.add(cur);loop.append(cur)
    loops.append(loop)
loops.sort(key=len,reverse=True)
print('loops',[len(l) for l in loops[:5]])
poly=np.array(loops[0])
# polygon area sign
def area(p):return 0.5*np.sum(p[:,0]*np.roll(p[:,1],-1)-np.roll(p[:,0],-1)*p[:,1])
if area(poly)<0:poly=poly[::-1]
print('floor poly bounds',poly.min(0),poly.max(0),'area',area(poly))
# simplify: drop near-duplicate points
keep=[0]
for i in range(1,len(poly)):
    if np.linalg.norm(poly[i]-poly[keep[-1]])>0.02:keep.append(i)
poly=poly[keep]
print('poly pts',len(poly))
# ear clipping (CCW)
def ear_clip(poly):
    idx=list(range(len(poly)));tris=[]
    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    def inside(p,a,b,c):
        return cross(a,b,p)>=-1e-12 and cross(b,c,p)>=-1e-12 and cross(c,a,p)>=-1e-12
    guard=0
    while len(idx)>3 and guard<100000:
        guard+=1;ear=False
        for k in range(len(idx)):
            i0,i1,i2=idx[k-1],idx[k],idx[(k+1)%len(idx)]
            a,b,c=poly[i0],poly[i1],poly[i2]
            if cross(a,b,c)<=1e-12:continue
            if any(inside(poly[j],a,b,c) for j in idx if j not in (i0,i1,i2)):continue
            tris.append((i0,i1,i2));idx.pop(k);ear=True;break
        if not ear:
            # degenerate: drop a vertex
            idx.pop(0)
    if len(idx)==3:tris.append(tuple(idx))
    return tris
ft=ear_clip(poly)
print('floor tris',len(ft),'expected',len(poly)-2)
# ---- entrance: furthest +z of the floor polygon (after flip entrance is +z)
imax=np.argmax(poly[:,1]);print('front-most floor point',poly[imax])
# centre x of chamber 1 front: average x of polygon points with z>max-1.0
front=poly[poly[:,1]>poly[:,1].max()-0.8]
cx_front=float(front[:,0].mean());zfront=float(poly[:,1].max())
print('front cx',cx_front,'zfront',zfront)
# recentre: x so that front doorway at x=0 ; z so that front wall plane (zfront) is z=0 -> dome extends toward -z
ox,oz=cx_front,zfront
def tf(v):
    v=v.copy();v[:,0]-=ox;v[:,1]-=YF;v[:,2]-=oz;return v
Pb=tf(Pw)
polyb=poly-np.array([ox,oz])
# drop tris centroid below floor
cen=Pb[I].mean(1)
keep=cen[:,1]>0.02
# doorway cut: ellipse in x-y, along z in [-0.75,+inf)
DX,DY,DH=0.46,0.95,0.15   # half width, half height, centre-height offset -> centre y = DY-0.0
cy=0.85
inelp=((cen[:,0]/DX)**2+((cen[:,1]-0.30)/0.55)**2<1.0)&(cen[:,2]>-0.65)
keep&=~inelp
I2=I[keep]
print('tris kept',len(I2),'door-cut removed',int((inelp&(cen[:,1]>0.02)).sum()))
used=np.unique(I2);rm=-np.ones(len(Pb),int);rm[used]=np.arange(len(used))
Vp=Pb[used].astype(np.float32);Vn=Nw[used].astype(np.float32);Vt=Tw[used].astype(np.float32);Vuv=UV[used].astype(np.float32)
Ii=rm[I2].astype(np.uint32)
# floor verts
fv=np.array([[p[0],0.0,p[1]] for p in polyb],np.float32)
fn=np.tile(np.array([0,1,0],np.float32),(len(fv),1))
ft_=np.tile(np.array([1,0,0,1],np.float32),(len(fv),1))
fuv=np.stack([fv[:,0]*0.35,fv[:,2]*0.35],1).astype(np.float32)
Fi=np.array(ft,np.uint32)
# make floor tris face up (normal +y): check winding
a,b,c=fv[Fi[:,0]],fv[Fi[:,1]],fv[Fi[:,2]]
nrm=np.cross(b-a,c-a)
flip=nrm[:,1]<0
Fi[flip]=Fi[flip][:,[0,2,1]]
print('floor flipped',int(flip.sum()))
# ---------- layout info
info={'floor_poly_bounds':[float(polyb[:,0].min()),float(polyb[:,1].min()),float(polyb[:,0].max()),float(polyb[:,1].max())],
 'ceiling_y':float(Vp[:,1].max()),'door_half_w':DX,'door_cy':cy,'door_half_h':0.9}
# neck: find z where floor-polygon x-width is minimal between 25% and 75% of length
zs=np.linspace(polyb[:,1].min()+0.3,polyb[:,1].max()-0.3,60)
widths=[]
for zq in zs:
    xs=[]
    n=len(polyb)
    for i in range(n):
        p,q=polyb[i],polyb[(i+1)%n]
        if (p[1]-zq)*(q[1]-zq)<0:
            xs.append(p[0]+(zq-p[1])/(q[1]-p[1])*(q[0]-p[0]))
    widths.append((zq,min(xs),max(xs),max(xs)-min(xs)) if len(xs)>=2 else (zq,0,0,0))
for w in widths[::4]:print('z %.2f x[%.2f,%.2f] w %.2f'%w)
info['widths']=[[round(a,3),round(b,3),round(c,3),round(d,3)] for a,b,c,d in widths]
# ceiling height per z
cz=[]
for zq in zs[::4]:
    m=np.abs(Vp[:,2]-zq)<0.15
    cz.append((round(float(zq),2),round(float(Vp[m,1].max()),2)))
print('ceiling per z',cz)
# ---------- write GLB
imgs=[]
j=j0;bin_=bin0
for im in j['images']:
    bv=j['bufferViews'][im['bufferView']];imgs.append(bin_[bv['byteOffset']:bv['byteOffset']+bv['byteLength']])
def pad(b,c=b'\x00'):return b+c*((4-len(b)%4)%4)
chunks=[];views=[];accs=[]
def add_view(data,target=None,stride=None):
    off=sum(len(c) for c in chunks)
    chunks.append(pad(data));v={'buffer':0,'byteOffset':off,'byteLength':len(data)}
    if target:v['target']=target
    if stride:v['byteStride']=stride
    views.append(v);return len(views)-1
def add_acc(view,off,ct,count,typ,mn=None,mx=None):
    a={'bufferView':view,'byteOffset':off,'componentType':ct,'count':count,'type':typ}
    if mn is not None:a['min']=mn;a['max']=mx
    accs.append(a);return len(accs)-1
def prim(Vp,Vn,Vt,Vuv,Idx):
    inter=np.concatenate([Vp,Vn,Vt,Vuv],1).astype(np.float32)  # 3+3+4+2=12 floats=48 bytes
    iv=add_view(Idx.astype(np.uint32).tobytes(),34963)
    vv=add_view(inter.tobytes(),34962,48)
    ai=add_acc(iv,0,5125,Idx.size,'SCALAR')
    ap=add_acc(vv,0,5126,len(Vp),'VEC3',Vp.min(0).tolist(),Vp.max(0).tolist())
    an=add_acc(vv,12,5126,len(Vp),'VEC3')
    at=add_acc(vv,24,5126,len(Vp),'VEC4')
    au=add_acc(vv,40,5126,len(Vp),'VEC2')
    return {'attributes':{'POSITION':ap,'NORMAL':an,'TANGENT':at,'TEXCOORD_0':au},'indices':ai,'material':0,'mode':4}
p1=prim(Vp,Vn,Vt,Vuv,Ii.reshape(-1))
p2=prim(fv,fn,ft_,fuv,Fi.reshape(-1))
img_views=[add_view(b) for b in imgs]
out={'asset':{'version':'2.0','generator':'cave bake'},'scene':0,'scenes':[{'nodes':[0]}],
 'nodes':[{'name':'CaveShell','mesh':0}],
 'meshes':[{'name':'CaveMesh','primitives':[p1,p2]}],
 'materials':[{'name':'cave_rock','doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0.0,'roughnessFactor':0.9,'metallicRoughnessTexture':{'index':2}},'normalTexture':{'index':1,'scale':0.9}}],
 'textures':j['textures'],'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}],
 'images':[{'mimeType':'image/png','bufferView':v} for v in img_views],
 'bufferViews':views,'accessors':accs,'buffers':[{'byteLength':sum(len(c) for c in chunks)}]}
for t in out['textures']:t['sampler']=0
jb=pad(json.dumps(out,separators=(',',':')).encode(),b' ')
binb=b''.join(chunks)
glb=struct.pack('<4sII',b'glTF',2,12+8+len(jb)+8+len(binb))+struct.pack('<I4s',len(jb),b'JSON')+jb+struct.pack('<I4s',len(binb),b'BIN\x00')+binb
open(OUT,'wb').write(glb);print('wrote',OUT,len(glb))
