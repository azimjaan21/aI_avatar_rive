"""Collect preliminary emulator evidence alongside mobile_test.dart.

Start before `flutter test integration_test/mobile_test.dart -d emulator-5554
--dart-define=AVATAR_PROBE=true`. Uses adb only; no app service or network API.
Writes bounded Flutter probe samples, Android PSS/CPU and real screenshots.
"""
import argparse
import json
import os
from pathlib import Path
import queue
import re
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--serial', default='emulator-5554')
parser.add_argument('--adb', default=str(Path(os.environ.get('LOCALAPPDATA', '')) / 'Android/Sdk/platform-tools/adb.exe'))
parser.add_argument('--timeout', type=int, default=1200)
parser.add_argument('--test-log', type=Path, help='Flutter test output file; integration-test print output bypasses logcat')
args = parser.parse_args()
PACKAGE = 'app.gettopik.gettopik_teacher_player'
out = ROOT / 'docs/measurements/android'
images = ROOT / 'docs/images/android'
out.mkdir(parents=True, exist_ok=True)
images.mkdir(parents=True, exist_ok=True)

def adb(*command, raw=False):
    r = subprocess.run([args.adb, '-s', args.serial, *command], capture_output=True, timeout=25)
    if r.returncode:
        raise RuntimeError(r.stderr.decode(errors='replace'))
    return r.stdout if raw else r.stdout.decode(errors='replace').strip()

def screenshot(name):
    (images / f'{name}.png').write_bytes(adb('exec-out', 'screencap', '-p', raw=True))

specs = {
    'serial': args.serial, 'model': adb('shell', 'getprop', 'ro.product.model'),
    'android': adb('shell', 'getprop', 'ro.build.version.release'),
    'api': adb('shell', 'getprop', 'ro.build.version.sdk'),
    'abi': adb('shell', 'getprop', 'ro.product.cpu.abi'),
    'kernel': adb('shell', 'uname', '-a'),
    'display': adb('shell', 'wm', 'size'), 'density': adb('shell', 'wm', 'density'),
    'memory': adb('shell', 'head', '-n', '3', '/proc/meminfo'),
    'cores': adb('shell', 'getconf', '_NPROCESSORS_ONLN'),
    'buildMode': 'debug', 'scope': 'Preliminary emulator diagnostics, not production benchmarks',
}
try:
    hz = int(adb('shell', 'getconf', 'CLK_TCK'))
except (ValueError, RuntimeError):
    hz = None
events = queue.Queue()
log = None if args.test_log else subprocess.Popen([args.adb, '-s', args.serial, 'logcat', '-v', 'brief', '-T', '1'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
def read_log():
    if args.test_log:
        while not args.test_log.exists() or args.test_log.stat().st_size < 2:
            time.sleep(.2)
        encoding = 'utf-16' if args.test_log.read_bytes()[:2] in [b'\xff\xfe', b'\xfe\xff'] else 'utf-8'
        with args.test_log.open(encoding=encoding, errors='replace') as source:
            pending = ''
            while True:
                pending += source.read()
                while '\n' in pending:
                    line, pending = pending.split('\n', 1)
                    if 'GETTOPIK_' in line:
                        events.put(line.strip())
                time.sleep(.2)
        return
    for line in iter(log.stdout.readline, b''):
        text = line.decode(errors='replace')
        if 'GETTOPIK_' in text:
            events.put(text.strip())
threading.Thread(target=read_log, daemon=True).start()
report = {'specs': specs, 'collectorStartUnixSeconds': time.time(), 'androidSamples': [], 'flutterSamples': [], 'stages': [], 'testResult': None}
start = time.monotonic()
session_start = None
next_sample = 0
previous_cpu = None

def sample():
    global previous_cpu
    elapsed = time.monotonic() - start
    pids = adb('shell', 'pidof', PACKAGE).split()
    if not pids:
        return
    pid = pids[0]
    mem = adb('shell', 'dumpsys', 'meminfo', PACKAGE)
    match = re.search(r'TOTAL PSS:\s*(\d+)', mem)
    if not match:
        match = re.search(r'^\s*TOTAL\s+(\d+)', mem, re.M)
    row = {'wallSeconds': round(elapsed, 3), 'sessionSeconds': round(time.monotonic() - session_start, 3) if session_start else None,
           'pid': int(pid), 'pssKiB': int(match[1]) if match else None}
    try:
        stat = adb('shell', 'run-as', PACKAGE, 'cat', f'/proc/{pid}/stat')
        fields = stat[stat.rfind(')') + 2:].split()
        ticks = int(fields[11]) + int(fields[12])
        now = time.monotonic()
        if hz and previous_cpu and previous_cpu[0] == pid:
            row['cpuPercentOneCore'] = round(100 * (ticks - previous_cpu[1]) / hz / (now - previous_cpu[2]), 3)
        previous_cpu = (pid, ticks, now)
    except (RuntimeError, ValueError, IndexError):
        row['cpuPercentOneCore'] = None
    report['androidSamples'].append(row)
    print(json.dumps(row), flush=True)

try:
    while time.monotonic() - start < args.timeout:
        try:
            line = events.get(timeout=.2)
        except queue.Empty:
            line = ''
        if 'GETTOPIK_STAGE ' in line:
            stage = line.split('GETTOPIK_STAGE ', 1)[1].strip()
            report['stages'].append({'stage': stage, 'wallSeconds': time.monotonic() - start})
            print('STAGE', stage, flush=True)
            if stage in ['home', 'characters', 'teacher']:
                screenshot(stage)
            if stage == 'background-test':
                adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
                time.sleep(2)
                adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
            if stage == 'five-minute-start':
                session_start = time.monotonic()
                sample()
                next_sample = time.monotonic() + 10
                # Host loopback measures emulator speaker output, not Android
                # hardware speaker latency or per-phoneme synchronization.
                subprocess.Popen(['python', str(ROOT / 'gettopik-teacher/tools/capture_audio_output.py'),
                    str(out / 'speaker-output.json'), '14'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if stage == 'five-minute-end':
                sample()
                (out / 'gfxinfo.txt').write_text(adb('shell', 'dumpsys', 'gfxinfo', PACKAGE, 'framestats'), encoding='utf-8')
                break
        if 'GETTOPIK_METRIC ' in line:
            try:
                report['flutterSamples'].append(json.loads(line.split('GETTOPIK_METRIC ', 1)[1]))
            except json.JSONDecodeError:
                report.setdefault('truncatedProbeLines', 0)
                report['truncatedProbeLines'] += 1
        if 'GETTOPIK_TEST_RESULT ' in line:
            report['testResult'] = json.loads(line.split('GETTOPIK_TEST_RESULT ', 1)[1])
        if session_start and time.monotonic() >= next_sample:
            sample()
            next_sample = time.monotonic() + 10
        (out / 'emulator-report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
finally:
    if log:
        log.terminate()
    (out / 'emulator-report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print('Saved', out / 'emulator-report.json', flush=True)
