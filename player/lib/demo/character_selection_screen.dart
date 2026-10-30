import 'package:flutter/material.dart';
import 'demo_theme.dart';
import '../features/ai_speaking/ai_speaking.dart';
import 'widgets/demo_pill.dart';

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
                                  DemoPill('ACTIVE', color: Colors.white),
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
                                    backgroundColor: demoGreen,
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
                                width: (constraints.maxWidth -
                                        12 * (columns - 1)) /
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
