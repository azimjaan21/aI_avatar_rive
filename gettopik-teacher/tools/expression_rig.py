"""Expression offsets on the shared avatar assembly; original eyes unchanged."""
from pathlib import Path
import xml.etree.ElementTree as ET


def configure_expressions(root):
    teacher=next(a for a in root.findall('Artboard') if a.get('name')=='Teacher')
    sway=next(n for n in teacher.iter('Node') if n.get('id')=='0:22')
    if not any(n.get('id')=='0:26' for n in sway.findall('Node')):
        amplitude=next(n for n in sway.findall('Node') if n.get('id')=='0:23')
        sway.remove(amplitude)
        expression=ET.SubElement(sway,'Node',name='ExpressionMotion',id='0:26')
        ET.SubElement(expression,'DataBindContext',sourcePathIds='0:40-0:46',propertyKey='15')
        ET.SubElement(expression,'DataBindContext',sourcePathIds='0:40-0:47',propertyKey='14')
        expression.append(amplitude)
    vm=next(v for v in root.findall('ViewModel') if v.get('name')=='AvatarController')
    instance=vm.find('ViewModelInstance')
    for name,prop_id in [('emotionTilt','0:46'),('emotionBob','0:47')]:
        if not any(p.get('id')==prop_id for p in vm):
            ET.SubElement(vm,'ViewModelPropertyNumber',name=name,id=prop_id)
        if not any(p.get('viewModelPropertyId')==prop_id for p in instance):
            ET.SubElement(instance,'ViewModelInstanceNumber',viewModelPropertyId=prop_id,propertyValue='0')


if __name__=='__main__':
    scene=Path(__file__).resolve().parents[1]/'scene.rml'
    tree=ET.parse(scene)
    configure_expressions(tree.getroot())
    ET.indent(tree)
    tree.write(scene,encoding='unicode')
    print('Expression motion added; eye PNGs and blink tracks unchanged.')
