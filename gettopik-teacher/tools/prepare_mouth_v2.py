"""Register v2 lips to the original Teacher; retain source artwork, no generation.

Run from any directory. Inputs are kept in staging; v1 is backed up separately.
Only mouth PNGs and an additive mouth-skin foundation are written.
"""
from pathlib import Path
import json
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
CHAR = ROOT/'gettopik-teacher/assets/ai_speaking/characters/teacher'
SRC = ROOT/'staging/gettopik_teacher_mouth_assets_v2/assets/ai_speaking/characters/teacher/mouth'
OUT = CHAR/'mouth'
QA = ROOT/'gettopik-teacher/validation/mouth-v2'
NAMES = ['rest','small','medium','wide','round','teeth','closed_press','smile']
# Visible vermilion + corner shadow, measured against the original lip region.
CENTER = (546, 675)
TARGETS = dict(rest=(172,64),small=(174,68),medium=(176,76),wide=(178,86),
               round=(144,76),teeth=(176,72),closed_press=(172,62),smile=(176,66))

def main_component(alpha, threshold=16):
    labels,_=ndimage.label(alpha>threshold,structure=np.ones((3,3)))
    sizes=np.bincount(labels.ravel());sizes[0]=0
    return labels==sizes.argmax()

def clean_source(name):
    rgba=np.array(Image.open(SRC/f'mouth_{name}.png').convert('RGBA'))
    alpha=rgba[:,:,3].astype(float)
    component=main_component(alpha)
    support=ndimage.binary_dilation(component,iterations=5)
    # Drop faint whole-canvas dust and disconnected specks. No black RGB matte
    # is introduced: use premultiplied filtering for every resampling operation.
    alpha=np.where(support,np.clip((alpha-6)*255/248,0,255),0)
    yy,xx=np.where(alpha>8)
    box=(int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1))
    x0,y0,x1,y1=box
    rgb=rgba[y0:y1,x0:x1,:3].astype(float)
    a=alpha[y0:y1,x0:x1]/255
    return rgb,a,box

def resize_rgba(rgb,alpha,size):
    # Premultiplication prevents dark transparent pixels bleeding into the edge.
    premult=rgb*alpha[:,:,None]
    a=np.array(Image.fromarray(alpha.astype('float32'),mode='F').resize(size,Image.Resampling.LANCZOS))
    a=np.clip(a,0,1)
    channels=[]
    for k in range(3):
        c=np.array(Image.fromarray(premult[:,:,k].astype('float32'),mode='F').resize(size,Image.Resampling.LANCZOS))
        channels.append(c/np.maximum(a,.00001))
    rgb=np.clip(np.stack(channels,axis=2),0,255)
    # A subpixel feather follows the actual lip silhouette, not a rectangular crop.
    a=np.array(Image.fromarray(np.uint8(a*255)).filter(ImageFilter.GaussianBlur(.45)))/255
    return np.uint8(np.dstack([rgb,a*255]).clip(0,255))

def make_foundation(original):
    # This mask encloses the entire old mouth and its corner shadows, so a
    # narrow round pose cannot reveal duplicate original lips underneath.
    mask=Image.new('L',original.size,0)
    d=ImageDraw.Draw(mask)
    d.polygon([(453,656),(476,640),(515,633),(547,636),(584,632),(619,640),
               (647,651),(646,679),(628,702),(601,720),(566,729),(518,729),
               (478,716),(453,690)],fill=255)
    mask=mask.filter(ImageFilter.GaussianBlur(2))
    hard=np.uint8(np.array(mask)>4)*255
    rgb=np.array(original)[:,:,:3]
    healed=cv2.inpaint(rgb,hard,9,cv2.INPAINT_TELEA)
    # Restore original philtrum/nose/skin, with an erased mouth core. The shared
    # foundation stays opaque throughout mouth-state transitions.
    outer=Image.new('L',original.size,0)
    ImageDraw.Draw(outer).rounded_rectangle((396,573,699,788),radius=48,fill=255)
    outer=outer.filter(ImageFilter.GaussianBlur(10))
    foundation=Image.fromarray(np.dstack([healed,np.array(outer)]).astype('uint8'),'RGBA')
    foundation.save(OUT/'mouth_foundation.png')
    foundation.crop((390,570,705,795)).resize((630,450)).save(QA/'foundation-inspection.png')
    return foundation

def main():
    QA.mkdir(exist_ok=True,parents=True)
    original=Image.open(CHAR/'teacher_original.png').convert('RGBA')
    base=Image.open(CHAR/'teacher_base.png').convert('RGBA')
    foundation=make_foundation(original)
    report={'originalReference':{'mouthBounds':[462,642,632,710],
      'lipColorComponentBounds':[471,645,638,716], 'center':list(CENTER),
      'note':'Corner bounds visually checked on original-mouth-grid.png; color component includes lower-lip shading.'},
      'foundation':'Original skin with the old mouth inpainted; original/base/head files remain unchanged.', 'poses':[]}
    sheet=Image.new('RGB',(1800,1080),'#e4e7e5');draw=ImageDraw.Draw(sheet)
    # Use a small shared lip-color correction, calibrated to the v2 rest and
    # original central vermilion, rather than changing color between poses.
    rest_rgb,rest_a,_=clean_source('rest')
    ref=np.array(original)[650:700,478:620,:3].astype(float)
    ref_mask=(ref[:,:,0]-ref[:,:,1]>45)&(ref[:,:,0]-ref[:,:,2]>35)
    src_mask=(rest_a>.9)&(rest_rgb[:,:,0]-rest_rgb[:,:,1]>40)&(rest_rgb[:,:,0]-rest_rgb[:,:,2]>30)
    shift=np.median(ref[ref_mask],axis=0)-np.median(rest_rgb[src_mask],axis=0)
    shift=np.clip(shift,-12,12)
    report['sharedLipRgbOffset']=shift.tolist()
    for i,name in enumerate(NAMES):
        rgb,alpha,box=clean_source(name)
        rgb=np.clip(rgb+shift,0,255)
        target=TARGETS[name]
        tight=Image.fromarray(resize_rgba(rgb,alpha,target),'RGBA')
        overlay=Image.new('RGBA',original.size)
        top=(CENTER[0]-target[0]//2,CENTER[1]-target[1]//2)
        overlay.paste(tight,top)
        if name=='wide':
            overlay.save(QA/'excluded-wide.png')
            (OUT/'mouth_wide.png').unlink(missing_ok=True)
        else:
            overlay.save(OUT/f'mouth_{name}.png')
        preview=base.copy();preview.alpha_composite(foundation);preview.alpha_composite(overlay)
        # Keep original eyes in this inspection image; production eyes/blink
        # continue to come from the existing Rive eye layers.
        close=original.copy();close.paste(preview.crop((390,570,705,795)),(390,570))
        close.crop((380,550,715,790)).resize((450,322)).convert('RGB').save(QA/f'preprocess-{name}.png')
        tile=close.crop((370,540,725,810)).resize((450,342)).convert('RGB')
        x=(i%4)*450;y=(i//4)*540;sheet.paste(tile,(x,y+35));draw.text((x+12,y+395),f'{name}: {target[0]} x {target[1]}  center {CENTER}',fill='black')
        report['poses'].append({'pose':name,'active':name!='wide','sourceComponentBounds':list(box),
          'sourceVisibleSize':[box[2]-box[0],box[3]-box[1]],'outputCanvas':list(overlay.size),
          'correctedBounds':list(overlay.getbbox()),'targetSize':list(target),'targetCenter':list(CENTER),
          'alphaPixelsOutsideTarget':0,'note':'Registered, premultiplied Lanczos resize, connected-component cleanup, subpixel contour feather.'})
    sheet.save(QA/'corrected-mouth-closeups.jpg')
    (QA/'preprocess-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
