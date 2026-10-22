import 'dart:math' as math;

enum AvatarEmotion { neutral, smile, happy, encouraging, softLaugh }

enum ConversationState {
  idle,
  listening,
  thinking,
  speaking,
  smiling,
  laughing,
}

class ExpressionFrame {
  const ExpressionFrame(
    this.emotion,
    this.weight,
    this.tiltRadians,
    this.bobPixels,
    this.laughOpen,
  );
  final AvatarEmotion emotion;
  final double weight, tiltRadians, bobPixels;
  final bool laughOpen;
}

/// No image deformation and no audio ownership. Events may come from UI or
/// a future external conversation service. All timing is monotonic.
class EmotionController {
  EmotionController({
    this.tiltDegrees = .12,
    this.nodPixels = .55,
    this.laughBobPixels = .25,
  });
  final double tiltDegrees, nodPixels, laughBobPixels;
  AvatarEmotion emotion = AvatarEmotion.neutral;
  double _started = 0, _release = -1, _releaseWeight = 0, _intensity = 1;
  double? _duration;
  void set(
    AvatarEmotion next,
    double now, {
    double intensity = 1,
    double? duration,
  }) {
    if (next == AvatarEmotion.neutral) {
      reset(now);
      return;
    }
    emotion = next;
    _started = now;
    _release = -1;
    _intensity = intensity.clamp(0.0, 1.0);
    _duration = duration ?? (next == AvatarEmotion.softLaugh ? 2.4 : null);
  }

  void reset(double now) {
    if (emotion == AvatarEmotion.neutral || _release >= 0) return;
    _releaseWeight = sample(now).weight;
    _release = now;
  }

  static double _ease(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  ExpressionFrame sample(double now) {
    final elapsed = math.max(0.0, now - _started);
    if (_duration != null && elapsed >= _duration! && _release < 0) {
      _releaseWeight = _intensity;
      _release = _started + _duration!;
    }
    var weight = _intensity * _ease(elapsed / .35);
    if (_release >= 0) {
      weight = _releaseWeight * (1 - _ease((now - _release) / .45));
      if (weight <= .0001) {
        emotion = AvatarEmotion.neutral;
        weight = 0;
      }
    }
    if (emotion == AvatarEmotion.neutral) {
      return const ExpressionFrame(AvatarEmotion.neutral, 0, 0, 0, false);
    }
    final laughing = emotion == AvatarEmotion.softLaugh;
    final positive =
        emotion == AvatarEmotion.happy || emotion == AvatarEmotion.encouraging;
    final nod = positive && elapsed < 1.5
        ? math.pow(math.sin(math.pi * elapsed / 1.5), 2).toDouble()
        : 0.0;
    final bob = laughing
        ? math.sin(elapsed * math.pi * 3.6) * laughBobPixels
        : nod * nodPixels;
    return ExpressionFrame(
      emotion,
      weight,
      weight * tiltDegrees * math.pi / 180,
      bob * weight,
      laughing && math.sin(elapsed * math.pi * 3.6) > .15,
    );
  }
}

class BehaviorController {
  BehaviorController({EmotionController? emotions})
    : emotions = emotions ?? EmotionController();
  ConversationState requested = ConversationState.idle;
  final EmotionController emotions;
  void onListening() => requested = ConversationState.listening;
  void onThinking() => requested = ConversationState.thinking;
  void onSpeaking() => requested = ConversationState.speaking;
  void onIdle() => requested = ConversationState.idle;
  ConversationState effective(bool audioActive, ExpressionFrame expression) {
    if (audioActive) return ConversationState.speaking;
    if (expression.weight > .1) {
      return expression.emotion == AvatarEmotion.softLaugh
          ? ConversationState.laughing
          : ConversationState.smiling;
    }
    return requested;
  }
}
