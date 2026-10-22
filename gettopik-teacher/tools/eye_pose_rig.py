"""Auto/Open/Half controls; Closed is temporarily excluded, PNG retained."""
from pathlib import Path
import xml.etree.ElementTree as ET

def disable_closed_eyes(root):
    changed=False
    for parent in root.iter():
        for child in list(parent):
            remove=(child.tag=='Image' and child.get('id')=='0:212') or \
                (child.tag=='ImageAsset' and child.get('id')=='0:112') or \
                (child.tag=='AnimationState' and child.get('id')=='0:910013') or \
                (child.tag=='LinearAnimation' and child.get('id')=='0:910003') or \
                (child.tag=='StateTransition' and child.get('stateToId')=='0:910013') or \
                (child.tag=='KeyedObject' and child.get('objectId')=='0:212')
            if remove:
                parent.remove(child);changed=True
    teacher=next(a for a in root.findall('Artboard') if a.get('name')=='Teacher')
    auto=next(a for a in teacher.findall('LinearAnimation') if a.get('name')=='EyeAuto')
    opened=next(k for k in auto.findall('KeyedObject') if k.get('objectId')=='0:210')
    half=next(k for k in auto.findall('KeyedObject') if k.get('objectId')=='0:211')
    open_values={k.get('frame','0'):float(k.get('value')) for k in opened.iter('KeyFrameDouble')}
    for k in half.iter('KeyFrameDouble'):
        value=format(1-open_values[k.get('frame','0')],'g')
        if k.get('value')!=value:k.set('value',value);changed=True
    return changed

def configure_eyes(root):
    teacher=next(a for a in root.findall('Artboard') if a.get('name')=='Teacher')
    vm=next(v for v in root.findall('ViewModel') if v.get('name')=='AvatarController')
    if any(p.get('name')=='eyePose' for p in vm):
        return disable_closed_eyes(root)
    sm=next(s for s in teacher.findall('StateMachine') if s.get('name')=='TeacherController')
    idle=next(a for a in teacher.findall('LinearAnimation') if a.get('name')=='Idle')
    eye_tracks=[k for k in idle.findall('KeyedObject') if k.get('objectId') in ['0:210','0:211']]
    if len(eye_tracks)!=2:
        raise ValueError('Expected Open and Half blink tracks')
    # Move, rather than duplicate, the old blink keys. Head/breathing stay in Idle.
    auto=ET.SubElement(teacher,'LinearAnimation',name='EyeAuto',id='0:910000',
        duration=idle.get('duration','1200'),fps=idle.get('fps','60'),loopValue='loop')
    for track in eye_tracks:
        idle.remove(track);auto.append(track)
    for pose,name in enumerate(['Open','Half']):
        anim=ET.SubElement(teacher,'LinearAnimation',name=f'Eye{name}',
            id=f'0:{910001+pose}',duration='60',loopValue='loop')
        for i in range(2):
            ko=ET.SubElement(anim,'KeyedObject',objectId=f'0:{210+i}')
            kp=ET.SubElement(ko,'KeyedProperty',propertyKey='18')
            ET.SubElement(kp,'KeyFrameDouble',frame='0',value='1' if i==pose else '0')
    ET.SubElement(vm,'ViewModelPropertyNumber',name='eyePose',id='0:43')
    instance=next(i for i in vm.findall('ViewModelInstance') if i.get('id')=='0:41')
    ET.SubElement(instance,'ViewModelInstanceNumber',viewModelPropertyId='0:43',propertyValue='-1')
    layer=ET.SubElement(sm,'StateMachineLayer',name='Eyes',id='0:910004')
    ET.SubElement(layer,'AnyState',x='400',y='-180')
    ET.SubElement(layer,'ExitState',x='600',y='-180')
    entry=ET.SubElement(layer,'EntryState',x='-200',y='0')
    ET.SubElement(entry,'StateTransition',stateToId='0:910010')
    for state_index,pose in enumerate([-1,0,1]):
        state=ET.SubElement(layer,'AnimationState',animationId=f'0:{910000+state_index}',
            id=f'0:{910010+state_index}',x=str((state_index%2)*320),
            y=str((state_index//2)*260),reset='true')
        for dest_index,dest_pose in enumerate([-1,0,1]):
            if dest_index==state_index:continue
            # Instant selection exposes one exact PNG; no blended inspection pose.
            t=ET.SubElement(state,'StateTransition',stateToId=f'0:{910010+dest_index}',duration='0')
            condition=ET.SubElement(t,'TransitionViewModelCondition',opValue='equal')
            comparator=ET.SubElement(condition,'TransitionPropertyViewModelComparator')
            bindable=ET.SubElement(comparator,'BindablePropertyNumber')
            ET.SubElement(bindable,'DataBindContext',sourcePathIds='0:40-0:43',propertyKey='636')
            ET.SubElement(condition,'TransitionValueNumberComparator',value=str(dest_pose))
    disable_closed_eyes(root)
    return True

if __name__=='__main__':
    scene=Path(__file__).resolve().parents[1]/'scene.rml'
    tree=ET.parse(scene)
    changed=configure_eyes(tree.getroot())
    if changed:
        ET.indent(tree);tree.write(scene,encoding='unicode')
    print('Eye pose controls added' if changed else 'Eye pose controls already present')
