import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:gettopik_teacher_player/demo/demo_app.dart';
import 'package:gettopik_teacher_player/features/ai_speaking/ai_speaking.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Android navigation, playback, lifecycle and five-minute session',
    (tester) async {
      await rive.RiveNative.init();
      Future<void> advance(int ms) async {
        for (var t = 0; t < ms; t += 100) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      void stage(String name) => debugPrint('GETTOPIK_STAGE $name');
      AvatarController controller() {
        final dynamic state = tester.state(find.byType(AiSpeakingScreen));
        return state.avatar as AvatarController;
      }

      Future<AvatarController> open() async {
        await tester.ensureVisible(find.byKey(const Key('select-teacher')));
        await tester.tap(find.byKey(const Key('select-teacher')));
        await advance(800);
        final c = controller();
        for (var n = 0; n < 600 && !c.ready && c.error == null; n++) {
          await advance(100);
        }
        expect(c.error, isNull);
        expect(c.ready, isTrue);
        expect(c.lipSyncStyle, LipSyncStyle.lightweight);
        return c;
      }

      await tester.pumpWidget(const GettopikDemoApp());
      await advance(1000);
      stage('home');
      await advance(2000);
      await tester.tap(find.byKey(const Key('ai-speaking-card')));
      await advance(800);
      stage('characters');
      await advance(2000);
      var c = await open();
      stage('teacher');
      await advance(2000);
      await tester.ensureVisible(find.byKey(const Key('play-pause')));
      await tester.tap(find.byKey(const Key('play-pause')));
      final mouths = <int>{};
      var silentSamples = 0;
      for (var n = 0; n < 45; n++) {
        await advance(100);
        mouths.add(c.mouth);
        if (c.silence && c.emotion == AvatarEmotion.neutral) {
          expect(c.mouth, 6);
          silentSamples++;
        }
      }
      expect(c.error, isNull);
      expect(c.position, greaterThan(2));
      expect(mouths, contains(1));
      expect(mouths, contains(2));
      expect(mouths, isNot(contains(3)));
      final beforePause = c.position;
      await c.pause();
      await advance(700);
      expect((c.position - beforePause).abs(), lessThan(.1));
      expect(c.mouth, 6);
      await c.seek(2);
      await c.toggle();
      await advance(1000);
      expect(c.position, greaterThan(2.4));
      for (final emotion in AvatarEmotion.values) {
        c.setEmotion(emotion);
        await advance(200);
        expect(c.emotion, emotion);
      }
      c.resetEmotion();
      for (final eye in [-1, 0, 1]) {
        c.selectEye(eye);
        await advance(100);
        expect(c.eyePose, eye);
      }
      c.selectEye(-1);
      // Host adb sends HOME and then restores this activity at this marker.
      stage('background-test');
      final backgroundPosition = c.position;
      await advance(8000);
      expect(c.presentationSuspensions, greaterThan(0));
      expect(c.position - backgroundPosition, lessThan(1));
      expect(c.transportActive, isFalse);
      expect(c.mouth, 6);
      await c.toggle();
      await advance(1000);
      expect(c.transportActive, isTrue);
      await c.stop();
      final reopenLoadMs = <double>[];
      for (var n = 0; n < 5; n++) {
        await tester.tap(find.byKey(const Key('close-speaking')));
        await advance(600);
        expect(find.byType(CharacterSelectionScreen), findsOneWidget);
        c = await open();
        reopenLoadMs.add(c.readyLoadMs!);
        await c.toggle();
        await advance(500);
        await c.stop();
      }
      // Five minutes of actual wall-clock playback, alternating the same engine's
      // local-file and chunked-stream producers. No substitute simulated clock.
      stage('five-minute-start');
      final session = Stopwatch()..start();
      var turns = 0, totalUnderruns = 0;
      var maxLag = 0.0, maxQueue = 0.0;
      final starts = <double>[];
      final requestStarts = <double>[];
      while (session.elapsed < const Duration(minutes: 5)) {
        await c.setAudioMode(
          turns.isEven ? AvatarAudioMode.offline : AvatarAudioMode.localStream,
        );
        await c.seek(0);
        await c.toggle();
        while (c.position < c.duration - .05 &&
            session.elapsed < const Duration(minutes: 5)) {
          await advance(100);
          expect(c.error, isNull);
          if (c.stream.firstPlaybackMs != null && (starts.length <= turns)) {
            starts.add(c.stream.firstPlaybackMs!);
          }
          if (c.playRequestToCursorMs != null &&
              requestStarts.length <= turns) {
            requestStarts.add(c.playRequestToCursorMs!);
          }
          if (c.stream.maxFrameLagMs > maxLag) maxLag = c.stream.maxFrameLagMs;
          if (c.stream.maxQueuedSeconds > maxQueue) {
            maxQueue = c.stream.maxQueuedSeconds;
          }
        }
        totalUnderruns += c.stream.underruns;
        turns++;
      }
      await c.pause();
      final report = <String, dynamic>{
        'test': 'mobile',
        'elapsedSeconds': session.elapsedMilliseconds / 1000,
        'playbackTurnsStarted': turns,
        'completedTurns': c.position >= c.duration - .05 ? turns : turns - 1,
        'mouthsObserved': mouths.toList(),
        'silentSamples': silentSamples,
        'underruns': totalUnderruns,
        'maxAnalysisFrameLagMs': maxLag,
        'maxQueueMs': maxQueue * 1000,
        'audioStartupCursorMs': starts,
        'localPlayRequestToCursorMs': requestStarts,
        'reopenReadyMs': reopenLoadMs,
        'diagnostics': c.diagnostics,
      };
      binding.reportData = report;
      debugPrint('GETTOPIK_TEST_RESULT ${jsonEncode(report)}');
      stage('five-minute-end');
      await advance(3000);
      await tester.tap(find.byKey(const Key('close-speaking')));
      await advance(500);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
