import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

/// Local audio clock -> Rive mouthIndex; disabled poses use safe replacements.
class AvatarController extends ChangeNotifier {
  AvatarController({
    this.rivAsset = 'assets/teacher.riv',
    this.audioAsset = 'korean_demo.wav',
    this.timelineAsset = 'assets/mouth_timeline.json',
    this.artboardName = 'Teacher',
    this.propertyName = 'mouthIndex',
  });
  final String rivAsset, audioAsset, timelineAsset, artboardName, propertyName;
  final audio = AudioPlayer();
  rive.File? file;
  rive.RiveWidgetController? riveController;
  rive.ViewModelInstance? instance;
  rive.ViewModelInstanceNumber? mouthProperty;
  rive.ViewModelInstanceNumber? eyeProperty;
  int eyePose = -1; // -1 Auto, 0 Open, 1 Half. Closed is temporarily disabled.
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<dynamic> frames = [];
  List<String> mouths = [];
  String source = '';
  double duration = 0, position = 0, energy = 0;
  int mouth = 6;
  bool playing = false, ready = false, seeking = false, silence = true;
  int? manualMouth;
  String? error;
  bool _disposed = false;

  Future<void> load() async {
    try {
      final data = jsonDecode(await rootBundle.loadString(timelineAsset));
      frames = data['frames'];
      mouths = List<String>.from(data['mouths']);
      duration = (data['duration'] as num).toDouble();
      source = data['source'];
      file = await rive.File.asset(rivAsset, riveFactory: rive.Factory.rive);
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
      if (mouthProperty == null) throw StateError('Missing $propertyName');
      eyeProperty = instance!.number('eyePose');
      if (eyeProperty == null) throw StateError('Missing eyePose');
      _subscriptions.add(
        audio.onPositionChanged.listen((p) {
          if (!seeking) {
            position = p.inMicroseconds / 1000000;
            _sample();
          }
        }),
      );
      _subscriptions.add(
        audio.onPlayerStateChanged.listen((s) {
          playing = s == PlayerState.playing;
          _sample();
        }),
      );
      _subscriptions.add(
        audio.onPlayerComplete.listen((_) {
          playing = false;
          position = duration;
          manualMouth = null;
          _sample();
        }),
      );
      await audio.setReleaseMode(ReleaseMode.stop);
      await audio.setSource(AssetSource(audioAsset));
      ready = true;
      _sample();
    } catch (e) {
      error = '$e';
      if (!_disposed) notifyListeners();
    }
  }

  void _sample() {
    if (_disposed || frames.isEmpty) return;
    var lo = 0, hi = frames.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if ((frames[mid]['time'] as num) <= position) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final f = frames[lo];
    energy = playing ? (f['energy'] as num).toDouble() : 0;
    silence = !playing || f['silence'] == true;
    final requested = manualMouth ?? (silence ? 6 : f['mouth'] as int);
    // Rest (0) uses Closed press; Wide (3) uses Medium.
    final next = requested == 0 ? 6 : (requested == 3 ? 2 : requested);
    if (next != mouth || mouthProperty?.value != next.toDouble()) {
      mouth = next;
      mouthProperty?.value = next.toDouble();
      riveController?.scheduleRepaint();
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    if (!ready) return;
    manualMouth = null;
    try {
      if (playing) {
        await audio.pause();
      } else {
        if (position >= duration - .05) await seek(0);
        await audio.resume();
      }
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> seek(double seconds) async {
    seeking = true;
    try {
      await audio.seek(Duration(microseconds: (seconds * 1000000).round()));
      position = seconds;
      _sample();
    } finally {
      seeking = false;
    }
  }

  Future<void> selectMouth(int? index) async {
    if (index == 0) index = 6;
    if (index == 3) index = 2;
    if (index != null && playing) await audio.pause();
    manualMouth = index;
    _sample();
  }

  /// Hold a source eye PNG without interrupting mouth motion or local audio.
  void selectEye(int pose) {
    RangeError.checkValueInInterval(pose, -1, 2, 'pose');
    if (pose == 2) pose = 1; // Legacy Closed requests fall back to Half.
    eyePose = pose;
    eyeProperty?.value = pose.toDouble();
    riveController?.scheduleRepaint();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(audio.dispose());
    mouthProperty?.dispose();
    eyeProperty?.dispose();
    riveController?.dispose();
    instance?.dispose();
    file?.dispose();
    super.dispose();
  }
}
