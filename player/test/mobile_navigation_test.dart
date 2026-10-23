import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gettopik_teacher_player/demo/demo_app.dart';

void main() {
  for (final width in [320.0, 390.0, 800.0]) {
    testWidgets('Home and character navigation at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const GettopikDemoApp());
      expect(find.text('AI Speaking'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ai-speaking-card')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('select-teacher')), findsOneWidget);
      for (final name in ['K-pop Star', 'Doctor', 'Soccer Player']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Coming Soon'), findsNWidgets(3));
      await tester.ensureVisible(find.text('Doctor'));
      await tester.tap(find.text('Doctor'));
      await tester.pumpAndSettle();
      expect(find.byType(CharacterSelectionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-speaking-card')), findsOneWidget);
    });
  }
}
