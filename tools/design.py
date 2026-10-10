from rig import *
import numpy as np
R=Rig(); N=R.names; I=lambda n:N.index(n)
UP=np.array([0,1.,0])
def norm(v): v=np.array(v,float); return v/np.linalg.norm(v)
def rot_between(a,b):
    a=norm(a); b=norm(b); d=np.dot(a,b)
    if d>0.999999: return ID.copy()
    if d<-0.999999:
        ax=np.cross(a,[1,0,0])
        if np.linalg.norm(ax)<1e-3: ax=np.cross(a,[0,1,0])
        return qaxis(ax,180)
    q=np.array([*np.cross(a,b),1+d]); return q/np.linalg.norm(q)
def basis_to_q(M):
    t=np.trace(M)
    if t>0:
        s=np.sqrt(t+1)*2; q=[(M[2,1]-M[1,2])/s,(M[0,2]-M[2,0])/s,(M[1,0]-M[0,1])/s,s/4]
    else:
        i=int(np.argmax(np.diag(M))); j=(i+1)%3;k=(i+2)%3
        s=np.sqrt(M[i,i]-M[j,j]-M[k,k]+1)*2; q=[0.]*4
        q[i]=s/4; q[j]=(M[j,i]+M[i,j])/s; q[k]=(M[k,i]+M[i,k])/s; q[3]=(M[k,j]-M[j,k])/s
    q=np.array(q); return q/np.linalg.norm(q)
def tri(p,s):
    p=norm(p); s=np.array(s,float)-p*np.dot(s,p); s=norm(s); return np.column_stack([p,s,np.cross(p,s)])
def frame_q(a1,d1,a2,d2): return basis_to_q(tri(d1,d2)@tri(a1,a2).T)

# eje nativo a1 (punta/larga), a2 opcional (orientacion), direccion en reposo, elevacion en reposo
WEAPONS={
 'sword_1handed':dict(a1=(0,1,0),idle=(0,-0.35,0.94)),
 'sword_2handed':dict(a1=(0,1,0),idle=(0,0.75,0.66)),
 'dagger':dict(a1=(0,1,0),idle=(0,-0.45,0.9)),
 'axe_1handed':dict(a1=(0,1,0),idle=(0,-0.35,0.94)),
 'axe_2handed':dict(a1=(0,1,0),idle=(0,0.75,0.66)),
 'staff':dict(a1=(0,1,0),idle=(0,1,0),lift=0.4),
 'wand':dict(a1=(0,1,0),idle=(0,1,0)),
 'bow':dict(a1=(0,0,1),a2=(1,0,0),idle=(0,1,0),idle2=(0,0,1),lift=0.5),
 'crossbow_1handed':dict(a1=(0,0,1),a2=(0,1,0),idle=(0,-0.1,1),idle2=(0,1,0)),
 'crossbow_2handed':dict(a1=(0,0,1),a2=(0,1,0),idle=(0,-0.1,1),idle2=(0,1,0)),
}
IG,IP=R.fk(R.idle_q)
def mount(wn,side):
    w=WEAPONS[wn]; G=IG[I('handslot.'+side)]; a1=np.array(w['a1'],float)
    if 'a2' in w: Gw=frame_q(a1,w['idle'],w['a2'],w['idle2'])
    else: Gw=qmul(rot_between(qrot(G,a1),w['idle']),G)
    M=qmul(qinv(G),Gw)
    off=qrot(qinv(G),np.array([0,w.get('lift',0),0.]))
    return M,off

class Pose:
    def __init__(s,twist=0,lean=0):
        s.twist=twist; s.lean=lean; s.q=[x.copy() for x in R.idle_q]; s.fix={}
        if twist or lean:
            s.fix[I('spine')]=qmul(qmul(qaxis(UP,twist*0.4),qaxis((1,0,0),lean*0.4)),IG[I('spine')])
            s.fix[I('chest')]=qmul(qmul(qaxis(UP,twist),qaxis((1,0,0),lean)),IG[I('chest')])
        s.fk()
    def fk(s):
        s.G=[None]*R.n; s.P=[None]*R.n
        for i in sorted(range(R.n),key=R.depth):
            p=R.parent[i]
            if i in s.fix and p>=0: s.q[i]=qmul(qinv(s.G[p]),s.fix[i])
            if p<0: s.G[i]=s.q[i]; s.P[i]=R.idle_t[i]
            else: s.G[i]=qmul(s.G[p],s.q[i]); s.P[i]=s.P[p]+qrot(s.G[p],R.idle_t[i])
    def shoulder(s,side): return s.P[I('upperarm.'+side)]
    def arm(s,side,target,wn=None,D=None,D2=None,pole=None,roll=0):
        ua,la,wr,hd,hs,ch=[I(x+('.'+side if x!='chest' else '')) for x in ['upperarm','lowerarm','wrist','hand','handslot','chest']]
        S=s.P[ua]; tE=R.idle_t[la]; tW=R.idle_t[wr]; L1=np.linalg.norm(tE); L2=np.linalg.norm(tW)
        T=np.array(target,float); v=T-S; d=np.linalg.norm(v)
        d=min(max(d,abs(L1-L2)+1e-3),L1+L2-1e-3); dv=norm(v)
        a=(L1*L1-L2*L2+d*d)/(2*d); h=np.sqrt(max(L1*L1-a*a,0))
        pole=norm(pole if pole is not None else ((-0.3 if side=='r' else 0.3),-0.8,-0.3))
        pp=norm(pole-dv*np.dot(pole,dv)); E=S+dv*a+pp*h; Wp=S+dv*d
        B=qmul(s.G[ch],R.idle_q[ua]); Gua=qmul(rot_between(qrot(B,norm(tE)),E-S),B)
        B2=qmul(Gua,R.idle_q[la]); Gla=qmul(rot_between(qrot(B2,norm(tW)),Wp-E),B2)
        Gwr=qmul(Gla,R.idle_q[wr])
        if wn is not None and D is not None:
            M,off=mount(wn,side); w=WEAPONS[wn]; a1=np.array(w['a1'],float)
            tail=qmul(R.idle_q[hd],R.idle_q[hs])
            Gw0=qmul(Gwr,qmul(tail,M))
            if 'a2' in w and D2 is not None: Gw=frame_q(a1,D,w['a2'],D2)
            else: Gw=qmul(rot_between(qrot(Gw0,a1),D),Gw0)
            if roll: Gw=qmul(qaxis(norm(D),roll),Gw)
            Gwr=qmul(qmul(Gw,qinv(M)),qinv(tail))
        s.fix[ua]=Gua; s.fix[la]=Gla; s.fix[wr]=Gwr; s.fk(); return s
    def weapon(s,wn,side):
        M,off=mount(wn,side); G=s.G[I('handslot.'+side)]; Gw=qmul(G,M)
        return s.P[I('handslot.'+side)]+qrot(Gw,np.array(off)*0+np.array([0,0,0.]))+qrot(G,off), Gw
    def wrist_to_slot(s,side): return np.linalg.norm(s.P[I('handslot.'+side)]-s.P[I('wrist.'+side)])

BONES=['spine','chest','upperarm.r','lowerarm.r','wrist.r','upperarm.l','lowerarm.l','wrist.l']
def idle_frame(wr=None,wl=None): 
    p=Pose(); return p
def solve(pm):
    """pm: dict twist,lean, r/l = dict(off|abs, D, D2, roll, pole) | 'grip:dist' ; weapons wr, wl"""
    p=Pose(pm.get('twist',0),pm.get('lean',0)); Rt=qmul(qaxis(UP,pm.get('twist',0)),qaxis((1,0,0),pm.get('lean',0)))
    wr,wl=pm.get('wr'),pm.get('wl')
    for side,wn in (('r',wr),('l',wl)):
        a=pm.get(side)
        if a is None or isinstance(a,str): continue
        S=p.shoulder(side); tgt=S+qrot(Rt,np.array(a['off'],float))
        p.arm(side,tgt,wn,a.get('D'),a.get('D2'),a.get('pole'),a.get('roll',0))
    a=pm.get('l')
    if isinstance(a,str) and a.startswith('grip'):     # mano izquierda en la empunadura del arma de la derecha
        dist=float(a.split(':')[1]); hs=p.P[I('handslot.r')]; Gw=qmul(p.G[I('handslot.r')],mount(wr,'r')[0])
        ax=qrot(Gw,np.array(WEAPONS[wr]['a1'],float)); tgt_slot=hs-ax*dist
        S=p.shoulder('l'); dv=norm(tgt_slot-S); tgt=tgt_slot-dv*0.16
        p.arm('l',tgt)
    return p
def lerp_pm(a,b,u):
    out={}
    for k in ['twist','lean']: out[k]=a.get(k,0)*(1-u)+b.get(k,0)*u
    out['wr']=b.get('wr'); out['wl']=b.get('wl')
    for side in 'rl':
        x,y=a.get(side),b.get(side)
        if isinstance(y,str) or isinstance(x,str): out[side]=y if u>0.5 else x; continue
        if x is None or y is None: out[side]=y if u>=0.5 else x; continue
        o={}
        o['off']=np.array(x['off'])*(1-u)+np.array(y['off'])*u
        for kk in ['D','D2','pole']:
            if x.get(kk) is not None and y.get(kk) is not None: o[kk]=norm(norm(x[kk])*(1-u)+norm(y[kk])*u)
            else: o[kk]=y.get(kk)
        o['roll']=x.get('roll',0)*(1-u)+y.get('roll',0)*u
        out[side]=o
    return out
EASE={'smooth':lambda u:u*u*(3-2*u),'in':lambda u:u*u,'out':lambda u:1-(1-u)*(1-u),'lin':lambda u:u}
def bake(keys,T,dt=0.05):
    """keys: [(t,pm,ease)] ; devuelve {hueso:[(t,quat)]} y frames Pose"""
    ts=list(np.round(np.arange(0,T+1e-6,dt),4)); res={b:[] for b in BONES}; poses=[]
    for t in ts:
        ks=sorted(keys,key=lambda k:k[0])
        k1=next((k for k in ks if k[0]>=t-1e-9),ks[-1]); k0=[k for k in ks if k[0]<=t+1e-9][-1]
        u=0 if k1[0]==k0[0] else EASE[k1[2]]((t-k0[0])/(k1[0]-k0[0]))
        pm=lerp_pm(k0[1],k1[1],u) if k1[0]!=k0[0] else k1[1]
        p=solve(pm); poses.append((t,p,pm))
        for b in BONES: res[b].append((float(t),p.q[I(b)].copy()))
    return res,poses
