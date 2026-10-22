# GETTOPIK Windows Player

Native Flutter player for the GETTOPIK Teacher Rive avatar and bundled Korean audio.

![GETTOPIK native Windows player](../docs/images/studio-ready.png)

## Run

Requires Flutter with Windows desktop support and Visual Studio C++ desktop build tools. Tested with Flutter 3.44.6 / Dart 3.12.2.

From this directory:

```powershell
flutter pub get
flutter run -d windows
```

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

`AvatarController` accepts `rivAsset`, `audioAsset`, `timelineAsset`, `artboardName` and `propertyName`. Keep a character's compiled Rive state machine and timeline indices consistent when reusing it. The current implementation expects the `eyePose` property as well as the configured mouth property.

`audioAsset` is relative to Flutter's `assets/` audio prefix; `rivAsset` and `timelineAsset` use their complete bundle keys. Dispose the controller with its owning widget.

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
