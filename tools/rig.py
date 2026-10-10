import json,struct,numpy as np
import os
# Carpeta del pack original KayKit Adventurers (descomprimido). Cambia con la variable KAYKIT_ADVENTURERS.
A=os.environ.get('KAYKIT_ADVENTURERS','./KayKit_Adventurers_2.0_FREE').rstrip('/')+'/'
def load_glb(p):
    d=open(p,'rb').read(); l=struct.unpack('<I',d[12:16])[0]
    j=json.loads(d[20:20+l]); off=20+l
    bl=struct.unpack('<I',d[off:off+4])[0]; binb=d[off+8:off+8+bl]
    return j,binb
def acc(j,b,i):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]
    n={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
    off=bv.get('byteOffset',0)+a.get('byteOffset',0)
    return np.frombuffer(b,dtype='<f4',count=a['count']*n,offset=off).reshape(a['count'],n)
# quaternion utils (x,y,z,w)
def qmul(a,b):
    x1,y1,z1,w1=a;x2,y2,z2,w2=b
    return np.array([w1*x2+x1*w2+y1*z2-z1*y2, w1*y2-x1*z2+y1*w2+z1*x2, w1*z2+x1*y2-y1*x2+z1*w2, w1*w2-x1*x2-y1*y2-z1*z2])
def qinv(a): return np.array([-a[0],-a[1],-a[2],a[3]])/np.dot(a,a)
def qrot(q,v):
    qv=np.array([v[0],v[1],v[2],0.]); return qmul(qmul(q,qv),qinv(q))[:3]
def qaxis(axis,deg):
    axis=np.array(axis,float); axis/=np.linalg.norm(axis); h=np.radians(deg)/2
    return np.array([*(axis*np.sin(h)),np.cos(h)])
ID=np.array([0,0,0,1.])
class Rig:
    def __init__(self):
        j,b=load_glb(A+'Characters/gltf/Knight.glb')
        sk=j['skins'][0]; self.joints=sk['joints']
        self.names=[j['nodes'][i]['name'] for i in self.joints]
        idx={n:i for i,n in enumerate(self.joints)}
        self.parent=[-1]*len(self.joints)
        for ji,n in enumerate(self.joints):
            for c in j['nodes'][n].get('children',[]):
                if c in idx: self.parent[idx[c]]=ji
        self.rest_t=[np.array(j['nodes'][n].get('translation',[0,0,0]),float) for n in self.joints]
        self.rest_q=[np.array(j['nodes'][n].get('rotation',[0,0,0,1]),float) for n in self.joints]
        # idle pose
        ja,ba=load_glb(A+'Animations/gltf/Rig_Medium/Rig_Medium_General.glb')
        an=[a for a in ja['animations'] if a['name']=='Idle_A'][0]
        self.idle_q=list(self.rest_q); self.idle_t=list(self.rest_t); self.idle_len=0
        for ch in an['channels']:
            nm=ja['nodes'][ch['target']['node']]['name']
            if nm not in self.names: continue
            i=self.names.index(nm); s=an['samplers'][ch['sampler']]
            times=acc(ja,ba,s['input']).ravel(); vals=acc(ja,ba,s['output'])
            self.idle_len=max(self.idle_len,times[-1])
            if ch['target']['path']=='rotation': self.idle_q[i]=vals[0].astype(float)
            elif ch['target']['path']=='translation': self.idle_t[i]=vals[0].astype(float)
        self.n=len(self.names)
    def fk(self,qs,ts=None):
        ts=ts or self.idle_t
        G=[None]*self.n;P=[None]*self.n
        order=sorted(range(self.n),key=lambda i:self.depth(i))
        for i in order:
            p=self.parent[i]
            if p<0: G[i]=qs[i]; P[i]=ts[i]
            else: G[i]=qmul(G[p],qs[i]); P[i]=P[p]+qrot(G[p],ts[i])
        return G,P
    def depth(self,i):
        d=0
        while self.parent[i]>=0: i=self.parent[i]; d+=1
        return d
if __name__=='__main__':
    r=Rig(); print(r.n,'bones; idle len',r.idle_len)
    for i,n in enumerate(r.names): print(i,n,'parent',r.names[r.parent[i]] if r.parent[i]>=0 else None)
    G,P=r.fk(r.rest_q,r.rest_t); print('--- REST (T-pose?)')
    for n in ['hips','head','upperarm.r','hand.r','handslot.r','handslot.l','foot.l']:
        i=r.names.index(n); print(n,np.round(P[i],2))
    G,P=r.fk(r.idle_q); print('--- IDLE')
    for n in ['hips','head','upperarm.r','lowerarm.r','hand.r','handslot.r','handslot.l','foot.l']:
        i=r.names.index(n); print(n,np.round(P[i],2))
    for n in ['handslot.r','handslot.l']:
        i=r.names.index(n)
        print(n,'local axes in model space (x,y,z):',[np.round(qrot(G[i],a),2).tolist() for a in ([1,0,0],[0,1,0],[0,0,1])])
