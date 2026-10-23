"""Summarize a completed measure-android.py run without extrapolating to devices."""
import json
import statistics
from pathlib import Path

root = Path(__file__).resolve().parents[1]
folder = root / 'docs/measurements/android'
data = json.loads((folder / 'emulator-report.json').read_text(encoding='utf-8'))
result = data['testResult']
if not result:
    raise SystemExit('No completed integration-test result; do not publish partial performance results.')
samples = [s for s in data['androidSamples'] if s.get('pssKiB') is not None]
cpu = [s['cpuPercentOneCore'] for s in samples if s.get('cpuPercentOneCore') is not None]
cpu_intervals = [(samples[i]['cpuPercentOneCore'], samples[i]['sessionSeconds'] - samples[i - 1]['sessionSeconds'])
                 for i in range(1, len(samples)) if samples[i].get('cpuPercentOneCore') is not None]
frames = [s for s in data['flutterSamples'] if s['event'] == 'sample']
last = frames[-1]
ready = [s for s in data['flutterSamples'] if s['event'] == 'ready']

def distribution(values):
    return {'min': min(values), 'median': statistics.median(values), 'max': max(values)} if values else None

summary = {
    'scope': 'Android emulator debug integration test with fully live rendering; not production performance',
    'specs': data['specs'],
    'wallSessionSeconds': result['elapsedSeconds'],
    'androidPssMiB': {
        'first': samples[0]['pssKiB'] / 1024,
        'last': samples[-1]['pssKiB'] / 1024,
        'netGrowth': (samples[-1]['pssKiB'] - samples[0]['pssKiB']) / 1024,
        'distribution': distribution([s['pssKiB'] / 1024 for s in samples]),
        'samples': len(samples),
        'sampleSpanSeconds': samples[-1]['sessionSeconds'] - samples[0]['sessionSeconds'],
    },
    'cpuPercentOneLogicalCore': {
        'weightedMean': sum(value * duration for value, duration in cpu_intervals) / sum(duration for _, duration in cpu_intervals) if cpu_intervals else None,
        'distribution': distribution(cpu),
    },
    'lastFrameWindow': {k: last[k] for k in ['buildP50ms', 'buildP95ms', 'rasterP50ms', 'rasterP95ms']},
    'frameWindowScope': 'Most recent 600 Flutter FrameTiming samples; separate build and raster stages',
    'sessionControllerFrames': last['frames'],
    'sessionControllerFramesOver16_67ms': last['over16_67ms'],
    'sessionControllerOverBudgetPercent': 100 * last['over16_67ms'] / last['frames'],
    'frameCounterScope': 'Last screen lifetime, including a short warm-up before the five-minute session; ends at final periodic sample',
    'firstTeacherRiveDecodeMs': ready[0]['riveLoadMs'],
    'firstTeacherReadyMs': ready[0]['readyLoadMs'],
    'reopenReadyMs': distribution(result['reopenReadyMs']),
    'firstChunkToPlaybackCursorMs': distribution(result['audioStartupCursorMs']),
    'localPlayRequestToPlaybackCursorMs': distribution(result['localPlayRequestToCursorMs']),
    'localFileRequestToCursorMs': distribution(result['localPlayRequestToCursorMs'][::2]),
    'simulatedStreamRequestToCursorMs': distribution(result['localPlayRequestToCursorMs'][1::2]),
    'maxAnalysisFrameLagMs': result['maxAnalysisFrameLagMs'],
    'underruns': result['underruns'],
    'maxQueueMs': result['maxQueueMs'],
    'playbackTurnsStarted': result['playbackTurnsStarted'],
    'completedTurns': result['completedTurns'],
    'mouthsObserved': result['mouthsObserved'],
    'audioTimingScope': 'Consumed PCM sample cursor and selected analysis frame; excludes hardware speaker/display latency and phoneme accuracy',
}
speaker = folder / 'speaker-output.json'
if speaker.exists():
    audio = json.loads(speaker.read_text())
    summary['hostSpeakerLoopback'] = {k: audio[k] for k in ['seconds', 'peakRms', 'audibleBlocks', 'outputDetected', 'method']}
(folder / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
print(json.dumps(summary, indent=2))
