"""Summarize measured A/B reports, retaining unavailable C explicitly."""
import json
from pathlib import Path
from PIL import Image, ImageDraw
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'validation/lipsync-quality'


def report():
    cpu=json.loads((OUT/'dsp-benchmark.json').read_text(encoding='utf-8'))
    data={}
    for case in ['A','B']:
        j=json.loads((OUT/f'{case}-playback-report.json').read_text(encoding='utf-8'))
        data[case]={k:v for k,v in j.items() if k!='trace'}
        data[case]['visualCaptureTimingNote']='Controller times precede external capture. PNGs are appearance evidence, not acoustic latency measurements.'
    for name,metrics in cpu['modes'].items():
        trace=metrics['trace']
        metrics['closedToMediumJumps']=sum(a['pose']==6 and b['pose']==2 for a,b in zip(trace,trace[1:]))
    summary={'comparison':data,'analysis':{n:{k:v for k,v in m.items() if k!='trace'} for n,m in cpu['modes'].items()},
             'C':cpu['timedVisemes'],
             'decision':'Keep B: exclusive photographic poses, narrow onset, conservative DSP. No phoneme recognition claimed.',
             'meshProbe':{'vertices':10,'triangles':10,'displacementsSourcePixels':[0,1.5,4.5],
                          'shipped':False,'reason':'Interior compression flattens lip highlights/teeth. It does not supply topology for closed/rounded shapes.'},
             'mobileTested':False}
    (OUT/'quality-report.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    fig,axes=plt.subplots(3,1,figsize=(12,6),sharex=True,layout='constrained')
    base=cpu['modes']['rms']['trace']
    axes[0].plot([f['time'] for f in base],[f['energy'] for f in base],color='#687b71',lw=1)
    axes[0].set_ylabel('Smoothed energy');axes[0].set_ylim(-.05,1.05)
    for ax,name,label in zip(axes[1:],['rms','lightweight'],['A: RMS baseline','B: Lightweight DSP']):
        trace=cpu['modes'][name]['trace']
        ax.step([f['time'] for f in trace],[{6:0,1:1,2:2}[f['pose']] for f in trace],where='post',color='#4b8267')
        ax.set_yticks([0,1,2],['Closed','Small','Medium']);ax.set_ylabel(label);ax.grid(alpha=.2)
    axes[-1].set_xlabel('Audio time (seconds)')
    fig.suptitle('Recorded Korean narration: causal audio-reactive poses, not phoneme labels')
    fig.savefig(OUT/'timing-comparison.png',dpi=150);plt.close(fig)
    # Native face crops keep the original app pixel scale; no enlargement.
    poses=[6,1,2,4,5,7]
    sheet=Image.new('RGB',(6*260,2*290),'#101916');draw=ImageDraw.Draw(sheet)
    for r,case in enumerate(['A','B']):
        for c,pose in enumerate(poses):
            im=Image.open(OUT/f'{case}-pose-{pose}.png')
            sheet.paste(im.crop((260,240,520,500)).convert('RGB'),(c*260,r*290+25))
            draw.text((c*260+8,r*290+7),f'{case} - index {pose}',fill='white')
    sheet.save(OUT/'normal-size-poses.png')
    for case in ['A','B']:
        sheet=Image.new('RGB',(4*300,2*325),'#101916');draw=ImageDraw.Draw(sheet)
        for i,f in enumerate(data[case].get('visualSpeechFrames',[])):
            im=Image.open(OUT/f['file'])
            sheet.paste(im.crop((240,225,540,515)).convert('RGB'),((i%4)*300,(i//4)*325+30))
            draw.text(((i%4)*300+8,(i//4)*325+8),f"{case}: capture requested ~{f['time']:.2f}s",fill='white')
        sheet.save(OUT/f'{case}-speech-sequence.png')
    print(json.dumps({case:{'startupMs':j['audioClock']['firstChunkToPlaybackCursorMs'],
          'peakRssMiB':j['peakSampledRssBytes']/1048576,'cpuCorePercent':j['cpuPercentOfOneCore']} for case,j in data.items()}))


if __name__=='__main__':report()
