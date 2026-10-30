"""Prepare a private podcast excerpt; does not change the licensed default sample."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--ffmpeg', required=True)
p.add_argument('--source', type=Path, required=True)
p.add_argument('--start', type=float, required=True)
p.add_argument('--end', type=float, required=True)
a = p.parse_args()
if not 0 <= a.start < a.end:
    p.error('Expected 0 <= start < end')
work = ROOT / 'staging/julia/prepared'
work.mkdir(parents=True, exist_ok=True)
wav = work / 'korean_demo.wav'
subprocess.run([
    a.ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
    '-ss', str(a.start), '-i', str(a.source), '-t', str(a.end-a.start),
    '-af', 'afade=t=in:d=0.02,afade=t=out:st='+str(a.end-a.start-.03)+':d=0.03',
    '-ac', '1', '-ar', '24000', '-c:a', 'pcm_s16le',
    '-map_metadata', '-1', str(wav),
], check=True)
spec = importlib.util.spec_from_file_location(
    'analyze_audio', ROOT / 'gettopik-teacher/tools/analyze_audio.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.analyze(wav, work)
assets = ROOT / 'player/assets'
shutil.copyfile(wav, assets / 'local_julia.wav')
shutil.copyfile(work / 'mouth_timeline.json', assets / 'local_julia_timeline.json')
metadata = {
    'title': '[Ep 2] Beginner Korean Listening Practice, Slow & Easy',
    'creator': 'Easy Korean Listening with Julia',
    'source': 'https://podcasts.apple.com/us/podcast/id1855367131?i=1000738171598',
    'sourceStartSeconds': a.start,
    'sourceEndSeconds': a.end,
    'modifications': 'Trim, 20/30 ms fades, mono 24 kHz PCM16. No speed/pitch change.',
    'sha256': hashlib.sha256(wav.read_bytes()).hexdigest(),
    'bytes': wav.stat().st_size,
    'usage': 'Local evaluation only. Redistribution permission not established.',
}
(work / 'source.json').write_text(json.dumps(metadata, indent=2)+'\n')
print(json.dumps(metadata, indent=2))
