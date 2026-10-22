import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../avatar/lip_sync.dart';

/// One turn of PCM16 mono audio. The native queue releases played samples.
/// Producers must retry a false add(): backpressure never silently drops audio.
class PcmStreamPlayer {
  PcmStreamPlayer({this.maxAheadSeconds = .48, this.prebufferSeconds = .16});
  final double maxAheadSeconds, prebufferSeconds;
  final _engine = SoLoud.instance;
  AudioSource? _source;
  SoundHandle? _handle;
  Timer? _timer;
  PcmAnalyzer? _analyzer;
  final _frames = ListQueue<EnergyFrame>();
  final _visemes = ListQueue<VisemeEvent>();
  final _clock = Stopwatch();
  int _generation = 0, _samples = 0, _lowByte = -1;
  int sampleRate = 24000, underruns = 0, ticks = 0;
  double consumed = 0, maxQueuedSeconds = 0, maxFrameLagMs = 0;
  double? firstPlaybackMs;
  bool active = false, paused = false, buffering = false, inputEnded = false;
  void Function()? onTick, onComplete;
  void Function(Object)? onError;
  double get received => _samples / sampleRate;
  double get queuedSeconds => math.max(0, received - consumed);
  bool get hasVoice => _handle != null;
  bool get audible => active && !paused && !buffering && hasVoice;

  Future<void> start({
    int rate = 24000,
    double referenceRms = 0,
    bool spectralFeatures = true,
  }) async {
    await stop();
    final generation = ++_generation;
    if (!_engine.isInitialized) {
      await _engine
          .init(sampleRate: 48000, bufferSize: 512)
          .timeout(const Duration(seconds: 10));
    }
    if (generation != _generation) return;
    sampleRate = rate;
    _analyzer = PcmAnalyzer(
      sampleRate: rate,
      referenceRms: referenceRms,
      spectralFeatures: spectralFeatures,
    );
    _samples = 0;
    consumed = 0;
    _lowByte = -1;
    ticks = 0;
    underruns = 0;
    maxQueuedSeconds = 0;
    maxFrameLagMs = 0;
    firstPlaybackMs = null;
    _frames.clear();
    _visemes.clear();
    _clock.reset();
    paused = false;
    buffering = true;
    inputEnded = false;
    active = true;
    _source = _engine.setBufferStream(
      sampleRate: rate,
      channels: Channels.mono,
      format: BufferType.s16le,
      bufferingType: BufferingType.released,
      maxBufferSizeDuration: const Duration(seconds: 2),
      bufferingTimeNeeds: prebufferSeconds,
      onBuffering: (waiting, handle, time) {
        if (generation != _generation || !active) return;
        if (waiting && !buffering && firstPlaybackMs != null && !inputEnded) {
          underruns++;
        }
        buffering = waiting;
        // A backend refill must never override an explicit user pause.
        if (!waiting && paused && _handle != null) {
          _engine.setPause(_handle!, true);
        }
      },
    );
    _timer = Timer.periodic(
      const Duration(milliseconds: 20),
      (_) => _poll(generation),
    );
  }

  bool add(Uint8List chunk) {
    if (!active || inputEnded) throw StateError('No writable PCM stream');
    if (chunk.isEmpty) return true;
    if (queuedSeconds +
            (chunk.length + (_lowByte < 0 ? 0 : 1)) / (sampleRate * 2) >
        maxAheadSeconds) {
      return false;
    }
    var data = chunk;
    if (_lowByte >= 0) {
      data = Uint8List(chunk.length + 1)..[0] = _lowByte;
      data.setRange(1, data.length, chunk);
      _lowByte = -1;
    }
    if (data.length.isOdd) {
      _lowByte = data.last;
      data = Uint8List.sublistView(data, 0, data.length - 1);
    }
    if (data.isEmpty) return true;
    if (!_clock.isRunning) _clock.start();
    _engine.addAudioDataStream(_source!, data);
    _samples += data.length ~/ 2;
    _frames.addAll(_analyzer!.add(data));
    maxQueuedSeconds = math.max(maxQueuedSeconds, queuedSeconds);
    if (_handle == null && received >= prebufferSeconds) _beginPlayback();
    return true;
  }

  /// Events are relative to this turn, ordered and bounded to a 2 s horizon.
  void addVisemes(Iterable<VisemeEvent> events) {
    final incoming = VisemeTrack(events).events;
    if (_visemes.length + incoming.length > 256) {
      throw StateError('Viseme queue full');
    }
    var previous = _visemes.isEmpty ? consumed : _visemes.last.end;
    for (final e in incoming) {
      if (e.start < previous || e.end > consumed + 2) {
        throw ArgumentError('Viseme event outside streaming horizon');
      }
      previous = e.end;
    }
    _visemes.addAll(incoming);
  }

  VisemeEvent? visemeAt(double time) {
    while (_visemes.isNotEmpty && _visemes.first.end <= time) {
      _visemes.removeFirst();
    }
    if (_visemes.isEmpty) return null;
    final event = _visemes.first;
    return event.start <= time && event.confidence >= .6 ? event : null;
  }

  EnergyFrame frameAt(double time) {
    while (_frames.length > 1 && _frames.elementAt(1).time <= time) {
      _frames.removeFirst();
    }
    if (_frames.isEmpty || _frames.first.time > time) {
      return EnergyFrame(time, 0, 0, true);
    }
    final frame = _frames.first;
    if (audible && !frame.silence) {
      maxFrameLagMs = math.max(maxFrameLagMs, (time - frame.time) * 1000);
    }
    return frame;
  }

  void _beginPlayback() {
    _handle = _engine.play(_source!, paused: paused);
    buffering = false;
  }

  void finish() {
    if (!active || inputEnded) return;
    if (_lowByte >= 0) {
      throw const FormatException('PCM stream ended inside a sample');
    }
    inputEnded = true;
    _engine.setDataIsEnded(_source!);
    if (_handle == null && _samples > 0) _beginPlayback();
    if (_samples == 0) {
      active = false;
      buffering = false;
      onComplete?.call();
    }
  }

  void pause() {
    paused = true;
    if (_handle != null) _engine.setPause(_handle!, true);
    onTick?.call();
  }

  void resume() {
    if (!active) return;
    paused = false;
    if (_handle != null) _engine.setPause(_handle!, false);
    onTick?.call();
  }

  void _poll(int generation) {
    if (generation != _generation || !active) return;
    try {
      final source = _source;
      if (source == null) return;
      consumed = _engine.getStreamTimeConsumed(source).inMicroseconds / 1e6;
      if (consumed > 0) firstPlaybackMs ??= _clock.elapsedMicroseconds / 1000;
      ticks++;
      if (_handle != null && !_engine.getIsValidVoiceHandle(_handle!)) {
        if (inputEnded) {
          consumed = received;
          active = false;
          buffering = false;
          _timer?.cancel();
          onComplete?.call();
          return;
        }
        throw StateError('PCM voice ended before end-of-stream');
      }
      // Measured sample cursor, never elapsed wall time, drives the avatar.
      onTick?.call();
    } catch (e) {
      active = false;
      _timer?.cancel();
      onError?.call(e);
    }
  }

  Map<String, dynamic> get metrics => {
    'firstChunkToPlaybackCursorMs': firstPlaybackMs,
    'maxQueuedMs': maxQueuedSeconds * 1000,
    'maxAllowedQueuedMs': maxAheadSeconds * 1000,
    'analysisFramesRetained': _frames.length,
    'visemeEventsRetained': _visemes.length,
    'maxAnalysisFrameLagMs': maxFrameLagMs,
    'receivedSeconds': received,
    'consumedSeconds': consumed,
    'underruns': underruns,
    'clockPollMs': 20,
    'clock': 'SoLoud released-stream consumed sample cursor',
    'latencyScope':
        'Playback cursor observation; excludes unmeasured speaker/display hardware latency',
  };

  Future<void> stop() async {
    ++_generation;
    _timer?.cancel();
    _timer = null;
    active = false;
    paused = false;
    buffering = false;
    final source = _source, handle = _handle;
    _source = null;
    _handle = null;
    if (handle != null && _engine.isInitialized) await _engine.stop(handle);
    if (source != null && _engine.isInitialized) {
      await _engine.disposeSource(source);
    }
    _frames.clear();
    _visemes.clear();
    _analyzer = null;
    _lowByte = -1;
  }
}
