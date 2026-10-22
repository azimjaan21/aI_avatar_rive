// Test-only entry point. Forces Flutter accessibility nodes for CDP automation;
// the production entry point keeps the usual on-demand semantics behavior.
import 'package:flutter/widgets.dart';
import 'package:gettopik_teacher_player/main.dart' as studio;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  await studio.main();
}
