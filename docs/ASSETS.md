# Avatar asset guide

## Source layout

All character artwork lives in `gettopik-teacher/assets/ai_speaking/`:

```text
ai_speaking/
├── backgrounds/classroom_bg.png
├── character_manifest.json
└── characters/teacher/
    ├── teacher_original.png
    ├── teacher_base.png
    ├── head.png
    ├── body.png
    ├── eyes/
    │   ├── eyes_open.png
    │   └── eyes_half.png
    └── mouth/
        ├── mouth_foundation.png
        ├── mouth_closed_press.png
        ├── mouth_small.png
        ├── mouth_medium.png
        ├── mouth_round.png
        ├── mouth_teeth.png
        └── mouth_smile.png
```

The unused `mouth_rest.png` source remains on disk as a reference. Neither it nor Wide is imported into the compiled avatar. Closed eyes are also excluded; an old Closed source file may be present in a local asset pack, but is not needed by the project.

## Alignment and compositing

| Property | Value |
| --- | --- |
| Teacher canvas | 1086 × 1448 px |
| Corrected mouth center | (546, 675) |
| Head pivot | (544, 870) |
| Original classroom image | 1080 × 1920 px |

Use full-canvas transparent overlays at their existing coordinates. Do not independently stretch, trim or recenter facial features. Head, eye and mouth layers share one head transform.

The visible order from back to front is: classroom → body → head → eyes / shared mouth foundation → active mouth. The foundation stays visible below every mouth pose to cover the original lips and avoid duplicate details during transitions.

`teacher_original.png` is the identity reference. Do not use the unmodified portrait underneath animated facial overlays, because it contains the original eyes and lips. The compiled head/body layers and shared foundation provide the animated composition.

## Mouth state contract

Indices are stable for compatibility with existing timelines and controller calls.

| Index | Pose | Status / behavior |
| --- | --- | --- |
| 0 | Rest | Disabled; controller requests fall back to Closed press |
| 1 | Small | Auto: lower energy; manual preview |
| 2 | Medium | Auto: medium and high energy; manual preview |
| 3 | Wide | Disabled; controller requests fall back to Medium |
| 4 | Round | Manual preview |
| 5 | Teeth | Manual preview |
| 6 | Closed press | Default, silence, pause, completion and manual preview |
| 7 | Smile | Manual preview |

Rive view model: `AvatarController`. Number property: `mouthIndex`. State machine: `TeacherController`. Disabled names remain as legacy slots in timeline metadata; their images, states and pose buttons are excluded.

## Eye state contract

| `eyePose` | Mode |
| --- | --- |
| -1 | Auto: Open → Half → Open partial blinking |
| 0 | Hold `eyes_open.png` |
| 1 | Hold `eyes_half.png` |
| 2 | Disabled Closed request; controller falls back to Half |

Eye selection is independent of mouth control and audio playback. Closed is absent from the compiled Rive asset and UI.

## Updating artwork

1. Back up the source image locally.
2. Inspect alpha, visible bounds, size and alignment against the original face.
3. Preserve the full canvas, mouth center and natural facial proportions.
4. Rebuild and copy the Rive asset using the [development guide](DEVELOPMENT.md#rebuild-the-avatar).
5. Inspect each affected pose in the player, then test Auto with real audio.

`tools/build_scene.py` recreates the rig and overwrites `scene.rml`; it is not needed for ordinary asset replacement. `tools/prepare_mouth_v2.py` is the historical normalization helper: it requires the original v2 ZIP extracted under the ignored `staging/gettopik_teacher_mouth_assets_v2/` path. Its output is already included; do not rerun it merely to start the demo. Additional preprocessing dependencies are in `requirements-mouth-v2.txt`.
