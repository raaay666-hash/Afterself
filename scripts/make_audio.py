"""Original, deterministic offline sound design for Startup Phase. No external samples."""
import math
import random
import struct
import wave
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent/'assets'/'audio'
ROOT.mkdir(parents=True,exist_ok=True)
RATE=22050
rng=random.Random(717204)

def save(name,samples):
    with wave.open(str(ROOT/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes(b''.join(struct.pack('<h',round(max(-1,min(1,x))*32767)) for x in samples))

def ambience():
    low=0.0; samples=[]
    for i in range(RATE*16):
        noise=rng.uniform(-1,1); low=.98*low+.02*noise
        ripple=math.sin(i/RATE*0.7)*0.02
        samples.append(noise*.14+low*.45+ripple*low)
    # Short crossfade at loop seam.
    n=2048
    for i in range(n):
        u=i/n;samples[-n+i]=samples[-n+i]*(1-u)+samples[i]*u
    save('rain',samples)
    chord=[73.416,110.0,146.832,164.814,220.0]
    samples=[]
    for i in range(RATE*24):
        t=i/RATE
        value=sum(math.sin(2*math.pi*f*t+math.sin(t*.13+j)*.14)*(0.045/(1+j*.5)) for j,f in enumerate(chord))
        value*=.62+.25*math.cos(2*math.pi*t/24)
        samples.append(value)
    for i in range(n):
        u=i/n;samples[-n+i]=samples[-n+i]*(1-u)+samples[i]*u
    save('drone',samples)

def effect(name,duration,kind):
    values=[]
    for i in range(int(duration*RATE)):
        t=i/RATE;u=t/duration
        if kind=='step':
            value=(rng.uniform(-1,1)*.25+math.sin(2*math.pi*96*t)*.4)*math.exp(-t*35)*(1-u)
        elif kind=='paper':
            value=rng.uniform(-1,1)*.22*math.sin(math.pi*u)**2*(.7+.3*math.sin(t*90))
        elif kind=='click':
            value=(math.sin(2*math.pi*740*t)*.22+rng.uniform(-1,1)*.1)*math.exp(-t*75)
        elif kind=='found':
            value=(math.sin(2*math.pi*440*t)+.5*math.sin(2*math.pi*660*t))*.14*math.sin(math.pi*u)*math.exp(-t*3)
        else:
            value=(math.sin(2*math.pi*130*t)*.2+rng.uniform(-1,1)*.04)*math.exp(-t*9)
        values.append(value)
    save(name,values)

ambience()
for args in [('step',.15,'step'),('paper',.4,'paper'),('click',.06,'click'),('found',.85,'found'),('lock',.45,'lock')]:effect(*args)
print('Created original rain, ambient drone and five interaction sounds')
