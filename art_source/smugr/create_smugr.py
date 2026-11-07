import bpy, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0,glow=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 m.node_tree.nodes.clear()
 p=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled');out=m.node_tree.nodes.new('ShaderNodeOutputMaterial');m.node_tree.links.new(p.outputs['BSDF'],out.inputs['Surface'])
 p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.4
 p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=glow
 return m
cloth=mat('Midnight velvet',(.045,.025,.09));purple=mat('Amethyst leather',(.24,.055,.36));gold=mat('Antique silver',(.48,.42,.58),.7);steel=mat('Moonsteel',(.4,.65,.72),.8);light=mat('Mirror energy',(.45,.08,1),.2,2);black=mat('Face shadow',(.008,.012,.025))
def joint(name,pos,parent=None):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=pos;o.parent=parent;return o
rig=joint('Smugr',(0,0,0));body=joint('Chest',(0,0,1.45),rig)
def mesh(name,pos,size,material,parent=rig,kind='box'):
 if kind=='orb': bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8)
 else: bpy.ops.mesh.primitive_cube_add()
 o=bpy.context.object;o.name=name;o.parent=parent;o.location=pos;o.scale=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
 if kind=='box':
  bevel=o.modifiers.new('Tailored edges','BEVEL');bevel.width=.045;bevel.segments=2
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=bevel.name)
 return o
mesh('Fitted coat',(0,0,.05),(.39,.23,.48),cloth,body)
mesh('Breastplate',(0,-.235,.1),(.29,.065,.32),purple,body)
mesh('Waist sash',(0,0,1.08),(.43,.26,.09),purple)
mesh('Buckle',(0,-.28,1.09),(.1,.04,.1),gold)
head=joint('Hood',(0,0,.67),body)
mesh('Hood shell',(0,.04,.1),(.36,.29,.43),cloth,head,'orb')
mesh('Shadow mask',(0,-.24,.08),(.255,.055,.25),black,head)
for side in [-1,1]:
 mesh('Eye slit',(side*.105,-.305,.15),(.065,.025,.025),light,head)
 mesh('Hood rim',(side*.28,-.14,.12),(.055,.12,.3),purple,head)
 mesh('Pauldrons',(side*.5,0,.39),(.22,.29,.12),gold,body)
arm=[];leg=[]
for side in [-1,1]:
 a=joint('Arm_L' if side<0 else 'Arm_R',(side*.52,0,.3),body);arm.append(a)
 mesh('Sleeve',(0,0,-.25),(.13,.14,.28),purple,a)
 mesh('Bracer',(0,-.015,-.57),(.15,.15,.17),gold,a)
 mesh('Glove',(0,0,-.79),(.12,.13,.12),cloth,a)
 mesh('Dagger grip',(0,-.05,-.9),(.045,.05,.16),black,a)
 mesh('Crossguard',(0,-.05,-1.02),(.2,.07,.04),gold,a)
 # Custom tapered, faceted blade rather than a rectangular placeholder.
 verts=[(-.11,-.05,-1.05),(.11,-.05,-1.05),(0,-.09,-1.05),(0,.0,-1.05),(0,-.05,-1.65)]
 faces=[(0,2,4),(2,1,4),(1,3,4),(3,0,4),(0,3,1,2)]
 me=bpy.data.meshes.new('Forged blade');me.from_pydata(verts,[],faces);o=bpy.data.objects.new('Moonsteel dagger',me);bpy.context.collection.objects.link(o);o.parent=a;me.materials.append(steel)
 l=joint('Leg_L' if side<0 else 'Leg_R',(side*.22,0,1.05),rig);leg.append(l)
 mesh('Trouser',(0,0,-.27),(.16,.17,.29),cloth,l)
 mesh('Knee armour',(0,-.16,-.49),(.17,.065,.14),gold,l)
 mesh('Boot',(0,-.06,-.79),(.18,.24,.24),purple,l)
cape=joint('Split cloak',(0,.25,.38),body)
for side in [-1,1]:
 o=mesh('Cloak tail',(side*.19,.04,-.55),(.18,.045,.62),purple,cape);o.rotation_euler[1]=side*.12
mesh('Mirror jewel',(0,-.32,.24),(.10,.055,.14),light,body,'orb')
# Object-joint animation: editable Blender actions, exported as shared NLA clips.
nodes=[rig,body,head,*arm,*leg,cape];base={o.name:tuple(o.location) for o in nodes}
for clip,frames in [('Idle',60),('Run',24),('Attack',14),('Cast',18),('Death',24),('Stun',40)]:
 for o in nodes:
  o.animation_data_create();o.animation_data.action=None;o.rotation_euler=(0,0,0);o.location=base[o.name]
 for f in range(1,frames+1):
  t=(f-1)/(frames-1);s=math.sin(t*math.tau)
  for o in nodes:o.rotation_euler=(0,0,0);o.location=base[o.name]
  if clip=='Run':
   for i in range(2):leg[i].rotation_euler.x=s*.65*(-1 if i else 1);arm[i].rotation_euler.x=-s*.55*(-1 if i else 1)
   body.location.z+=abs(s)*.065;body.rotation_euler.x=.15;cape.rotation_euler.x=-.25+s*.1
  elif clip=='Attack':
   swing=math.sin(t*math.pi);body.rotation_euler.z=swing*.65
   arm[1].rotation_euler.x=-swing*1.8;arm[1].rotation_euler.y=-swing*.8;arm[0].rotation_euler.x=-swing*.8
  elif clip=='Cast':
   for i,a in enumerate(arm):a.rotation_euler.y=math.sin(t*math.pi)*(-1 if i else 1)*1.4
   body.location.z+=math.sin(t*math.pi)*.12
  elif clip=='Death':rig.rotation_euler.x=-t*1.5;rig.location.z=t*.22
  elif clip=='Stun':head.rotation_euler.z=s*.16;body.rotation_euler.x=.12
  else:body.location.z+=s*.025;cape.rotation_euler.x=s*.06
  for o in nodes:
   o.keyframe_insert('location',frame=f);o.keyframe_insert('rotation_euler',frame=f)
 for o in nodes:
  action=o.animation_data.action;action.name=clip+'_'+o.name
  track=o.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,1,action);o.animation_data.action=None
for o in nodes:o.location=base[o.name];o.rotation_euler=(0,0,0)
bpy.context.scene.render.fps=30
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/smugr/Smugr.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/characters/smugr/smugr.glb'),export_format='GLB',export_animation_mode='NLA_TRACKS',export_force_sampling=True)
print('SMUGR_EXPORT_OK')
