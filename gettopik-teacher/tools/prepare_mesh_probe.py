"""Isolated fixed-boundary mouth mesh experiment; never edits the shipped rig."""
import base64
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT.parent/'staging/lipsync-quality/mesh-probe'


def prepare(amount=1.5):
    out=OUT/str(amount)
    out.mkdir(parents=True,exist_ok=True)
    tree=ET.parse(ROOT/'scene.rml')
    root=tree.getroot()
    for asset in root.findall('ImageAsset'):
        asset.set('file',(ROOT/asset.get('file')).resolve().as_posix())
    image=next(e for e in root.iter('Image') if e.get('id')=='0:202')
    poses=json.loads((ROOT/'assets/ai_speaking/characters/teacher/mouth/runtime/manifest.json').read_text(encoding='utf-8'))['poses']
    x0,y0,x1,y1=next(p['box'] for p in poses if p['name']=='medium')
    w,h=x1-x0,y1-y0
    image.set('x',str(float(image.get('x'))+w/2));image.set('y',str(float(image.get('y'))+h/2))
    image.set('originX','.5');image.set('originY','.5')
    triangles=[(0,1,8),(1,2,8),(2,3,8),(3,9,8),(3,4,9),(4,5,9),(5,6,9),(6,7,9),(7,8,9),(7,0,8)]
    mesh=ET.SubElement(image,'Mesh',name='Fixed boundary lip test',triangleIndexBytes=base64.b64encode(bytes(i for t in triangles for i in t)).decode(),id='0:950000')
    uv=[(0,0),(.5,0),(1,0),(1,.5),(1,1),(.5,1),(0,1),(0,.5),(.5,.3),(.5,.7)]
    for i,(u,v) in enumerate(uv):
        offset=amount if i==8 else -amount if i==9 else 0
        ET.SubElement(mesh,'ContourMeshVertex' if i<8 else 'MeshVertex',
                      x=str((u-.5)*w),y=str((v-.5)*h+offset),u=str(u),v=str(v),id=f'0:{950001+i}')
    ET.indent(tree);tree.write(out/'scene.rml',encoding='unicode')
    (out/'rive.yaml').write_text('name: teacher_mesh_probe\nmain: Teacher\n',encoding='utf-8')
    print(out)


if __name__=='__main__':
    for amount in [0.0,1.5,4.5]:prepare(amount)
