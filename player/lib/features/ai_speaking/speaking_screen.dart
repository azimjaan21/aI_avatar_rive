import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../avatar_controller.dart';
import 'teacher_avatar_view.dart';

/// Embeddable screen. The host supplies navigation and Material theme.
/// Audio never resumes automatically after a system interruption.
class AiSpeakingScreen extends StatefulWidget {
  const AiSpeakingScreen({super.key, required this.onClose, this.onController});
  final VoidCallback onClose;
  final ValueChanged<AvatarController>? onController;
  @override
  State<AiSpeakingScreen> createState() => _AiSpeakingScreenState();
}

class _AiSpeakingScreenState extends State<AiSpeakingScreen>
    with WidgetsBindingObserver {
  final avatar = AvatarController();
  final _loadClock = Stopwatch()..start();
  final _frameBuild = <int>[];
  final _frameRaster = <int>[];
  Timer? _probe;
  double? _seekPreview;
  bool _foreground = true;
  bool _fullscreen = false;
  final _avatarSurfaceKey = GlobalKey(debugLabel: 'teacher-surface');
  static const _probing = bool.fromEnvironment('AVATAR_PROBE');
  int _frames = 0, _overBudget = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_probing) {
      SchedulerBinding.instance.addTimingsCallback(_timings);
      _probe = Timer.periodic(const Duration(seconds: 5), (_) => _report());
    }
    widget.onController?.call(avatar);
    unawaited(
      avatar.load().then((_) {
        _loadClock.stop();
        if (!mounted) return;
        if (!_foreground) avatar.suspendPresentation();
        if (_probing) _report(event: 'ready');
      }),
    );
  }

  void _timings(List<FrameTiming> frames) {
    for (final f in frames) {
      _frames++;
      if (f.buildDuration.inMicroseconds > 16667 ||
          f.rasterDuration.inMicroseconds > 16667) {
        _overBudget++;
      }
      _frameBuild.add(f.buildDuration.inMicroseconds);
      _frameRaster.add(f.rasterDuration.inMicroseconds);
    }
    // Bounded instrumentation; samples describe the most recent 600 frames.
    if (_frameBuild.length > 600) {
      _frameBuild.removeRange(0, _frameBuild.length - 600);
      _frameRaster.removeRange(0, _frameRaster.length - 600);
    }
  }

  double? _percentile(List<int> values, double p) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    return sorted[((sorted.length - 1) * p).round()] / 1000;
  }

  void _report({String event = 'sample'}) {
    debugPrint(
      'GETTOPIK_METRIC ${jsonEncode({'event': event, 'utc': DateTime.now().toUtc().toIso8601String(), 'buildMode': kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug', 'readyMs': _loadClock.elapsedMilliseconds, 'foreground': _foreground, 'position': avatar.position, 'mouth': avatar.mouth, 'playing': avatar.playing, 'ready': avatar.ready, 'error': avatar.error, 'frames': _frames, 'over16_67ms': _overBudget, 'buildP50ms': _percentile(_frameBuild, .5), 'buildP95ms': _percentile(_frameBuild, .95), 'rasterP50ms': _percentile(_frameRaster, .5), 'rasterP95ms': _percentile(_frameRaster, .95), ...avatar.diagnostics})}',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      avatar.resumePresentation();
    } else {
      avatar.suspendPresentation();
    }
    if (_probing) _report(event: 'lifecycle-${state.name}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _probe?.cancel();
    if (_probing) {
      _report(event: 'dispose');
      SchedulerBinding.instance.removeTimingsCallback(_timings);
    }
    avatar.dispose();
    super.dispose();
  }

  String _time(double value) =>
      '${value ~/ 60}:${(value.toInt() % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: avatar,
    builder: (context, _) => _fullscreen
        ? _callView(context)
        : Scaffold(
            appBar: AppBar(
              leading: IconButton(
                key: const Key('close-speaking'),
                tooltip: 'Back to characters',
                onPressed: widget.onClose,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Korean Teacher',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'AI Speaking · Offline demo',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  key: const Key('enter-fullscreen'),
                  tooltip: 'Full-screen teacher',
                  onPressed: () => setState(() => _fullscreen = true),
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final wide = bounds.maxWidth >= 700;
                  final stage = ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        TeacherAvatarView(
                          key: _avatarSurfaceKey,
                          controller: avatar,
                        ),
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Chip(
                            avatar: Icon(
                              avatar.playing
                                  ? Icons.graphic_eq
                                  : Icons.school_outlined,
                              size: 16,
                            ),
                            label: Text(
                              avatar.playing
                                  ? 'Speaking Korean'
                                  : 'Ready when you are',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  final controls = _controls(context);
                  if (wide) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(child: stage),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: 340,
                            child: SingleChildScrollView(child: controls),
                          ),
                        ],
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                      children: [
                        SizedBox(
                          height: (bounds.maxHeight * .55).clamp(270.0, 470.0),
                          child: stage,
                        ),
                        const SizedBox(height: 20),
                        controls,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
  );

  Widget _callView(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) setState(() => _fullscreen = false);
    },
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            TeacherAvatarView(
              key: _avatarSurfaceKey,
              controller: avatar,
              cover: true,
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xDD000000),
                    ],
                    stops: [0, .25, .6, 1],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          key: const Key('exit-fullscreen'),
                          tooltip: 'Return to controls',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: .18,
                            ),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => setState(() => _fullscreen = false),
                          icon: const Icon(Icons.fullscreen_exit_rounded),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Korean Teacher',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                'AI Speaking · Offline demo',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.school_outlined,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (MediaQuery.sizeOf(context).height >= 500) ...[
                      Text(
                        avatar.error ??
                            (avatar.playing
                                ? 'Listen and follow along'
                                : 'Your teacher is ready'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_time(avatar.position)} / ${_time(avatar.duration)} · Local Korean audio',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final entry in const {
                              AvatarEmotion.neutral: 'Neutral',
                              AvatarEmotion.smile: 'Smile',
                              AvatarEmotion.happy: 'Happy',
                              AvatarEmotion.encouraging: 'Encourage',
                              AvatarEmotion.softLaugh: 'Soft laugh',
                            }.entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: ActionChip(
                                  key: Key('call-emotion-${entry.key.name}'),
                                  backgroundColor: avatar.emotion == entry.key
                                      ? const Color(0xFFD8EDDB)
                                      : Colors.white.withValues(alpha: .9),
                                  label: Text(
                                    entry.value,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF182D2A),
                                    ),
                                  ),
                                  onPressed: avatar.ready
                                      ? () => avatar.setEmotion(entry.key)
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _callButton(
                          key: const Key('call-controls'),
                          icon: Icons.tune_rounded,
                          label: 'Controls',
                          onPressed: () => setState(() => _fullscreen = false),
                        ),
                        _callButton(
                          key: const Key('call-end'),
                          icon: Icons.call_end_rounded,
                          label: 'End',
                          large: true,
                          color: const Color(0xFFE53964),
                          onPressed: () async {
                            await avatar.stop();
                            if (mounted) widget.onClose();
                          },
                        ),
                        _callButton(
                          key: const Key('call-play-pause'),
                          icon: avatar.transportActive
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          label: avatar.transportActive ? 'Pause' : 'Play',
                          color: const Color(0xFF24745F),
                          onPressed: avatar.ready ? avatar.toggle : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _callButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
    bool large = false,
  }) => Column(
    children: [
      IconButton.filled(
        key: key,
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: color ?? Colors.white.withValues(alpha: .18),
          foregroundColor: Colors.white,
          minimumSize: Size.square(large ? 76 : 56),
        ),
        icon: Icon(icon, size: large ? 34 : 25),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );

  Widget _controls(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A little Korean, every day.',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Listen to your teacher and follow along.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        if (avatar.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              avatar.error!,
              key: const Key('avatar-error'),
              style: TextStyle(color: colors.error),
            ),
          ),
        Slider(
          key: const Key('audio-seek'),
          value: (_seekPreview ?? avatar.position).clamp(0, avatar.duration),
          max: avatar.duration > 0 ? avatar.duration : 1,
          onChanged: avatar.ready && !avatar.seeking
              ? (v) => setState(() => _seekPreview = v)
              : null,
          onChangeEnd: (v) {
            setState(() => _seekPreview = null);
            unawaited(avatar.seek(v));
          },
        ),
        Row(
          children: [
            Text(_time(avatar.position)),
            const Spacer(),
            Text(_time(avatar.duration)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton.outlined(
              key: const Key('restart-audio'),
              tooltip: 'Restart recording',
              onPressed: avatar.ready ? () => avatar.seek(0) : null,
              icon: const Icon(Icons.replay_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const Key('play-pause'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
                onPressed: avatar.ready ? avatar.toggle : null,
                icon: Icon(
                  avatar.transportActive
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(
                  avatar.transportActive ? 'Pause' : 'Play Korean audio',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'EXPRESSION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final entry in const {
              AvatarEmotion.neutral: 'Neutral',
              AvatarEmotion.smile: 'Smile',
              AvatarEmotion.happy: 'Happy',
              AvatarEmotion.encouraging: 'Encourage',
              AvatarEmotion.softLaugh: 'Soft laugh',
            }.entries)
              ChoiceChip(
                key: Key('emotion-${entry.key.name}'),
                label: Text(entry.value),
                selected: avatar.emotion == entry.key,
                onSelected: avatar.ready
                    ? (_) => avatar.setEmotion(entry.key)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          key: const Key('test-controls'),
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'Avatar test controls',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Lightweight DSP · Playback-clock sync',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final entry in const <int?, String>{
                  null: 'Auto',
                  6: 'Closed press',
                  1: 'Small',
                  2: 'Medium',
                  4: 'Round',
                  5: 'Teeth',
                  7: 'Smile',
                }.entries)
                  ChoiceChip(
                    key: Key('mouth-${entry.key ?? 'auto'}'),
                    label: Text(entry.value),
                    selected: avatar.manualMouth == entry.key,
                    onSelected: avatar.ready
                        ? (_) => avatar.selectMouth(entry.key)
                        : null,
                  ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 6,
              children: [
                for (final entry in const {
                  -1: 'Auto blink',
                  0: 'Eyes open',
                  1: 'Eyes half',
                }.entries)
                  ChoiceChip(
                    key: Key('eye-${entry.key}'),
                    label: Text(entry.value),
                    selected: avatar.eyePose == entry.key,
                    onSelected: avatar.ready
                        ? (_) => avatar.selectEye(entry.key)
                        : null,
                  ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 6,
              children: [
                for (final mode in [
                  AvatarAudioMode.offline,
                  AvatarAudioMode.localStream,
                ])
                  ChoiceChip(
                    key: Key('mode-${mode.name}'),
                    label: Text(
                      mode == AvatarAudioMode.offline
                          ? 'Local WAV'
                          : 'PCM stream test',
                    ),
                    selected: avatar.mode == mode,
                    onSelected: avatar.ready
                        ? (_) => avatar.setAudioMode(mode)
                        : null,
                  ),
                TextButton(
                  key: const Key('speech-interrupt'),
                  onPressed: avatar.ready ? avatar.onSpeechInterrupted : null,
                  child: const Text('Interrupt / reset'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
