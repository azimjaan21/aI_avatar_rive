# Closed press replaces Rest

Rest is excluded from the mouth state machine, images, imported Rive assets,
manual pose controls and baked audio animation. Its source PNG remains on disk
for reference only. Default, detected silence, pause and audio completion use
Closed press (index 6). Legacy controller requests for index 0 also select 6.
Wide and Closed eyes remain disabled.

The RMS values, audio file, timing, smoothing, image alignment and existing
artwork are unchanged. Auto uses Closed press, Small and Medium. Manual choices
are Small, Medium, Round, Teeth, Closed press and Smile.

Validation:

- Official Rive CLI verify/build: zero errors and warnings; inspect: no problems.
- `rig-report.json`: compiled Rive excludes Rest, Wide and Closed eyes; all
  silence frames use 6; default render pixel-matches explicit Closed press.
- Local `default.png` and `closed-press.png`: actual Rive renders after 10 frames
  (generated captures are ignored by Git).
- Native Windows integration test: real audio playback and speaker loopback,
  silence, pause, seek, resume, completion, replay, six manual mouth poses,
  legacy Rest/Wide fallback, and independent eye controls passed.
- `playback-report.json` and `audio-output-report.json` record the updated player.
- [Ready screenshot](../../../docs/images/studio-ready.png),
  [speaking screenshot](../../../docs/images/studio-speaking.png) and
  [paused screenshot](../../../docs/images/studio-paused.png) are kept in Git.

This remains amplitude-driven mouth animation; phoneme alignment is unchanged.
