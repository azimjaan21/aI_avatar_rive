import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:gettopik_teacher_player/main.dart';
import 'package:gettopik_teacher_player/avatar_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'PCM streaming, expressions, interruption, EOF and bounded buffering',
    (tester) async {
      await rive.RiveNative.init();
      final c = AvatarController();
      final frameTimings = <FrameTiming>[];
      void collectTimings(List<FrameTiming> frames) {
        frameTimings.addAll(frames);
        if (frameTimings.length > 1200) {
          frameTimings.removeRange(0, frameTimings.length - 1200);
        }
      }

      SchedulerBinding.instance.addTimingsCallback(collectTimings);
      Future<void> advance(int ms) async {
        for (var t = 0; t < ms; t += 20) {
          await tester.pump(const Duration(milliseconds: 20));
        }
      }

      Future<void> capture(String name) async {
        final result = await Process.run('python', [
          '../gettopik-teacher/tools/capture_window.py',
          'gettopik_teacher_player',
          '../gettopik-teacher/validation/adaptive/$name.png',
        ]);
        expect(result.exitCode, 0, reason: '${result.stdout} ${result.stderr}');
      }

      await tester.pumpWidget(TeacherApp(controller: c));
      for (var i = 0; i < 200 && !c.ready && c.error == null; i++) {
        await advance(100);
      }
      expect(c.error, isNull);
      expect(c.ready, isTrue);
      expect(c.emotionTiltProperty, isNotNull);
      expect(c.emotionBobProperty, isNotNull);
      c.onListening();
      await advance(150);
      expect(c.conversation, ConversationState.listening);
      await capture('listening');
      c.onThinking();
      await advance(150);
      expect(c.conversation, ConversationState.thinking);
      await capture('thinking');
      c.setEmotion(AvatarEmotion.smile);
      await advance(600);
      expect(c.mouth, 7);
      await capture('smile');
      c.setEmotion(AvatarEmotion.happy);
      await advance(600);
      expect(c.mouth, 7);
      expect(c.emotionBobProperty!.value, greaterThan(0));
      await capture('happy');
      c.setEmotion(AvatarEmotion.encouraging);
      await advance(600);
      expect(c.mouth, 7);
      await capture('encouraging');
      c.setEmotion(AvatarEmotion.softLaugh);
      final laughPoses = <int>{};
      for (var i = 0; i < 20; i++) {
        await advance(75);
        laughPoses.add(c.mouth);
      }
      expect(laughPoses, containsAll([1, 7]));
      await capture('soft-laugh');
      await advance(1800);
      expect(c.emotion, AvatarEmotion.neutral);
      c.onIdle();
      // Existing offline playback must continue while an emotion is activated.
      await c.toggle();
      await advance(1200);
      final offlineBefore = c.position;
      await tester.ensureVisible(find.text('Behavior lab'));
      await tester.tap(find.text('Behavior lab'));
      await advance(250);
      await tester.ensureVisible(find.byKey(const Key('emotion-smile')));
      await tester.tap(find.byKey(const Key('emotion-smile')));
      await advance(900);
      expect(c.playing, isTrue);
      expect(c.position, greaterThan(offlineBefore + .4));
      await capture('speaking-smile');
      await c.onSpeechInterrupted();
      await advance(300);
      expect(c.mouth, 6);

      // Real speaker output is measured during incrementally received PCM.
      final loopback = await Process.start('python', [
        '../gettopik-teacher/tools/capture_audio_output.py',
        '../gettopik-teacher/validation/adaptive/stream-speaker-output.json',
        '10',
      ]);
      final captureOutput = loopback.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();
      final captureErrors = loopback.stderr.transform(utf8.decoder).join();
      await captureOutput
          .firstWhere((line) => line == 'READY')
          .timeout(const Duration(seconds: 15));
      await c.setAudioMode(AvatarAudioMode.localStream);
      await c.toggle();
      final seen = <int>{};
      var silent = 0, speech = 0;
      for (var i = 0; i < 80; i++) {
        await advance(40);
        expect(c.error, isNull);
        expect(c.stream.queuedSeconds, lessThanOrEqualTo(.481));
        if (c.silence) {
          expect(c.mouth, 6);
          silent++;
        } else {
          seen.add(c.mouth);
          speech++;
        }
        if (i == 40) await capture('streaming');
      }
      expect(c.position, greaterThan(2));
      expect(seen, contains(2));
      expect(speech, greaterThan(0));
      expect(silent, greaterThan(0));
      final metrics = Map<String, dynamic>.from(c.stream.metrics);
      expect(metrics['firstChunkToPlaybackCursorMs'], isNotNull);
      expect(metrics['maxQueuedMs'], lessThanOrEqualTo(481));
      expect(metrics['analysisFramesRetained'], lessThan(60));
      await c.pause();
      final paused = c.position;
      await advance(400);
      expect((c.position - paused).abs(), lessThan(.05));
      expect(c.mouth, 6);
      c.resume();
      await advance(400);
      expect(c.position, greaterThan(paused + .15));
      await c.onSpeechInterrupted();
      await advance(400);
      expect(c.stream.active, isFalse);
      expect(c.mouth, 6);
      expect(
        await loopback.exitCode.timeout(const Duration(seconds: 15)),
        0,
        reason: await captureErrors,
      );
      final speaker = jsonDecode(
        File(
          '../gettopik-teacher/validation/adaptive/stream-speaker-output.json',
        ).readAsStringSync(),
      );
      expect(speaker['outputDetected'], isTrue);

      // Restart/seek uses a fresh bounded stream and resets its analysis history.
      final seekTarget = c.duration * .55;
      await c.seek(seekTarget);
      await c.toggle();
      await advance(500);
      expect(c.position, greaterThan(seekTarget + .1));
      await c.onSpeechInterrupted();
      // The low-energy final phrase is outside the initial streaming window.
      // Sample it explicitly so Small coverage does not depend on timer luck.
      await c.seek(9.45);
      await c.toggle();
      for (var i = 0; i < 30; i++) {
        await advance(10);
        if (!c.silence) seen.add(c.mouth);
      }
      expect(seen, containsAll([1, 2]));
      await c.onSpeechInterrupted();
      final oldTurn = await c.startPcmStream();
      await c.onSpeechInterrupted();
      expect(
        c.addPcmChunk(oldTurn, Uint8List(480)),
        PcmEnqueueResult.staleTurn,
      );
      // A short external PCM turn reaches neutral at actual playback completion.
      final turn = await c.startPcmStream();
      expect(c.addPcmChunk(turn, Uint8List(4800)), PcmEnqueueResult.accepted);
      c.finishPcmStream(turn);
      await advance(700);
      expect(c.stream.active, isFalse);
      expect(c.mouth, 6);
      expect(c.error, isNull);
      final buildMs =
          frameTimings
              .map((f) => f.buildDuration.inMicroseconds / 1000)
              .toList()
            ..sort();
      final rasterMs =
          frameTimings
              .map((f) => f.rasterDuration.inMicroseconds / 1000)
              .toList()
            ..sort();
      double percentile(List<double> values, double p) =>
          values.isEmpty ? 0 : values[((values.length - 1) * p).round()];
      File(
        '../gettopik-teacher/validation/adaptive/adaptive-report.json',
      ).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'result': 'passed',
          'audio': 'Korean female solo narration, FLEURS ko_kr/test row 4',
          'audioDurationSeconds': 12.12,
          'offlineSpeakingWithSmile': true,
          'localStreamingSpeakerOutput': true,
          'streamMetrics': metrics,
          'speechPoses': seen.toList(),
          'silenceSamples': silent,
          'expressions': [
            'neutral',
            'smile',
            'happy',
            'encouraging',
            'softLaugh',
          ],
          'conversationStates': [
            'idle',
            'listening',
            'thinking',
            'speaking',
            'smiling',
            'laughing',
          ],
          'pauseResumeSeekInterruptEofAndStaleChunk': true,
          'diagnostics': c.diagnostics,
          'frameTimings': {
            'mode':
                'Windows integration debug build; not a mobile or release benchmark',
            'samples': frameTimings.length,
            'buildP50Ms': percentile(buildMs, .5),
            'buildP95Ms': percentile(buildMs, .95),
            'rasterP50Ms': percentile(rasterMs, .5),
            'rasterP95Ms': percentile(rasterMs, .95),
          },
        }),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      SchedulerBinding.instance.removeTimingsCallback(collectTimings);
    },
  );
}
