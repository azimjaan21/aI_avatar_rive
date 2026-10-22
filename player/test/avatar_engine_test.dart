import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gettopik_teacher_player/avatar/behavior.dart';
import 'package:gettopik_teacher_player/avatar/character_profile.dart';
import 'package:gettopik_teacher_player/avatar/lip_sync.dart';
import 'package:gettopik_teacher_player/audio/pcm_wav.dart';

void main() {
  test(
    'PCM analysis is invariant to odd-byte and irregular chunk boundaries',
    () {
      final pcm = Uint8List(24000 * 2);
      final data = ByteData.sublistView(pcm);
      for (var i = 0; i < 24000; i++) {
        data.setInt16(
          i * 2,
          i < 12000 ? (math.sin(i * .08) * 9000).round() : 0,
          Endian.little,
        );
      }
      final whole = PcmAnalyzer().add(pcm), split = <EnergyFrame>[];
      final analyzer = PcmAnalyzer();
      var offset = 0;
      for (final size in [1, 7, 489, 2001, 5, 301]) {
        split.addAll(
          analyzer.add(Uint8List.sublistView(pcm, offset, offset + size)),
        );
        offset += size;
      }
      split.addAll(analyzer.add(Uint8List.sublistView(pcm, offset)));
      expect(split.length, whole.length);
      for (var i = 0; i < whole.length; i++) {
        expect(split[i].rms, whole[i].rms);
        expect(split[i].time, whole[i].time);
        expect(split[i].silence, whole[i].silence);
      }
      expect(whole.last.silence, isTrue);
      expect(whole.firstWhere((f) => f.time > .55).silence, isTrue);
    },
  );

  test('Korean phone categories use safe artwork and no guessed unknowns', () {
    expect(koreanPhoneViseme('pʰ'), Viseme.mbp);
    expect(koreanPhoneViseme('ㅏ'), Viseme.a);
    expect(koreanPhoneViseme('i'), Viseme.ei);
    expect(koreanPhoneViseme('o'), Viseme.o);
    expect(koreanPhoneViseme('u'), Viseme.u);
    expect(koreanPhoneViseme('a_B'), Viseme.a);
    expect(koreanPhoneViseme('tɕ'), isNull);
    expect(CharacterProfile.teacher.visemes[Viseme.o], 4);
    expect(CharacterProfile.teacher.visemes[Viseme.u], 4);
  });

  test('Alignment rejects wrong audio, bad ordering, overlaps and NaN', () {
    expect(
      () => VisemeTrack.fromJson({
        'audioSha256': 'wrong',
        'events': [],
      }, 'actual'),
      throwsFormatException,
    );
    expect(
      () => VisemeTrack([
        const VisemeEvent(1, 2, Viseme.a),
        const VisemeEvent(1.5, 3, Viseme.o),
      ]),
      throwsFormatException,
    );
    expect(
      () => VisemeTrack([const VisemeEvent(double.nan, 2, Viseme.a)]),
      throwsFormatException,
    );
    final track = VisemeTrack([const VisemeEvent(.2, .4, Viseme.o)]);
    expect(track.at(.1), isNull);
    expect(track.at(.3)!.viseme, Viseme.o);
    expect(track.at(.4), isNull);
  });

  test('Verified events choose Round/Teeth; silence overrides everything', () {
    final lips = LipSyncEngine(CharacterProfile.teacher)
      ..alignment = VisemeTrack([
        const VisemeEvent(0, .15, Viseme.o),
        const VisemeEvent(.15, .3, Viseme.ei),
        const VisemeEvent(.3, .4, Viseme.mbp),
      ]);
    expect(
      lips.resolve(.1, const EnergyFrame(.1, .1, .8, false), playing: true),
      4,
    );
    expect(
      lips.resolve(.2, const EnergyFrame(.2, .1, .8, false), playing: true),
      5,
    );
    expect(
      lips.resolve(.31, const EnergyFrame(.31, .1, .8, false), playing: true),
      6,
    );
    expect(
      lips.resolve(.12, const EnergyFrame(.12, 0, 0, true), playing: true),
      6,
    );
    expect(
      lips.resolve(.1, const EnergyFrame(.1, .1, .8, false), playing: false),
      6,
    );
  });

  test('Fallback hysteresis and dwell resist rapid mouth flicker', () {
    final lips = LipSyncEngine(CharacterProfile.teacher);
    expect(
      lips.resolve(0, const EnergyFrame(0, .1, .5, false), playing: true),
      2,
    );
    expect(
      lips.resolve(.01, const EnergyFrame(.01, .1, .1, false), playing: true),
      2,
    );
    expect(
      lips.resolve(.1, const EnergyFrame(.1, .1, .3, false), playing: true),
      2,
    );
    expect(
      lips.resolve(.2, const EnergyFrame(.2, .1, .1, false), playing: true),
      1,
    );
    expect(
      lips.resolve(.21, const EnergyFrame(.21, 0, 0, true), playing: true),
      6,
    );
  });

  test('Emotions coexist with speech and release smoothly to neutral', () {
    final behavior = BehaviorController()..onListening();
    behavior.emotions.set(AvatarEmotion.happy, 0);
    expect(
      behavior.effective(true, behavior.emotions.sample(.5)),
      ConversationState.speaking,
    );
    expect(
      behavior.effective(false, behavior.emotions.sample(.5)),
      ConversationState.smiling,
    );
    behavior.emotions.reset(1);
    expect(behavior.emotions.sample(1.2).weight, greaterThan(0));
    expect(
      behavior.effective(false, behavior.emotions.sample(1.6)),
      ConversationState.listening,
    );
    behavior.emotions.set(AvatarEmotion.softLaugh, 2);
    expect(
      behavior.effective(false, behavior.emotions.sample(2.5)),
      ConversationState.laughing,
    );
    expect(behavior.emotions.sample(5).emotion, AvatarEmotion.neutral);
  });

  test('Solo Korean narration is valid 12.12 second PCM16 mono', () {
    final wav = PcmWav.parse(File('assets/korean_demo.wav').readAsBytesSync());
    expect(wav.sampleRate, 24000);
    expect(wav.duration, closeTo(12.12, .00001));
    expect(() => PcmWav.parse(Uint8List(3)), throwsFormatException);
  });
}
