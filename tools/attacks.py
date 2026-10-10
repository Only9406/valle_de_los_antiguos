from design import *
import numpy as np
def X(x): return x   # x+ = izquierda del personaje
def pm_idle(wr=None,wl=None,**kw): return dict(twist=0,lean=0,wr=wr,wl=wl,r=None,l=None,**kw)
ATT={}
# ---------- SLASH (espada/hacha 1 mano, mano derecha) ----------
def slash():
    w='sword_1handed'
    wind=dict(twist=-35,lean=-4,wr=w,r=dict(off=(-0.10,0.38,-0.12),D=(-0.2,0.9,-0.45),pole=(-0.6,-0.4,-0.7)),l=None)
    hit =dict(twist=30,lean=10,wr=w,r=dict(off=(0.02,-0.10,0.47),D=(0.25,-0.35,0.9),pole=(-0.5,-0.7,-0.2)),l=None)
    fol =dict(twist=45,lean=12,wr=w,r=dict(off=(0.30,-0.34,0.28),D=(0.8,-0.5,0.35),pole=(-0.3,-0.8,0.0)),l=None)
    idle=pm_idle(w)
    return 0.80,0.30,[(0,idle,'lin'),(0.20,wind,'smooth'),(0.32,hit,'in'),(0.46,fol,'out'),(0.80,idle,'smooth')]
ATT['Slash']=slash()
def chop():
    w='sword_2handed'
    G=dict(l='grip:0.30')
    wind=dict(twist=0,lean=-14,wr=w,r=dict(off=(0.10,0.50,-0.10),D=(0,0.85,-0.5),pole=(-0.6,-0.3,-0.7)),**G)
    hit =dict(twist=0,lean=18,wr=w,r=dict(off=(0.10,-0.05,0.45),D=(0,-0.25,0.97),pole=(-0.6,-0.7,0.0)),**G)
    fol =dict(twist=0,lean=26,wr=w,r=dict(off=(0.08,-0.30,0.36),D=(0,-0.75,0.65),pole=(-0.6,-0.8,0.0)),**G)
    idle=pm_idle(w)
    return 1.00,0.46,[(0,idle,'lin'),(0.30,wind,'smooth'),(0.46,hit,'in'),(0.62,fol,'out'),(1.00,idle,'smooth')]
ATT['Chop']=chop()
def stab(side='r'):
    w='dagger'; m=1 if side=='r' else -1
    def mk(tw,off,D,lean=0): 
        d=dict(twist=tw*m,lean=lean,wl=None,wr=None); d['w'+side]=w
        d[side]=dict(off=(off[0]*m,off[1],off[2]),D=(D[0]*m,D[1],D[2]),pole=(-0.4*m,-0.8,-0.2)); return d
    cock=mk(-25,(0.0,-0.10,0.08),(0.0,0.1,1),0)
    thr=mk(30,(0.0,-0.02,0.50),(0.05,0.05,1),6)
    rec=mk(8,(0.0,-0.10,0.30),(0.0,-0.1,1),0)
    idle=pm_idle(**{'w'+side:w}) 
    return 0.60,0.24,[(0,idle,'lin'),(0.14,cock,'smooth'),(0.24,thr,'in'),(0.34,rec,'out'),(0.60,idle,'smooth')]
ATT['Stab']=stab('r'); ATT['StabL']=stab('l')
def cast():
    w='staff'
    wind=dict(twist=-15,lean=-8,wr=w,r=dict(off=(-0.12,0.30,0.0),D=(-0.15,1,-0.15),pole=(-0.5,-0.5,-0.7)),l=dict(off=(0.0,0.0,0.15),pole=(0.3,-0.8,-0.2)))
    hit =dict(twist=15,lean=6,wr=w,r=dict(off=(-0.05,0.10,0.45),D=(0,0.55,0.83),pole=(-0.5,-0.7,-0.2)),l=dict(off=(-0.05,0.05,0.48),pole=(0.3,-0.8,-0.2)))
    fol =dict(twist=15,lean=4,wr=w,r=dict(off=(-0.05,0.08,0.40),D=(0,0.6,0.8),pole=(-0.5,-0.7,-0.2)),l=dict(off=(-0.05,0.05,0.44),pole=(0.3,-0.8,-0.2)))
    idle=pm_idle(w)
    return 0.80,0.34,[(0,idle,'lin'),(0.22,wind,'smooth'),(0.34,hit,'in'),(0.46,fol,'lin'),(0.80,idle,'smooth')]
ATT['Cast']=cast()
def bow():
    w='bow'
    # arco: eje largo -> vertical, parte curva (+X nativo) hacia delante
    aim =dict(twist=-20,lean=0,wl=w,l=dict(off=(-0.02,0.0,0.50),D=(0,1,0),D2=(0,0,1),pole=(0.4,-0.8,0)),r=dict(off=(0.20,0.20,0.12),pole=(-0.4,-0.6,-0.8)))
    draw=dict(twist=-20,lean=0,wl=w,l=dict(off=(-0.02,0.0,0.50),D=(0,1,0),D2=(0,0,1),pole=(0.4,-0.8,0)),r=dict(off=(0.20,0.30,-0.04),pole=(-0.4,-0.4,-0.9)))
    rel =dict(twist=-20,lean=0,wl=w,l=dict(off=(-0.02,0.0,0.50),D=(0,1,0),D2=(0,0,1),pole=(0.4,-0.8,0)),r=dict(off=(0.12,0.28,-0.18),pole=(-0.4,-0.4,-0.9)))
    idle=pm_idle(None,w)
    return 0.90,0.46,[(0,idle,'lin'),(0.25,aim,'smooth'),(0.44,draw,'smooth'),(0.48,rel,'out'),(0.62,rel,'lin'),(0.90,idle,'smooth')]
ATT['Bow']=bow()
def aim(two):
    w='crossbow_2handed' if two else 'crossbow_1handed'
    L='grip:0.34' if two else None
    mk=lambda back:dict(twist=-10,lean=-2,wr=w,r=dict(off=(0.10,0.02,0.34-back),D=(0,0.03+back*0.8,1),D2=(0,1,0),pole=(-0.5,-0.7,-0.3)),l=L)
    idle=pm_idle(w)
    return 0.70,0.30,[(0,idle,'lin'),(0.22,mk(0),'smooth'),(0.30,mk(0),'lin'),(0.34,mk(0.10),'out'),(0.46,mk(0.0),'smooth'),(0.70,idle,'smooth')]
ATT['Aim2']=aim(True); ATT['Aim1']=aim(False)

if __name__=='__main__':   # python attacks.py -> sheet1.png / sheet2.png para revisar las poses
    import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
    def draw(ax,p,pm,view):
        c=(2,1) if view=='side' else (0,1)
        for i in range(R.n):
            q=R.parent[i]
            if q>=0: ax.plot([p.P[q][c[0]],p.P[i][c[0]]],[p.P[q][c[1]],p.P[i][c[1]]],'k-',lw=1.5)
        for side,wn in (('r',pm.get('wr')),('l',pm.get('wl'))):
            if not wn: continue
            hs,Gw=p.weapon(wn,side); a1=np.array(WEAPONS[wn]['a1'],float)
            L={'sword_1handed':1.4,'sword_2handed':1.9,'dagger':.95,'staff':1.2,'bow':0.99,'crossbow_1handed':.9,'crossbow_2handed':1.1}.get(wn,1)
            ax_=qrot(Gw,a1); st=hs-ax_*(0.4 if wn!='bow' and wn!='crossbow_1handed' and wn!='crossbow_2handed' else (L if wn=='bow' else 0.2))
            en=hs+ax_*L
            ax.plot([st[c[0]],en[c[0]]],[st[c[1]],en[c[1]]],'r-' if side=='r' else 'b-',lw=3)
            if 'a2' in WEAPONS[wn]:
                a2=qrot(Gw,np.array(WEAPONS[wn]['a2'],float)); e2=hs+a2*0.3
                ax.plot([hs[c[0]],e2[c[0]]],[hs[c[1]],e2[c[1]]],'g-',lw=2)
        ax.plot([-3,3],[0,0],'gray',lw=.5); ax.set_aspect('equal'); ax.set_xlim(-1.2,1.6) if view=='side' else ax.set_xlim(-1.3,1.3); ax.set_ylim(-0.2,2.2); ax.axis('off')
    names=list(ATT)
    for grp,fn in ((names[:4],'sheet1.png'),(names[4:],'sheet2.png')):
        cols=6; fig,axs=plt.subplots(len(grp)*2,cols,figsize=(cols*2.1,len(grp)*2*2.3))
        for gi,nm in enumerate(grp):
            T,hit,keys=ATT[nm]; res,poses=bake(keys,T)
            sel=[poses[int(round(t/0.05))] for t in np.linspace(0,T*0.75,cols)]
            for ci,(t,p,pm) in enumerate(sel):
                draw(axs[gi*2][ci],p,pm,'side'); draw(axs[gi*2+1][ci],p,pm,'front')
                axs[gi*2][ci].set_title(f'{nm} t={t:.2f}',fontsize=7)
        plt.tight_layout(); plt.savefig(fn,dpi=60); print('saved',fn)
