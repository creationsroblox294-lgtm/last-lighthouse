import numpy as np, scipy.io.wavfile as w
from scipy.signal import butter, lfilter
SR=44100
rng=np.random.default_rng(7)
def t(d): return np.arange(int(SR*d))/SR
def lp(x,f): b,a=butter(2,f/(SR/2)); return lfilter(b,a,x)
def hp(x,f): b,a=butter(2,f/(SR/2),'high'); return lfilter(b,a,x)
def env(tt,a,d): return np.minimum(tt/a,1)*np.exp(-tt/d)
def norm(x,g=0.9): x=x-np.mean(x); return x/np.max(np.abs(x))*g
# punch: low body thump with pitch drop + short noise slap
tt=t(0.35)
f=60+140*np.exp(-tt/0.03)
body=np.sin(2*np.pi*np.cumsum(f)/SR)*env(tt,0.002,0.09)
slap=lp(rng.standard_normal(len(tt)),2500)*env(tt,0.0005,0.018)
punch=norm(np.tanh(2.5*(body*1.0+slap*0.7)))
# harpoon: meaty thunk + wet tear + small metallic ring
tt=t(0.5)
f=90+260*np.exp(-tt/0.02)
thunk=np.sin(2*np.pi*np.cumsum(f)/SR)*env(tt,0.001,0.08)
tear=hp(lp(rng.standard_normal(len(tt)),5000),600)*env(tt,0.002,0.05)
ring=sum(np.sin(2*np.pi*fr*tt)*np.exp(-tt/0.18)/(i+1) for i,fr in enumerate([1240,1910,2770]))*0.25
harp=norm(np.tanh(2*(thunk+0.6*tear))+ring)
# kill: heavy boom + crunch + rising shimmer
tt=t(0.9)
f=45+200*np.exp(-tt/0.05)
boom=np.sin(2*np.pi*np.cumsum(f)/SR)*env(tt,0.002,0.25)
crunch=lp(rng.standard_normal(len(tt)),3500)*env(tt,0.001,0.06)
sh=sum(np.sin(2*np.pi*fr*(1+0.15*tt)*tt) for fr in [880,1320,1760])*env(tt,0.08,0.3)*0.12
kill=norm(np.tanh(2.2*(boom+0.8*crunch))+sh)
for n,x in [('HitPunch',punch),('HitHarpoon',harp),('HitKill',kill)]:
    w.write(n+'.wav',SR,(x*32767).astype(np.int16))
