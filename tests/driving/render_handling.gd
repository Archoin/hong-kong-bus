extends SceneTree

var arena: Node3D
var bus: Minibus
var camera: Camera3D
var path: Array[Vector3] = []
var t := 0.0
var capture_index := 0
var max_deviation := 0.0
var collisions := 0
var started := false
var digital_steering := false
var no_capture := false

func _initialize(): call_deferred("run")

func box(p: Vector3, size: Vector3, color: Color, collision:=false, pitch:=0.0):
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	var material := StandardMaterial3D.new()
	material.albedo_color=color
	material.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
	mesh.material=material
	node.mesh=mesh
	arena.add_child(node)
	node.position=p
	node.rotation.x=pitch
	if collision:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size=size
		col.shape=shape
		body.add_child(col)
		arena.add_child(body)
		body.position=p
		body.rotation.x=pitch

func run():
	digital_steering="--digital-steering" in OS.get_cmdline_user_args()
	no_capture="--no-capture" in OS.get_cmdline_user_args()
	for a in ["accelerate","reverse","left","right","brake"]:
		if not InputMap.has_action(a): InputMap.add_action(a)
	arena=Node3D.new()
	root.add_child(arena)
	box(Vector3(35,-.5,15),Vector3(180,1,180),Color("b0b99a"),true)
	box(Vector3(0,.03,30),Vector3(12,.06,72),Color("354e57"))
	box(Vector3(40,.04,0),Vector3(92,.06,12),Color("354e57"))
	for z in range(10,60,7): box(Vector3(0,.08,z),Vector3(.14,.02,3),Color("edd6a4"))
	for x in range(12,82,7): box(Vector3(x,.08,0),Vector3(3,.02,.14),Color("edd6a4"))
	box(Vector3(40,5,32),Vector3(60,10,50),Color("879b9b"),true)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("a9ced1")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("c2d0c7")
	env.environment.ambient_light_energy=.4
	arena.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-30,0)
	sun.shadow_enabled=true
	arena.add_child(sun)
	bus=Minibus.new()
	arena.add_child(bus)
	bus.reset_at(Vector3(0,0,40))
	bus.enabled=true
	bus.max_speed=14
	bus.bumped.connect(func(_strength): collisions+=1)
	camera=Camera3D.new()
	camera.far=400
	camera.current=true
	arena.add_child(camera)
	path.append(Vector3(0,0,10))
	for i in range(0,9):
		var angle:=PI+float(i)/8.0*PI/2
		path.append(Vector3(6+6*cos(angle),0,6+6*sin(angle)))
	path.append(Vector3(60,0,0))
	started=true

func _physics_process(delta: float):
	if not started: return
	t+=delta
	camera.position=bus.position+Vector3(-9,6,12)
	camera.look_at(bus.position+Vector3(0,1.6,0))
	if path.is_empty():
		Input.action_release("accelerate")
		Input.action_press("brake")
	else:
		var diff:=path[0]-bus.position
		diff.y=0
		if diff.length()<2.0: path.pop_front()
		else:
			var angle:=wrapf(atan2(-diff.x,-diff.z)-bus.rotation.y,-PI,PI)
			Input.action_release("left")
			Input.action_release("right")
			if angle>.025: Input.action_press("left",1.0 if digital_steering else minf(1,angle*2.4))
			elif angle<-.025: Input.action_press("right",1.0 if digital_steering else minf(1,-angle*2.4))
			var desired_speed:=7.0 if bus.position.z<15 and bus.position.x<16 else 14.0
			if bus.speed>desired_speed+.3:
				Input.action_release("accelerate")
				Input.action_press("brake")
			else:
				Input.action_release("brake")
				Input.action_press("accelerate")
	var deviation:=minf(absf(bus.position.x),absf(bus.position.z))
	max_deviation=maxf(max_deviation,deviation)
	if t>2+capture_index*2 and capture_index<5:
		capture_index+=1
		call_deferred("capture",capture_index)
	if t>14:
		started=false
		print("RENDER_HANDLING: digital=",digital_steering," collisions=",collisions," max_center_deviation=",max_deviation," final=",bus.position)
		call_deferred("finish")

func capture(index: int):
	if no_capture: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/driving_corner_%d.png"%index)

func finish():
	await capture(6)
	quit()
