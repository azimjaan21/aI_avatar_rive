# Android demo evidence

- `emulator-report.json`: full debug probes and 31 Android PSS/CPU samples from
  the completed 300-second, fully live integration test. The final test result
  is embedded. Host-GPU emulator, headless, before screen mirroring began.
- `summary.json`: derived by `python tools/summarize-android.py`; CPU is weighted
  by sample interval, PSS uses KiB → MiB conversion. Frame p50/p95 use the final
  600-frame window, not a whole-session percentile.
- `speaker-output.json`: 14-second host WASAPI loopback during actual emulator
  playback; block energy only, no microphone recording.
- `gfxinfo.txt`: Android native container data. Only two frames were reported;
  these numbers do not describe Flutter/Rive rendering.
- `setup.json`: host, SDK, emulator, first-install startup and asset identity
  checks. Includes the windowed emulator graphics limitation.
- `final-apk.json`: delivered APK size/SHA-256 and three measured process-cold,
  cache-warm launches. SwiftShader with mirroring, a different graphics setup
  from the five-minute run.
- `validation.json`: check commands and functional validation scope.
- `windows-*.json`: Windows playback regression evidence, kept separately from
  Android metrics. That regression ran during initial SDK setup and observed one
  streaming underrun under host load; all functional assertions passed.

Full-screen view has its own Android functional integration test. The five-minute
performance results describe the standard Teacher studio, before the optional
call view was added. No physical-device or release/profile performance is claimed.
