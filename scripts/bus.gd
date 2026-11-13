class_name Minibus
extends CharacterBody3D

signal bumped(impact: float)
var speed := 0.0
var max_speed := 23.0
var acceleration := 11.0
var enabled := false
var steering := 0.0
var distance_driven := 0.0
var visual: Node3D
var brake_light: MeshInstance3D
var bump_cooldown := 0.0
var engine: AudioStreamPlayer
var body_color := Color("c43d38")
var wheels: Array[Node3D] = []
var controlled := true
var door_open := false
var door_slide := 0.0
var sliding_door: Node3D
var brake_material: StandardMaterial3D

func _ready():
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = .5
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5,2.6,5.9)
	col.shape = shape
	col.position.y = 1.32
	add_child(col)
	visual = preload("res://assets/models/minibus.glb").instantiate()
	add_child(visual)
	_style(visual)
	build_door_and_brakelights()
	var plate := Label3D.new()
	plate.text = "HK  1988"
	plate.font_size = 34
	plate.pixel_size = .009
	plate.modulate = Color("172f3a")
	plate.outline_size = 0
	plate.position = Vector3(0,.96,3.20)
	add_child(plate)
	var route_label := Label3D.new()
	route_label.text = "紅VAN  •  HUSTLE"
	route_label.font_size = 26
	route_label.pixel_size = .0065
	route_label.modulate = Color("fff0ba")
	route_label.outline_size = 0
	route_label.position = Vector3(0,3.12,-2.33)
	route_label.rotation.y = PI
	add_child(route_label)
	var rear := Label3D.new()
	rear.text = "PUBLIC LIGHT BUS\n19 SEATS  •  BIG DREAMS"
	rear.font_size = 26
	rear.pixel_size = .006
	rear.outline_size = 0
	rear.modulate = Color("183b42")
	rear.position = Vector3(0,1.58,3.09)
	add_child(rear)
	if controlled and DisplayServer.get_name() != "headless":
		engine = AudioStreamPlayer.new()
		engine.stream = load("res://assets/audio/engine.wav")
		engine.volume_db = -26
		add_child(engine)
		engine.play()

func _style(n: Node):
	if n is MeshInstance3D:
		var mesh_node := n as MeshInstance3D
		for i in mesh_node.mesh.get_surface_count():
			var source := mesh_node.get_active_material(i)
			if source is StandardMaterial3D:
				var m := ShaderMaterial.new()
				m.shader = preload("res://assets/shaders/toon.gdshader")
				var color: Color = source.albedo_color
				if "Chilli" in source.resource_name: color = body_color
				m.set_shader_parameter("paint",color)
				mesh_node.set_surface_override_material(i,m)
	if str(n.name).begins_with("Tire"): wheels.append(n)
	for child in n.get_children(): _style(child)

func _physics_process(delta: float):
	door_slide = move_toward(door_slide,1.0 if door_open else 0.0,delta*3)
	if sliding_door: sliding_door.position.z = -1.55+door_slide*1.35
	if brake_material: brake_material.albedo_color = Color("ff674b") if speed<.5 or Input.is_action_pressed("brake") else Color("8f2828")
	if not controlled: return
	bump_cooldown = maxf(0,bump_cooldown-delta)
	var throttle := Input.get_action_strength("accelerate") if enabled else 0.0
	var reverse := Input.get_action_strength("reverse") if enabled else 0.0
	var braking := Input.is_action_pressed("brake") or not enabled
	var turn := Input.get_action_strength("left") - Input.get_action_strength("right") if enabled else 0.0
	steering = move_toward(steering,turn,delta*5)
	var previous_speed := speed
	if braking:
		speed = move_toward(speed,0,delta*23)
	elif throttle > 0:
		speed = move_toward(speed,max_speed,delta*acceleration)
	elif reverse > 0:
		speed = move_toward(speed,-8.0,delta*(20 if speed>0 else 8))
	else:
		speed = move_toward(speed,0,delta*3.0)
	var turn_ratio := clampf(absf(speed)/6,0,1) * (1.0 - .28*clampf(absf(speed)/max_speed,0,1))
	rotation.y += steering * turn_ratio * signf(speed) * delta * 1.75
	var forward := -global_transform.basis.z
	velocity.x = forward.x*speed
	velocity.z = forward.z*speed
	velocity.y -= 24*delta
	move_and_slide()
	if is_on_floor(): velocity.y = 0
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if absf(hit.get_normal().y) < .4:
			if absf(speed)>4 and bump_cooldown<=0:
				bumped.emit(absf(speed))
				bump_cooldown = 1.1
			speed *= .55
			break
	distance_driven += absf(speed)*delta
	for wheel in wheels: wheel.rotate_object_local(Vector3.UP,speed*delta/.54)
	if visual:
		visual.rotation.z = lerpf(visual.rotation.z,-steering*speed*.004,delta*6)
		visual.rotation.x = lerpf(visual.rotation.x,clampf((previous_speed-speed)*.02,-.06,.06),delta*5)
		visual.position.y = sin(distance_driven*1.6)*.015*clampf(absf(speed)/10,0,1)
	if engine:
		engine.pitch_scale = .7 + absf(speed)/max_speed*1.1
		engine.volume_db = -28 if not enabled else -23

func reset_at(p: Vector3, heading := 0.0):
	global_position = p + Vector3(0,.05,0)
	rotation = Vector3(0,heading,0)
	speed = 0
	velocity = Vector3.ZERO

func apply_livery(color: Color, seat_count: int):
	body_color = color
	_recolor(visual)
	for child in get_children():
		if child is Label3D and child.text.begins_with("PUBLIC LIGHT BUS"):
			child.text = "PUBLIC LIGHT BUS\n%d SEATS  •  BIG DREAMS"%seat_count

func _recolor(n: Node):
	if n is MeshInstance3D:
		for i in n.mesh.get_surface_count():
			var original: Material = n.mesh.surface_get_material(i)
			if original and "Chilli" in original.resource_name:
				n.get_surface_override_material(i).set_shader_parameter("paint",body_color)
	for child in n.get_children(): _recolor(child)

func little_box(parent: Node3D, where: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/toon.gdshader")
	mat.set_shader_parameter("paint",color)
	mesh.material = mat
	node.mesh = mesh
	parent.add_child(node)
	node.position = where
	return node

func build_door_and_brakelights():
	little_box(visual,Vector3(-1.255,1.58,-1.55),Vector3(.05,1.9,1.25),Color("173840"))
	sliding_door = Node3D.new()
	visual.add_child(sliding_door)
	sliding_door.position = Vector3(-1.3,1.58,-1.55)
	little_box(sliding_door,Vector3.ZERO,Vector3(.08,1.9,1.23),Color("eed49c"))
	little_box(sliding_door,Vector3(-.05,.4,0),Vector3(.02,.86,1.02),Color("164c59"))
	little_box(sliding_door,Vector3(-.07,-.2,.4),Vector3(.05,.15,.08),Color("20383e"))
	brake_material = StandardMaterial3D.new()
	brake_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	brake_material.albedo_color = Color("8f2828")
	for x in [-.88,.88]:
		var lamp := little_box(visual,Vector3(x,1.39,3.13),Vector3(.36,.23,.04),Color("ff674b"))
		lamp.material_override = brake_material
