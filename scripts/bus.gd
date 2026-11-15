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
var bump_cooldown := 0.0
var engine: AudioStreamPlayer
var body_color := Color("c43d38")
var wheels: Array[Node3D] = []
var controlled := true
var door_open := false
var door_slide := 0.0
var sliding_door: Node3D
var brake_material: StandardMaterial3D
var hull: CollisionShape3D
var rear_label: Label3D
var route_display: Label3D
var side_labels: Array[Label3D] = []
var front_wheel_pivots: Array[Node3D] = []
var steering_angle := 0.0
var lateral_accel := 0.0
var last_stop_approach_speed := 0.0
var last_brake_peak := 0.0
var seconds_since_impact := 999.0
var ground_pitch := 0.0
var ground_roll := 0.0
var _drive_velocity := Vector3.ZERO
var _ground_normal := Vector3.UP
var _approach_peak := 0.0
var _brake_peak := 0.0
var _was_moving := false
var _last_braking := false

const WHEELBASE := 3.8
const SERVICE_BRAKE := 24.0
const REVERSE_LIMIT := 8.0

func _ready():
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 1.1
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(42.0)
	max_slides = 6
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5,2.6,5.9)
	col.shape = shape
	col.position.y = 1.32
	add_child(col)
	hull = col
	visual = preload("res://assets/models/minibus.glb").instantiate()
	add_child(visual)
	_style(visual)
	build_wheel_rig()
	build_door_and_brakelights()
	var plate := Label3D.new()
	plate.text = "HK  1988"
	plate.font_size = 34
	plate.pixel_size = .006
	plate.modulate = Color("172f3a")
	plate.outline_size = 0
	plate.position = Vector3(0,.96,3.20)
	visual.add_child(plate)
	var route_label := Label3D.new()
	route_label.text = "中環 · 西營盤"
	route_label.font_size = 26
	route_label.pixel_size = .0065
	route_label.modulate = Color("fff0ba")
	route_label.outline_size = 0
	route_label.position = Vector3(0,3.12,-2.33)
	route_label.rotation.y = PI
	visual.add_child(route_label)
	route_display=route_label
	var rear := Label3D.new()
	rear.text = "PUBLIC LIGHT BUS\n19 SEATS  •  BIG DREAMS"
	rear.font_size = 26
	rear.pixel_size = .006
	rear.outline_size = 0
	rear.modulate = Color("fff0ba")
	rear.position = Vector3(0,2.18,3.09)
	visual.add_child(rear)
	rear_label = rear
	for side in [-1,1]:
		var lettering := Label3D.new()
		lettering.text="PUBLIC LIGHT BUS  19 SEATS"
		lettering.font_size=26
		lettering.pixel_size=.009
		lettering.modulate=Color("fff2cd")
		lettering.outline_size=0
		lettering.position=Vector3(side*1.252,2.86,.12)
		lettering.rotation.y=side*PI/2
		visual.add_child(lettering)
		side_labels.append(lettering)
	# The hand-written-style fare card is an iconic minibus detail, not a HUD duplicate.
	little_box(visual,Vector3(.62,2.08,-2.98),Vector3(.45,.29,.025),Color("f4e6bf"))
	var fare_card := Label3D.new()
	fare_card.text="$14"
	fare_card.font_size=32
	fare_card.pixel_size=.006
	fare_card.outline_size=0
	fare_card.modulate=Color("b5342f")
	fare_card.position=Vector3(.62,2.08,-3.0)
	fare_card.rotation.y=PI
	visual.add_child(fare_card)
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
	door_slide = move_toward(door_slide,1.0 if door_open and absf(speed)<1.2 else 0.0,delta*3)
	if sliding_door: sliding_door.position.z = -1.55+door_slide*1.35
	if brake_material:
		brake_material.albedo_color = Color("ff674b") if _last_braking or absf(speed)<.4 else Color("8f2828")
	if not controlled: return
	bump_cooldown = maxf(0,bump_cooldown-delta)
	seconds_since_impact += delta
	var throttle := Input.get_action_strength("accelerate") if enabled else 0.0
	var reverse := Input.get_action_strength("reverse") if enabled else 0.0
	var braking := Input.is_action_pressed("brake") or not enabled
	var turn := Input.get_action_strength("left") - Input.get_action_strength("right") if enabled else 0.0
	var previous_speed := speed
	var previous_position := global_position
	# The input rack responds quickly, but returns faster so keyboard taps remain precise.
	var rack_rate := 7.5 if absf(turn)<.01 else 5.8
	steering = move_toward(steering,turn,delta*rack_rate)
	if braking:
		speed = move_toward(speed,0,delta*SERVICE_BRAKE)
		if absf(speed)<.25: speed=0
	elif throttle > 0:
		var engine_pull := acceleration * throttle
		if speed < -.1: engine_pull = 20.0
		speed = move_toward(speed,max_speed*throttle,delta*engine_pull)
	elif reverse > 0:
		speed = move_toward(speed,-REVERSE_LIMIT*reverse,delta*(20.0 if speed>0 else 8.0))
	else:
		speed = move_toward(speed,0,delta*(1.0+absf(speed)*.065))
	# Bicycle-like steering: tight low-speed manoeuvres and a wider, stable fast arc.
	var speed_blend := smoothstep(5.0,26.0,absf(speed))
	var rack_limit := lerpf(.64,.25,speed_blend)
	steering_angle = steering*rack_limit
	var yaw_rate := clampf(speed/WHEELBASE*tan(steering_angle),-1.65,1.65)
	rotation.y += yaw_rate*delta
	lateral_accel = absf(speed*yaw_rate)
	var forward := -global_transform.basis.z
	var target_velocity := forward*speed
	var grip := 16.0 if braking else lerpf(13.0,8.0,speed_blend)
	_drive_velocity = _drive_velocity.lerp(target_velocity,1.0-exp(-grip*delta))
	# At parking speed there is no invisible sideways glide after a precise stop.
	if absf(speed)<.2 and braking: _drive_velocity=Vector3.ZERO
	velocity.x = _drive_velocity.x
	velocity.z = _drive_velocity.z
	velocity.y = -2.0 if is_on_floor() else velocity.y-26.0*delta
	move_and_slide()
	var max_impact := 0.0
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if absf(hit.get_normal().y) < .4:
			var wall_normal := hit.get_normal()
			wall_normal.y=0
			wall_normal=wall_normal.normalized()
			var impact := maxf(0.0,-target_velocity.dot(wall_normal))
			max_impact=maxf(max_impact,impact)
			var facing_wall := maxf(0.0,-(forward*signf(speed)).dot(wall_normal))
			if facing_wall>.72:
				speed *= maxf(0.0,1.0-facing_wall)
			else:
				# Scrapes remove the into-wall component, not most of the forward speed.
				speed=move_toward(speed,0,delta*(1.5+impact*.12))
			_drive_velocity=Vector3(velocity.x,0,velocity.z)
	if max_impact>3.2 and bump_cooldown<=0:
		bumped.emit(max_impact)
		seconds_since_impact=0
		bump_cooldown=.85
	if is_on_floor():
		_ground_normal=_ground_normal.lerp(get_floor_normal(),1.0-exp(-delta*10.0)).normalized()
		velocity.y=0
	else:
		_ground_normal=_ground_normal.lerp(Vector3.UP,1.0-exp(-delta*3.0)).normalized()
	_update_ground_pose(delta)
	var travelled := Vector2(global_position.x-previous_position.x,global_position.z-previous_position.z).length()
	distance_driven += travelled
	for wheel in wheels: wheel.rotate_object_local(Vector3.UP,travelled*signf(speed)/.54)
	for pivot in front_wheel_pivots: pivot.rotation.y=steering_angle
	var longitudinal_accel := (speed-previous_speed)/maxf(delta,.001)
	_brake_peak=maxf(_brake_peak,-longitudinal_accel)
	_approach_peak=maxf(_approach_peak,absf(speed))
	if absf(speed)<.3 and _was_moving:
		last_stop_approach_speed=_approach_peak
		last_brake_peak=_brake_peak
		_approach_peak=0
		_brake_peak=0
	_was_moving=absf(speed)>=.3
	_last_braking=braking or (reverse>0 and previous_speed>0)
	if visual:
		var body_roll := clampf(-yaw_rate*speed*.0045,-.10,.10)
		var body_pitch := clampf(-longitudinal_accel*.0025,-.045,.065)
		visual.rotation.z=lerpf(visual.rotation.z,ground_roll+body_roll,1.0-exp(-delta*7.0))
		visual.rotation.x=lerpf(visual.rotation.x,ground_pitch+body_pitch,1.0-exp(-delta*7.0))
		visual.position.y=sin(distance_driven*1.5)*.012*clampf(absf(speed)/10,0,1)
	if engine:
		# Small pitch rises during acceleration and falls under service braking.
		var desired_pitch := .7+absf(speed)/max_speed*1.0+throttle*.12
		engine.pitch_scale=lerpf(engine.pitch_scale,desired_pitch,1.0-exp(-delta*5.0))
		engine.volume_db=-28 if not enabled else -23

func _update_ground_pose(delta: float):
	var local_up := global_transform.basis.inverse()*_ground_normal
	ground_pitch=clampf(atan2(local_up.z,local_up.y),-.55,.55)
	ground_roll=clampf(-atan2(local_up.x,local_up.y),-.35,.35)
	# Keep the physical hull parallel to a hill without tilting the yaw/camera root.
	var slope_basis := Basis.from_euler(Vector3(ground_pitch,0,ground_roll))
	hull.basis=hull.basis.slerp(slope_basis,1.0-exp(-delta*9.0)).orthonormalized()
	hull.position=hull.basis*Vector3(0,1.32,0)

func telemetry() -> Dictionary:
	return {"speed":absf(speed), "lateral_accel":lateral_accel,
		"last_stop_approach_speed":last_stop_approach_speed,
		"last_brake_peak":last_brake_peak, "seconds_since_impact":seconds_since_impact,
		"steering":steering, "ground_pitch":ground_pitch, "ground_roll":ground_roll}

func reset_at(p: Vector3, heading := 0.0):
	global_position = p + Vector3(0,.05,0)
	rotation = Vector3(0,heading,0)
	speed = 0
	velocity = Vector3.ZERO
	_drive_velocity=Vector3.ZERO
	steering=0
	steering_angle=0
	lateral_accel=0
	_ground_normal=Vector3.UP
	ground_pitch=0
	ground_roll=0
	_approach_peak=0
	_brake_peak=0
	_was_moving=false
	_last_braking=false
	last_stop_approach_speed=0
	last_brake_peak=0
	seconds_since_impact=999
	bump_cooldown=0
	if hull:
		hull.rotation=Vector3.ZERO
		hull.position=Vector3(0,1.32,0)
	if visual: visual.rotation=Vector3.ZERO

func apply_livery(color: Color, seat_count: int):
	body_color = color
	_recolor(visual)
	if is_instance_valid(rear_label):
		rear_label.text = "PUBLIC LIGHT BUS\n%d SEATS  •  BIG DREAMS"%seat_count
	for label in side_labels: label.text="PUBLIC LIGHT BUS  %d SEATS"%seat_count

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

func build_wheel_rig():
	var tire_meshes: Array[Node3D] = wheels.duplicate()
	var wheel_parts: Array[Node3D] = []
	for child in visual.get_children():
		if str(child.name).begins_with("Tire") or str(child.name).begins_with("Cylinder"):
			wheel_parts.append(child)
	wheels.clear()
	for tire in tire_meshes:
		var center := tire.position
		var pivot := Node3D.new()
		pivot.name="SteeringPivot"
		visual.add_child(pivot)
		pivot.position=center
		var spin := Node3D.new()
		spin.name="WheelSpin"
		pivot.add_child(spin)
		# Keep the established wheels API: rotate around local UP to spin the axle.
		spin.rotation.z=-PI/2
		for part in wheel_parts:
			if part.get_parent()==visual and part.position.distance_to(center)<.45:
				part.reparent(spin,true)
		wheels.append(spin)
		if center.z<0: front_wheel_pivots.append(pivot)

func set_remote_motion(direction: Vector3, travel_speed: float, delta: float):
	# AI owns its road-graph position; this shares the visible suspension and wheels.
	var previous_speed := speed
	speed=maxf(0,travel_speed)
	_last_braking=speed<.4 or speed<previous_speed-.2
	if direction.length_squared()>.001:
		var travel_direction := direction.normalized()
		var right := travel_direction.cross(Vector3.UP).normalized()
		var road_up := right.cross(travel_direction).normalized()
		_ground_normal=_ground_normal.lerp(road_up,1.0-exp(-delta*10.0)).normalized()
		var local_direction := global_transform.basis.inverse()*travel_direction
		steering_angle=clampf(atan2(-local_direction.x,-local_direction.z),-.6,.6)
	_update_ground_pose(delta)
	for wheel in wheels: wheel.rotate_object_local(Vector3.UP,speed*delta/.54)
	for pivot in front_wheel_pivots: pivot.rotation.y=steering_angle
	visual.rotation.x=lerpf(visual.rotation.x,ground_pitch,1.0-exp(-delta*7.0))
	visual.rotation.z=lerpf(visual.rotation.z,ground_roll,1.0-exp(-delta*7.0))

func set_route_display(text: String):
	if route_display: route_display.text=text
