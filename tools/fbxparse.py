import struct, zlib, sys
class N:
    __slots__=("name","props","children")
    def __init__(s,n): s.name=n; s.props=[]; s.children=[]
    def find(s,n): return [c for c in s.children if c.name==n]
    def first(s,n):
        r=s.find(n); return r[0] if r else None
def parse(path):
    d=open(path,"rb").read()
    ver=struct.unpack_from("<I",d,23)[0]
    big = ver>=7500
    off=27
    def rd(off):
        if big:
            end,np,pl,nl=struct.unpack_from("<QQQB",d,off); off+=25
        else:
            end,np,pl,nl=struct.unpack_from("<IIIB",d,off); off+=13
        if end==0: return None,off
        n=N(d[off:off+nl].decode()); off+=nl
        for _ in range(np):
            t=chr(d[off]); off+=1
            if t in "YCFDLIBZ"[:0]: pass
            if t=='Y': v=struct.unpack_from("<h",d,off)[0]; off+=2
            elif t=='C': v=bool(d[off]); off+=1
            elif t=='I': v=struct.unpack_from("<i",d,off)[0]; off+=4
            elif t=='F': v=struct.unpack_from("<f",d,off)[0]; off+=4
            elif t=='D': v=struct.unpack_from("<d",d,off)[0]; off+=8
            elif t=='L': v=struct.unpack_from("<q",d,off)[0]; off+=8
            elif t in 'fdlib':
                ln,enc,cl=struct.unpack_from("<III",d,off); off+=12
                raw=d[off:off+cl]; off+=cl
                if enc: raw=zlib.decompress(raw)
                fmt={'f':'f','d':'d','l':'q','i':'i','b':'?'}[t]
                import array
                a=array.array({'f':'f','d':'d','l':'q','i':'i','b':'b'}[t]); a.frombytes(raw); v=a
            elif t in 'SR':
                ln=struct.unpack_from("<I",d,off)[0]; off+=4
                raw=d[off:off+ln]; off+=ln
                v=raw.decode("latin1") if t=='S' else raw
            else: raise Exception("type "+t)
            n.props.append(v)
        while off<end:
            c,off=rd(off)
            if c is None: break
            n.children.append(c)
        return n,end
    root=N("root")
    while off<len(d)-200:
        c,off=rd(off)
        if c is None: break
        root.children.append(c)
    return root,ver
if __name__=="__main__":
    r,v=parse(sys.argv[1]); print("ver",v)
    def dump(n,ind=0,maxd=2):
        if ind>maxd*1: return
        pr=[ (p if not hasattr(p,'typecode') else f"<arr {len(p)}>") for p in n.props][:4]
        print("  "*ind+n.name,pr)
        for c in n.children: dump(c,ind+1,maxd)
    for c in r.children: 
        if c.name in("Objects","Takes","GlobalSettings"): dump(c,0,1)
