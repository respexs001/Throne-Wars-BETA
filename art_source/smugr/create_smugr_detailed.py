"""Original stylized assassin: sculpted ring meshes and articulated animation."""
import bpy, math
from pathlib import Path
exec((Path(__file__).parent/'create_smugr.py').read_text().split('rig=joint')[0])
next(n for n in cloth.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Roughness'].default_value=.85
next(n for n in purple.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Roughness'].default_value=.72
rig=joint('Smugr',(0,0,0));body=joint('Chest',(0,0,1.48),rig)
def surface(name,verts,faces,material,parent):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);ob.parent=parent;me.materials.append(material)
 for p in me.polygons:p.use_smooth=True
 return ob
def form(name,rings,material,parent,n=20):
 vs=[]
 for z,rx,ry,cy in rings:
  vs.extend([(rx*math.cos(i*math.tau/n),cy+ry*math.sin(i*math.tau/n),z) for i in range(n)])
 fs=[tuple(reversed(range(n)))]
 for j in range(len(rings)-1):
  for i in range(n):a=j*n+i;b=j*n+(i+1)%n;fs.append((a,b,b+n,a+n))
 fs.append(tuple(range((len(rings)-1)*n,len(rings)*n)))
 return surface(name,vs,fs,material,parent)
def ell(name,pos,size,material,parent):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12)
 o=bpy.context.object;o.name=name;o.parent=parent;o.location=pos;o.scale=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
 for p in o.data.polygons:p.use_smooth=True
 return o
def line(name,pts,r,material,parent):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=r;cu.bevel_resolution=2
 sp=cu.splines.new('POLY');sp.points.add(len(pts)-1)
 for p,co in zip(sp.points,pts):p.co=(*co,1)
 o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o);o.parent=parent;cu.materials.append(material)
 # glTF exports mesh geometry, convert decorative piping explicitly.
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False)
 return o
form('Anatomical leather cuirass',[(-.42,.24,.17,0),(-.25,.27,.18,0),(.04,.36,.21,0),(.28,.43,.20,.015),(.4,.31,.16,.01)],cloth,body)
form('Layered amethyst chest',[(-.22,.25,.19,-.025),(.02,.35,.225,-.015),(.22,.37,.22,-.01),(.3,.29,.18,-.01)],purple,body)
for z in [-.18,-.08,.02]:
 line('Silver cuirass seams',[(-.29,-.16,z+.04),(0,-.245,z-.04),(.29,-.16,z+.04)],.012,gold,body)
form('Belt',[(1.04,.275,.19,0),(1.13,.28,.2,0),(1.17,.265,.19,0)],gold,rig)
ell('Belt gem',(0,-.215,1.11),(.075,.04,.09),light,rig)
head=joint('Head',(0,0,.57),body)
# Open-front hood built as a curved shell, with a pointed crown and thick rim.
verts=[];rows=9;cols=25
for j in range(rows):
 v=j/(rows-1);z=-.14+v*.66;radius=.28*math.sin(math.pi*(.18+.78*v))+.025
 for i in range(cols):
  a=-.24+ (math.pi+ .48)*i/(cols-1)
  verts.append((math.cos(a)*radius,math.sin(a)*radius*.9-.045,z))
faces=[(j*cols+i,j*cols+i+1,(j+1)*cols+i+1,(j+1)*cols+i) for j in range(rows-1) for i in range(cols-1)]
hood=surface('Sculpted open hood',verts,faces,cloth,head)
mod=hood.modifiers.new('Fabric thickness','SOLIDIFY');mod.thickness=.018
for edge in [0,cols-1]:line('Embroidered hood rim',[verts[j*cols+edge] for j in range(rows)],.022,purple,head)
ell('Masked face',(0,-.075,.13),(.205,.17,.25),black,head)
ell('Nose bridge',(0,-.237,.12),(.045,.035,.075),gold,head)
for side in [-1,1]:
 eye=ell('Luminous eye',(side*.088,-.227,.22),(.062,.018,.018),light,head);eye.rotation_euler.y=side*-.15
 line('Mask cheek filigree',[(side*.16,-.17,.12),(side*.12,-.22,.04),(side*.045,-.24,-.015)],.012,gold,head)
ell('Mirror focus',(0,-.25,.17),(.075,.035,.11),light,body)
arms=[];elbows=[];legs=[];knees=[]
for side in [-1,1]:
 a=joint('Shoulder_'+str(side),(side*.43,0,.28),body);arms.append(a)
 ell('Layered pauldron',(side*.035,.005,-.025),(.235,.235,.18),gold,a)
 ell('Inset pauldron',(side*.06,-.025,.035),(.20,.21,.11),purple,a)
 form('Upper sleeve',[(0,.105,.12,0),(-.16,.13,.125,0),(-.37,.09,.095,0)],cloth,a)
 e=joint('Elbow_'+str(side),(0,0,-.36),a);elbows.append(e)
 form('Tapered vambrace',[(.02,.10,.11,0),(-.08,.13,.14,-.015),(-.28,.085,.1,0),(-.34,.075,.085,0)],gold,e)
 ell('Gloved hand',(0,-.01,-.39),(.085,.09,.12),cloth,e)
 for k in range(3):line('Vambrace etching',[(-.09,-.1,-.08-k*.055),(0,-.15,-.11-k*.055),(.09,-.1,-.08-k*.055)],.008,purple,e)
 w=joint('Dagger_'+str(side),(0,-.035,-.44),e)
 form('Wrapped grip',[(.06,.035,.035,0),(-.12,.035,.035,0)],cloth,w,12)
 line('Swept guard',[(-.15,0,-.14),(-.07,-.025,-.11),(0,0,-.15),(.1,.01,-.12),(.17,0,-.16)],.023,gold,w)
 blade=surface('Curved moonsteel blade',[(-.075,0,-.16),(0,-.035,-.16),(.075,0,-.16),(-.08,0,-.35),(0,-.035,-.38),(.07,0,-.36),(.07,0,-.69),(.15,0,-.78)],[(0,1,4,3),(1,2,5,4),(3,4,6),(4,5,6),(5,7,6),(2,0,3,6,7,5)],steel,w)
 line('Blade energy channel',[(0,-.04,-.19),(0,-.04,-.37),(.07,-.015,-.65)],.009,light,w)
 l=joint('Hip_'+str(side),(side*.18,0,1.1),rig);legs.append(l)
 form('Sculpted thigh',[(0,.13,.15,0),(-.18,.155,.16,.015),(-.47,.10,.105,0)],cloth,l)
 k=joint('Knee_'+str(side),(0,0,-.47),l);knees.append(k)
 ell('Kneecap',(0,-.085,-.025),(.12,.075,.13),gold,k)
 form('Fitted greave',[(0,.10,.105,0),(-.15,.12,.12,.015),(-.39,.075,.085,0),(-.47,.08,.095,-.015)],purple,k)
 ell('Pointed leather boot',(0,-.09,-.49),(.10,.21,.095),cloth,k)
 line('Greave silver ridge',[(0,-.12,-.09),(0,-.13,-.24),(0,-.09,-.42)],.014,gold,k)
# Three connected cloak sections, sculpted folds and scalloped hem.
cape=[];parent=body
for section in range(3):
 c=joint('Cloak_'+str(section),(0,.19,.31) if section==0 else (0,.055,-.35),parent);cape.append(c);parent=c
 vs=[];n=25;m=7
 for j in range(m):
  v=j/(m-1);depth=section+v;width=.34+depth*.11
  for i in range(n):
   u=i/(n-1)*2-1;fold=math.cos(u*math.pi*4)*(.025+depth*.015)
   vs.append((u*width,.075+v*.055+fold+.10*u*u,-v*.43-(.045*math.cos(u*math.pi*3) if section==2 else 0)))
 fs=[(j*n+i,j*n+i+1,(j+1)*n+i+1,(j+1)*n+i) for j in range(m-1) for i in range(n-1)]
 o=surface('Flowing folded cloak',vs,fs,purple,c);o.modifiers.new('Double sided cloth','SOLIDIFY').thickness=.012
 for edge in [0,n-1]:line('Cloak silver border',[vs[j*n+edge] for j in range(m)],.012,gold,c)
 if section==2:line('Embroidered hem',vs[-n:],.018,gold,c)
 if section==1:
  line('Mirror sigil',[(0,.17,-.04),(-.12,.15,-.20),(0,.20,-.37),(.12,.15,-.20),(0,.17,-.04)],.012,gold,c)
  line('Sigil inner light',[(0,.185,-.12),(-.055,.18,-.20),(0,.21,-.29),(.055,.18,-.20),(0,.185,-.12)],.009,light,c)
nodes=[rig,body,head,*arms,*elbows,*legs,*knees,*cape];base={o.name:tuple(o.location) for o in nodes}
for clip,frames in [('Idle',90),('Run',25),('Attack',15),('Cast',18),('Death',25),('Stun',60)]:
 for o in nodes:o.animation_data_create();o.animation_data.action=None
 for f in range(1,frames+1):
  t=(f-1)/(frames-1);phase=t*math.tau;s=math.sin(phase)
  for o in nodes:o.location=base[o.name];o.rotation_euler=(0,0,0)
  for i,e in enumerate(elbows):e.rotation_euler.x=-.25
  if clip=='Run':
   for i in range(2):
    p=phase+i*math.pi;legs[i].rotation_euler.x=math.sin(p)*.65;knees[i].rotation_euler.x=max(0,math.sin(p-.65))*.95
    arms[i].rotation_euler.x=-math.sin(p)*.42;elbows[i].rotation_euler.x=-.65-max(0,-math.sin(p))*.25
   body.location.z+=.035*(1-math.cos(phase*2));body.rotation_euler.x=.13;body.rotation_euler.z=s*.055
  elif clip=='Attack':
   a=math.sin(math.pi*t)**2;body.rotation_euler.z=a*.75;body.rotation_euler.x=a*.18
   arms[1].rotation_euler.x=-a*1.65;arms[1].rotation_euler.y=-a*.9;elbows[1].rotation_euler.x=-.3-a*.5;arms[0].rotation_euler.y=a*.55
  elif clip=='Cast':
   a=math.sin(math.pi*t)**2
   for i in range(2):arms[i].rotation_euler.y=a*(1 if i==0 else -1)*1.25;elbows[i].rotation_euler.x=-.3-a*.65
   head.rotation_euler.x=-a*.2;body.location.z+=a*.07
  elif clip=='Death':
   a=t*t*(3-2*t);rig.rotation_euler.x=-a*1.55;rig.location.z=a*.16
   for k in knees:k.rotation_euler.x=a*.6
  elif clip=='Stun':head.rotation_euler.z=s*.12;body.rotation_euler.x=.1
  else:body.location.z+=s*.018;head.rotation_euler.z=s*.025
  for i,c in enumerate(cape):c.rotation_euler.x=(-.18 if clip=='Run' else -.04)+math.sin(phase-i*.65)*(.09 if clip=='Run' else .025);c.rotation_euler.y=math.sin(phase-i*.5)*.025
  for o in nodes:o.keyframe_insert('location',frame=f);o.keyframe_insert('rotation_euler',frame=f)
 for o in nodes:
  action=o.animation_data.action;action.name=clip+'_'+o.name
  track=o.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,1,action);o.animation_data.action=None
for o in nodes:o.location=base[o.name];o.rotation_euler=(0,0,0)
bpy.context.scene.render.fps=30
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/smugr/Smugr.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/characters/smugr/smugr.glb'),export_format='GLB',export_animation_mode='NLA_TRACKS',export_force_sampling=True)
print('DETAILED_SMUGR_EXPORT_OK')
