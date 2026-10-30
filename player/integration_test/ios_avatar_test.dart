import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:gettopik_teacher_player/avatar_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Teacher paints visible pixels and plays on iOS', (tester) async {
    await rive.RiveNative.init();
    final avatar = AvatarController();
    final boundaryKey = GlobalKey();
    await avatar.load();
    expect(avatar.error, isNull);
    expect(avatar.ready, isTrue);
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(
          width: 300,
          height: 400,
          child: rive.RiveWidget(
            controller: avatar.riveController!,
            fit: rive.Fit.contain,
          )),
    ))));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final pixels =
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    var visible = 0;
    for (var i = 3; i < pixels.lengthInBytes; i += 4) {
      if (pixels.getUint8(i) > 32) visible++;
    }
    image.dispose();
    expect(visible, greaterThan(10000),
        reason: 'Teacher must paint actual visible pixels');
    await avatar.toggle();
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(avatar.error, isNull);
    expect(avatar.position, greaterThan(.1));
    await avatar.pause();
    expect(avatar.transportActive, isFalse);
    await tester.pumpWidget(const SizedBox());
    avatar.dispose();
  });
}
