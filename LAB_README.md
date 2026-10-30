# AI Speaking Avatar Lab

Isolated checkout for Teacher experiments. GETTOPIK mobile is not modified.
Upstream baseline: `6b31d63018e14d6a9c7a600961c3acbbcc8d0eaf`.

## Start the character flow

```sh
cd /Users/dalab/Desktop/ai-speaking-avatar-lab/player
flutter pub get
flutter run -d chrome -t lib/main_mobile.dart --web-port=7361
```

For a browser-independent local server:

```sh
flutter run -d web-server -t lib/main_mobile.dart --web-hostname=127.0.0.1 --web-port=7361
```

Open http://127.0.0.1:7361. Choose AI Speaking → Korean Teacher → Play Korean audio.
Use pause, replay, mouth/eye controls and fullscreen to inspect the existing avatar.
Other characters are disabled Coming Soon placeholders.
`lib/main.dart` retains the original desktop studio; `lib/main_mobile.dart`
launches the Home and character flow on any supported platform.
This lab also includes an iOS runner. Start the booted simulator with:

```sh
open -a Simulator
flutter run -d 64E5EF7A-24ED-4002-A408-5D4CF953D489 -t lib/main_mobile.dart
```

Use `flutter devices` to find the ID if your simulator differs.
For Xcode, open `player/ios/Runner.xcworkspace`.
The app display name is Avatar Lab. No microphone permission is requested because
this prototype only plays bundled audio.

## Code boundaries

- `lib/demo/demo_app.dart`: application configuration only.
- `lib/demo/demo_theme.dart`: shared demo colors.
- `lib/demo/demo_home_screen.dart`: Home entry card.
- `lib/demo/character_selection_screen.dart`: character selection and demo navigation.
- `lib/demo/widgets/`: small shared presentation widgets.
- `lib/features/ai_speaking/`: host-independent speaking screen and avatar surface.
- `lib/avatar_controller.dart`: existing playback and avatar coordination.
- `lib/audio/`: existing PCM decoding and stream transport.
- `lib/avatar/`: existing character profiles, behavior and lip-sync analysis.

The refactor splits the former single demo file without replacing the existing
audio engine, changing bundled artwork, or upgrading dependencies. Existing public
screen imports from `demo_app.dart` remain available through exports.

## Actual capabilities

This is an offline playback prototype, not a live AI conversation. It plays a
12.12-second bundled Korean recording. Mouth animation follows audio analysis;
it does not recognize Korean phonemes. No API keys or backend are required.
Microphone capture, speech recognition, generated replies, TTS, subtitles and
beginner answer suggestions are not implemented.

## Validation on 2026-10-31

- Flutter 3.44.6 / Dart 3.12.2; dependencies resolved from the existing lockfile.
- `flutter analyze`: no issues after refactor.
- `flutter test`: 13 tests passed (audio/behavior and 320/390/800 px navigation).
- Web debug compilation succeeds and the preview server starts on port 7361.
- Browser control is unavailable in this session: interactive rendering, audible
  output and native-device playback have not been manually verified here.
  Existing upstream validation reports are historical, not new lab measurements.

Before GETTOPIK integration, manually check playback, pause, seek, expressions,
fullscreen, back navigation and background/resume on target devices. Keep the
feature outside the production app until that integration is explicitly requested.
No new or replacement assets were introduced in this refactor.

## iOS invisible Teacher fix

The native Rive texture rendered an empty avatar on the Intel iOS simulator.
The lab now selects `Factory.flutter` on iOS; other platforms retain `Factory.rive`.
A native simulator integration test passed after the change: the Teacher alone
painted more than 10,000 visible pixels into a transparent 300×400 surface,
audio position advanced, and pause stopped the transport.

```sh
flutter test integration_test/ios_avatar_test.dart -d 64E5EF7A-24ED-4002-A408-5D4CF953D489
```

This verifies visible rendering and playback state, not perceived audio quality
or visual likeness. Physical iOS devices still need checking.

## Slow Korean local sample

See [local Julia audio](docs/LOCAL_JULIA_AUDIO.md) for the 42.3-second excerpt,
source attribution and simulator run command. Original FLEURS audio is preserved.
