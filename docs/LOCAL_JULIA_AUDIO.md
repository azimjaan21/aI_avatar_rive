# Local slow Korean sample

Source: [Easy Korean Listening with Julia — Episode 2: Beginner Korean Listening
Practice, Slow & Easy](https://podcasts.apple.com/us/podcast/id1855367131?i=1000738171598).
Creator: Easy Korean Listening with Julia. Published 2025-11-24.

The local fixture uses source 00:30.000–01:12.300 (42.3 seconds).
A single female speaker introduces Sujin and talks about Busan. A local automated
transcript was used to locate Korean sentences; the endpoint was checked against
quiet PCM frames. This is not a manual listening-quality review.

The recording keeps its original pace and pitch. Processing: trim, 20 ms fade-in,
30 ms fade-out, 24 kHz mono PCM16, metadata stripped. Audio size: 2,030,478 bytes.
A new 60 fps RMS timeline matches the clip. No phoneme alignment is claimed.

## Run in the iOS simulator

```sh
cd /Users/dalab/Desktop/ai-speaking-avatar-lab/player
flutter run -d 64E5EF7A-24ED-4002-A408-5D4CF953D489 -t lib/main_mobile.dart --dart-define=LOCAL_JULIA_AUDIO=true
```

Choose AI Speaking → Korean Teacher → Play Korean audio. Duration should be 0:42.
A full restart is required when changing the compile-time audio option.
Without the define, the original licensed FLEURS sample remains the default.

## Files and reproducibility

- `player/assets/local_julia.wav` and `local_julia_timeline.json` are Git-ignored.
- The full download, preparation metadata and automated transcript are in ignored
  `staging/julia/`.
- Original FLEURS audio and timing data have not been overwritten.

```sh
python3 tools/prepare-local-julia.py --ffmpeg staging/ffmpeg/ffmpeg --source staging/julia/episode.mp3 --start 30 --end 72.3
cd player
flutter test test/local_audio_sample_test.dart --dart-define=LOCAL_JULIA_AUDIO=true
```

This is a local evaluation fixture. The publicly downloadable podcast has no
verified redistribution grant. Do not commit/upload the fixture or include it in
a distributed build without appropriate permission. The lab's `assets/` folder
bundles local files while they exist, so remove the two local fixtures before any
distribution. Nothing was added to the production GETTOPIK application.
