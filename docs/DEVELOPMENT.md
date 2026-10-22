# Development guide

## Toolchain

| Tool | Tested version / role |
| --- | --- |
| Flutter | 3.44.6; native Windows player |
| Dart | 3.12.2; SDK constraint in `player/pubspec.yaml` |
| Rive CLI | 1.7.0; RML authoring, verification, compilation and preview |
| Python | 3.11; audio analysis and validation helpers |
| Visual Studio | C++ desktop tools and Windows SDK for Flutter Windows builds |

Use the installed CLI documentation (`rive docs`, `rive schema`) when authoring RML. The player can run from the bundled assets without Rive or Python installed.

## Windows setup

From the repository root:

```powershell
flutter doctor -v
cd player
flutter pub get
flutter run -d windows
```

If Flutter reports missing plugin symlink privileges, return to the repository root and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/prepare-windows.ps1
cd player
flutter run -d windows
```

The helper creates local directory junctions for Windows plugins; it does not change Developer Mode or system settings. Generated plugin links and configuration remain ignored.

## Rebuild the avatar

After editing source mouth PNGs, run `python gettopik-teacher/tools/audit_mouth_rig.py`, `python gettopik-teacher/tools/build_scene.py` and `python gettopik-teacher/tools/bake_timeline.py` before compiling. This regenerates lossless runtime crops and keeps the RML consistent.

Run these commands from the repository root with `rive` on `PATH`. On the original Windows installation the executable is also available at `$env:USERPROFILE\.rive\bin\rive.exe`.

```powershell
rive gettopik-teacher --verify
rive inspect gettopik-teacher --summary
rive gettopik-teacher --once
Copy-Item gettopik-teacher/build/teacher.riv player/assets/teacher.riv -Force
```

Restart the Flutter player after replacing its bundled Rive asset. When distributing an executable, rebuild the release so the new asset is packaged.

To watch source changes in the native CLI preview:

```powershell
rive gettopik-teacher --artboard=Classroom --viewport=620x826 --fit=contain
```

To render the current silence pose:

```powershell
rive gettopik-teacher --screenshot=gettopik-teacher/build/closed-press.png --data=mouthIndex=6 --advance=10
```

The CLI preview has no synchronization with Flutter's audio clock. Test synchronized playback in the native player.

## Change the lesson

From the repository root, install the helper dependencies and choose a local MP3 or 16-bit PCM WAV:

```powershell
python -m pip install -r gettopik-teacher/tools/requirements.txt
python gettopik-teacher/tools/analyze_audio.py "C:\audio\korean-lesson.mp3"
python gettopik-teacher/tools/bake_timeline.py
rive gettopik-teacher --verify
rive inspect gettopik-teacher --summary
rive gettopik-teacher --once
Copy-Item gettopik-teacher/build/teacher.riv player/assets/teacher.riv -Force
Copy-Item gettopik-teacher/audio/korean_demo.wav player/assets/korean_demo.wav -Force
Copy-Item gettopik-teacher/audio/mouth_timeline.json player/assets/mouth_timeline.json -Force
```

MP3 decoding uses the local FFmpeg executable provided by `imageio-ffmpeg`. The analyzer writes a 24 kHz mono WAV for MP3 input, a 60 fps mouth timeline and an analysis report. Paths to the original recording are not required at playback time.

The current recording is a 12.12-second Korean female solo narration; see [source and attribution](AUDIO_SOURCE.md). If you replace it, update the integration test's known-silence timestamp and any lesson-specific assertions. Commit both the updated source outputs in `gettopik-teacher/audio/` and the player copies together.

## Animation pipeline

1. Measure PCM RMS in a 20 ms window at 60 fps.
2. Apply 30 ms attack / 70 ms release smoothing.
3. Detect silence using an adaptive threshold and two quiet frames.
4. Hold non-silence pose changes for at least four frames.
5. Map silence to Closed press, lower energy to Small, and medium/high energy to Medium.
6. Sample the timeline using native audio position and update the Rive `mouthIndex` property.
7. The current runtime selects one photographic mouth through Rive Solo; eye and idle layers run independently. See [current mouth quality](LIPSYNC_QUALITY.md) for the DSP policy and A/B comparison.

Head motion uses a separate `motionTalking` property with a 700 ms quiet hold and eased state transitions. Breathing runs independently on a 31-second timeline. See the [motion guide](MOTION.md) for viewport compensation and the current shoulder-seam fallback.

`AudioMouth` is also baked into the RML as a one-shot timeline. Flutter uses the mouth state machine instead of running that timeline concurrently.

## Checks

From the repository root:

```powershell
rive gettopik-teacher --verify
rive inspect gettopik-teacher --summary
cd player
flutter analyze
flutter test test/avatar_engine_test.dart
flutter test integration_test/playback_test.dart -d windows
flutter test integration_test/adaptive_test.dart -d windows --reporter expanded
```

Install the Python helper requirements before the integration test. Run it in an interactive Windows desktop session with speaker output available, and close other copies of the demo so screenshots capture the test window. It plays real audio and measures speaker loopback; it also checks silence, pause, seek, completion, replay, manual poses and independent eye controls.

## Package Windows

From the repository root:

```powershell
Push-Location player
flutter build windows --release
Pop-Location

New-Item -ItemType Directory -Force dist/GETTOPIK-Teacher-Windows | Out-Null
Copy-Item player/build/windows/x64/runner/Release/* dist/GETTOPIK-Teacher-Windows -Recurse -Force
Copy-Item README.md dist/GETTOPIK-Teacher-Windows/README-source.md -Force
Copy-Item docs/AUDIO_SOURCE.md dist/GETTOPIK-Teacher-Windows/AUDIO-SOURCE.md -Force
Copy-Item gettopik-teacher/audio/audio_source.json dist/GETTOPIK-Teacher-Windows/audio_source.json -Force
Compress-Archive -Path dist/GETTOPIK-Teacher-Windows -DestinationPath dist/GETTOPIK-Teacher-Windows.zip -Force
```

Distribute the complete folder, including DLLs and `data/`. `dist/` is intentionally ignored; attach portable builds to GitHub Releases separately if needed.

## Git conventions

- Track source RML, PNGs, manifests, scripts, runner files and `player/pubspec.lock`.
- Keep the bundled `player/assets/teacher.riv`, WAV and timeline so a checkout can run directly.
- Keep curated screenshots in `docs/images/` and current JSON evidence in `gettopik-teacher/validation/closed-press-default/`.
- Leave generated builds, caches, release ZIPs, staging archives and backups untracked.
- After an avatar or audio change, refresh source outputs and runtime copies together.
