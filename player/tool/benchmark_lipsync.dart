// Pure Dart benchmark: no recognition model, Flutter renderer or audio backend.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:gettopik_teacher_player/audio/pcm_wav.dart';
import 'package:gettopik_teacher_player/avatar/character_profile.dart';
import 'package:gettopik_teacher_player/avatar/lip_sync.dart';

void main() {
  final wav = PcmWav.parse(File('assets/korean_demo.wav').readAsBytesSync());
  final report = <String, dynamic>{
    'scope': 'Pure Dart Windows VM; CPU analysis time, not mobile or rendering',
    'audioDuration': wav.duration,
    'timedVisemes': {
      'status': 'unavailable',
      'reason': 'No verified Korean phoneme timings; no invented C score',
    },
    'modes': <String, dynamic>{},
  };
  for (final style in LipSyncStyle.values) {
    final chunks = <int>[], traces = <Map<String, dynamic>>[];
    var cpuUs = 0, transitions = 0, largeOpens = 0, noiseLike = 0;
    var onsetSamples = <double>[];
    for (var repeat = 0; repeat < 55; repeat++) {
      final analyzer = PcmAnalyzer(
        spectralFeatures: style == LipSyncStyle.lightweight,
      );
      final engine = LipSyncEngine(CharacterProfile.teacher)..style = style;
      var previous = 6, wasSilent = true;
      double? onset;
      for (var i = 0; i < wav.pcm.length; i += 1920) {
        final timer = Stopwatch()..start();
        final frames = analyzer.add(
          Uint8List.sublistView(wav.pcm, i, math.min(i + 1920, wav.pcm.length)),
        );
        for (final f in frames) {
          final pose = engine.resolve(f.time, f, playing: true);
          if (repeat == 54) {
            if (wasSilent && !f.silence) onset = f.time;
            if (f.silence) onset = null;
            if (onset != null && pose != 6) {
              onsetSamples.add((f.time - onset) * 1000);
              onset = null;
            }
            if (pose != previous) {
              transitions++;
              if (pose == 2) largeOpens++;
            }
            if (f.noiseLike) noiseLike++;
            traces.add({
              'time': f.time,
              'pose': pose,
              'silence': f.silence,
              'energy': f.energy,
              'noiseLike': f.noiseLike,
            });
            previous = pose;
            wasSilent = f.silence;
          }
        }
        timer.stop();
        if (repeat >= 5) {
          chunks.add(timer.elapsedMicroseconds);
          cpuUs += timer.elapsedMicroseconds;
        }
      }
    }
    chunks.sort();
    onsetSamples.sort();
    final voice = traces.where((f) => f['silence'] == false).length;
    report['modes'][style.name] = {
      'repetitions': 50,
      'analyzedAudioSeconds': 50 * wav.duration,
      'analysisWallMs': cpuUs / 1000,
      'analysisMsPerAudioSecond': cpuUs / 1000 / (50 * wav.duration),
      'chunk40msP50Us': chunks[chunks.length ~/ 2],
      'chunk40msP95Us': chunks[(chunks.length * .95).floor()],
      'processRssBytes': ProcessInfo.currentRss,
      'poseChanges': transitions,
      'entriesToMedium': largeOpens,
      'speechFrames': voice,
      'noiseLikeFrames': noiseLike,
      'onsetToFirstOpeningP50Ms': onsetSamples[onsetSamples.length ~/ 2],
      'onsetToFirstOpeningMaxMs': onsetSamples.last,
      'silenceViolations': traces
          .where((f) => f['silence'] == true && f['pose'] != 6)
          .length,
      'trace': traces,
    };
  }
  final out = File(
    '../gettopik-teacher/validation/lipsync-quality/dsp-benchmark.json',
  );
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  for (final entry in (report['modes'] as Map).entries) {
    final metrics = Map<String, dynamic>.from(entry.value)..remove('trace');
    stdout.writeln('${entry.key}: ${jsonEncode(metrics)}');
  }
}
