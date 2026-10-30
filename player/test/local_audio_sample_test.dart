import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gettopik_teacher_player/avatar_controller.dart';
import 'package:gettopik_teacher_player/audio/pcm_wav.dart';

void main() {
  if (!const bool.fromEnvironment('LOCAL_JULIA_AUDIO')) return;
  test('Selected local sample matches its timing data', () {
    final controller = AvatarController();
    expect(controller.audioAsset, 'local_julia.wav');
    expect(controller.visemeAsset, isNull);
    final bytes = File('assets/${controller.audioAsset}').readAsBytesSync();
    final wav = PcmWav.parse(bytes);
    final timing =
        jsonDecode(File(controller.timelineAsset).readAsStringSync());
    expect(wav.sampleRate, 24000);
    expect(wav.duration, closeTo(42.3, .00001));
    expect(timing['duration'], closeTo(wav.duration, .00001));
    expect(timing['audioSha256'], sha256.convert(bytes).toString());
    expect((timing['frames'] as List).last['mouth'], 6);
    controller.dispose();
  });
}
