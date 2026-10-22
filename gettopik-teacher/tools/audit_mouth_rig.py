"""Inspect original PNGs and derive lossless tight runtime crops. No eye edits."""
from pathlib import Path
import json
import hashlib
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CHAR = ROOT / 'assets/ai_speaking/characters/teacher'
OUT = ROOT / 'validation/lipsync-quality'
NAMES = ['closed_press', 'small', 'medium', 'round', 'teeth', 'smile']


def audit():
    OUT.mkdir(parents=True, exist_ok=True)
    runtime = CHAR / 'mouth/runtime'
    runtime.mkdir(exist_ok=True)
    original = Image.open(CHAR / 'teacher_original.png').convert('RGBA')
    base = Image.open(CHAR / 'head.png').convert('RGBA')
    base.alpha_composite(Image.open(CHAR / 'mouth/mouth_foundation.png'))
    rows = []
    sources = {}
    for name in NAMES + ['foundation']:
        path = CHAR / f'mouth/mouth_{name}.png'
        img = Image.open(path).convert('RGBA')
        bounds = img.getchannel('A').getbbox()
        x0, y0, x1, y1 = bounds
        box = [max(0, x0-2), max(0, y0-2), min(img.width, x1+2), min(img.height, y1+2)]
        crop = img.crop(box)
        crop.save(runtime / f'mouth_{name}.png')
        restored = Image.new('RGBA', img.size)
        restored.paste(crop, box[:2])
        # RGB under zero alpha is immaterial. Premultiplied compositing must match.
        test = Image.new('RGBA', img.size, (37, 52, 43, 255))
        exact = Image.alpha_composite(test, restored).tobytes() == Image.alpha_composite(test, img).tobytes()
        assert exact
        rows.append(dict(name=name, box=box, alphaBounds=bounds,
                         center=[(x0+x1)/2, (y0+y1)/2],
                         sourceSha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                         sourceRgbaBytes=img.width*img.height*4,
                         runtimeRgbaBytes=crop.width*crop.height*4,
                         compositingIdentical=exact))
        sources[name] = img
    # Show the actual ~80 px mouth at 0.45 avatar scale as well as a close-up.
    sheet = Image.new('RGB', (1680, 960), '#101916')
    draw = ImageDraw.Draw(sheet)
    items = [('original', original)]
    for name in NAMES:
        face = base.copy()
        face.alpha_composite(sources[name])
        items.append((name, face))
    for i, (name, face) in enumerate(items):
        x = (i % 4)*420; y = (i//4)*480
        draw.text((x+12, y+8), name, fill='white')
        sheet.paste(face.crop((365, 505, 730, 855)).resize((365, 350)).convert('RGB'), (x+20, y+30))
        scaled = face.resize((489, 652), Image.Resampling.LANCZOS)
        sheet.paste(scaled.crop((180, 270, 315, 350)).convert('RGB'), (x+130, y+395))
    sheet.save(OUT/'mouth-audit.png')
    blend = Image.new('RGB', (1500, 660), '#101916')
    draw = ImageDraw.Draw(blend)
    for r, (a, b) in enumerate([('closed_press', 'medium'), ('small', 'round')]):
        for c, t in enumerate([0, .25, .5, .75, 1]):
            # Rive crossfades opacity tracks, then draws PNGs over the foundation.
            face = base.copy()
            order = list(reversed(NAMES))  # Rive's reverse sibling draw order.
            for n in order:
                if n not in [a,b]: continue
                image = sources[n].copy()
                alpha = 1-t if n == a else t
                image.putalpha(image.getchannel('A').point(lambda v: round(v*alpha)))
                face.alpha_composite(image)
            blend.paste(face.crop((395, 580, 695, 850)).convert('RGB'), (c*300,r*330+35))
            draw.text((c*300+8,r*330+8), f'{a} -> {b}: {t:.2f}', fill='white')
    blend.save(OUT/'baseline-crossfades.png')
    report = dict(poses=rows, fullCanvasRgbaBytes=sum(r['sourceRgbaBytes'] for r in rows),
                  croppedRgbaBytes=sum(r['runtimeRgbaBytes'] for r in rows),
                  note='RGBA byte estimates describe decoded mouth textures only, not total process/GPU memory.')
    (runtime/'manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    (OUT/'asset-audit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='poses'}))


if __name__ == '__main__':
    audit()
