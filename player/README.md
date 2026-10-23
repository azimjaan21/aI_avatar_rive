# GETTOPIK Flutter Player

Native Flutter player for the GETTOPIK Teacher Rive avatar and bundled Korean audio.

Android uses a separate mobile demo host with Home, character selection and
Teacher speaking screens. Run `flutter run -d emulator-5554 -t lib/main_mobile.dart`.
See [Android setup, reusable module and validation](../docs/ANDROID_DEMO.md).

![GETTOPIK native Windows player](../docs/images/studio-ready.png)

## Run

Requires Flutter with Windows desktop support and Visual Studio C++ desktop build tools. Tested with Flutter 3.44.6 / Dart 3.12.2.

From this directory:

```powershell
flutter pub get
flutter run -d windows
```

For the Chrome web preview, from this directory:

```powershell
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=7357
```

Open `http://127.0.0.1:7357` and press **Play lesson** to start browser audio. The web preview uses the same bundled final `.riv`, recording and timeline as the Windows player. Browser rendering has been checked; the full speaker-loopback integration test remains Windows-specific.

All playback assets are bundled. Python and the Rive CLI are only needed for authoring or validation helpers. No backend configuration is required.

## Implementation

| File | Responsibility |
| --- | --- |
| `lib/main.dart` | Classroom view, audio controls and independent mouth/eye pose selection |
| `lib/avatar_controller.dart` | Local audio playback, timeline lookup and Rive view model updates |
| `assets/teacher.riv` | Compiled Teacher and Classroom artboards |
| `assets/korean_demo.wav` | Local Korean lesson recording |
| `assets/mouth_timeline.json` | Precomputed 60 fps RMS mouth timeline |
| `integration_test/playback_test.dart` | Native playback, silence, pause, seek, replay and pose checks |

`AvatarController` accepts `rivAsset`, `audioAsset`, `timelineAsset`, `artboardName` and `propertyName`. Keep a character's compiled Rive state machine and timeline indices consistent when reusing it. The current implementation expects `eyePose`, `motionTalking` and `breathAmplitude` number properties as well as the configured mouth property.

`audioAsset` is relative to Flutter's `assets/` audio prefix; `rivAsset` and `timelineAsset` use their complete bundle keys. Dispose the controller with its owning widget.

The existing Rive viewport calls `configureViewport(width, height)` to keep breathing translation near ±2 logical pixels without changing the UI layout. Head/whole-avatar motion and breathing are authored in Rive; the player only supplies audio activity and viewport gain. See the [motion guide](../docs/MOTION.md).

## Build and validate

```powershell
flutter analyze
flutter build windows --release
```

For native integration testing, install the Python dependencies from this directory first:

```powershell
python -m pip install -r ../gettopik-teacher/tools/requirements.txt
flutter test integration_test/playback_test.dart -d windows --reporter expanded
```

The integration test uses a visible Windows session and an available speaker output for loopback verification. Its pause assertion at 8.15 seconds is specific to the bundled lesson.

See [development](../docs/DEVELOPMENT.md), [asset conventions](../docs/ASSETS.md) and [validation](../docs/VALIDATION.md) for the complete workflow.

The current player uses one SoLoud PCM engine for local WAV, simulated arrival and external chunks. See [mouth quality and measured performance](../docs/LIPSYNC_QUALITY.md). The old JSON mouth timeline is retained for metadata and CLI authoring; live mouth choices are computed causally.
