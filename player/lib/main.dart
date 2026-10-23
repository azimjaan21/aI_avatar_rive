import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:rive/rive.dart' as rive;
import 'avatar_controller.dart';
import 'behavior_lab.dart';
import 'demo/demo_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await rive.RiveNative.init();
  runApp(
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? const GettopikDemoApp()
        : const TeacherApp(),
  );
}

class TeacherApp extends StatelessWidget {
  const TeacherApp({super.key, this.controller});
  final AvatarController? controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GETTOPIK · Speaking Studio',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFC2E4A1),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF101916),
      fontFamily: 'Segoe UI',
    ),
    home: TeacherPage(controller: controller),
  );
}

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key, this.controller});
  final AvatarController? controller;
  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  late final AvatarController avatar;
  bool classroom = true;
  @override
  void initState() {
    super.initState();
    avatar = widget.controller ?? AvatarController();
    avatar.load();
  }

  @override
  void dispose() {
    avatar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: avatar,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.graphic_eq, color: Color(0xFFC2E4A1)),
                  const SizedBox(width: 10),
                  const Text(
                    'GETTOPIK',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Text(
                    'SPEAKING STUDIO',
                    style: TextStyle(
                      color: Colors.white54,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  const Chip(
                    label: Text('LOCAL AUDIO'),
                    avatar: Icon(Icons.offline_bolt, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (classroom)
                              Image.asset(
                                avatar.profile.backgroundAsset,
                                fit: BoxFit.cover,
                              )
                            else
                              const ColoredBox(color: Color(0xFF53615A)),
                            if (avatar.riveController != null)
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  avatar.configureViewport(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  );
                                  return rive.RiveWidget(
                                    key: const Key('teacher-avatar'),
                                    controller: avatar.riveController!,
                                    fit: rive.Fit.contain,
                                    alignment: Alignment.bottomCenter,
                                  );
                                },
                              ),
                            Positioned(
                              top: 18,
                              left: 18,
                              child: Chip(
                                label: Text(
                                  avatar.playing ? '선생님이 말하고 있어요' : '한국어 선생님',
                                ),
                                avatar: Icon(
                                  avatar.playing
                                      ? Icons.volume_up
                                      : Icons.school,
                                  size: 16,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 18,
                              right: 18,
                              child: IconButton.filledTonal(
                                tooltip: 'Toggle classroom',
                                onPressed: () =>
                                    setState(() => classroom = !classroom),
                                icon: Icon(
                                  classroom ? Icons.layers : Icons.landscape,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            const Text(
                              'LISTEN & PRACTICE',
                              style: TextStyle(
                                color: Color(0xFFC2E4A1),
                                letterSpacing: 2,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '한국어로\n이야기해요.',
                              style: TextStyle(
                                fontSize: 36,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Your Korean speaking teacher',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 26),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D2B25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TODAY’S AUDIO',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    avatar.source.isEmpty
                                        ? 'Loading lesson…'
                                        : avatar.source,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(height: 18),
                                  Slider(
                                    key: const Key('audio-seek'),
                                    value: avatar.position.clamp(
                                      0,
                                      avatar.duration,
                                    ),
                                    min: 0,
                                    max: avatar.duration > 0
                                        ? avatar.duration
                                        : 1,
                                    onChanged: avatar.ready
                                        ? (v) => avatar.seek(v)
                                        : null,
                                  ),
                                  Row(
                                    children: [
                                      Text(_clock(avatar.position)),
                                      const Spacer(),
                                      Text(
                                        _clock(avatar.duration),
                                        style: const TextStyle(
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          key: const Key('play-pause'),
                                          onPressed: avatar.ready
                                              ? avatar.toggle
                                              : null,
                                          icon: Icon(
                                            avatar.playing
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                          ),
                                          label: Text(
                                            avatar.playing
                                                ? 'Pause'
                                                : 'Play lesson',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton.filledTonal(
                                        tooltip: 'Restart',
                                        onPressed: avatar.ready
                                            ? () => avatar.seek(0)
                                            : null,
                                        icon: const Icon(Icons.replay),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Icon(
                                  avatar.silence
                                      ? Icons.more_horiz
                                      : Icons.graphic_eq,
                                  size: 18,
                                  color: const Color(0xFFC2E4A1),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  avatar.manualMouth != null
                                      ? 'Pose preview'
                                      : avatar.playing
                                      ? (avatar.silence
                                            ? 'Listening pause'
                                            : 'Speaking')
                                      : 'Ready when you are',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: avatar.energy,
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Eye poses',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                for (var i = -1; i < 2; i++)
                                  ChoiceChip(
                                    key: Key(i == -1 ? 'eye-auto' : 'eye-$i'),
                                    label: Text(
                                      const ['Auto', 'Open', 'Half'][i + 1],
                                    ),
                                    tooltip: i == -1
                                        ? 'Natural blinking'
                                        : 'Hold this eye asset',
                                    selected: avatar.eyePose == i,
                                    onSelected: avatar.ready
                                        ? (_) => avatar.selectEye(i)
                                        : null,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'Mouth poses',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Preview each expression, or follow the lesson audio.',
                              style: TextStyle(
                                color: Colors.white54,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                ChoiceChip(
                                  label: const Text('Auto'),
                                  selected: avatar.manualMouth == null,
                                  onSelected: (_) => avatar.selectMouth(null),
                                ),
                                for (var i = 0; i < avatar.mouths.length; i++)
                                  if (!avatar.profile.disabledMouthIndices
                                      .contains(i))
                                    ChoiceChip(
                                      key: Key('mouth-$i'),
                                      label: Text(
                                        avatar.mouths[i].replaceAll('_', ' '),
                                      ),
                                      selected: avatar.manualMouth == i,
                                      onSelected: (_) => avatar.selectMouth(i),
                                    ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            AvatarBehaviorLab(avatar: avatar),
                            if (avatar.error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: SelectableText(
                                  avatar.error!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'GETTOPIK  /  Korean, one conversation at a time.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  String _clock(double value) =>
      '${value ~/ 60}:${(value.toInt() % 60).toString().padLeft(2, '0')}';
}
