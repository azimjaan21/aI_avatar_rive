"""Measure Windows speaker loopback during the native demo test; never uses a mic.

Writes only block energy measurements, not a recording.
"""
import json, sys, time
from pathlib import Path
import numpy as np
import soundcard as sc

out=Path(sys.argv[1]); seconds=float(sys.argv[2]) if len(sys.argv)>2 else 13
speaker=sc.default_speaker()
loopback=sc.get_microphone(id=speaker.id,include_loopback=True)
values=[]; rate=24000
with loopback.recorder(samplerate=rate,channels=2,blocksize=2400) as rec:
    print('READY',flush=True)
    for _ in range(round(seconds*10)):
        block=rec.record(numframes=2400)
        values.append(float(np.sqrt(np.mean(block.astype(np.float64)**2))))
result={'device':speaker.name,'method':'WASAPI speaker loopback, stereo, 24 kHz; RMS per 100 ms','seconds':seconds,'rms':values,'peakRms':max(values),'audibleBlocks':sum(v>.0001 for v in values),'outputDetected':max(values)>.0001}
out.write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({'outputDetected':result['outputDetected'],'peakRms':result['peakRms']}),flush=True)
