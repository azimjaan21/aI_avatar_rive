# Teacher Rive Project

Editable RML source and original PNG layers for the GETTOPIK Teacher avatar. The project uses the official **Rive CLI 1.7.0**; no Editor or custom Rive scripts are required.

## Build

From the repository root, with the CLI installed:

```powershell
rive gettopik-teacher --verify
rive inspect gettopik-teacher --summary
rive gettopik-teacher --once
Copy-Item gettopik-teacher/build/teacher.riv player/assets/teacher.riv -Force
```

`build/teacher.riv` is generated and ignored. `player/assets/teacher.riv` is the versioned runtime copy used by Flutter.

## Live preview

```powershell
rive gettopik-teacher --artboard=Classroom --viewport=620x826 --fit=contain
```

The CLI opens a native preview and watches source changes. Use the Flutter player for synchronized audio playback. Consult this installation's `rive docs` and `rive schema` when changing RML types or properties; see [AGENTS.md](AGENTS.md) and the [official CLI documentation](https://rive.app/docs/cli).

## Project contents

| Path | Purpose |
| --- | --- |
| `scene.rml` | Teacher and Classroom artboards, view models and animation layers |
| `rive.yaml` | Project configuration; Teacher is the default artboard |
| `assets/ai_speaking/` | Registered Teacher images, classroom and manifest |
| `audio/` | Local lesson, measured RMS timeline and analysis metadata |
| `tools/` | Audio analysis, timeline baking, rig generation and capture helpers |
| `validation/closed-press-default/` | Current playback and rig evidence |

Closed press is the default and silence pose. Rest, Wide and Closed eyes are excluded from the active rig. All facial layers retain their original canvas coordinates.

See [asset conventions](../docs/ASSETS.md), [authoring workflow](../docs/DEVELOPMENT.md) and [validation](../docs/VALIDATION.md).
