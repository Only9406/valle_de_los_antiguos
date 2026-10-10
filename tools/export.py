import os
from attacks import *
out=['# GENERADO por tools/export.py: animaciones de ataque (IK) y montaje de armas. No editar a mano.','extends RefCounted','',
'## Pistas de rotacion locales por hueso: [t, x, y, z, w, t, x, y, z, w, ...]','const ATTACKS := {']
for nm,(T,hit,keys) in ATT.items():
    res,_=bake(keys,T)
    out.append(f'\t"{nm}": {{"length": {T}, "hit": {hit}, "tracks": {{')
    for b,ks in res.items():
        flat=[]
        for t,q in ks:
            if q[3]<0: q=-q
            flat+= [round(float(t),3)]+[round(float(x),5) for x in q]
        out.append(f'\t\t"{b}": {flat},')
    out.append('\t}},')
out.append('}\n')
out.append('## Montaje de cada arma en la mano: [qx,qy,qz,qw, ox,oy,oz] (rotacion y desplazamiento en el espacio del handslot)')
out.append('const MOUNTS := {')
for wn in WEAPONS:
    ent={}
    for side in 'rl':
        M,off=mount(wn,side)
        if M[3]<0: M=-M
        ent[side]=[round(float(x),5) for x in M]+[round(float(x),4) for x in off]
    out.append(f'\t"{wn}": {{"r": {ent["r"]}, "l": {ent["l"]}}},')
out.append('}')
open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','scripts','attack_data.gd'),'w').write('\n'.join(out)+'\n')
print(len('\n'.join(out)),'bytes'); 
for nm,(T,hit,_) in ATT.items(): print(nm,T,hit)
