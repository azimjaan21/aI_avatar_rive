"""Import actual MFA/Praat phone intervals; never derive phone times from RMS.

Requires a long-format TextGrid with matching word + phone tiers, the exact WAV,
and its checked transcript. No ASR or alignment model runs in this importer.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import wave


def category(phone):
    p=re.sub(r'_[BIES]$', '', phone).lower()
    p=re.sub('[ːˑˈˌʰ͈̚012]', '', p)
    groups={
        'neutral':{'sil','sp','spn','<eps>',''},
        'mbp':{'m','b','p','ㅁ','ㅂ','ㅃ','ㅍ','ᄆ','ᄇ','ᄈ','ᄑ','ᆷ','ᆸ'},
        'a':{'a','ɑ','ɐ','ʌ','ɒ','ㅏ','ㅓ','ᅡ','ᅥ'},
        'ei':{'e','ɛ','i','ɪ','ɯ','ɨ','ㅐ','ㅔ','ㅣ','ㅡ','ᅢ','ᅦ','ᅵ','ᅳ'},
        'o':{'o','ɔ','ø','ㅗ','ᅩ'},'u':{'u','ʊ','y','ㅜ','ᅮ'},
    }
    return next((name for name,phones in groups.items() if p in phones),None)


def tiers(text):
    found={}
    for block in re.split(r'\bitem\s*\[\d+\]\s*:',text)[1:]:
        name=re.search(r'\bname\s*=\s*"((?:[^"]|"")*)"',block)
        if not name or 'IntervalTier' not in block: continue
        intervals=[]
        for part in re.split(r'\bintervals\s*\[\d+\]\s*:',block)[1:]:
            start=re.search(r'\bxmin\s*=\s*([^\s]+)',part)
            end=re.search(r'\bxmax\s*=\s*([^\s]+)',part)
            value=re.search(r'\btext\s*=\s*"((?:[^"]|"")*)"',part)
            if not (start and end and value): raise ValueError('Malformed TextGrid interval')
            intervals.append((float(start[1]),float(end[1]),value[1].replace('""','"')))
        found[name[1]]=intervals
    return found


def export(grid,wav,transcript,out):
    parsed=tiers(grid.read_text(encoding='utf-8-sig'))
    phones=[v for k,v in parsed.items() if k.lower().endswith('phones')]
    words=[v for k,v in parsed.items() if k.lower().endswith('words')]
    if len(phones)!=1 or len(words)!=1: raise ValueError('Need one phone tier and matching word tier')
    normalize=lambda s:re.sub(r'[^\w]','',s.lower())
    source_text=transcript.read_text(encoding='utf-8-sig').strip()
    grid_text=' '.join(v for _,_,v in words[0] if v not in ('','<unk>','spn','sil'))
    if not source_text or normalize(source_text)!=normalize(grid_text):
        raise ValueError('Checked transcript does not match the TextGrid word tier')
    with wave.open(str(wav),'rb') as audio: duration=audio.getnframes()/audio.getframerate()
    events=[];unknown=set();previous=0
    for start,end,phone in phones[0]:
        if not all(math.isfinite(x) for x in [start,end]) or start<previous or end<=start or end>duration+.001:
            raise ValueError('Invalid/overlapping phone interval')
        previous=end
        viseme=category(phone)
        if viseme is None: unknown.add(phone);continue
        events.append(dict(start=start,end=end,viseme=viseme,phone=phone))
    if not any(e['viseme'] in ('a','ei','o','u','mbp') for e in events): raise ValueError('No supported phones in alignment')
    result={
        'version':1,'alignment':'phone','language':'ko',
        'provenance':'Imported phone intervals from MFA/Praat TextGrid; not manually distributed word times',
        'audioSha256':hashlib.sha256(wav.read_bytes()).hexdigest(),
        'alignmentSha256':hashlib.sha256(grid.read_bytes()).hexdigest(),
        'transcriptSha256':hashlib.sha256(transcript.read_bytes()).hexdigest(),
        'duration':duration,'events':events,'unmappedPhones':sorted(unknown),
        'confidencePolicy':'No acoustic confidence supplied by TextGrid; interval presence is not a confidence estimate',
    }
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps({'events':len(events),'unmappedPhones':sorted(unknown),'output':str(out)},ensure_ascii=True))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('textgrid',type=Path)
    parser.add_argument('--wav',type=Path,required=True)
    parser.add_argument('--transcript',type=Path,required=True)
    parser.add_argument('--out',type=Path,default=Path(__file__).resolve().parents[2]/'player/assets/korean_visemes.json')
    args=parser.parse_args()
    export(args.textgrid,args.wav,args.transcript,args.out)
