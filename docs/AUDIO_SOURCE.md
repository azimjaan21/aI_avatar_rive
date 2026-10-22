# Korean solo narration

The bundled demo uses **one Korean female narrator**, replacing the earlier dialogue recording.

| Item | Value |
| --- | --- |
| Source | [Google FLEURS](https://huggingface.co/datasets/google/fleurs) |
| Recording | `ko_kr`, `test`, row 4, recording ID 1801 |
| Publisher speaker label | Female |
| Original filename | `10111865575098096607.wav` |
| Subject | Hong Kong's skyline reflected in Victoria Harbour |
| Duration | 12.12 seconds, including the source recording's pauses |
| Runtime format | 24 kHz, mono, signed PCM16 WAV |
| Runtime path | `player/assets/korean_demo.wav` |
| Display name | `korean_female_narration.wav` |
| License | [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/) |

Attribution: **FLEURS: Few-shot Learning Evaluation of Universal Representations of Speech, Google, 2022.** The source recording was resampled from 16 kHz to 24 kHz and converted to PCM16. No generated voice or speaker mixing was added. This attribution applies to the recording; it does not license the Teacher artwork or application branding.

[Exact source metadata](../gettopik-teacher/audio/audio_source.json) includes the original checksum and publisher transcript. The [transcript](../gettopik-teacher/audio/transcript.txt) is available for future forced alignment. A transcript by itself does not provide phoneme timestamps.

Runtime WAV SHA-256:

```text
f5197ae7223c755c7afbaeb455ff0cf8c913c71f69303411772fe517fb21ba00
```

## Reproduce the download and timeline

From the repository root, with the dependencies in `gettopik-teacher/tools/requirements.txt` installed:

```powershell
python gettopik-teacher/tools/prepare_fleurs_demo.py
python gettopik-teacher/tools/analyze_audio.py staging/audio-candidates/korean_female_narration.wav
python gettopik-teacher/tools/bake_timeline.py
rive gettopik-teacher --verify
rive inspect gettopik-teacher --summary
rive gettopik-teacher --once
Copy-Item gettopik-teacher/build/teacher.riv player/assets/teacher.riv -Force
Copy-Item gettopik-teacher/audio/korean_demo.wav player/assets/korean_demo.wav -Force
Copy-Item gettopik-teacher/audio/mouth_timeline.json player/assets/mouth_timeline.json -Force
```

The helper checks the publisher's language and gender metadata and saves attribution. It backs up the earlier audio and timeline under ignored `backups/previous-dialogue-audio/` before replacement. Network access is needed to fetch the source, but playback uses the bundled WAV offline.
