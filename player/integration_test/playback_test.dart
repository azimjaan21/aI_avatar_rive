import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:gettopik_teacher_player/main.dart';
import 'package:gettopik_teacher_player/avatar_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native audio drives mouth; silence, pause, seek, resume, all poses',
    (tester) async {
      await rive.RiveNative.init();
      final c = AvatarController();
      Future<void> advanceFor(int milliseconds) async {
        for (var t = 0; t < milliseconds; t += 25) {
          await tester.pump(const Duration(milliseconds: 25));
        }
      }

      await tester.pumpWidget(TeacherApp(controller: c));
      for (var i = 0; i < 200 && !c.ready && c.error == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(c.error, isNull);
      expect(c.ready, isTrue);
      expect(c.mouth, 6);
      expect(c.mouthProperty!.value, 6);
      expect(c.motionProperty!.value, 0);
      // Native viewport size controls breathing amplitude rather than artwork size.
      await tester.pump(const Duration(milliseconds: 100));
      final avatarSize = tester.getSize(
        find.byKey(const Key('teacher-avatar')),
      );
      final displayScale = avatarSize.width / 1086 < avatarSize.height / 1448
          ? avatarSize.width / 1086
          : avatarSize.height / 1448;
      expect(c.breathProperty!.value * 8 * displayScale, closeTo(2, .01));
      expect(find.byKey(const Key('mouth-0')), findsNothing);
      expect(find.byKey(const Key('mouth-3')), findsNothing);
      expect(find.byKey(const Key('eye-2')), findsNothing);
      final evidence = <String, dynamic>{
        'source': c.source,
        'duration': c.duration,
        'samples': <dynamic>[],
      };
      final samples = evidence['samples'] as List<dynamic>;
      Future<void> capture(String name) async {
        final r = await Process.run('python', [
          '../gettopik-teacher/tools/capture_window.py',
          'gettopik_teacher_player',
          '../gettopik-teacher/validation/$name.png',
        ]);
        expect(r.exitCode, 0, reason: '${r.stdout} ${r.stderr}');
      }

      // Hold each actual source PNG past the first scheduled blink at 3.05 s.
      expect(c.eyeProperty!.value, -1);
      for (var pose = 0; pose < 2; pose++) {
        final chip = find.byKey(Key('eye-$pose'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await advanceFor(3300);
        expect(c.eyePose, pose);
        expect(c.eyeProperty!.value, pose.toDouble());
        await capture('eye-${const ['open', 'half', 'closed'][pose]}');
        // Mouth inspection must leave the selected eye PNG held.
        await c.selectMouth(1);
        await advanceFor(100);
        expect(c.eyeProperty!.value, pose.toDouble());
        await c.selectMouth(null);
      }
      c.selectEye(2);
      await advanceFor(100);
      expect(c.eyePose, 1);
      expect(c.eyeProperty!.value, 1);
      await tester.tap(find.byKey(const Key('eye-auto')));
      await advanceFor(100);
      expect(c.eyePose, -1);
      expect(c.eyeProperty!.value, -1);
      evidence['eyePoseControls'] = {
        'manualOpenHalfHoldPastBlink': true,
        'closedTemporarilyDisabled': true,
        'mouthSelectionIndependent': true,
        'autoRestored': true,
      };

      await tester.pump(const Duration(milliseconds: 300));
      await capture('player-ready');
      final loopback = await Process.start('python', [
        '../gettopik-teacher/tools/capture_audio_output.py',
        '../gettopik-teacher/validation/audio-output-report.json',
        '13',
      ]);
      final outputReady = loopback.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();
      await outputReady
          .firstWhere((line) => line == 'READY')
          .timeout(const Duration(seconds: 15));
      await tester.tap(find.byKey(const Key('play-pause')));
      c.selectEye(0);
      final observed = <int>{};
      var silent = 0;
      var speech = 0;
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        samples.add({
          'time': c.position,
          'playing': c.playing,
          'mouth': c.mouth,
          'silence': c.silence,
          'riveValue': c.mouthProperty!.value,
          'motionTalking': c.motionProperty!.value,
        });
        if (c.silence) {
          expect(c.mouth, 6);
          silent++;
        } else {
          expect(c.motionProperty!.value, 1);
          observed.add(c.mouth);
          speech++;
        }
        expect(c.mouthProperty!.value, c.mouth.toDouble());
        if (i < 60) expect(c.eyeProperty!.value, 0);
        if (i == 60) c.selectEye(-1);
        if (i == 50) await capture('player-speaking');
      }
      expect(c.position, greaterThan(8));
      expect(observed.length, greaterThan(1));
      expect(observed, isNot(contains(3)));
      expect(observed, isNot(contains(0)));
      expect(observed, containsAll([1, 2]));
      expect(c.frames.every((f) => f['mouth'] != 0 && f['mouth'] != 3), isTrue);
      expect(silent, greaterThan(0));
      expect(speech, greaterThan(0));
      expect(await loopback.exitCode.timeout(const Duration(seconds: 15)), 0);
      final audioOutput = jsonDecode(
        File(
          '../gettopik-teacher/validation/audio-output-report.json',
        ).readAsStringSync(),
      );
      expect(audioOutput['outputDetected'], isTrue);
      evidence['speakerLoopbackOutputDetected'] = true;
      await tester.tap(find.byKey(const Key('play-pause')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.playing, isFalse);
      expect(c.motionProperty!.value, 0);
      expect(c.mouth, 6);
      final paused = c.position;
      await advanceFor(700);
      expect((c.position - paused).abs(), lessThan(.12));
      await capture('player-paused');
      // The original MP3 has a measured pause from 8.05 to 8.57 s.
      await c.seek(8.15);
      await c.toggle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.silence, isTrue);
      expect(c.mouth, 6);
      await advanceFor(700);
      expect(c.position, greaterThan(8.6));
      if (c.playing) await c.toggle();
      await c.seek(30);
      await c.toggle();
      await advanceFor(500);
      expect(c.position, greaterThan(30.2));
      await c.toggle();
      for (var i = 0; i < 8; i++) {
        if (i == 0 || i == 3) continue;
        await c.selectMouth(i);
        await tester.pump(const Duration(milliseconds: 120));
        expect(c.mouth, i);
        expect(c.mouthProperty!.value, i.toDouble());
        expect(c.motionProperty!.value, 0);
      }
      await c.selectMouth(3);
      await advanceFor(100);
      expect(c.mouth, 2); // Even legacy Wide requests safely select Medium.
      await c.selectMouth(0);
      await advanceFor(100);
      expect(c.mouth, 6); // Legacy Rest requests use Closed press.
      expect(c.mouthProperty!.value, 6);
      await c.selectMouth(null);
      // Confirm completion closes the mouth and Play starts again at the beginning.
      await c.seek(c.duration - .4);
      await c.toggle();
      await advanceFor(1000);
      expect(c.playing, isFalse);
      expect(c.mouth, 6);
      await c.toggle();
      await advanceFor(350);
      expect(c.playing, isTrue);
      expect(c.position, lessThan(2));
      await c.toggle();
      evidence.addAll({
        'result': 'passed',
        'speechPoses': observed.toList(),
        'silenceSamples': silent,
        'speechSamples': speech,
        'pausedPosition': paused,
        'allSixActivePoses': true,
        'restAssetDisabled': true,
        'silencePose': 'closed_press',
        'wideAssetDisabled': true,
        'completionAndReplay': true,
        'audioDrivenMotion': true,
        'breathingDisplayAmplitude': 2,
      });
      File(
        '../gettopik-teacher/validation/playback-report.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(evidence));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
