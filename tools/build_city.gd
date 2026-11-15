extends SceneTree
# Authored OSM-derived district builder. Run with a renderer, not --headless.
const D = preload("res://scripts/district.gd")
var city: Node3D
var solid: StaticBody3D
var batches := {}
var materials := {}
var rng := RandomNumberGenerator.new()
var data: Dictionary
var meshes := {}
var shop_count := 0
const PALETTE = ["b3b5a7","a9bcae","d2c4a9","b8aba2","95acac","c7b9aa","aeb3a9","c4baa7"]
const SHOPS = ["永樂海味","好運茶餐廳","德記藥房","陳記燒臘","華昌辦館","生記粥品","同發五金","新記麵家","恆生找換","美香餅家","永安參茸","合興茶莊"]
const ENGLISH = ["WING LOK SEAFOOD","GOOD LUCK CAFE","TAK KEE MEDICINE","CHAN'S ROAST MEAT","WAH CHEONG STORE","SANG KEE CONGEE","TUNG FAT HARDWARE","SUN KEE NOODLES","MONEY EXCHANGE","MEI HEUNG BAKERY","WING ON HERBS","HOP HING TEA"]

func material(hex: String) -> ShaderMaterial:
	if materials.has(hex): return materials[hex]
	var m := ShaderMaterial.new()
	m.shader=load("res://assets/shaders/toon.gdshader")
	m.set_shader_parameter("paint",Color(hex))
	materials[hex]=m
	return m

func box(p: Vector3,size: Vector3,color: String,collision:=false,rot:=0.0):
	if not batches.has(color): batches[color]=[]
	batches[color].append(Transform3D((Basis(Vector3.UP,rot)*Basis.from_scale(size)),p))
	if collision:
		var c:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=size
		c.shape=shape
		solid.add_child(c)
		c.owner=city
		c.position=p
		c.rotation.y=rot

func text3d(value:String,p:Vector3,size:int,color:Color,rot:=0.0):
	var l:=Label3D.new()
	l.text=value
	l.font_size=size
	l.pixel_size=.018
	l.modulate=color
	l.outline_size=0
	l.visibility_range_end=95
	city.add_child(l)
	l.owner=city
	l.position=p
	l.rotation.y=rot

func pos(x:float,z:float,lift:=0.0)->Vector3:
	return Vector3(x,D.road_height(Vector3(x,0,z))+lift,z)

func add_tri(bucket:String,a:Vector3,b:Vector3,c:Vector3,ua:=Vector2.ZERO,ub:=Vector2.ZERO,uc:=Vector2.ZERO):
	if not meshes.has(bucket): meshes[bucket]={"v":PackedVector3Array(),"uv":PackedVector2Array()}
	meshes[bucket].v.append_array(PackedVector3Array([a,b,c]))
	meshes[bucket].uv.append_array(PackedVector2Array([ua,ub,uc]))

func quad(bucket:String,a:Vector3,b:Vector3,c:Vector3,d:Vector3,uv_size:=Vector2.ONE):
	add_tri(bucket,a,b,c,Vector2.ZERO,Vector2(uv_size.x,0),uv_size)
	add_tri(bucket,a,c,d,Vector2.ZERO,uv_size,Vector2(0,uv_size.y))

func strip(a:Vector3,b:Vector3,width:float,color:String,lift:=.03):
	var flat:=Vector3(b.x-a.x,0,b.z-a.z)
	var side:=Vector3.UP.cross(flat.normalized())*width*.5
	var along_count:=maxi(1,int(ceil(flat.length()/3.0)))
	var across_count:=maxi(1,int(ceil(width/3.0)))
	for i in along_count:
		var begin:=a.lerp(b,float(i)/along_count)
		var end:=a.lerp(b,float(i+1)/along_count)
		for j in across_count:
			var left:=side*lerpf(-1,1,float(j)/across_count)
			var right:=side*lerpf(-1,1,float(j+1)/across_count)
			var corners=[begin+left,begin+right,end+right,end+left]
			for k in 4:corners[k].y=D.road_height(corners[k])+lift
			quad(color,corners[0],corners[1],corners[2],corners[3])

func beam(a:Vector3,b:Vector3,width:float,color:String):
	var delta:=b-a
	var basis:=(Basis.looking_at(delta.normalized(),Vector3.UP)*Basis.from_scale(Vector3(width,width,delta.length())))
	if not batches.has(color):batches[color]=[]
	batches[color].append(Transform3D(basis,(a+b)*.5))

func shore_z(x:float)->float:
	var coast:Array=data.coast
	for i in range(coast.size()-1):
		if x>=coast[i][0] and x<=coast[i+1][0]:return lerpf(coast[i][1],coast[i+1][1],(x-coast[i][0])/(coast[i+1][0]-coast[i][0]))
	return coast[0][1] if x<coast[0][0] else coast[-1][1]

func terrain():
	# 8m triangles use the same smooth function as vehicle spawning and road strips.
	for x in range(-560,560,8):
		for z in range(-330,330,8):
			if z+8<shore_z(x):continue
			quad("terrain",pos(x,z),pos(x+8,z),pos(x+8,z+8),pos(x,z+8))
	box(Vector3(0,-1,-650),Vector3(2600,1,1350),"438f9b")
	for i in 260:
		box(Vector3(rng.randf_range(-1000,1000),-.46,rng.randf_range(-1100,-350)),Vector3(rng.randf_range(3,14),.02,.22),"83bdba")
	for i in range(data.coast.size()-1):
		var a=pos(data.coast[i][0],data.coast[i][1])
		var b=pos(data.coast[i+1][0],data.coast[i+1][1])
		strip(a,b,6,"c1c0aa",.04)
		beam(a+Vector3(0,.9,0),b+Vector3(0,.9,0),.13,"566d69")
		for p in [a,b]:box(p+Vector3(0,.5,0),Vector3(.15,1,.15),"566d69")

func roads():
	var count:=0
	for e in D.road_segments():
		var a:Vector3=e.a
		var b:Vector3=e.b
		var tangent:=(b-a).normalized()
		tangent.y=0
		var left:=Vector3.UP.cross(tangent).normalized()
		strip(a,b,e.width+3.8,"bdb7a5",.025)
		strip(a,b,e.width,"475659",.045)
		# Curbs are painted on the union boundary below, never across junctions.
		if not e.tram and (b-a).length()>6:
			strip(a.lerp(b,.25),a.lerp(b,.6),.12,"dbd5b8",.075)
		if count%6==0 and (b-a).length()>7:
			var p:Vector3=a+left*(e.width*.5+1)
			p.y=D.road_height(p)
			box(p+Vector3(0,3.8,0),Vector3(.12,7.6,.12),"66746c")
			beam(p+Vector3(0,7.6,0),p-left*2+Vector3(0,7.6,0),.15,"66746c")
			box(p-left*2+Vector3(0,7.5,0),Vector3(.6,.17,1.1),"e8ddae")

		count+=1
	# Static rails and moving trams share the same actual OSM railway spine.
	var rail_path:Array=D.tram_routes()[0]
	var pole_distance:=0.0
	for i in range(rail_path.size()-1):
		var a:Vector3=rail_path[i]
		var b:Vector3=rail_path[i+1]
		var tangent:=(b-a).normalized()
		var side:=Vector3.UP.cross(tangent).normalized()
		for offset in [-2.8,-1.35,1.35,2.8]:strip(a+side*offset,b+side*offset,.12,"a1aba4",.09)
		for offset in [-2.075,2.075]:beam(a+side*offset+Vector3(0,6.2,0),b+side*offset+Vector3(0,6.2,0),.04,"48575a")
		pole_distance+=a.distance_to(b)
		if pole_distance>35:
			pole_distance=0
			beam(a-side*10+Vector3(0,6.5,0),a+side*10+Vector3(0,6.5,0),.055,"48575a")
	for line in data.curb_lines:
		for i in range(line.size()-1):
			strip(pos(line[i][0],line[i][1]),pos(line[i+1][0],line[i+1][1]),.12,"d5b261",.08)
	# Pedestrian streets remain rendered, but absent from the bus routing graph.
	for way in data.pedestrian:
		for i in range(way.points.size()-1):
			var a=pos(way.points[i][0],way.points[i][1])
			var b=pos(way.points[i+1][0],way.points[i+1][1])
			strip(a,b,3.6,"b4ab95",.055)
			if way.steps:
				var count_steps:=int(a.distance_to(b)/1.4)
				for j in count_steps:
					var p:Vector3=a.lerp(b,float(j)/maxi(1,count_steps))
					var side:=Vector3.UP.cross((b-a).normalized())*1.6
					strip(p-side,p+side,.10,"dbcfad",.09)

func building(b:Dictionary):
	var points:=PackedVector2Array()
	for p in b.points:points.append(Vector2(p[0],p[1]))
	var triangulated:=Geometry2D.triangulate_polygon(points)
	var height:float=b.height
	var base:float=b.base-.5
	var top:=base+height
	var index:int=int(b.seed)%PALETTE.size()
	var bucket:String="glass" if b.style=="glass" else "facade_"+PALETTE[index]
	if b.name in ["Western Market","Man Mo Temple","Lit Shing Kung","PMQ","Central Market"]:return
	for i in range(0,triangulated.size(),3):
		var a:Vector2=points[triangulated[i]]
		var c:Vector2=points[triangulated[i+1]]
		var d:Vector2=points[triangulated[i+2]]
		add_tri("9faaa1",Vector3(a.x,top,a.y),Vector3(c.x,top,c.y),Vector3(d.x,top,d.y))
	for i in points.size():
		var a:=points[i]
		var b2:=points[(i+1)%points.size()]
		var length:=a.distance_to(b2)
		quad(bucket,Vector3(a.x,base,a.y),Vector3(b2.x,base,b2.y),Vector3(b2.x,top,b2.y),Vector3(a.x,top,a.y),Vector2(length,height))
		if length<5:continue
		var midpoint:=(a+b2)*.5
		var near:=D.nearest_road(Vector3(midpoint.x,0,midpoint.y))
		var outward:=Vector3(near.x-midpoint.x,0,near.z-midpoint.y).normalized()
		var normal:=Vector3(b2.y-a.y,0,a.x-b2.x).normalized()
		if absf(outward.dot(normal))<.65:continue
		if Vector2(near.x-midpoint.x,near.z-midpoint.y).length()>20:continue
		if outward.dot(normal)<0:normal=-normal
		var t:=Vector3(b2.x-a.x,0,b2.y-a.y).normalized()
		var rot:=atan2(normal.x,normal.z)
		var center:=pos(midpoint.x,midpoint.y)
		var usable:=minf(length-1,22)
		var tint:String=["397469","8f4c41","b58a4c","465c70"][int(b.seed)%4]
		box(center+normal*.1+Vector3(0,1.3,0),Vector3(usable,2.6,.2),"314b4d",false,rot)
		for j in range(int(usable/2.5)):
			box(center+t*(j*2.5-usable*.5+1)+normal*.25+Vector3(0,1.3,0),Vector3(.12,2.6,.25),"aaaca0",false,rot)
		box(center+normal*.3+Vector3(0,3.15,0),Vector3(usable,1.0,.35),tint,false,rot)
		if shop_count%2==0:
			text3d(SHOPS[int(b.seed)%SHOPS.size()],center+normal*.51+Vector3(0,3.3,0),52,Color("eee1b4"),rot)
			text3d(ENGLISH[int(b.seed)%SHOPS.size()],center+normal*.52+Vector3(0,2.92,0),16,Color("eee1b4"),rot)
		box(center+normal*1.0+Vector3(0,2.6,0),Vector3(usable,.12,1.8),tint,false,rot)
		for j in range(int(usable/1.5)):
			box(center+t*(j*1.5-usable*.5+.7)+normal*1+Vector3(0,2.68,0),Vector3(.5,.04,1.8),"d7cfb0",false,rot)
		# Physical AC units and balconies give silhouette depth beneath procedural upper windows.
		for floor_i in range(2,mini(12,int(height/3))):
			for j in range(maxi(1,int(usable/4))):
				var unit:=center+t*(j*4-usable*.5+1.7)+normal*.45+Vector3(0,floor_i*3-.5,0)
				box(unit,Vector3(1.0,.65,.65),"b4b9ad",false,rot)
				box(unit+normal*.34,Vector3(.62,.4,.02),"687a77",false,rot)
		if shop_count%5==0:
			var blade:=center+t*(usable*.3)+normal*1.3+Vector3(0,6.3,0)
			box(blade,Vector3(.28,4.5,2.3),tint,false,rot)
			text3d(["茶\n餐\n廳","海\n味","押","麵\n家"][int(b.seed)%4],blade+t*.18,58,Color("ffdfa2"),rot+PI/2)
		if shop_count%19==0:
			for j in range(int(usable/2)):
				box(center+t*(j*2-usable*.5)+normal*.8+Vector3(0,height*.5,0),Vector3(.08,height,.08),"a99766")
			for f in range(int(height/2.5)):beam(center-t*usable*.5+normal*.8+Vector3(0,f*2.5,0),center+t*usable*.5+normal*.8+Vector3(0,f*2.5,0),.075,"a99766")
		shop_count+=1
	# Triangle prisms avoid filling concave courtyards with broad collision boxes.
	for tri in range(0,triangulated.size(),3):
		var vertices:=PackedVector3Array()
		for k in 3:
			var p:Vector2=points[triangulated[tri+k]]
			vertices.append(Vector3(p.x,base,p.y))
			vertices.append(Vector3(p.x,top,p.y))
		var shape:=ConvexPolygonShape3D.new()
		shape.points=vertices
		var collider:=CollisionShape3D.new()
		collider.shape=shape
		solid.add_child(collider)
		collider.owner=city

func flush():
	for color in batches:
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		var mesh:=BoxMesh.new()
		mesh.material=material(color)
		mm.mesh=mesh
		mm.instance_count=batches[color].size()
		for i in mm.instance_count:mm.set_instance_transform(i,batches[color][i])
		var instance:=MultiMeshInstance3D.new()
		instance.multimesh=mm
		instance.name="Detail_"+color
		city.add_child(instance)
		instance.owner=city
	for bucket in meshes:
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in meshes[bucket].v.size():
			st.set_uv(meshes[bucket].uv[i])
			st.add_vertex(meshes[bucket].v[i])
		st.generate_normals()
		var mesh:=st.commit()
		var instance:=MeshInstance3D.new()
		instance.mesh=mesh
		instance.name="Surface_"+bucket
		if bucket.begins_with("facade_") or bucket=="glass":
			var m:=ShaderMaterial.new()
			m.shader=load("res://assets/shaders/facade.gdshader")
			m.set_shader_parameter("paint",Color(bucket.trim_prefix("facade_")) if bucket!="glass" else Color("769a9c"))
			m.set_shader_parameter("glass",bucket=="glass")
			instance.material_override=m
		else:instance.material_override=material("aca894" if bucket=="terrain" else bucket)
		city.add_child(instance)
		instance.owner=city
		if bucket=="terrain":
			instance.position.y=-.18 # Visual ground sits below roads; collision retains exact reference elevation.
			var collider:=CollisionShape3D.new()
			collider.shape=mesh.create_trimesh_shape()
			solid.add_child(collider)
			collider.owner=city

func _initialize():
	if DisplayServer.get_name()=="headless":
		push_error("Bake with renderer so MultiMesh buffers are preserved")
		quit(1)
		return
	rng.seed=8311
	data=D.map_data()
	city=Node3D.new()
	city.name="SheungWanCentral"
	solid=StaticBody3D.new()
	solid.name="DistrictCollision"
	city.add_child(solid)
	solid.owner=city
	terrain()
	roads()
	for b in data.buildings:building(b)
	landmarks()
	street_furniture()
	batches.erase("718b7e") # Boundary volumes are collision-only, never skyline walls.
	flush()
	lighting()
	var packed:=PackedScene.new()
	packed.pack(city)
	ResourceSaver.save(packed,"res://scenes/district.tscn")
	print("CITY_BAKED ",data.buildings.size()," footprints, ",shop_count," shopfronts, ",batches.size()," instanced batches")
	city.free()
	quit()

func lighting():
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("a6cccf")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("c1d5d3")
	env.environment.ambient_light_energy=.48
	env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env.environment.fog_enabled=true
	env.environment.fog_light_color=Color("b1cbca")
	env.environment.fog_density=.00065
	city.add_child(env)
	env.owner=city
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-28,0)
	sun.light_color=Color("ffe3b9")
	sun.light_energy=1.0
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=160
	city.add_child(sun)
	sun.owner=city

func local_box(center:Vector3,offset:Vector3,size:Vector3,color:String,rot:float,collision:=false):
	box(center+Basis(Vector3.UP,rot)*offset,size,color,collision,rot)

func landmarks():
	# Western Market: red brick, cream string courses, tall arched openings, corner turret.
	var p:=pos(-93.5,-134.34)
	var angle:=-.262
	local_box(p,Vector3(0,7.5,0),Vector3(17,15,34),"a45e4e",angle,true)
	local_box(p,Vector3(0,-2.5,0),Vector3(17,5,34),"9c9280",angle)
	for y in [1.0,5.0,11.0,14.5]:local_box(p,Vector3(0,y,0),Vector3(17.5,.4,34.5),"d6c8a6",angle)
	local_box(p,Vector3(0,15.3,0),Vector3(18,.65,35),"536f68",angle)
	for side in [-1,1]:
		for z in range(-13,14,6):
			local_box(p,Vector3(side*8.55,7.8,z),Vector3(.12,4.7,2.8),"36565a",angle)
			for edge in [-1,1]:local_box(p,Vector3(side*8.7,7.8,z+edge*1.6),Vector3(.25,5.2,.3),"dbc8a4",angle)
			local_box(p,Vector3(side*8.7,10.4,z),Vector3(.25,.4,3.4),"dbc8a4",angle)
		for x in [-5,0,5]:local_box(p,Vector3(x,7.5,side*17.05),Vector3(2.8,5,.15),"36565a",angle)
	var face:=p+Basis(Vector3.UP,angle)*Vector3(0,12.5,17.32)
	text3d("西 港 城",face,58,Color("fff0c8"),angle)
	text3d("WESTERN MARKET",face-Vector3(0,.9,0),27,Color("fff0c8"),angle)
	local_box(p,Vector3(-5.5,17,12),Vector3(5.5,4.5,5.5),"a45e4e",angle)
	local_box(p,Vector3(-5.5,19.5,12),Vector3(6,.7,6),"536f68",angle)
	# Man Mo Temple fits the real small footprint behind Hollywood Road.
	p=pos(-109,171)
	angle=-.37
	local_box(p,Vector3(0,2.8,0),Vector3(11,5.6,20),"d0c8ae",angle,true)
	local_box(p,Vector3(0,-2.5,0),Vector3(11,5,20),"aaa58e",angle)
	for z in [-5,5]:
		var roof_basis:=Basis(Vector3.UP,angle)
		for side in [-1,1]:
			var a:=p+roof_basis*Vector3(-6.5,6.0,z+side*5.5)
			var b:=p+roof_basis*Vector3(6.5,6.0,z+side*5.5)
			var c:=p+roof_basis*Vector3(6.5,8.0,z)
			var d:=p+roof_basis*Vector3(-6.5,8.0,z)
			quad("426c58",a,b,c,d)
			quad("426c58",d,c,b,a)
			for tile in range(-6,7):
				beam(p+roof_basis*Vector3(tile,6.08,z+side*5.5),p+roof_basis*Vector3(tile,8.08,z),.09,"69866a")
		local_box(p,Vector3(0,8.15,z),Vector3(13,.3,.45),"b1b69a",angle)
		for end_x in [-6.5,6.5]:local_box(p,Vector3(end_x,8.5,z),Vector3(.6,.7,.6),"b1b69a",angle)
	# Lit Shing Kung adjoins the temple, not a modern tower.
	var wing:=pos(-118,168)
	local_box(wing,Vector3(0,2.5,0),Vector3(5,5,18),"ccc6ad",angle,true)
	local_box(wing,Vector3(0,-2.5,0),Vector3(5,5,18),"aaa58e",angle)
	local_box(wing,Vector3(0,5.5,0),Vector3(6,.8,19),"426c58",angle)
	local_box(p,Vector3(0,2,-10.15),Vector3(3.7,4,.2),"a24637",angle)
	text3d("文武廟",p+Basis(Vector3.UP,angle)*Vector3(0,4.8,-10.3),45,Color("8e3c32"),angle+PI)
	for x in [-4,4]:local_box(p,Vector3(x,3,-10.5),Vector3(.8,1.3,.8),"c54d36",angle)
	# The Center crown: stepped faceted silhouette above its real star-shaped footprint.
	p=pos(266,106)
	for i in 6:box(p+Vector3(0,223+i*3,0),Vector3(24-i*3,3,24-i*3),"86b4ba",false,.2)
	box(p+Vector3(0,247,0),Vector3(.65,24,.65),"c1d0c5")
	# Shun Tak's red and silver harbour-facing twin office blocks.
	for x in [-28,12]:
		p=pos(x,-202)
		box(p+Vector3(0,28,0),Vector3(30,56,30),"a14c48",true)
		for y in range(8,55,4):box(p+Vector3(0,y,-15.05),Vector3(27,2.8,.12),"8ca6aa")
		for side in [-1,1]:box(p+Vector3(side*14,29,0),Vector3(2.2,53,30.2),"c2c6b7")
	# Ferry terminal shelter and finger piers on the actual harbour side.
	p=pos(10,-242)
	box(p+Vector3(0,4,0),Vector3(110,.7,30),"6a8581")
	for x in range(-40,61,20):box(p+Vector3(x,2,0),Vector3(.5,4,.5),"c9c7b1")
	text3d("港澳碼頭  /  MACAU FERRY TERMINAL",p+Vector3(0,4.7,15.4),62,Color("eee5c4"))
	for x in [-60,25,110]:
		box(Vector3(x,.5,-300),Vector3(15,1,60),"a9b4a7")
		box(Vector3(x+20,.5,-315),Vector3(12,2,36),"d2d4b9")
		box(Vector3(x+20,2.1,-315),Vector3(11,1.3,28),"457f70")
		box(Vector3(x+20,3,-315),Vector3(11.5,.4,29),"e9dec1")
	# High Connaught viaduct. Ground roads are separate and remain fully drivable.
	for way in data.flyovers:
		for i in range(way.points.size()-1):
			var a:=pos(way.points[i][0],way.points[i][1],10)
			var b:=pos(way.points[i+1][0],way.points[i+1][1],10)
			var t:=(b-a).normalized()
			var side:=Vector3.UP.cross(t).normalized()*5
			quad("8b9993",a-side,b-side,b+side,a+side)
			for s in [-1,1]:beam(a+side*s+Vector3(0,.65,0),b+side*s+Vector3(0,.65,0),.6,"9baba3")
			if i%4==0:
				var near:=D.nearest_road(a)
				if Vector2(a.x-near.x,a.z-near.z).length()>16:box(a-Vector3(0,5,0),Vector3(1.7,10,1.7),"99a69c",true)
	# Kowloon skyline beyond the water, separate silhouettes rather than identical slabs.
	for i in 58:
		var h:=rng.randf_range(28,130)
		var x:=-1100+i*40.0
		box(Vector3(x,h*.5,-1050-rng.randf_range(0,180)),Vector3(rng.randf_range(16,38),h,24),"86afb0")
		if i%5==0:box(Vector3(x,h+8,-1100),Vector3(9,16,12),"86afb0")

func street_furniture():
	for i in D.STOP_POS.size():
		var p:Vector3=D.STOP_POS[i]
		var q:Vector3=D.stop_curb_position(i)
		var t:Vector3=D.stop_tangent(i)
		var side:=Vector3.UP.cross(t)
		var rot:=atan2(t.x,t.z)
		strip(p-t*7,p+t*7,5.6,"d8b768",.09)
		strip(p-t*6.7,p+t*6.7,5.1,"4d6260",.10)
		# Shelter deliberately on the sidewalk, parallel to street.
		box(q+Vector3(0,2.8,0),Vector3(2.5,.22,6),"44776b",false,rot)
		for along in [-2.6,2.6]:box(q+t*along+side*.7+Vector3(0,1.4,0),Vector3(.12,2.8,.12),"c5c4aa")
		box(q+side*.65+Vector3(0,.65,0),Vector3(.65,.18,4.3),"9c6c51",false,rot)
		var pole:=q+t*4
		box(pole+Vector3(0,1.7,0),Vector3(.12,3.4,.12),"bbbfa8")
		box(pole+Vector3(0,3,0),Vector3(.18,1.1,1.1),"ac483c",false,rot)
		text3d(str(i+1),pole-side*.14+Vector3(0,3,0),55,Color("fff0bd"),rot-PI/2)
		text3d(D.STOP_SHORT[i],q-side*1.28+Vector3(0,2.8,0),29,Color("fff0bd"),rot-PI/2)
		# Paired street name signs are readable from the approach.
		var sign:=q-t*5.5
		box(sign+Vector3(0,1.8,0),Vector3(.1,3.6,.1),"65776a")
		box(sign+Vector3(0,3.5,0),Vector3(3.8,.7,.12),"397166",false,rot-PI/2)
		text3d(data.stops[i].street,sign-side*.08+Vector3(0,3.5,0),20,Color("eee4c2"),rot-PI/2)
	# Small market stalls in pedestrian lanes, clear of drivable service bays.
	var placed:=0
	for way in data.pedestrian:
		if way.steps or way.points.size()<2:continue
		if not ("Market" in way.name or "Lascar" in way.name or "Peel" in way.name):continue
		for pp in way.points:
			var p:=pos(pp[0],pp[1])
			if p.distance_to(D.nearest_road(p))<10:continue
			box(p+Vector3(0,.6,0),Vector3(2.5,1.2,1.4),"947456")
			box(p+Vector3(0,2.5,0),Vector3(3,.15,2.2),"508b72" if placed%2==0 else "b35e47")
			for x in [-1.25,1.25]:box(p+Vector3(x,1.3,0),Vector3(.07,2.6,.07),"7d7862")
			for x in [-.8,0,.8]:box(p+Vector3(x,1.4,0),Vector3(.55,.45,.7),"b9ad70")
			placed+=1
	# Trees frame harbour and Hollywood Road Park; seeded placement avoids roadway.
	for i in 120:
		var x:=rng.randf_range(-540,530)
		var z:=shore_z(x)+rng.randf_range(8,16)
		if i>75:x=rng.randf_range(-360,-310);z=rng.randf_range(-5,40)
		var p:=pos(x,z)
		if p.distance_to(D.nearest_road(p))<17:continue
		box(p+Vector3(0,2,0),Vector3(.45,4,.45),"807a55")
		box(p+Vector3(0,4.8,0),Vector3(4.5,3.6,4.5),"75966b",false,.4)
		box(p+Vector3(0,6.2,0),Vector3(3.3,2.4,3.3),"8da877",false,.7)
	# Street ends meet visible maintenance barriers; background buildings continue beyond bounds.
	var closed:Dictionary={}
	for e in D.road_segments():
		for point in [e.a,e.b]:
			if absf(point.x)<555 and point.z<325:continue
			var key:=Vector2i(int(point.x/16),int(point.z/16))
			if closed.has(key):continue
			closed[key]=true
			var tangent:Vector3=(e.b-e.a).normalized()
			var side:=Vector3.UP.cross(tangent)
			var rotation:=atan2(tangent.x,tangent.z)
			for n in range(-2,3):
				var p:Vector3=point+side*n*2.7
				p.y=D.road_height(p)
				box(p+Vector3(0,.7,0),Vector3(2.4,1.4,.65),"cfad58",false,rotation)
				box(p+Vector3(0,.7,0),Vector3(.65,1.45,.7),"eee0b4",false,rotation)
	for side in [-1,1]:
		for z in range(-180,401,45):
			var p:=pos(side*610,z)
			var h:=rng.randf_range(22,85)
			box(p+Vector3(0,h*.5,0),Vector3(32,h,30),PALETTE[absi(z)%PALETTE.size()])

	# Physical boundary barriers prevent escape; road-end construction stripes explain closure.
	for x in [-562,562]:box(pos(x,0)+Vector3(0,90,0),Vector3(2,220,665),"718b7e",true)
	box(pos(0,332)+Vector3(0,65,0),Vector3(1124,180,2),"718b7e",true)
