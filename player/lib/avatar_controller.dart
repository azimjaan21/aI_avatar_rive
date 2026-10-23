import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;
import 'audio/pcm_stream_player.dart';
import 'audio/pcm_wav.dart';
import 'avatar/behavior.dart';
import 'avatar/character_profile.dart';
import 'avatar/lip_sync.dart';
export 'avatar/behavior.dart';
export 'avatar/character_profile.dart';
export 'avatar/lip_sync.dart' show VisemeEvent, LipSyncStyle;

enum AvatarAudioMode { offline, localStream, externalStream }

enum PcmEnqueueResult { accepted, backpressure, staleTurn }

/// Coordinates playback-clock lip sync, independent expressions and Rive.
/// No service connection is required. PCM turn IDs reject late interrupted data.
class AvatarController extends ChangeNotifier {
  AvatarController({
    this.profile = CharacterProfile.teacher,
    String? rivAsset,
    this.audioAsset = 'korean_demo.wav',
    this.timelineAsset = 'assets/mouth_timeline.json',
    this.visemeAsset = 'assets/korean_visemes.json',
    String? artboardName,
    String? propertyName,
  }) : rivAsset = rivAsset ?? profile.rivAsset,
       artboardName = artboardName ?? profile.artboard,
       propertyName = propertyName ?? profile.mouthProperty;
  final CharacterProfile profile;
  final String rivAsset, audioAsset, timelineAsset, artboardName, propertyName;
  final String? visemeAsset;
  final stream = PcmStreamPlayer();
  late final behavior = BehaviorController(
    emotions: EmotionController(
      tiltDegrees: profile.emotionTiltDegrees,
      nodPixels: profile.positiveNodPixels,
      laughBobPixels: profile.laughBobPixels,
    ),
  );
  late final lips = LipSyncEngine(profile);
  rive.File? file;
  rive.RiveWidgetController? riveController;
  rive.ViewModelInstance? instance;
  rive.ViewModelInstanceNumber? mouthProperty,
      eyeProperty,
      motionProperty,
      breathProperty;
  rive.ViewModelInstanceNumber? emotionTiltProperty, emotionBobProperty;
  late int eyePose = profile.autoEye;
  final _clock = Stopwatch()..start();
  final _arrivalClock = Stopwatch();
  final _playRequestClock = Stopwatch();
  double? playRequestToCursorMs;
  bool _awaitingFirstCursor = false;
  int _arrivalDueMs = 0;
  Timer? _behaviorTimer, _feedTimer;
  PcmWav? _wav;
  int _feedOffset = 0, _turn = 0, _arrivalIndex = 0;
  double _streamOffset = 0, _displayScale = .5, _breathAmplitude = .5;
  double? _lastSpeechPosition;
  double _lastUi = -1;
  int uiNotifications = 0, visualSamples = 0;
  EnergyFrame _frame = const EnergyFrame(0, 0, 0, true);
  List<dynamic> frames = [];
  List<String> mouths = [];
  String source = '',
      alignmentStatus = 'Audio-reactive fallback — no verified timings';
  double duration = 0, position = 0, energy = 0;
  double _lessonDuration = 0;
  late int mouth = profile.neutral;
  bool playing = false, ready = false, seeking = false, silence = true;
  bool _disposed = false, _forceNeutral = true;
  bool _presentationSuspended = false;
  int presentationSuspensions = 0;
  double? riveLoadMs, readyLoadMs;
  int? manualMouth;
  String? error;
  AvatarAudioMode mode = AvatarAudioMode.offline;
  ConversationState conversation = ConversationState.idle;
  AvatarEmotion get emotion => behavior.emotions.emotion;
  double get _now => _clock.elapsedMicroseconds / 1e6;
  bool get isStreaming => mode != AvatarAudioMode.offline;
  bool get buffering => stream.active && stream.buffering;
  bool get transportActive => stream.active && !stream.paused;

  Future<void> load() async {
    final loadClock = Stopwatch()..start();
    try {
      final data = jsonDecode(await rootBundle.loadString(timelineAsset));
      frames = data['frames'];
      mouths = List<String>.from(data['mouths']);
      duration = (data['duration'] as num).toDouble();
      _lessonDuration = duration;
      source = data['source'];
      final riveClock = Stopwatch()..start();
      file = await rive.File.asset(rivAsset, riveFactory: rive.Factory.rive);
      riveLoadMs = riveClock.elapsedMicroseconds / 1000;
      if (_disposed) {
        file?.dispose();
        return;
      }
      if (file == null) throw StateError('Rive asset could not be decoded');
      riveController = rive.RiveWidgetController(
        file!,
        artboardSelector: rive.ArtboardSelector.byName(artboardName),
      );
      instance = riveController!.dataBind(rive.DataBind.auto());
      mouthProperty = instance!.number(propertyName);
      eyeProperty = instance!.number(profile.eyeProperty);
      motionProperty = instance!.number(profile.motionProperty);
      breathProperty = instance!.number(profile.breathProperty);
      emotionTiltProperty = instance!.number(profile.emotionTiltProperty);
      emotionBobProperty = instance!.number(profile.emotionBobProperty);
      if ([
        mouthProperty,
        eyeProperty,
        motionProperty,
        breathProperty,
      ].any((p) => p == null)) {
        throw StateError('Missing required avatar view model properties');
      }
      breathProperty!.value = _breathAmplitude;
      stream.onTick = _streamTick;
      stream.onComplete = () {
        if (!_disposed) {
          playing = false;
          position = duration;
          _completed();
        }
      };
      stream.onError = _failure;
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (visemeAsset != null && manifest.listAssets().contains(visemeAsset)) {
        try {
          final json =
              jsonDecode(await rootBundle.loadString(visemeAsset!))
                  as Map<String, dynamic>;
          final wav = await rootBundle.load('assets/$audioAsset');
          final hash = sha256
              .convert(
                wav.buffer.asUint8List(wav.offsetInBytes, wav.lengthInBytes),
              )
              .toString();
          lips.alignment = VisemeTrack.fromJson(json, hash);
          if (lips.alignment!.events.isNotEmpty &&
              lips.alignment!.events.last.end > duration + .001) {
            lips.alignment = null;
            throw const FormatException(
              'Alignment extends beyond the recording',
            );
          }
          alignmentStatus = 'Aligned Korean visemes';
        } on FlutterError {
          alignmentStatus = 'Audio-reactive fallback — no verified timings';
        } catch (e) {
          alignmentStatus = 'Audio-reactive fallback — alignment rejected: $e';
        }
      }
      if (_disposed) return;
      ready = true;
      readyLoadMs = loadClock.elapsedMicroseconds / 1000;
      if (!_presentationSuspended) resumePresentation();
      _applyVisuals();
      _publish(force: true);
    } catch (e) {
      if (!_disposed) _failure(e);
    }
  }

  void _streamTick() {
    if (_disposed || _presentationSuspended) return;
    position = _streamOffset + stream.consumed;
    playing = stream.audible;
    if (_awaitingFirstCursor && playing && stream.consumed > 0) {
      playRequestToCursorMs = _playRequestClock.elapsedMicroseconds / 1000;
      _awaitingFirstCursor = false;
      _playRequestClock.stop();
    }
    _frame = stream.frameAt(stream.consumed);
    if (mode == AvatarAudioMode.externalStream) duration = stream.received;
    _applyVisuals();
  }

  void _applyVisuals() {
    if (_disposed || !ready) return;
    visualSamples++;
    energy = playing ? _frame.energy : 0;
    silence = !playing || _frame.silence;
    if (!playing || manualMouth != null) {
      _lastSpeechPosition = null;
    } else if (!silence) {
      _lastSpeechPosition = position;
    }
    final lastSpeech = _lastSpeechPosition;
    final talking =
        playing &&
        manualMouth == null &&
        lastSpeech != null &&
        position >= lastSpeech &&
        position - lastSpeech < .7;
    _setNumber(motionProperty, talking ? 1 : 0);
    final expression = behavior.emotions.sample(_now);
    conversation = behavior.effective(transportActive, expression);
    final external = mode == AvatarAudioMode.externalStream;
    final event = external
        ? stream.visemeAt(stream.consumed)
        : lips.alignment?.at(position);
    var next =
        manualMouth ??
        lips.resolve(
          position,
          _frame,
          playing: playing,
          eventOverride: event,
          useAlignment: !external,
        );
    if (manualMouth == null &&
        !_forceNeutral &&
        profile.supportsSmile &&
        expression.weight > .45) {
      if (!transportActive) {
        next =
            expression.emotion == AvatarEmotion.softLaugh &&
                expression.laughOpen
            ? profile.small
            : profile.smile;
      } else if (!silence && event == null && energy < .16) {
        // Reuse the actual Smile image at weak openings, never deform vowels.
        next = profile.smile;
      }
    }
    if (_forceNeutral && manualMouth == null && !playing) {
      next = profile.neutral;
    }
    if (next != mouth || mouthProperty?.value != next.toDouble()) {
      mouth = next;
      _setNumber(mouthProperty, next.toDouble());
    }
    _setNumber(emotionTiltProperty, expression.tiltRadians);
    _setNumber(emotionBobProperty, expression.bobPixels / _displayScale);
    _publish();
  }

  void _setNumber(rive.ViewModelInstanceNumber? property, double value) {
    if (property != null && (property.value - value).abs() > .000001) {
      property.value = value;
      riveController?.scheduleRepaint();
    }
  }

  void _publish({bool force = false}) {
    if (_disposed) return;
    if (!force && _now - _lastUi < .1) return;
    _lastUi = _now;
    uiNotifications++;
    notifyListeners();
  }

  void _failure(Object e) {
    error = '$e';
    playing = false;
    _forceNeutral = true;
    _applyVisuals();
    _publish(force: true);
  }

  void _completed() {
    _forceNeutral = true;
    manualMouth = null;
    _lastSpeechPosition = null;
    behavior.onIdle();
    behavior.emotions.reset(_now);
    lips.reset();
    _frame = EnergyFrame(position, 0, 0, true);
    _applyVisuals();
    _publish(force: true);
  }

  Future<void> toggle() async {
    if (!ready || _presentationSuspended) return;
    try {
      manualMouth = null;
      if (!stream.active) {
        if (mode != AvatarAudioMode.externalStream) {
          await _startLocal(position >= duration - .05 ? 0 : position);
        }
      } else if (stream.paused) {
        resume();
      } else {
        await pause();
      }
      _publish(force: true);
    } catch (e) {
      _failure(e);
    }
  }

  Future<void> pause() async {
    _arrivalClock.stop();
    stream.pause();
    playing = false;
    _forceNeutral = true;
    behavior.onIdle();
    _applyVisuals();
    _publish(force: true);
  }

  /// Mobile hosts suspend idle work as well as playback when backgrounded.
  void suspendPresentation() {
    if (_disposed) return;
    if (!_presentationSuspended) presentationSuspensions++;
    _presentationSuspended = true;
    _behaviorTimer?.cancel();
    _feedTimer?.cancel();
    unawaited(pause());
  }

  /// Resume visuals only. Audio requires an explicit Play gesture.
  void resumePresentation() {
    if (_disposed) return;
    _presentationSuspended = false;
    _behaviorTimer?.cancel();
    if (ready) {
      _behaviorTimer = Timer.periodic(
        const Duration(milliseconds: 33),
        (_) => _applyVisuals(),
      );
    }
  }

  void resume() {
    if (_disposed || _presentationSuspended) return;
    if (!stream.active) {
      unawaited(toggle());
      return;
    }
    _forceNeutral = false;
    behavior.onSpeaking();
    _arrivalClock.start();
    stream.resume();
    if (mode != AvatarAudioMode.externalStream && !stream.inputEnded) {
      _feedTimer?.cancel();
      _feedLocal(_turn);
    }
    _streamTick();
    _publish(force: true);
  }

  Future<void> seek(double seconds) async {
    if (mode == AvatarAudioMode.externalStream) return;
    seconds = seconds.clamp(0, duration);
    seeking = true;
    _lastSpeechPosition = null;
    lips.reset();
    try {
      final resumeAfterSeek = transportActive;
      if (resumeAfterSeek) {
        await _startLocal(seconds);
      } else {
        ++_turn;
        _feedTimer?.cancel();
        _arrivalClock.stop();
        await stream.stop();
        _streamOffset = seconds;
        position = seconds;
        playing = false;
        _frame = EnergyFrame(seconds, 0, 0, true);
        _forceNeutral = true;
        _applyVisuals();
      }
    } catch (e) {
      _failure(e);
    } finally {
      seeking = false;
      _publish(force: true);
    }
  }

  LipSyncStyle get lipSyncStyle => lips.style;
  void setLipSyncStyle(LipSyncStyle value) {
    lips.style = value;
    lips.reset();
    // A/B share PCM analysis and transport. Changing the decision policy never
    // interrupts audio or changes the consumed sample clock.
    _publish(force: true);
  }

  Future<void> setAudioMode(AvatarAudioMode next) async {
    if (next == mode) return;
    await stop();
    mode = next;
    duration = _lessonDuration;
    position = 0;
    _streamOffset = 0;
    _publish(force: true);
  }

  Future<void> _startLocal(double from) async {
    _playRequestClock
      ..reset()
      ..start();
    _awaitingFirstCursor = true;
    playRequestToCursorMs = null;
    final turn = ++_turn;
    _feedTimer?.cancel();
    if (_wav == null) {
      final wavData = await rootBundle.load('assets/$audioAsset');
      _wav = PcmWav.parse(
        wavData.buffer.asUint8List(
          wavData.offsetInBytes,
          wavData.lengthInBytes,
        ),
      );
    }
    if (turn != _turn || _disposed) return;
    playing = false;
    _frame = EnergyFrame(from, 0, 0, true);
    await stream.start(rate: _wav!.sampleRate);
    if (turn != _turn || _disposed) return;
    _streamOffset = from;
    position = from;
    _feedOffset = ((from * _wav!.sampleRate).floor() * 2).clamp(
      0,
      _wav!.pcm.length,
    );
    _arrivalIndex = 0;
    _arrivalDueMs = 0;
    _arrivalClock
      ..reset()
      ..start();
    _forceNeutral = false;
    manualMouth = null;
    lips.reset();
    behavior.onSpeaking();
    // A native backend may finish initialization after Android backgrounds us.
    if (_presentationSuspended) {
      await pause();
      return;
    }
    _feedLocal(turn);
  }

  void _feedLocal(int turn) {
    if (_disposed ||
        _presentationSuspended ||
        turn != _turn ||
        mode == AvatarAudioMode.externalStream ||
        !stream.active) {
      return;
    }
    const delays = [34, 42, 37, 46, 39, 41];
    try {
      var backpressure = false;
      // Schedule against absolute arrival deadlines: UI/capture delays must not
      // accumulate into a producer rate slower than the audio sample clock.
      if (!stream.paused) {
        for (
          var count = 0;
          count < 12 &&
              (mode == AvatarAudioMode.offline ||
                  _arrivalDueMs <= _arrivalClock.elapsedMilliseconds);
          count++
        ) {
          final wav = _wav!;
          if (_feedOffset >= wav.pcm.length) {
            stream.finish();
            return;
          }
          final end = math.min(
            wav.pcm.length,
            _feedOffset + (wav.sampleRate * .04).round() * 2,
          );
          if (!stream.add(Uint8List.sublistView(wav.pcm, _feedOffset, end))) {
            backpressure = true;
            break;
          }
          _feedOffset = end;
          _arrivalDueMs += delays[_arrivalIndex++ % delays.length];
        }
      }
      final delay = mode == AvatarAudioMode.offline
          ? 20
          : stream.paused
          ? 40
          : backpressure
          ? 20
          : math.max(1, _arrivalDueMs - _arrivalClock.elapsedMilliseconds);
      _feedTimer = Timer(Duration(milliseconds: delay), () => _feedLocal(turn));
    } catch (e) {
      _failure(e);
      unawaited(stream.stop());
    }
  }

  Future<int> startPcmStream({int sampleRate = 24000}) async {
    _awaitingFirstCursor = false;
    await stop();
    final turn = ++_turn;
    mode = AvatarAudioMode.externalStream;
    position = 0;
    duration = 0;
    _streamOffset = 0;
    await stream.start(rate: sampleRate);
    if (turn != _turn) return turn;
    _forceNeutral = false;
    behavior.onSpeaking();
    _publish(force: true);
    return turn;
  }

  PcmEnqueueResult addPcmChunk(int turn, Uint8List bytes) {
    if (_disposed ||
        turn != _turn ||
        mode != AvatarAudioMode.externalStream ||
        !stream.active) {
      return PcmEnqueueResult.staleTurn;
    }
    return stream.add(bytes)
        ? PcmEnqueueResult.accepted
        : PcmEnqueueResult.backpressure;
  }

  bool addStreamingVisemes(int turn, Iterable<VisemeEvent> events) {
    if (turn != _turn || !stream.active) return false;
    stream.addVisemes(events);
    return true;
  }

  void finishPcmStream(int turn) {
    if (turn == _turn && stream.active) stream.finish();
  }

  Future<void> stop() async {
    _awaitingFirstCursor = false;
    ++_turn;
    _arrivalClock.stop();
    _feedTimer?.cancel();
    _feedTimer = null;
    await stream.stop();
    playing = false;
    position = 0;
    _completed();
  }

  Future<void> onSpeechInterrupted() async {
    await stop();
    resetEmotion();
  }

  void onListening() {
    behavior.onListening();
    _publish(force: true);
  }

  void onThinking() {
    behavior.onThinking();
    _publish(force: true);
  }

  void onSpeaking() {
    behavior.onSpeaking();
    _publish(force: true);
  }

  void onIdle() {
    behavior.onIdle();
    _publish(force: true);
  }

  void setEmotion(
    AvatarEmotion emotion, {
    double intensity = 1,
    Duration? duration,
  }) {
    _forceNeutral = false;
    behavior.emotions.set(
      emotion,
      _now,
      intensity: intensity,
      duration: duration == null ? null : duration.inMicroseconds / 1e6,
    );
    _applyVisuals();
    _publish(force: true);
  }

  void resetEmotion() {
    behavior.emotions.reset(_now);
    _applyVisuals();
    _publish(force: true);
  }

  void configureViewport(double width, double height, {bool cover = false}) {
    final scale = (cover ? math.max : math.min)(
      width / profile.canvasWidth,
      height / profile.canvasHeight,
    );
    if (!scale.isFinite || scale <= 0) return;
    _displayScale = scale;
    _breathAmplitude =
        (profile.breathingPixels / (profile.authoredBreathUnits * scale)).clamp(
          .001,
          1.0,
        );
    _setNumber(breathProperty, _breathAmplitude);
  }

  Future<void> selectMouth(int? index) async {
    if (profile.id == 'teacher') {
      if (index == 0) index = profile.neutral;
      if (index == 3) index = profile.medium;
    }
    if (index != null && transportActive) await pause();
    manualMouth = index;
    _applyVisuals();
    _publish(force: true);
  }

  void selectEye(int pose) {
    if (pose == 2 && profile.id == 'teacher') pose = profile.halfEye;
    if (![profile.autoEye, profile.openEye, profile.halfEye].contains(pose)) {
      throw RangeError('Unsupported eye pose');
    }
    eyePose = pose;
    _setNumber(eyeProperty, pose.toDouble());
    _publish(force: true);
  }

  Map<String, dynamic> get diagnostics => {
    'riveLoadMs': riveLoadMs,
    'readyLoadMs': readyLoadMs,
    'presentationSuspensions': presentationSuspensions,
    'localPlayRequestToCursorMs': playRequestToCursorMs,
    'mode': mode.name,
    'playbackEngine': 'SoLoud PCM16 consumed sample cursor for all sources',
    'lipSyncStyle': lips.style.name,
    'alignment': alignmentStatus,
    'conversation': conversation.name,
    'emotion': emotion.name,
    'uiNotifications': uiNotifications,
    'visualSamples': visualSamples,
    'stream': stream.metrics,
  };
  @override
  void dispose() {
    _disposed = true;
    ++_turn;
    _feedTimer?.cancel();
    _behaviorTimer?.cancel();
    stream.onTick = null;
    stream.onComplete = null;
    stream.onError = null;
    unawaited(stream.stop());
    mouthProperty?.dispose();
    eyeProperty?.dispose();
    motionProperty?.dispose();
    breathProperty?.dispose();
    emotionTiltProperty?.dispose();
    emotionBobProperty?.dispose();
    riveController?.dispose();
    instance?.dispose();
    file?.dispose();
    super.dispose();
  }
}
