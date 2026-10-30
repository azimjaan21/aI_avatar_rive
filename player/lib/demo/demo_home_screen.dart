import 'package:flutter/material.dart';
import 'demo_theme.dart';
import 'character_selection_screen.dart';
import 'widgets/demo_pill.dart';
import 'widgets/demo_feature.dart';

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
                      Icon(Icons.spa_rounded, color: demoGreen, size: 27),
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
                        foregroundColor: demoGreen,
                        child: Icon(Icons.person_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'YOUR KOREAN JOURNEY',
                    style: TextStyle(
                      fontSize: 11,
                      color: demoGreen,
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
                                      const Color(0xFFE0EEDB)
                                          .withValues(alpha: .9),
                                      const Color(0xFFE0EEDB)
                                          .withValues(alpha: 0),
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
                                  DemoPill('TRY THE DEMO', color: Colors.white),
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
                                      style:
                                          TextStyle(height: 1.5, fontSize: 14),
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
                                        backgroundColor: demoInk,
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
                  const DemoFeature(
                    icon: Icons.headphones_rounded,
                    title: 'Listen naturally',
                    subtitle: 'Real Korean audio with a familiar teacher.',
                  ),
                  const DemoFeature(
                    icon: Icons.favorite_outline_rounded,
                    title: 'Learn at your pace',
                    subtitle: 'Pause, replay and get comfortable.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'OFFLINE EXPERIENCE',
                    style: TextStyle(
                        fontSize: 10, letterSpacing: 2, color: demoGreen),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
