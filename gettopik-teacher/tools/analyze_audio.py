"""Offline PCM RMS -> 60 fps mouth timeline. MP3 needs a local ffmpeg executable."""
import argparse, array, hashlib, json, math, subprocess, sys, wave
from pathlib import Path

def analyze(source, dest):
    dest.mkdir(parents=True,exist_ok=True)
    wav=dest/'korean_demo.wav'
    if source.suffix.lower()=='.wav':
        import shutil
        if source.resolve()!=wav.resolve(): shutil.copyfile(source,wav)
    else:
        import imageio_ffmpeg
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-y','-i',str(source),'-ac','1','-ar','24000','-c:a','pcm_s16le',str(wav)],check=True,capture_output=True)
    with wave.open(str(wav),'rb') as w:
        rate,channels,width=w.getframerate(),w.getnchannels(),w.getsampwidth()
        if width!=2: raise ValueError('Use 16-bit PCM WAV')
        samples=array.array('h',w.readframes(w.getnframes()))
    if sys.byteorder!='little': samples.byteswap()
    mono=[sum(samples[i:i+channels])/channels/32768 for i in range(0,len(samples),channels)]
    duration=len(mono)/rate; fps=60; win=round(rate*.020)
    rms=[]
    for frame in range(math.ceil(duration*fps)+1):
        center=round(frame*rate/fps)
        segment=mono[max(0,center-win//2):min(len(mono),center+win//2)]
        rms.append(math.sqrt(sum(v*v for v in segment)/max(1,len(segment))))
    sorted_rms=sorted(rms); peak=max(.001,sorted_rms[round(.95*(len(rms)-1))])
    threshold=max(10**(-50/20),peak*10**(-32/20))
    env=0; quiet=0; state=6; last_change=-99; frames=[]
    for i,raw in enumerate(rms):
        tau=.030 if raw>env else .070
        env+=(raw-env)*(1-math.exp(-1/fps/tau))
        quiet=quiet+1 if raw<threshold else 0
        silence=quiet>=2 or (raw<threshold and i<2)
        level=min(1,env/peak)
        target=6 if silence else (1 if level<.28 else 2)
        if target==6 or i-last_change>=4:
            if target!=state: last_change=i
            state=target
        frames.append({'time':round(i/fps,6),'rms':round(raw,6),'energy':round(level,6),'silence':silence,'mouth':state})
    frames[-1].update(mouth=6,silence=True)
    result={'version':1,'source':source.name,'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'audioSha256':hashlib.sha256(wav.read_bytes()).hexdigest(),'duration':duration,'fps':fps,'mouths':['rest','small','medium','wide','round','teeth','closed_press','smile'],'disabledMouthIndices':[0,3],'silenceMouthIndex':6,'method':{'windowMs':20,'attackMs':30,'releaseMs':70,'silenceThresholdRms':threshold,'referenceRms':peak,'silenceFrames':2,'minPoseFrames':4,'crossfadeMs':45,'note':'Rest and Wide are disabled. Silence uses Closed press. Medium and high energy use Medium. Energy animation, not phoneme or viseme alignment. Extra art states are manually selectable.'},'frames':frames}
    (dest/'mouth_timeline.json').write_text(json.dumps(result,separators=(',',':')),encoding='utf-8')
    summary={k:v for k,v in result.items() if k!='frames'}
    summary.update(frames=len(frames),silenceFrames=sum(f['silence'] for f in frames),usedMouths=sorted(set(f['mouth'] for f in frames)),silenceViolations=sum(f['silence'] and f['mouth']!=6 for f in frames))
    (dest/'analysis_report.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(json.dumps(summary,indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('--out',type=Path,default=Path(__file__).resolve().parents[1]/'audio');args=p.parse_args();analyze(args.source,args.out)
