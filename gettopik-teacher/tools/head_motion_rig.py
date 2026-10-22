"""Subtle neck-pivot motion and responsive Rive breathing, without scripts."""
import argparse
import math
from pathlib import Path
import xml.etree.ElementTree as ET

IDLE = [(0, 0), (167, .58), (347, -.8), (561, .24), (817, .7),
        (1019, -.42), (1211, .8), (1469, .12), (1643, -.67),
        (1889, .37), (2107, -.8), (2399, .51), (2581, -.28), (2820, 0)]
TALK = [(0, 0), (151, .82), (337, -1.2), (569, .46), (747, 1.2),
        (1013, -.63), (1229, .96), (1417, -.26), (1699, -1.05),
        (1913, .64), (2159, -.43), (2347, 1.12), (2603, .14),
        (2789, -.92), (3037, .71), (3299, -1.2), (3491, .39),
        (3733, -.54), (4020, 0)]
# Unequal inhale/exhale lengths; 31 s breathing, 47 s idle, 67 s talking.
BREATH = [(0, 0), (105, -1), (255, 1), (364, -.9), (523, 1),
          (649, -1), (821, .925), (934, -.95), (1113, 1),
          (1241, -1), (1393, .95), (1522, -.925), (1712, 1), (1860, 0)]


def keys(animation, object_id, property_key, samples):
    obj = ET.SubElement(animation, 'KeyedObject', objectId=object_id)
    prop = ET.SubElement(obj, 'KeyedProperty', propertyKey=str(property_key))
    for frame, value in samples:
        key = ET.SubElement(prop, 'KeyFrameDouble', frame=str(frame),
                            value=f'{value:.9f}', interpolationType='cubic')
        ET.SubElement(key, 'CubicEaseInterpolator', x1='.42', y1='0', x2='.58', y2='1')


def transition(state, destination, value):
    change = ET.SubElement(state, 'StateTransition', stateToId=destination,
                           duration='700', enableEarlyExit='true', interpolationType='cubic')
    ET.SubElement(change, 'CubicEaseInterpolator', x1='.42', y1='0', x2='.58', y2='1')
    condition = ET.SubElement(change, 'TransitionViewModelCondition', opValue='equal')
    comparator = ET.SubElement(condition, 'TransitionPropertyViewModelComparator')
    bindable = ET.SubElement(comparator, 'BindablePropertyNumber')
    ET.SubElement(bindable, 'DataBindContext', sourcePathIds='0:40-0:44', propertyKey='636')
    ET.SubElement(condition, 'TransitionValueNumberComparator', value=str(value))


def configure_motion(root, whole_avatar_fallback=True):
    teacher = next(a for a in root.findall('Artboard') if a.get('name') == 'Teacher')
    machine = teacher.find('StateMachine')
    breath = next(n for n in teacher.iter('Node') if n.get('id') == '0:20')
    sway = next((n for n in teacher.findall('Node') if n.get('id') == '0:22'), None)
    if sway is None:
        index = list(teacher).index(breath)
        teacher.remove(breath)
        sway = ET.Element('Node', name='AvatarNeckPivot', id='0:22', x='544', y='870')
        sway.append(breath)
        teacher.insert(index, sway)
    amplitude = next((n for n in sway.findall('Node') if n.get('id') == '0:23'), None)
    if amplitude is None:
        sway.remove(breath)
        amplitude = ET.SubElement(sway, 'Node', name='BreathAmplitude', id='0:23', scaleY='.5')
        ET.SubElement(amplitude, 'DataBindContext', sourcePathIds='0:40-0:45', propertyKey='17')
        offset = ET.SubElement(amplitude, 'Node', name='BreathOffset', id='0:24')
        compensation = ET.SubElement(offset, 'Node', name='BreathCompensation', id='0:25', scaleY='2')
        ET.SubElement(compensation, 'DataBindContext', sourcePathIds='0:40-0:45',
                      propertyKey='17', converterId='0:920100')
        compensation.append(breath)
    breath.set('x', '0')
    breath.set('y', '0')
    breath.set('scaleX', '1.003')
    breath.set('scaleY', '1.003')
    head = next(n for n in breath.findall('Node') if n.get('id') == '0:21')
    head.set('x', '0')
    head.set('y', '0')
    head.set('rotation', '0')
    sway.set('rotation', '0')
    body = next(n for n in breath.findall('Image') if n.get('id') == '0:221')
    body.set('x', '-544')
    body.set('y', '-870')

    for animation in list(teacher.findall('LinearAnimation')):
        if animation.get('name') == 'Idle' or animation.get('id') in {'0:920000','0:920001','0:920002'}:
            teacher.remove(animation)
    idle = ET.SubElement(teacher, 'LinearAnimation', name='Idle', id='0:6',
                         fps='60', duration='2820', loopValue='loop')
    talk = ET.SubElement(teacher, 'LinearAnimation', name='TalkingMotion', id='0:920000',
                         fps='60', duration='4020', loopValue='loop')
    target = '0:22' if whole_avatar_fallback else '0:21'
    # The supplied head artwork includes shoulders: default to a smaller shared
    # neck-pivot sway to preserve the overlap with the body exactly.
    idle_gain = .35/.8 if whole_avatar_fallback else 1
    talk_gain = .5/1.2 if whole_avatar_fallback else 1
    keys(idle, target, 15, [(f, math.radians(v*idle_gain)) for f,v in IDLE])
    keys(talk, target, 15, [(f, math.radians(v*talk_gain)) for f,v in TALK])
    layer = next(l for l in machine.findall('StateMachineLayer') if l.get('name') == 'Idle')
    state = next(s for s in layer.findall('AnimationState') if s.get('id') == '0:12')
    state.attrib.pop('reset', None)  # Resume long timelines on re-entry.
    for change in list(state.findall('StateTransition')):
        state.remove(change)
    for old in list(layer.findall('AnimationState')):
        if old.get('id') == '0:920012':
            layer.remove(old)
    talking = ET.SubElement(layer, 'AnimationState', id='0:920012',
                            animationId='0:920000', x='480', y='0')
    transition(state, '0:920012', 1)
    transition(talking, '0:12', 0)

    for old in list(machine.findall('StateMachineLayer')):
        if old.get('name') == 'Breathing':
            machine.remove(old)
    layer = ET.SubElement(machine, 'StateMachineLayer', name='Breathing', id='0:920010')
    ET.SubElement(layer, 'AnyState', x='0', y='-180')
    ET.SubElement(layer, 'ExitState', x='240', y='-180')
    entry = ET.SubElement(layer, 'EntryState', x='-200', y='0')
    ET.SubElement(entry, 'StateTransition', stateToId='0:920011')
    ET.SubElement(layer, 'AnimationState', id='0:920011', animationId='0:920001', x='120', y='0')
    animation = ET.SubElement(teacher, 'LinearAnimation', name='Breathing',
                              id='0:920001', fps='60', duration='1860', loopValue='loop')
    keys(animation, '0:24', 14, [(f,v*8) for f,v in BREATH])
    for prop in [16,17]:
        keys(animation, '0:20', prop, [(f,1.003-v*.001) for f,v in BREATH])

    vm = next(v for v in root.findall('ViewModel') if v.get('name') == 'AvatarController')
    instance = vm.find('ViewModelInstance')
    for name, prop_id, value in [('motionTalking','0:44','0'), ('breathAmplitude','0:45','.5')]:
        if not any(p.get('id') == prop_id for p in vm):
            ET.SubElement(vm, 'ViewModelPropertyNumber', name=name, id=prop_id)
        else:
            next(p for p in vm if p.get('id') == prop_id).set('name', name)
        if not any(p.get('viewModelPropertyId') == prop_id for p in instance):
            ET.SubElement(instance, 'ViewModelInstanceNumber', viewModelPropertyId=prop_id, propertyValue=value)
        else:
            next(p for p in instance if p.get('viewModelPropertyId') == prop_id).set('propertyValue', value)
    if not any(c.get('id') == '0:920100' for c in root):
        # Paired inverse scales change translation amplitude without stretching
        # artwork. The exponent -1 supplies the compensating child scale.
        ET.SubElement(root, 'DataConverterOperationValue', name='InverseBreathAmplitude',
                      id='0:920100', operationType='6', operationValue='-1')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--separate-head', action='store_true', help='Inspect full requested head range before choosing the seam fallback')
    args = parser.parse_args()
    scene = Path(__file__).resolve().parents[1]/'scene.rml'
    tree = ET.parse(scene)
    configure_motion(tree.getroot(), whole_avatar_fallback=not args.separate_head)
    ET.indent(tree)
    tree.write(scene, encoding='unicode')
    print('Neck motion configured:', 'separate head .8/1.2 degrees' if args.separate_head else 'whole-avatar seam fallback .35/.5 degrees')
