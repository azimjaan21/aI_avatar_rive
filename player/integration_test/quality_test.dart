import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:gettopik_teacher_player/main.dart';
import 'package:gettopik_teacher_player/avatar_controller.dart';

// Run A and B in separate processes so GPU/cache retention does not pollute RSS.
// A needs the pre-change .riv copied temporarily to assets/teacher_baseline.riv.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const variant = String.fromEnvironment(
    'AVATAR_BENCH_CASE',
    defaultValue: 'B',
  );
  testWidgets('Actual PCM playback and normal-size Teacher comparison $variant', (
    tester,
  ) async {
    await rive.RiveNative.init();
    final c = AvatarController(
      rivAsset: variant == 'A' ? 'assets/teacher_baseline.riv' : null,
    );
    c.setLipSyncStyle(
      variant == 'A' ? LipSyncStyle.rms : LipSyncStyle.lightweight,
    );
    Future<void> advance(int ms) async {
      for (var t = 0; t < ms; t += 20) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    Future<Map<String, dynamic>> processMetrics() async {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '\$p=Get-Process -Id $pid; [pscustomobject]@{cpuMs=\$p.TotalProcessorTime.TotalMilliseconds; workingSetBytes=\$p.WorkingSet64; privateBytes=\$p.PrivateMemorySize64} | ConvertTo-Json -Compress',
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return jsonDecode(result.stdout as String) as Map<String, dynamic>;
    }

    Future<void> capture(String name) async {
      final result = await Process.run('python', [
        '../gettopik-teacher/tools/capture_window.py',
        'gettopik_teacher_player',
        '../gettopik-teacher/validation/lipsync-quality/$variant-$name.png',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout} ${result.stderr}');
    }

    await tester.pumpWidget(TeacherApp(controller: c));
    for (var i = 0; i < 200 && !c.ready && c.error == null; i++) {
      await advance(50);
    }
    expect(c.error, isNull);
    expect(c.ready, isTrue);
    await advance(500);
    final size = tester.getSize(find.byKey(const Key('teacher-avatar')));
    final scale = math.min(size.width / 1086, size.height / 1448);
    await c.setAudioMode(AvatarAudioMode.localStream);
    final times = <FrameTiming>[];
    void collect(List<FrameTiming> data) {
      times.addAll(data);
    }

    SchedulerBinding.instance.addTimingsCallback(collect);
    final before = await processMetrics();
    final wall = Stopwatch()..start();
    var peakRss = ProcessInfo.currentRss;
    final trace = <Map<String, dynamic>>[];
    await c.toggle();
    for (var i = 0; i < 700 && c.position < 9.8; i++) {
      await advance(20);
      peakRss = math.max(peakRss, ProcessInfo.currentRss);
      expect(c.error, isNull);
      if (c.silence) expect(c.mouth, 6);
      trace.add({
        'time': c.position,
        'mouth': c.mouth,
        'energy': c.energy,
        'silence': c.silence,
      });
    }
    expect(c.position, greaterThan(9.5));
    final after = await processMetrics();
    wall.stop();
    final streamMetrics = Map<String, dynamic>.from(c.stream.metrics);
    expect(streamMetrics['underruns'], 0);
    expect(streamMetrics['maxQueuedMs'], lessThanOrEqualTo(481));
    SchedulerBinding.instance.removeTimingsCallback(collect);
    await c.pause();
    final frozen = c.position;
    await advance(200);
    expect(c.position, closeTo(frozen, .04));
    final build =
        times.map((t) => t.buildDuration.inMicroseconds / 1000).toList()
          ..sort();
    final raster =
        times.map((t) => t.rasterDuration.inMicroseconds / 1000).toList()
          ..sort();
    double p95(List<double> v) =>
        v.isEmpty ? 0 : v[((v.length - 1) * .95).round()];
    final report = <String, dynamic>{
      'result': 'passed',
      'case': variant,
      'platform': 'Windows Flutter integration debug',
      'rig': variant == 'A'
          ? 'Original full-canvas PNGs and 45ms opacity fades'
          : 'Lossless cropped PNGs and exclusive Solo selection',
      'estimator': c.lipSyncStyle.name,
      'audioClock': streamMetrics,
      'wallSampleMs': wall.elapsedMicroseconds / 1000,
      'processCpuMs': (after['cpuMs'] as num) - (before['cpuMs'] as num),
      'cpuPercentOfOneCore':
          ((after['cpuMs'] as num) - (before['cpuMs'] as num)) /
          (wall.elapsedMicroseconds / 1000) *
          100,
      'workingSetBefore': before['workingSetBytes'],
      'workingSetAfter': after['workingSetBytes'],
      'peakSampledRssBytes': peakRss,
      'privateBytesAfter': after['privateBytes'],
      'buildP95Ms': p95(build),
      'rasterP95Ms': p95(raster),
      'frameSamples': times.length,
      'avatarDisplaySize': [size.width, size.height],
      'mouthWidthDisplayPixels': 176 * scale,
      'scope':
          'No capture during CPU sample. Debug desktop measurements, not mobile, release or acoustic latency.',
      'trace': trace,
    };
    for (final pose in [6, 1, 2, 4, 5, 7]) {
      await c.selectMouth(pose);
      await advance(160);
      await capture('pose-$pose');
    }
    // Capture actual moving speech separately from resource measurements.
    // No zoom or enlarged avatar is used. Each PNG has its playback position.
    await c.selectMouth(null);
    await c.seek(0);
    await c.toggle();
    await advance(1400);
    final visualFrames = <Map<String, dynamic>>[];
    for (var i = 0; i < 8; i++) {
      final name = 'speech-$i';
      visualFrames.add({
        'file': '$variant-$name.png',
        'time': c.position,
        'mouth': c.mouth,
        'silence': c.silence,
      });
      await capture(name);
      await advance(100);
    }
    await c.onSpeechInterrupted();
    report['visualSpeechFrames'] = visualFrames;
    File(
      '../gettopik-teacher/validation/lipsync-quality/$variant-playback-report.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
