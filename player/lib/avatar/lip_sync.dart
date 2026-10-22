import 'dart:math' as math;
import 'dart:typed_data';
import 'character_profile.dart';

enum LipSyncStyle { rms, lightweight }

/// Explicit phone mapping, never inferred from RMS. Compound vowels need
/// phone-level intervals from the aligner; text is not divided into fake times.
Viseme? koreanPhoneViseme(String phone) {
  final p = phone
      .toLowerCase()
      .replaceFirst(RegExp(r'_[bies]$'), '')
      .replaceAll(RegExp(r'[ːˑˈˌʰ͈̚012]'), '');
  if (['sil', 'sp', 'spn', '<eps>', ''].contains(p)) return Viseme.neutral;
  if ([
    'm',
    'b',
    'p',
    'ㅁ',
    'ㅂ',
    'ㅃ',
    'ㅍ',
    'ᄆ',
    'ᄇ',
    'ᄈ',
    'ᄑ',
    'ᆷ',
    'ᆸ',
  ].contains(p)) {
    return Viseme.mbp;
  }
  if (['a', 'ɑ', 'ɐ', 'ʌ', 'ɒ', 'ㅏ', 'ㅓ', 'ᅡ', 'ᅥ'].contains(p)) {
    return Viseme.a;
  }
  if ([
    'e',
    'ɛ',
    'i',
    'ɪ',
    'ɯ',
    'ɨ',
    'ㅐ',
    'ㅔ',
    'ㅣ',
    'ㅡ',
    'ᅢ',
    'ᅦ',
    'ᅵ',
    'ᅳ',
  ].contains(p)) {
    return Viseme.ei;
  }
  if (['o', 'ɔ', 'ø', 'ㅗ', 'ᅩ'].contains(p)) return Viseme.o;
  if (['u', 'ʊ', 'y', 'ㅜ', 'ᅮ'].contains(p)) return Viseme.u;
  return null; // Unknown consonants use the energy fallback, not a guess.
}

class VisemeEvent {
  const VisemeEvent(this.start, this.end, this.viseme, {this.confidence = 1});
  final double start, end, confidence;
  final Viseme viseme;
}

class VisemeTrack {
  VisemeTrack(Iterable<VisemeEvent> input) : events = List.unmodifiable(input) {
    double end = 0;
    for (final e in events) {
      if (!e.start.isFinite ||
          !e.end.isFinite ||
          e.start < end ||
          e.end <= e.start ||
          !e.confidence.isFinite ||
          e.confidence < 0 ||
          e.confidence > 1) {
        throw const FormatException(
          'Viseme intervals must be ordered, finite and non-overlapping',
        );
      }
      end = e.end;
    }
  }
  final List<VisemeEvent> events;

  /// Bind alignment to the exact audio. Empty/missing alignment stays RMS.
  factory VisemeTrack.fromJson(Map<String, dynamic> json, String audioHash) {
    if (json['audioSha256'] != audioHash ||
        json['alignment'] != 'phone' ||
        json['provenance'] is! String ||
        (json['provenance'] as String).isEmpty) {
      throw const FormatException(
        'Phone alignment provenance/audio hash missing or mismatched',
      );
    }
    return VisemeTrack(
      (json['events'] as List).map(
        (dynamic row) => VisemeEvent(
          (row['start'] as num).toDouble(),
          (row['end'] as num).toDouble(),
          Viseme.values.byName(row['viseme'] as String),
          confidence: (row['confidence'] as num? ?? 1).toDouble(),
        ),
      ),
    );
  }

  VisemeEvent? at(double seconds) {
    var low = 0, high = events.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (events[mid].start <= seconds) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low == 0) return null;
    final event = events[low - 1];
    return seconds < event.end && event.confidence >= .6 ? event : null;
  }
}

class EnergyFrame {
  const EnergyFrame(
    this.time,
    this.rms,
    this.energy,
    this.silence, {
    this.lowBandRatio = 0,
    this.highBandRatio = 0,
    this.zeroCrossingRate = 0,
  });
  final double time, rms, energy;
  final bool silence;
  // Coarse DSP evidence, NOT phonemes, vowels or learned viseme probabilities.
  final double lowBandRatio, highBandRatio, zeroCrossingRate;
  bool get noiseLike => highBandRatio > .40 && zeroCrossingRate > .18;
}

/// Stateful 20 ms trailing RMS / 10 ms hop. Chunk boundaries may split samples.
class PcmAnalyzer {
  PcmAnalyzer({
    this.sampleRate = 24000,
    this.referenceRms = 0,
    this.spectralFeatures = true,
  }) {
    if (sampleRate < 8000 ||
        sampleRate > 96000 ||
        !referenceRms.isFinite ||
        referenceRms < 0) {
      throw ArgumentError('Unsupported PCM sample rate');
    }
  }
  final int sampleRate;
  final double referenceRms;
  final bool spectralFeatures;
  late final double _lowGain = 1 - math.exp(-2 * math.pi * 700 / sampleRate);
  late final double _upperGain = 1 - math.exp(-2 * math.pi * 2500 / sampleRate);
  double _low = 0, _upper = 0, _last = 0;
  double _lowSum = 0, _highSum = 0, _midSum = 0;
  double _previousLow = 0, _previousHigh = 0, _previousMid = 0;
  int _crossings = 0, _previousCrossings = 0;
  int _lowByte = -1, _count = 0, _samples = 0, _quiet = 0;
  double _sum = 0, _previous = 0, _envelope = 0, _noise = .001;
  double _peak = .04;
  bool _first = true;

  List<EnergyFrame> add(Uint8List bytes) {
    final frames = <EnergyFrame>[];
    for (final byte in bytes) {
      if (_lowByte < 0) {
        _lowByte = byte;
        continue;
      }
      var value = _lowByte | (byte << 8);
      _lowByte = -1;
      if (value >= 32768) value -= 65536;
      final sample = value / 32768;
      if (spectralFeatures) {
        _low += _lowGain * (sample - _low);
        _upper += _upperGain * (sample - _upper);
        final mid = _upper - _low, high = sample - _upper;
        _lowSum += _low * _low;
        _midSum += mid * mid;
        _highSum += high * high;
        if ((_last < 0) != (sample < 0)) _crossings++;
        _last = sample;
      }
      _sum += sample * sample;
      _count++;
      _samples++;
      if (_count < sampleRate ~/ 100) continue;
      final mean = _sum / _count;
      final rms = math.sqrt(_first ? mean : (mean + _previous) / 2);
      _first = false;
      _previous = mean;
      _sum = 0;
      _count = 0;
      final tau = rms > _envelope ? .03 : .07;
      _envelope += (rms - _envelope) * (1 - math.exp(-.01 / tau));
      // Causal peak follower for unknown future streams; local recordings use
      // their measured 95th-percentile RMS instead of a different lesson's gain.
      _peak = math.max(rms, _peak * .999);
      if (rms < .008) _noise += .02 * (rms - _noise);
      final quiet = rms < math.max(.0032, _noise * 2.5);
      _quiet = quiet ? _quiet + 1 : 0;
      final bandTotal =
          _lowSum +
          _midSum +
          _highSum +
          _previousLow +
          _previousMid +
          _previousHigh;
      final lowRatio = bandTotal > 1e-12
          ? (_lowSum + _previousLow) / bandTotal
          : 0.0;
      final highRatio = bandTotal > 1e-12
          ? (_highSum + _previousHigh) / bandTotal
          : 0.0;
      final zcr = (_crossings + _previousCrossings) / (sampleRate / 50);
      _previousLow = _lowSum;
      _previousHigh = _highSum;
      _previousMid = _midSum;
      _previousCrossings = _crossings;
      _lowSum = 0;
      _midSum = 0;
      _highSum = 0;
      _crossings = 0;
      frames.add(
        EnergyFrame(
          _samples / sampleRate,
          rms,
          (_envelope / (referenceRms > 0 ? referenceRms : math.max(.02, _peak)))
              .clamp(0.0, 1.0),
          _quiet >= 2 || (quiet && _samples <= sampleRate ~/ 50),
          lowBandRatio: lowRatio,
          highBandRatio: highRatio,
          zeroCrossingRate: zcr,
        ),
      );
    }
    return frames;
  }
}

class LipSyncEngine {
  LipSyncEngine(this.profile) : _pose = profile.neutral;
  final CharacterProfile profile;
  VisemeTrack? alignment;
  LipSyncStyle style = LipSyncStyle.lightweight;
  int _pose;
  double _changed = -1, _lastTime = -1;

  int resolve(
    double time,
    EnergyFrame frame, {
    required bool playing,
    VisemeEvent? eventOverride,
    bool useAlignment = true,
  }) {
    if (time < _lastTime) reset();
    _lastTime = time;
    // Silence and stop always beat phonemes, emotions and the minimum hold.
    if (!playing || frame.silence) {
      _pose = profile.neutral;
      _changed = time;
      return _pose;
    }
    final event = eventOverride ?? (useAlignment ? alignment?.at(time) : null);
    final int desired;
    if (event != null) {
      // Trustworthy timings must not be delayed by heuristic pose dwell.
      _pose = profile.visemes[event.viseme] ?? profile.neutral;
      _changed = time;
      return _pose;
    } else {
      final improved = style == LipSyncStyle.lightweight;
      final threshold = _pose == profile.medium
          ? (improved ? .30 : .24)
          : (improved ? .43 : .34);
      desired = frame.energy < threshold || (improved && frame.noiseLike)
          ? profile.small
          : profile.medium;
      if (improved && _pose == profile.neutral) {
        // Audible onset gets a narrow opening immediately. Do not jump from
        // a closed photographic mouth straight to the largest allowed image.
        _pose = profile.small;
        _changed = time;
        return _pose;
      }
    }
    // A real aligned bilabial closure should not wait for the vowel hold.
    if (desired != _pose &&
        time - _changed >= (style == LipSyncStyle.lightweight ? .100 : .075)) {
      _pose = desired;
      _changed = time;
    }
    return _pose;
  }

  void reset() {
    _pose = profile.neutral;
    _changed = -1;
    _lastTime = -1;
  }
}
