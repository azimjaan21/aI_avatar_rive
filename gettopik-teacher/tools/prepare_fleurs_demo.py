"""Fetch one attributed Korean female solo recording; no model or TTS API."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import urllib.parse
import urllib.request
import imageio_ffmpeg

ROOT=Path(__file__).resolve().parents[2]


def prepare():
    params=urllib.parse.urlencode(dict(dataset='google/fleurs',config='ko_kr',split='test',offset=4,length=1))
    with urllib.request.urlopen('https://datasets-server.huggingface.co/rows?'+params,timeout=30) as response:
        row=json.load(response)['rows'][0]['row']
    if row['gender']!=1 or row['language']!='Korean': raise ValueError('Unexpected source metadata')
    with urllib.request.urlopen(row['audio'][0]['src'],timeout=30) as response:
        original=response.read()
    staging=ROOT/'staging/audio-candidates';staging.mkdir(parents=True,exist_ok=True)
    source=staging/'fleurs-ko-kr-test-4-original.wav';source.write_bytes(original)
    converted=staging/'korean_female_narration.wav'
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-y','-i',str(source),'-ac','1','-ar','24000',
                    '-c:a','pcm_s16le',str(converted)],check=True,capture_output=True)
    backup=ROOT/'backups/previous-dialogue-audio';backup.mkdir(parents=True,exist_ok=True)
    for name in ['korean_demo.wav','mouth_timeline.json','analysis_report.json']:
        old=ROOT/'gettopik-teacher/audio'/name
        if old.exists() and not (backup/name).exists(): shutil.copy2(old,backup/name)
    metadata={
        'title':'Korean female solo narration - FLEURS','dataset':'google/fleurs','subset':'ko_kr',
        'split':'test','row':4,'recordingId':row['id'],'originalFile':Path(row['path']).name,
        'speakerLabel':'female (publisher metadata)','language':'Korean',
        'source':'https://huggingface.co/datasets/google/fleurs/viewer/ko_kr/test?row=4',
        'license':'CC BY 4.0','licenseUrl':'https://creativecommons.org/licenses/by/4.0/',
        'attribution':'FLEURS: Few-shot Learning Evaluation of Universal Representations of Speech, Google, 2022.',
        'originalSha256':hashlib.sha256(original).hexdigest(),
        'modification':'Resampled from 16 kHz to 24 kHz mono PCM16. No generated speech or speaker mixing.',
        'transcript':row['raw_transcription'],
    }
    audio=ROOT/'gettopik-teacher/audio'
    (audio/'audio_source.json').write_text(json.dumps(metadata,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    (audio/'transcript.txt').write_text(row['raw_transcription']+'\n',encoding='utf-8')
    print(json.dumps({'source':str(converted),'recordingId':row['id'],'duration':row['num_samples']/16000}))


if __name__=='__main__': prepare()
