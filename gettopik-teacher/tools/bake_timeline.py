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
obj=ET.SubElement(anim,'KeyedObject',objectId='0:224')
prop=ET.SubElement(obj,'KeyedProperty',propertyKey='296')
for frame,state in changes:
    ET.SubElement(prop,'KeyFrameId',frame=str(frame),value=f'0:{200+state}',interpolationType='hold')
ET.indent(tree)
tree.write(root/'scene.rml',encoding='unicode')
print(f'Baked AudioMouth: {len(data["frames"])} frames, {len(changes)} pose changes')
