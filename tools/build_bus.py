import bpy, math, os
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(name, rgb, metal=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*rgb,1); p.inputs['Roughness'].default_value=.64;p.inputs['Metallic'].default_value=metal
 return m
cream=mat('Custard enamel',(.93,.83,.53));red=mat('Chilli red',(.72,.055,.08)); dark=mat('Midnight rubber',(.035,.055,.066)); glass=mat('Petrol blue glass',(.06,.20,.25),.3); silver=mat('Warm chrome',(.63,.68,.65),.5);white=mat('Ivory lettering',(.98,.95,.79));amber=mat('Amber indicators',(1,.51,.08)); lamp=mat('Headlights',(1,.94,.68)); seat=mat('Retro jade seats',(.12,.42,.35))
def box(name,loc,scale,ma,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(ma)
 if bevel:
  mod=o.modifiers.new('Soft stamped corners','BEVEL');mod.width=bevel;mod.segments=2;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o
box('Body',(0,0,1.25),(2.42,6.1,1.35),cream,.18)
box('WindowCabin',(0,-.06,2.21),(2.27,5.85,1.14),glass,.22)
box('Roof',(0,-.1,2.86),(2.48,5.98,.38),red,.2)
box('WaistStripe',(0,0,1.68),(2.46,6.10,.12),red,.025)
for x in [-1.17,1.17]:
 for y in [-2.65,-1.55,-.4,.75,1.85,2.61]:box('WindowPillar',(x,y,2.19),(.10,.10,1.02),cream,.02)
 box('Cantrail',(x,0,2.66),(.09,5.5,.12),cream)
 box('SideSill',(x,0,.78),(.15,5.7,.16),dark,.02)
 for y in [-1.96,1.85]:
  bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.54,depth=.26,location=(x,y,.58),rotation=(0,math.pi/2,0));o=bpy.context.object;o.name='Tire';o.data.materials.append(dark)
  bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.29,depth=.28,location=(x*1.015,y,.58),rotation=(0,math.pi/2,0));bpy.context.object.data.materials.append(silver)
  bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.13,depth=.30,location=(x*1.02,y,.58),rotation=(0,math.pi/2,0));bpy.context.object.data.materials.append(dark)
for y in [-3.06,3.06]:
 box('Bumper',(0,y,.75),(2.44,.17,.22),silver,.06)
 box('Plate',(0,y*1.03,.96),(.76,.05,.25),amber,.02)
 box('Grille',(0,y,1.32),(.90,.06,.29),dark,.04)
 for x in [-.88,.88]:
  box('Light',(x,y,1.39),(.42,.09,.32),lamp if y>0 else red,.06)
  box('TurnSignal',(x,y,1.12),(.33,.08,.13),amber,.02)
# Split windscreen, wipers, wing mirrors.
box('FrontSplit',(0,2.88,2.2),(.055,.08,.9),cream)
for x in [-.6,.6]:
 w=box('Wiper',(x,2.96,1.98),(.055,.055,.50),dark);w.rotation_euler[1]=-.38
for x in [-1.46,1.46]:
 box('MirrorArm',(x,2.35,2.03),(.48,.07,.07),dark)
 box('Mirror',(x*1.12,2.35,2.14),(.16,.24,.39),dark,.06)
box('RouteBox',(0,1.97,3.13),(1.78,.60,.44),cream,.07)
box('RouteDisplay',(0,2.29,3.12),(1.56,.04,.30),dark,.01)
# Door outlined in cream on left side, windows remain visible.
for y in [1.0,2.27]:box('DoorFrame',(-1.225,y,1.67),(.055,.065,1.8),cream)
box('DoorSplit',(-1.24,1.64,1.6),(.04,.04,1.65),silver)
box('DoorStep',(-1.29,1.64,.59),(.3,1.3,.12),dark)
for y in [-2.2,-1.3,-.4,.5]:
 for x in [-.68,.68]:
  box('Seat',(x,y,1.59),(.57,.52,.16),seat,.06);box('SeatBack',(x,y-.24,1.9),(.57,.13,.65),seat,.06)
# Driver and lucky pineapple on dashboard.
box('Dashboard',(0,2.5,1.82),(2.05,.55,.18),dark,.05)
bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.13,location=(-.48,2.5,2.05));bpy.context.object.name='LuckyPineapple';bpy.context.object.data.materials.append(amber)
bpy.ops.mesh.primitive_cone_add(vertices=5,radius1=.12,radius2=0,depth=.24,location=(-.48,2.5,2.25));bpy.context.object.data.materials.append(seat)
path=os.path.abspath('assets/models/minibus.glb')
bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath('tools/source/minibus.blend'))
print('BUS_EXPORTED',path)
