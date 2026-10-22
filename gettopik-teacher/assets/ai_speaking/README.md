# Teacher artwork

Source PNG layers and metadata for the GETTOPIK Teacher avatar. The original portrait is the identity reference; the Rive scene combines registered head, body, eye and corrected v2 mouth images.

## Canvas and placement

- Teacher layers use a **1086 × 1448 px** canvas with transparent backgrounds.
- Corrected mouth overlays share center **(546, 675)**. The manifest's older upper-lip anchor **(546, 645)** is a baseline reference, not the mouth center.
- Head, eyes and mouth share the same transform and neck pivot **(544, 870)**.
- The classroom image is **1080 × 1920 px** and is drawn behind the transparent Teacher.

Keep the original overlay coordinates. Avoid trimming or stretching facial features independently.

## Active artwork

| Layer | Files |
| --- | --- |
| Body / head | `characters/teacher/body.png`, `characters/teacher/head.png` |
| Eyes | `eyes_open.png`, `eyes_half.png` in `characters/teacher/eyes/` |
| Shared mouth foundation | `characters/teacher/mouth/mouth_foundation.png` |
| Mouth poses | `mouth_closed_press.png`, `mouth_small.png`, `mouth_medium.png`, `mouth_round.png`, `mouth_teeth.png`, `mouth_smile.png` |
| Background | `backgrounds/classroom_bg.png` |

Render the shared foundation above the head and below the selected mouth to cover the original lips. Keep it visible during transitions. Never put `teacher_original.png` underneath animated face overlays: it already contains the original eyes and lips.

**Closed press** is used by default and during silence, pause and completion. **Rest, Wide and Closed eyes are excluded from the rig and compiled runtime asset.** An unused Rest source PNG is retained for reference. Eye Auto uses Open → Half → Open partial blinking.

## Updating assets

Compare visible-content bounds, alpha edges, lip color and alignment against `teacher_original.png` and `teacher_base.png` before rebuilding. Corrected v2 files already retain full-canvas coordinates. The original portrait, base, head and body were preserved during mouth integration.

See the [asset guide](../../../docs/ASSETS.md) for state indices and compositing, and the [development guide](../../../docs/DEVELOPMENT.md#rebuild-the-avatar) for rebuilding embedded images.

Fine lip contours and the skin foundation can look less natural at close magnification. These assets support restrained 2D motion; they do not provide a 3D head turn or phoneme-aligned visemes.
