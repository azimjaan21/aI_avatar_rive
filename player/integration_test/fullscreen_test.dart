import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:gettopik_teacher_player/demo/demo_app.dart';
import 'package:gettopik_teacher_player/features/ai_speaking/ai_speaking.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Call view keeps the same Rive and playback clock', (
    tester,
  ) async {
    await rive.RiveNative.init();
    Future<void> advance(int ms) async {
      for (var n = 0; n < ms; n += 100) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.pumpWidget(const GettopikDemoApp());
    await advance(700);
    await tester.tap(find.byKey(const Key('ai-speaking-card')));
    await advance(600);
    await tester.tap(find.byKey(const Key('select-teacher')));
    await advance(800);
    final dynamic screen = tester.state(find.byType(AiSpeakingScreen));
    final c = screen.avatar as AvatarController;
    for (var n = 0; n < 200 && !c.ready && c.error == null; n++) {
      await advance(100);
    }
    expect(c.error, isNull);
    expect(c.ready, isTrue);
    final rig = c.riveController;
    await c.toggle();
    await advance(700);
    final position = c.position;
    final breath = c.breathProperty!.value;
    await tester.tap(find.byKey(const Key('enter-fullscreen')));
    await advance(1200);
    expect(find.byKey(const Key('call-play-pause')), findsOneWidget);
    expect(find.byKey(const Key('teacher-avatar')), findsOneWidget);
    expect(c.riveController, same(rig));
    expect(c.position, greaterThan(position + .5));
    expect(c.breathProperty!.value, lessThan(breath));
    await tester.tap(find.byKey(const Key('call-emotion-smile')));
    await advance(400);
    expect(c.emotion, AvatarEmotion.smile);
    expect(c.transportActive, isTrue);
    await tester.tap(find.byKey(const Key('call-play-pause')));
    await advance(300);
    final paused = c.position;
    await advance(300);
    expect((c.position - paused).abs(), lessThan(.1));
    c.resetEmotion();
    expect(c.mouth, 6);
    await tester.tap(find.byKey(const Key('call-play-pause')));
    await advance(500);
    expect(c.transportActive, isTrue);
    await tester.tap(find.byKey(const Key('exit-fullscreen')));
    await advance(400);
    expect(find.byKey(const Key('enter-fullscreen')), findsOneWidget);
    expect(c.riveController, same(rig));
    expect(c.breathProperty!.value, closeTo(breath, .0001));
    await tester.tap(find.byKey(const Key('enter-fullscreen')));
    await advance(400);
    await binding.handlePopRoute();
    await advance(400);
    expect(find.byKey(const Key('enter-fullscreen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('enter-fullscreen')));
    await advance(300);
    await tester.tap(find.byKey(const Key('call-end')));
    await advance(700);
    expect(find.byType(CharacterSelectionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
