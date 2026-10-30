import 'package:flutter/material.dart';
import 'demo_home_screen.dart';
import 'demo_theme.dart';

export 'demo_home_screen.dart';
export 'character_selection_screen.dart';

/// Demo-only host. Feature widgets do not import this app, its routes or theme.
class GettopikDemoApp extends StatelessWidget {
  const GettopikDemoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GETTOPIK',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: demoGreen,
            surface: const Color(0xFFF8F9F6),
            onSurface: demoInk,
            primary: demoGreen,
          ),
          scaffoldBackgroundColor: const Color(0xFFF8F9F6),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF8F9F6),
            foregroundColor: demoInk,
            centerTitle: false,
            scrolledUnderElevation: 0,
          ),
          chipTheme: ChipThemeData(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        home: const DemoHomeScreen(),
      );
}
