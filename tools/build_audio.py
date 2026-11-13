import wave, math, struct, random, os
random.seed(8); rate=22050

def save(name,secs,fn):
 with wave.open('assets/audio/'+name+'.wav','w') as w:
  w.setparams((1,2,rate,0,'NONE','not compressed'))
  w.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,fn(i/rate)))*25000)) for i in range(int(secs*rate))))
save('engine',1,lambda t:.28*math.sin(2*math.pi*55*t)+.14*math.sin(2*math.pi*110*t)+.06*math.sin(2*math.pi*165*t))
save('horn',.45,lambda t:(math.sin(2*math.pi*392*t)+.7*math.sin(2*math.pi*493.88*t))*.23*min(1,t*40)*min(1,(.45-t)*20))
save('coin',.45,lambda t:math.sin(2*math.pi*(880 if t<.12 else 1320)*t)*.45*math.exp(-t*8))
save('board',.16,lambda t:math.sin(2*math.pi*660*t)*.22*math.exp(-t*25))
save('bump',.22,lambda t:random.uniform(-1,1)*.38*math.exp(-t*20)+math.sin(2*math.pi*65*t)*.25*math.exp(-t*15))
save('bell',.7,lambda t:(math.sin(2*math.pi*660*t)+.5*math.sin(2*math.pi*990*t))*.3*math.exp(-t*6))
# Original relaxed pentatonic instrumental loop. 100bpm, 8 bars.
notes=[60,64,67,69,67,64,62,55,60,62,64,67,72,69,67,64,57,60,64,67,64,62,60,57,55,59,62,67,69,67,62,59]
def music(t):
 beat=t/.6;step=int(beat);phase=t% .6
 n=notes[step%32];f=440*2**((n-69)/12)
 melody=(math.sin(2*math.pi*f*t)+.3*math.sin(2*math.pi*f*2*t))*.11*math.exp(-phase*8)
 bass_note=[36,36,33,31][int(beat/8)%4];bf=440*2**((bass_note-69)/12)
 bass=math.sin(2*math.pi*bf*t)*.14*math.exp(-(t%1.2)*5)
 kick=math.sin(2*math.pi*(55+45*math.exp(-phase*30))*phase)*.12*math.exp(-phase*18) if step%2==0 else 0
 hat=random.uniform(-1,1)*.025*math.exp(-(t%.3)*80)
 return melody+bass+kick+hat
save('music',19.2,music)
