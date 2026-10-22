"""Bake the RMS timeline into RML too, for hosts that scrub animations directly.

The Flutter demo uses the mouthIndex state machine, keeping idle motion separate.
"""
from pathlib import Path
import json
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[1]
data=json.loads((root/'audio/mouth_timeline.json').read_text(encoding='utf-8'))
tree=ET.parse(root/'scene.rml')
a=next(a for a in tree.getroot().findall('Artboard') if a.get('name')=='Teacher')
for old in list(a.findall('LinearAnimation')):
    if old.get('name')=='AudioMouth': a.remove(old)
anim=ET.SubElement(a,'LinearAnimation',name='AudioMouth',id='0:900000',fps='60',duration=str(len(data['frames'])-1),loopValue='oneShot')
changes=[(i,f['mouth']) for i,f in enumerate(data['frames']) if i==0 or f['mouth']!=data['frames'][i-1]['mouth']]
for j in range(8):
    if j in (0,3): continue  # Rest and Wide are excluded from the rig and export.
    obj=ET.SubElement(anim,'KeyedObject',objectId=f'0:{200+j}')
    prop=ET.SubElement(obj,'KeyedProperty',propertyKey='18')
    values={0:1 if j==data['frames'][0]['mouth'] else 0}
    for frame,state in changes[1:]:
        previous=data['frames'][frame-1]['mouth']
        values[max(0,frame-1)]=1 if j==previous else 0
        values[min(frame+2,len(data['frames'])-1)]=1 if j==state else 0
    for f,v in sorted(values.items()): ET.SubElement(prop,'KeyFrameDouble',frame=str(f),value=str(v),interpolationType='linear')
ET.indent(tree)
tree.write(root/'scene.rml',encoding='unicode')
print(f'Baked AudioMouth: {len(data["frames"])} frames, {len(changes)} pose changes')
