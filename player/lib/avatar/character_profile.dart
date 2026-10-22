enum Viseme { neutral, a, ei, o, u, mbp }

/// Artwork descriptions are deliberately independent of phoneme labels.
enum MouthShape { neutral, closed, transitional, open, rounded, spread, smile }

/// Only capabilities backed by the supplied artwork belong in a profile.
class CharacterProfile {
  const CharacterProfile({
    required this.id,
    required this.rivAsset,
    required this.backgroundAsset,
    required this.visemes,
    this.artboard = 'Teacher',
    this.mouthProperty = 'mouthIndex',
    this.eyeProperty = 'eyePose',
    this.neutral = 6,
    this.small = 1,
    this.medium = 2,
    this.smile = 7,
    this.openEye = 0,
    this.halfEye = 1,
    this.autoEye = -1,
    this.canvasWidth = 1086,
    this.canvasHeight = 1448,
    this.mouthX = 546,
    this.mouthY = 675,
    this.neckX = 544,
    this.neckY = 870,
    this.breathingPixels = 2,
    this.authoredBreathUnits = 8,
    this.supportsSmile = true,
    this.supportsEyeExpressions = false,
    this.disabledMouthIndices = const {0, 3},
    this.motionProperty = 'motionTalking',
    this.breathProperty = 'breathAmplitude',
    this.emotionTiltProperty = 'emotionTilt',
    this.emotionBobProperty = 'emotionBob',
    this.emotionTiltDegrees = .12,
    this.positiveNodPixels = .55,
    this.laughBobPixels = .25,
    this.shapes = const {
      MouthShape.neutral: 6,
      MouthShape.closed: 6,
      MouthShape.transitional: 1,
      MouthShape.open: 2,
      MouthShape.rounded: 4,
      MouthShape.spread: 5,
      MouthShape.smile: 7,
    },
  });
  final String id,
      rivAsset,
      backgroundAsset,
      artboard,
      mouthProperty,
      eyeProperty;
  final Map<Viseme, int> visemes;
  final int neutral, small, medium, smile, openEye, halfEye, autoEye;
  final double canvasWidth, canvasHeight, mouthX, mouthY, neckX, neckY;
  final double breathingPixels, authoredBreathUnits;
  final bool supportsSmile, supportsEyeExpressions;
  final Set<int> disabledMouthIndices;
  final String motionProperty,
      breathProperty,
      emotionTiltProperty,
      emotionBobProperty;
  final double emotionTiltDegrees, positiveNodPixels, laughBobPixels;
  final Map<MouthShape, int> shapes;

  static const teacher = CharacterProfile(
    id: 'teacher',
    rivAsset: 'assets/teacher.riv',
    backgroundAsset: 'assets/classroom_bg.png',
    // Teeth is a broad toothy smile, not a neutral E/I vowel. Small is the
    // closest restrained substitute. O/U still share one rounded image.
    visemes: {
      Viseme.neutral: 6,
      Viseme.a: 2,
      Viseme.ei: 1,
      Viseme.o: 4,
      Viseme.u: 4,
      Viseme.mbp: 6,
    },
  );
}
