extends SceneTree

var city: Node3D
var batches := {}
var materials := {}
var rng := RandomNumberGenerator.new()
var solid: StaticBody3D
const D = preload("res://scripts/district.gd")

func material(hex: String) -> ShaderMaterial:
	if materials.has(hex):
		return materials[hex]
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/toon.gdshader")
	m.set_shader_parameter("paint",Color(hex))
	materials[hex] = m
	return m

func box(p: Vector3, size: Vector3, color: String, collision := false, rot := 0.0):
	if not batches.has(color):
		batches[color] = []
	var t := Transform3D(Basis(Vector3.UP, rot).scaled(size), p)
	batches[color].append(t)
	if collision:
		var c := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		c.shape = shape
		solid.add_child(c)
		c.owner = city
		c.position = p
		c.rotation.y = rot

func text3d(value: String, p: Vector3, size: int, color: Color, rot := 0.0):
	var l := Label3D.new()
	l.text = value
	l.font_size = size
	l.pixel_size = 0.018
	l.modulate = color
	l.outline_size = 0
	l.no_depth_test = false
	city.add_child(l)
	l.owner = city
	l.position = p
	l.rotation.y = rot

func _initialize():
	if DisplayServer.get_name() == "headless":
		push_error("City baking needs a renderer to serialize MultiMesh buffers. Run without --headless.")
		quit(1)
		return
	rng.seed = 20261113
	city = Node3D.new()
	city.name = "OldTownDistrict"
	solid = StaticBody3D.new()
	solid.name = "ArchitectureCollision"
	city.add_child(solid)
	solid.owner = city
	box(Vector3(0,-0.5,0), Vector3(260,1,218), "d6c5a2", true)
	box(Vector3(0,-0.4,-168), Vector3(700,0.5,120), "438d9a")
	# Parallel waterfront promenades and harbor sparkle.
	box(Vector3(0,0.1,-100), Vector3(258,0.2,12), "dfceab")
	for x in range(-124,125,4):
		box(Vector3(x,0.85,-105),Vector3(.12,1.5,.12),"54716c")
	box(Vector3(0,1.5,-105),Vector3(250,.10,.10),"54716c")
	for i in 90:
		box(Vector3(rng.randf_range(-300,300),-.1,rng.randf_range(-220,-112)),Vector3(rng.randf_range(2,9),.02,.18),"80c8c3")
	# City's street lattice, generous junctions for arcade driving.
	for x in D.ROAD_X:
		box(Vector3(x,.012,0),Vector3(19,.024,164),"3e535b")
		for z in range(-80,81,7):
			if abs(z) > 12 and abs(z-72) > 12 and abs(z+72) > 12:
				box(Vector3(x,.036,z),Vector3(.18,.025,3.0),"f1dfb1")
		for side in [-1,1]:
			box(Vector3(x+side*8.7,.04,0),Vector3(.15,.025,162),"d7aa59")
	for z in D.ROAD_Z:
		box(Vector3(0,.02,z),Vector3(211,.025,19),"3e535b")
		for x in range(-103,104,7):
			var junction := false
			for rx in D.ROAD_X:
				if abs(x-rx)<12: junction=true
			if not junction: box(Vector3(x,.045,z),Vector3(3,.025,.18),"f1dfb1")
		for side in [-1,1]:
			box(Vector3(0,.05,z+side*8.7),Vector3(210,.025,.15),"d7aa59")
	for x in D.ROAD_X:
		for z in D.ROAD_Z:
			for offset in [-12,12]:
				for stripe in range(-6,7,2):
					box(Vector3(x+stripe,.066,z+offset),Vector3(.9,.025,2.7),"d7d9c1")
			# Deliberately iconic yellow box junctions.
			for k in [-1,0,1]:
				box(Vector3(x+k*3,.075,z),Vector3(.10,.02,12),"d7aa59",false,.75)
				box(Vector3(x+k*3,.075,z),Vector3(.10,.02,12),"d7aa59",false,-.75)
	# Blocks: shops, weathered pastel towers, awnings, AC units and roof tanks.
	var palette = ["b9b3a2","b2bba0","d7b68f","8caaa8","c89b91","c5c5b2","bdaca0"]
	var shops = ["MILK TEA CLUB", "GOOD LUCK NOODLES", "WING LOK TRADING", "PINEAPPLE BUNS", "LUCKY LAUNDRY", "VERY FRESH FISH", "PAWN & PROSPER", "NO. 8 CAFE", "JADE & JUNK", "DIM SUM DAILY", "AUNTIE'S KITCHEN", "HAPPY HARDWARE"]
	var n := 0
	for bx in [-64.0,0.0,64.0]:
		for bz in [-36.0,36.0]:
			box(Vector3(bx,.12,bz),Vector3(44,.24,52),"c4b79e",true)
			for ox in [-11.0,11.0]:
				for oz in [-15.0,15.0]:
					var p := Vector3(bx+ox,0,bz+oz)
					var h := rng.randf_range(13,31)
					var col: String = palette[n%palette.size()]
					box(p+Vector3(0,h/2,0),Vector3(19,h,24),col,true)
					box(p+Vector3(0,3,0),Vector3(19.3,.45,24.3),"e0cbaa")
					box(p+Vector3(0,h+.25,0),Vector3(19.4,.5,24.4),"ded2b1")
					box(p+Vector3(2,h+1.6,2),Vector3(4,2.5,4),"798f87")
					for side in [-1,1]:
						for floor_i in range(1,int(h/3)):
							for w in [-6,0,6]:
								box(p+Vector3(w,3.5+floor_i*2.7,side*12.03),Vector3(2.1,1.6,.08),"405e64")
								box(p+Vector3(side*9.54,3.5+floor_i*2.7,w*1.4),Vector3(.08,1.6,2.1),"405e64")
								if (floor_i+w)%3 == 0:
									box(p+Vector3(w+.8,2.6+floor_i*2.7,side*12.3),Vector3(1,.6,.6),"d0c9b2")
						var shop_color: String = ["a84138","397a70","d5a252","51637d"][n%4]
						box(p+Vector3(0,1.5,side*12.08),Vector3(16,2.3,.12),"274a50")
						box(p+Vector3(0,3.4,side*12.25),Vector3(17,.9,.3),shop_color)
						text3d(shops[n%shops.size()],p+Vector3(0,3.4,side*12.44),34,Color("fff0bf"),0 if side==1 else PI)
						box(p+Vector3(0,2.8,side*13.0),Vector3(17,.12,1.8),shop_color)
						for stripe in range(-7,8,2):
							box(p+Vector3(stripe,2.87,side*13),Vector3(.7,.04,1.8),"efe0b7")
					# Side-facing shopfronts keep north/south streets just as lively.
					for side in [-1,1]:
						var shop_color: String = ["a84138","397a70","d5a252","51637d"][n%4]
						box(p+Vector3(side*9.57,1.5,0),Vector3(.12,2.3,20),"274a50")
						box(p+Vector3(side*9.75,3.4,0),Vector3(.3,.9,20),shop_color)
						text3d(shops[n%shops.size()],p+Vector3(side*9.96,3.4,0),38,Color("fff0bf"),side*PI/2)
						box(p+Vector3(side*10.4,2.8,0),Vector3(1.8,.12,20),shop_color)
						for stripe in range(-9,10,2):
							box(p+Vector3(side*10.4,2.87,stripe),Vector3(1.8,.04,.7),"efe0b7")
						for pillar in range(-9,10,3):
							box(p+Vector3(side*9.66,1.5,pillar),Vector3(.2,2.3,.14),"d1bd96")
						# Projecting bilingual blade signs, oriented toward approaching traffic.
						var blade := p+Vector3(side*11.0,6.8,7)
						box(blade,Vector3(2.2,4.3,.3),shop_color)
						text3d(["茶餐廳","好運來","大排檔","當舖"][n%4],blade+Vector3(0,0,.18),46,Color("fff0b0"))
						text3d(["CAFE","LUCKY","EAT","PAWN"][n%4],blade+Vector3(0,-1.5,.18),22,Color("fff0b0"))
					# Blade signs hanging out into the narrow streets.
					var signpos := p+Vector3(10.9,7,8)
					box(signpos,Vector3(3.1,5,.28),"254c54")
					text3d(["TEA\n茶","LUCK\n福","EAT\n食","PAWN\n押"][n%4],signpos+Vector3(0,0,.18),62,Color("ffd27f"))
					n += 1
	# Peripheral facades create a district silhouette without blocking views of the sea.
	for x in range(-118,119,21):
		if abs(x)<26: continue
		var h := rng.randf_range(16,39)
		box(Vector3(x,h/2,99),Vector3(18,h,15),palette[abs(x)%palette.size()],true)
		for y in range(5,int(h),4):
			for wx in [-5,0,5]: box(Vector3(x+wx,y,91.45),Vector3(2.2,2,.08),"4f6a6c")
	for side in [-1,1]:
		for z in [-63,-17,25,66]:
			box(Vector3(side*119,10,z),Vector3(15,20,25),palette[abs(z)%7],true)
	# Western / eastern boundary tenements face inward, with shopfront detail.
	for side in [-1,1]:
		for z in [-63,-17,25,66]:
			var face_x: float = side*111.45
			for y in range(5,20,3):
				for wz in [-9,-4,1,6]:
					box(Vector3(face_x,y,z+wz),Vector3(.12,1.6,2.2),"405e64")
					box(Vector3(face_x-side*.3,y-.9,z+wz),Vector3(.7,.55,.9),"d0c9b2")
			box(Vector3(face_x,1.5,z),Vector3(.15,2.3,22),"274a50")
			box(Vector3(face_x-side*.2,3.4,z),Vector3(.3,.9,23),"397a70")
			text3d("GOOD FORTUNE  •  好運茶餐廳",Vector3(face_x-side*.38,3.4,z),36,Color("fff0bf"),-side*PI/2)
			box(Vector3(face_x-side*.9,2.8,z),Vector3(1.8,.12,23),"397a70")
			for wz in range(-10,11,2):
				box(Vector3(face_x-side*.9,2.87,z+wz),Vector3(1.8,.04,.65),"efe0b7")
			# Bamboo scaffolding accents on two tenements.
			if z==25:
				for wz in range(-11,12,3):
					box(Vector3(face_x-side*.65,10,z+wz),Vector3(.08,20,.08),"b29a64")
				for y in range(3,21,3):
					box(Vector3(face_x-side*.65,y,z),Vector3(.08,.08,24),"b29a64")
	# Temple occupies a forecourt on the southern edge.
	box(Vector3(0,.4,93),Vector3(26,.8,18),"d1b997",true)
	box(Vector3(0,3,97),Vector3(22,5,12),"a64b3e",true)
	for x in [-9,-3,3,9]: box(Vector3(x,3,90.9),Vector3(.6,5,.6),"bf5140")
	box(Vector3(0,6,97),Vector3(27,.8,16),"375d5a")
	box(Vector3(0,7,97),Vector3(23,.8,12),"3e6b60")
	box(Vector3(0,8,97),Vector3(17,.8,7),"548476")
	text3d("MAN MO TEMPLE",Vector3(0,4.6,90.5),58,Color("ffe0a2"),PI)
	for x in [-10,10]:
		box(Vector3(x,2,87),Vector3(.15,4,.15),"5f6656")
		box(Vector3(x,3.5,87),Vector3(1,1.4,1),"d4533c")
	# Western Market clock tower and red brick frontage at waterfront.
	box(Vector3(-72,5,-94),Vector3(25,10,13),"a65c4e",true)
	box(Vector3(-72,12,-94),Vector3(6,5,6),"bc8164")
	box(Vector3(-72,15,-94),Vector3(7,.6,7),"506e68")
	text3d("WESTERN MARKET",Vector3(-72,7,-87.4),52,Color("ffe5b2"))
	text3d("12\n9  •  3\n6",Vector3(-72,12,-90.95),36,Color("fff1cd"))
	for x in range(-81,-62,4):
		box(Vector3(x,3,-87.44),Vector3(2.2,4,.12),"38565d")
		box(Vector3(x,7,-87.44),Vector3(2.2,2,.12),"e2c7a2")
	for x in D.ROAD_X:
		for z in D.ROAD_Z:
			box(Vector3(x+10.4,1.7,z+10.4),Vector3(.12,3.4,.12),"44645c")
			box(Vector3(x+10.4,3.3,z+10.4),Vector3(2.8,.65,.14),"347767")
			text3d("皇后大道" if z==0 else ("HOLLYWOOD RD" if z>0 else "CONNAUGHT RD"),Vector3(x+10.4,3.3,z+10.5),18,Color("fff1cd"))
	# Ferry pier and a stylized ferry in the harbor.
	box(Vector3(22,.3,-115),Vector3(20,.6,30),"b8bca5",true)
	box(Vector3(22,3,-120),Vector3(22,.5,17),"537f72")
	for x in [13,31]: box(Vector3(x,1.7,-115),Vector3(.3,3,.3),"f0dec0")
	text3d("VICTORIA HARBOUR  /  PIER 3",Vector3(22,3.4,-106),34,Color("fff0c7"))
	box(Vector3(52,.9,-135),Vector3(10,2.2,25),"e7ddbd")
	box(Vector3(52,2.5,-135),Vector3(9,1.5,20),"407f72")
	box(Vector3(52,3.6,-135),Vector3(9.5,.4,21),"f1dfb8")
	for z in range(-142,-127,3): box(Vector3(46.9,2.6,z),Vector3(.1,.8,1.8),"244c57")
	# Street furniture: lamps, bollards, crates, red taxis, market stalls.
	for x in D.ROAD_X:
		for z in [-54,-18,18,54]:
			for side in [-1,1]:
				box(Vector3(x+side*10.5,3.5,z),Vector3(.13,7,.13),"4a635e")
				box(Vector3(x+side*9.5,7,z),Vector3(2.3,.15,.15),"4a635e")
				box(Vector3(x+side*8.5,6.9,z),Vector3(.8,.15,.45),"ffe4a1")
	for i in 12:
		var p := Vector3(-82+i*3.4,.5,86)
		box(p,Vector3(2.8,1,2.5),"9e7153")
		box(p+Vector3(0,1.7,0),Vector3(3,.18,3),"bd6147" if i%2==0 else "4e8f75")
		for xx in [-1,1]:box(p+Vector3(xx,.8,0),Vector3(.08,1.5,.08),"816f4e")
	# Trees with low-poly canopies.
	for x in range(-110,111,22):
		box(Vector3(x,1.7,-94),Vector3(.45,3.4,.45),"7f7552")
		box(Vector3(x,4,-94),Vector3(3.3,2.7,3.3),"7f9e65",false,.35)
		box(Vector3(x,5,-94),Vector3(2.4,2,2.4),"93b776",false,.7)
	# Stops: road paint, shelters, route totems and seating.
	for i in 6:
		var p: Vector3 = D.STOP_POS[i]
		var horizontal := i==1 or i==4
		var q := p + (Vector3(0,0,-12) if horizontal else Vector3(-12,0,0))
		box(p+Vector3(0,.09,0),Vector3(13,.03,6) if horizontal else Vector3(6,.03,13),"b09855")
		box(p+Vector3(0,.11,0),Vector3(12.4,.03,5.4) if horizontal else Vector3(5.4,.03,12.4),"4a5d5e")
		box(q+Vector3(0,2.7,0),Vector3(6,.3,3),"42796e")
		for x in [-2.6,2.6]:box(q+Vector3(x,1.3,0),Vector3(.14,2.6,.14),"e4cf9f")
		box(q+Vector3(0,.65,0),Vector3(4,.18,.7),"ab654c")
		box(q+Vector3(3.7,1.7,0),Vector3(.12,3.4,.12),"d8d2b1")
		box(q+Vector3(3.7,3.1,0),Vector3(1.2,1.1,.15),"ad433d")
		text3d(str(i+1),q+Vector3(3.7,3.1,.1),58,Color("fff1bd"))
		text3d(D.STOP_SHORT[i],q+Vector3(0,2.7,1.56),27,Color("fff1bd"))
	# Invisible world-edge barriers and visible construction chevrons.
	box(Vector3(-132,5,0),Vector3(2,10,230),"648278",true)
	box(Vector3(132,5,0),Vector3(2,10,230),"648278",true)
	box(Vector3(0,5,115),Vector3(264,10,2),"648278",true)
	box(Vector3(0,1,-107),Vector3(264,2,.3),"54716c",true)
	# Distant Kowloon silhouette, no collision.
	for i in 35:
		var h := rng.randf_range(15,70)
		box(Vector3(-360+i*22,h/2,-260-rng.randf_range(0,60)),Vector3(rng.randf_range(10,21),h,18),"79a6ac")
	flush()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9cc9cc")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a7c8ce")
	env.environment.ambient_light_energy = .38
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color("a9c7c2")
	env.environment.fog_density = .0012
	city.add_child(env)
	env.owner = city
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-33,0)
	sun.light_color = Color("ffe0ad")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180
	city.add_child(sun)
	sun.owner = city
	var packed := PackedScene.new()
	packed.pack(city)
	ResourceSaver.save(packed,"res://scenes/district.tscn")
	print("CITY_BAKED: ", batches.size(), " instanced material batches")
	city.free()
	quit()

func flush():
	for color in batches:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh.material = material(color)
		mm.mesh = mesh
		mm.instance_count = batches[color].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i,batches[color][i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mm
		instance.name = "City_"+color
		city.add_child(instance)
		instance.owner = city
