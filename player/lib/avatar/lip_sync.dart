import 'dart:math' as math;
import 'dart:typed_data';
import 'character_profile.dart';

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
  const EnergyFrame(this.time, this.rms, this.energy, this.silence);
  final double time, rms, energy;
  final bool silence;
}

/// Stateful 20 ms trailing RMS / 10 ms hop. Chunk boundaries may split samples.
class PcmAnalyzer {
  PcmAnalyzer({this.sampleRate = 24000, this.referenceRms = 0}) {
    if (sampleRate < 8000 ||
        sampleRate > 96000 ||
        !referenceRms.isFinite ||
        referenceRms < 0) {
      throw ArgumentError('Unsupported PCM sample rate');
    }
  }
  final int sampleRate;
  final double referenceRms;
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
      frames.add(
        EnergyFrame(
          _samples / sampleRate,
          rms,
          (_envelope / (referenceRms > 0 ? referenceRms : math.max(.02, _peak)))
              .clamp(0.0, 1.0),
          _quiet >= 2 || (quiet && _samples <= sampleRate ~/ 50),
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
      desired = profile.visemes[event.viseme] ?? profile.neutral;
    } else {
      final threshold = _pose == profile.medium ? .24 : .34;
      desired = frame.energy < threshold ? profile.small : profile.medium;
    }
    // A real aligned bilabial closure should not wait for the vowel hold.
    if (desired != _pose &&
        (event?.viseme == Viseme.mbp || time - _changed >= .075)) {
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
