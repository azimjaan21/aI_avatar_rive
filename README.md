# GETTOPIK Speaking Studio

An offline Korean speaking teacher demo, built with **Rive CLI**, **RML** and **Flutter for Windows**. A layered Teacher avatar follows a local lesson recording with subtle mouth movement, partial blinking, breathing and head motion.

![GETTOPIK Speaking Studio showing the Teacher in a classroom with local audio and pose controls](docs/images/studio-ready.png)

The demo runs locally without a backend, API key or paid avatar service. Rive artwork is authored from source PNGs using the official CLI, without the Rive Editor.

[Quick start](#quick-start) · [Development](docs/DEVELOPMENT.md) · [Avatar assets](docs/ASSETS.md) · [Validation](docs/VALIDATION.md)

## Features

- **Solo Korean female narration:** a 12.12-second local recording with Play/Pause, seeking, restart and replay. [Source and attribution](docs/AUDIO_SOURCE.md).
- **Streaming simulation:** bounded PCM buffering, sample-clock animation and interruption handling.
- **Expression controls:** Smile, Happy, Encouraging and Soft laugh in the collapsed Behavior lab.
- **Audio-driven mouth movement:** RMS analysis, smoothing, silence detection and 45 ms pose transitions.
- **Six mouth poses:** Small, Medium, Round, Teeth, Closed press and Smile, with manual preview buttons.
- **Subtle motion:** neck-pivot sway, ±2 px breathing, 1.002–1.004 breathing scale and Open → Half → Open partial blinking. The current artwork uses a smaller shared sway to keep the shoulders aligned.
- **Independent eye inspection:** Auto, Open and Half controls work alongside audio and mouth animation.
- **Transparent Teacher:** layered PNG artwork over a classroom or plain background.
- **Reusable controller:** configurable Rive asset, artboard, audio, timeline and mouth property.

**Current behavior:** Closed press is the default during silence, pause and audio completion. RMS Auto uses Closed press, Small and Medium. Verified phoneme events can select Round and Teeth; the current recording has no phone alignment. Rest, Wide and Closed eyes are disabled and excluded from the compiled Rive asset.

## Demo

| Speaking with local audio | Paused: Closed press |
| --- | --- |
| ![Teacher speaking while the local Korean recording plays](docs/images/studio-speaking.png) | ![Paused lesson with the Teacher mouth in Closed press](docs/images/studio-paused.png) |

These screenshots are from the native Windows application. Playback, silence, pause, seeking and replay were exercised in the [native integration test](player/integration_test/playback_test.dart); see the [validation record](docs/VALIDATION.md).

## Quick start

### Run from source

Tested with **Flutter 3.44.6 / Dart 3.12.2**, Windows x64 and Visual Studio C++ desktop build tools. The compiled avatar, local WAV and mouth timeline are included in `player/assets/`, so running the player does not require Python or the Rive CLI.

From the repository root:

```powershell
cd player
flutter pub get
flutter run -d windows
```

Alternatively, double-click `Start-Demo.cmd`. It opens a local portable build when one is present in `dist/GETTOPIK-Teacher-Windows/`; otherwise it runs Flutter from source.

The first source build downloads dependencies. The built Windows application plays the bundled lesson offline.

For a Chrome web preview, run `flutter run -d chrome --web-hostname=127.0.0.1 --web-port=7357` from `player/`, then open [the local demo](http://127.0.0.1:7357). It uses the same bundled final Rive asset. Press **Play lesson** to begin browser audio; the native integration test is Windows-specific.

### Use the player

| Control | Behavior |
| --- | --- |
| Play lesson / Pause | Play or pause the local Korean recording |
| Timeline slider / Restart | Seek to a position or rewind |
| Mouth pose | Pause audio and hold the selected expression |
| Mouth Auto | Return mouth control to the audio timeline; press Play to continue |
| Eye Auto / Open / Half | Follow partial blinking or hold an eye asset independently |
| Background button | Switch between the classroom and a plain backdrop |

For a Windows plugin symlink error, see [Windows setup](docs/DEVELOPMENT.md#windows-setup).

## Repository layout

```text
.
├── docs/                         # Setup, asset guide, validation and demo images
├── gettopik-teacher/
│   ├── scene.rml                 # Rive animation and state machines
│   ├── rive.yaml                 # Official CLI project configuration
│   ├── assets/ai_speaking/        # Teacher PNG layers and manifest
│   ├── audio/                    # WAV, RMS timeline and analysis report
│   ├── tools/                    # Authoring, audio analysis and capture helpers
│   └── validation/               # Curated current validation reports
├── player/
│   ├── assets/                   # Bundled .riv, WAV, timeline and background
│   ├── lib/                      # Flutter UI and reusable AvatarController
│   ├── integration_test/         # Real native audio and pose validation
│   └── windows/                  # Windows runner
├── tools/prepare-windows.ps1     # Optional local plugin junction setup
└── Start-Demo.cmd                # Windows launcher
```

`build/`, `dist/`, caches, extracted archives, backups and historical captures are ignored. Runtime assets and `pubspec.lock` stay versioned so the checkout is runnable. Portable ZIPs can be attached separately to a GitHub Release.

## Development

[Development guide](docs/DEVELOPMENT.md): rebuild the Rive asset, change the lesson, run checks and package Windows output.

[Asset guide](docs/ASSETS.md): layer order, fixed canvas coordinates, mouth indices and current exclusions.

[Validation record](docs/VALIDATION.md): playback evidence and visual limitations.

[Adaptive avatar report](docs/ADAPTIVE_AVATAR.md): streaming APIs, expressions, reusable profiles, tests and current limitations.

[Motion guide](docs/MOTION.md): idle/talking ranges, breathing compensation and the shoulder-seam fallback.

## Scope and limitations

Mouth motion follows audio energy; it does **not** identify Korean phonemes. Medium is used for both medium and high energy. Round and Teeth require manual selection or verified phoneme events. Smile is also available through the expression controller; automatic laughter recognition is not implemented. Closed eyes are currently disabled, so Auto provides partial blinking.

This is a 2D avatar: lip contours and the shared skin patch can look less natural at high magnification, and head movement may reveal a slight shoulder seam. Windows is the tested and packaged platform.

## License and media

No open-source license has been assigned to this repository. The bundled FLEURS recording is licensed under CC BY 4.0; see [audio attribution](docs/AUDIO_SOURCE.md). Teacher artwork and branding are included as demo materials; their presence does not grant separate redistribution rights. Dependency licenses remain with their respective owners.
