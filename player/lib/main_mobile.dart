import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;
import 'demo/demo_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await rive.RiveNative.init();
  runApp(const GettopikDemoApp());
}
