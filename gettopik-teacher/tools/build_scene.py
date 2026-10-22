"""Author the transparent Teacher artboard using original, registered PNGs."""
from pathlib import Path
import xml.etree.ElementTree as ET
import math
import json
from eye_pose_rig import configure_eyes
from head_motion_rig import configure_motion
from expression_rig import configure_expressions

ROOT = Path(__file__).resolve().parents[1]
MOUTHS = ['rest', 'small', 'medium', 'wide', 'round', 'teeth', 'closed_press', 'smile']

def build():
    crops = {p['name']: p['box'] for p in json.loads((ROOT/'assets/ai_speaking/characters/teacher/mouth/runtime/manifest.json').read_text(encoding='utf-8'))['poses']}
    r = ET.Element('Rive', version='1', kind='fragment')
    a = ET.SubElement(r, 'Artboard', width='1086', height='1448', name='Teacher', id='0:2', defaultStateMachineId='0:7', styleId='0:5', viewModelId='0:40', viewModelInstanceId='0:41', isComponent='true')
    ET.SubElement(a, 'LayoutComponentStyle', name='Teacher Style', id='0:5')
    sm = ET.SubElement(a, 'StateMachine', name='TeacherController', id='0:7')
    layer = ET.SubElement(sm, 'StateMachineLayer', name='Idle')
    ET.SubElement(layer, 'AnyState', x='180', y='-140')
    ET.SubElement(layer, 'ExitState', x='380', y='-140')
    entry = ET.SubElement(layer, 'EntryState', x='0', y='0')
    ET.SubElement(entry, 'StateTransition', stateToId='0:12')
    ET.SubElement(layer, 'AnimationState', animationId='0:6', id='0:12', x='200', y='0')
    mouths = ET.SubElement(sm, 'StateMachineLayer', name='Mouth')
    ET.SubElement(mouths, 'AnyState', x='0', y='-350')
    ET.SubElement(mouths, 'ExitState', x='200', y='-350')
    entry = ET.SubElement(mouths, 'EntryState', x='-400', y='0')
    ET.SubElement(entry, 'StateTransition', stateToId='0:306')
    for i in range(8):
        if i in (0,3): continue
        state = ET.SubElement(mouths, 'AnimationState', animationId=f'0:{400+i}', id=f'0:{300+i}', x=str(round(300*math.cos(i*math.pi/4))), y=str(round(300*math.sin(i*math.pi/4))), reset='true')
        for j in range(8):
            if i == j or j in (0,3): continue
            t = ET.SubElement(state, 'StateTransition', stateToId=f'0:{300+j}', duration='0', enableEarlyExit='true')
            c = ET.SubElement(t, 'TransitionViewModelCondition', opValue='equal')
            prop = ET.SubElement(c, 'TransitionPropertyViewModelComparator')
            b = ET.SubElement(prop, 'BindablePropertyNumber')
            ET.SubElement(b, 'DataBindContext', sourcePathIds='0:40-0:42', propertyKey='636')
            ET.SubElement(c, 'TransitionValueNumberComparator', value=str(j))
    rig = ET.SubElement(a, 'Node', name='BreathRoot', id='0:20', x='543', y='1448')
    head = ET.SubElement(rig, 'Node', name='HeadPivot', id='0:21', x='1', y='-578')
    def image(parent, name, aid, iid, x, y, opacity=None):
        attrs = dict(name=name, assetId=f'0:{aid}', id=f'0:{iid}', x=str(x), y=str(y), originX='0', originY='0')
        if opacity is not None: attrs['opacity'] = str(opacity)
        return ET.SubElement(parent, 'Image', **attrs)
    # One fully opaque pose at a time: opacity blending of photographic lips
    # exposes the skin patch and draws two incompatible contours simultaneously.
    solo = ET.SubElement(head, 'Solo', name='MouthPoses', id='0:224', activeComponentId='0:206')
    for i, name in enumerate(MOUTHS):
        if i not in (0,3):
            x0,y0,_,_ = crops[name]
            image(solo, f'Mouth_{name}', 100+i, 200+i, x0-544, y0-870)
    x0,y0,_,_ = crops['foundation']
    image(head, 'MouthFoundation', 123, 222, x0-544, y0-870)
    for i, name in enumerate(['open','half']): image(head, f'Eyes_{name}', 110+i, 210+i, -544, -870, 1 if i == 0 else 0)
    image(head, 'Head', 120, 220, -544, -870)
    image(rig, 'Body', 121, 221, -543, -1448)
    idle = ET.SubElement(a, 'LinearAnimation', name='Idle', id='0:6', duration='1200', loopValue='loop')
    def keys(anim, obj, key, samples, smooth=False):
        ko = ET.SubElement(anim, 'KeyedObject', objectId=f'0:{obj}')
        kp = ET.SubElement(ko, 'KeyedProperty', propertyKey=str(key))
        for frame, value in samples:
            k = ET.SubElement(kp, 'KeyFrameDouble', frame=str(frame), value=str(value), interpolationType='cubic' if smooth else 'linear')
            if smooth: ET.SubElement(k, 'CubicEaseInterpolator', x1='0.42', y1='0', x2='0.58', y2='1')
    keys(idle, 21, 15, [(0,0),(175,.01745),(390,-.01396),(610,.01047),(850,-.01745),(1060,.00873),(1200,0)], True)
    # Uniform breathing scale preserves proportions, feet/torso pivot stays fixed.
    for key in [16,17]: keys(idle,20,key,[(f,1.0025 if f%240==120 else 1) for f in range(0,1201,120)],True)
    blink=[(0,[1,0,0])]
    for start in [183,431,588,840,1103]:
        for offset,weights in [(0,[1,0,0]),(2,[0,1,0]),(4,[0,0,1]),(6,[0,1,0]),(9,[1,0,0])]: blink.append((start+offset,weights))
    blink.append((1200,[1,0,0]))
    for i in range(2): keys(idle,210+i,18,[(f,w[i]) for f,w in blink])
    for i,name in enumerate(MOUTHS):
        if i in (0,3): continue
        anim=ET.SubElement(a,'LinearAnimation',name=f'Mouth_{name}',id=f'0:{400+i}',duration='60',loopValue='loop')
        obj = ET.SubElement(anim,'KeyedObject',objectId='0:224')
        prop = ET.SubElement(obj,'KeyedProperty',propertyKey='296')
        ET.SubElement(prop,'KeyFrameId',frame='0',value=f'0:{200+i}',interpolationType='hold')
    vm=ET.SubElement(r,'ViewModel',name='AvatarController',id='0:40',defaultInstanceId='0:41')
    ET.SubElement(vm,'ViewModelPropertyNumber',name='mouthIndex',id='0:42')
    instance=ET.SubElement(vm,'ViewModelInstance',name='Default',id='0:41',exports='true')
    ET.SubElement(instance,'ViewModelInstanceNumber',viewModelPropertyId='0:42',propertyValue='6')
    # Classroom is a separate composition; Teacher itself has no background fill.
    classroom=ET.SubElement(r,'Artboard',width='1086',height='1448',x='1250',name='Classroom',id='0:500',defaultStateMachineId='0:501',styleId='0:502')
    ET.SubElement(classroom,'LayoutComponentStyle',name='Classroom Style',id='0:502')
    csm=ET.SubElement(classroom,'StateMachine',name='Preview',id='0:501')
    cl=ET.SubElement(csm,'StateMachineLayer',name='Preview')
    ET.SubElement(cl,'AnyState',x='180',y='-140'); ET.SubElement(cl,'ExitState',x='380',y='-140')
    ce=ET.SubElement(cl,'EntryState',x='0',y='0'); ET.SubElement(ce,'StateTransition',stateToId='0:503')
    ET.SubElement(cl,'AnimationState',animationId='0:504',id='0:503',x='200',y='0')
    ET.SubElement(classroom,'LinearAnimation',name='Preview',id='0:504',duration='60',loopValue='loop')
    nested=ET.SubElement(classroom,'NestedArtboard',artboardId='0:2',name='Teacher',isStateful='true')
    ET.SubElement(nested,'NestedStateMachine',animationId='0:7',name='TeacherController')
    ET.SubElement(classroom,'Image',assetId='0:122',name='Classroom Background',x='543',y='724',scaleX=str(1086/1080),scaleY=str(1086/1080))
    ET.SubElement(r,'ComponentAsset',artboardId='0:2',name='Teacher')
    ET.SubElement(r,'ImageAsset',file='assets/ai_speaking/backgrounds/classroom_bg.png',name='classroom',id='0:122')
    base = 'assets/ai_speaking/characters/teacher/'
    for i, name in enumerate(MOUTHS):
        if i not in (0,3): ET.SubElement(r, 'ImageAsset', file=f'{base}mouth/runtime/mouth_{name}.png', name=f'mouth_{name}', id=f'0:{100+i}')
    ET.SubElement(r, 'ImageAsset', file=f'{base}mouth/runtime/mouth_foundation.png', name='mouth_foundation', id='0:123')
    for i, name in enumerate(['open','half']): ET.SubElement(r, 'ImageAsset', file=f'{base}eyes/eyes_{name}.png', name=f'eyes_{name}', id=f'0:{110+i}')
    for i, name in enumerate(['head','body']): ET.SubElement(r, 'ImageAsset', file=f'{base}{name}.png', name=name, id=f'0:{120+i}')
    configure_eyes(r)
    configure_motion(r)
    configure_expressions(r)
    ET.indent(r)
    ET.ElementTree(r).write(ROOT/'scene.rml', encoding='unicode')

if __name__ == '__main__': build()
