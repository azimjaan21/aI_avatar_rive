import 'package:flutter/material.dart';
import '../features/ai_speaking/ai_speaking.dart';

const _ink = Color(0xFF182D2A);
const _green = Color(0xFF24745F);

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
        seedColor: _green,
        surface: const Color(0xFFF8F9F6),
        onSurface: _ink,
        primary: _green,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9F6),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8F9F6),
        foregroundColor: _ink,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    home: const DemoHomeScreen(),
  );
}

class DemoHomeScreen extends StatelessWidget {
  const DemoHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Row(
                children: [
                  Icon(Icons.spa_rounded, color: _green, size: 27),
                  SizedBox(width: 9),
                  Text(
                    'GETTOPIK',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Spacer(),
                  CircleAvatar(
                    backgroundColor: Color(0xFFE6EDE5),
                    foregroundColor: _green,
                    child: Icon(Icons.person_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Text(
                'YOUR KOREAN JOURNEY',
                style: TextStyle(
                  fontSize: 11,
                  color: _green,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Small conversations.\nBig possibilities.',
                style: TextStyle(
                  fontSize: 34,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Build confidence, one Korean phrase at a time.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 30),
              Material(
                color: const Color(0xFFE0EEDB),
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('ai-speaking-card'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CharacterSelectionScreen(),
                    ),
                  ),
                  child: SizedBox(
                    height: 360,
                    child: Stack(
                      children: [
                        Positioned(
                          right: -36,
                          bottom: -4,
                          width: 225,
                          height: 285,
                          child: ExcludeSemantics(
                            child: Image.asset(
                              'assets/teacher_portrait.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFE0EEDB),
                                  const Color(0xFFE0EEDB).withValues(alpha: .9),
                                  const Color(0xFFE0EEDB).withValues(alpha: 0),
                                ],
                                stops: const [0, .35, .78],
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Pill('TRY THE DEMO', color: Colors.white),
                              SizedBox(height: 22),
                              Text(
                                'AI Speaking',
                                style: TextStyle(
                                  fontSize: 29,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.7,
                                ),
                              ),
                              SizedBox(height: 8),
                              SizedBox(
                                width: 170,
                                child: Text(
                                  'Meet your Korean\nconversation partner.',
                                  style: TextStyle(height: 1.5, fontSize: 14),
                                ),
                              ),
                              Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Meet your teacher',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _ink,
                                    foregroundColor: Colors.white,
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 19,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'A space to find your voice',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
              ),
              const SizedBox(height: 16),
              const _Feature(
                icon: Icons.headphones_rounded,
                title: 'Listen naturally',
                subtitle: 'Real Korean audio with a familiar teacher.',
              ),
              const _Feature(
                icon: Icons.favorite_outline_rounded,
                title: 'Learn at your pace',
                subtitle: 'Pause, replay and get comfortable.',
              ),
              const SizedBox(height: 16),
              const Text(
                'OFFLINE EXPERIENCE',
                style: TextStyle(fontSize: 10, letterSpacing: 2, color: _green),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CharacterSelectionScreen extends StatelessWidget {
  const CharacterSelectionScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'AI Speaking',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
            children: [
              const Text(
                'Who will you\nspeak with?',
                style: TextStyle(
                  fontSize: 34,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose a partner for your Korean journey.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              Material(
                color: const Color(0xFFE1EDDC),
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('select-teacher'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (routeContext) => AiSpeakingScreen(
                        onClose: () => Navigator.of(routeContext).pop(),
                      ),
                    ),
                  ),
                  child: SizedBox(
                    height: 260,
                    child: Stack(
                      children: [
                        Positioned(
                          right: 0,
                          top: 8,
                          bottom: 0,
                          width: 190,
                          child: Image.asset(
                            'assets/teacher_portrait.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Pill('ACTIVE', color: Colors.white),
                              Spacer(),
                              Text(
                                'Korean\nTeacher',
                                style: TextStyle(
                                  fontSize: 27,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Patient. Warm. Familiar.',
                                style: TextStyle(fontSize: 12),
                              ),
                              SizedBox(height: 15),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: _green,
                                foregroundColor: Colors.white,
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'More voices, coming soon',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 330 ? 3 : 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final entry in const {
                        'K-pop Star': Icons.music_note_rounded,
                        'Doctor': Icons.medical_services_outlined,
                        'Soccer Player': Icons.sports_soccer_rounded,
                      }.entries)
                        Semantics(
                          label: '${entry.key}, Coming Soon',
                          enabled: false,
                          child: Container(
                            width:
                                (constraints.maxWidth - 12 * (columns - 1)) /
                                columns,
                            height: 156,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE4E8E2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  entry.value,
                                  size: 29,
                                  color: const Color(0xFF83918A),
                                ),
                                const Spacer(),
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Coming Soon',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF83918A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w800,
        color: _green,
      ),
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0E5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _green),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
