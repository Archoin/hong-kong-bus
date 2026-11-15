extends SceneTree

var bus: Minibus
var arena: Node3D
var failures := 0
var metrics := {}
var hill_degrees := 12.0

func _initialize(): call_deferred("run")

func frames(count: int):
	for i in count: await physics_frame

func body_box(where: Vector3, dimensions: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	c.shape = shape
	b.add_child(c)
	arena.add_child(b)
	b.position=where
	return b

func clear_input():
	for a in ["accelerate","reverse","brake","left","right"]: Input.action_release(a)

func reset(position := Vector3.ZERO, yaw := 0.0):
	clear_input()
	bus.reset_at(position,yaw)
	bus.enabled=true
	bus.max_speed=23
	await frames(8)

func require(condition: bool, message: String):
	if not condition:
		failures+=1
		push_error(message)

func run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hill-degrees="): hill_degrees=float(argument.get_slice("=",1))
	var hill_angle := deg_to_rad(hill_degrees)
	for action in ["accelerate","reverse","brake","left","right"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	arena=Node3D.new()
	root.add_child(arena)
	body_box(Vector3(0,-.5,0),Vector3(500,1,500))
	bus=Minibus.new()
	arena.add_child(bus)
	await frames(5)
	await reset()
	Input.action_press("accelerate")
	await frames(120)
	metrics["speed_after_2s"]=bus.speed
	var before: Vector3=bus.position
	Input.action_release("accelerate")
	Input.action_press("brake")
	await frames(90)
	metrics["brake_distance_from_22ms"]=before.distance_to(bus.position)
	require(absf(bus.speed)<.1,"brake must stop")
	for speed in [8.0,23.0]:
		await reset()
		bus.max_speed=speed
		bus.speed=speed
		Input.action_press("accelerate")
		Input.action_press("left")
		await frames(60)
		metrics["turn_degrees_at_%d"%speed]=rad_to_deg(bus.rotation.y)
		metrics["turn_position_at_%d"%speed]=[bus.position.x,bus.position.y,bus.position.z]
	# Parallel wall, with a shallow collision angle: a glancing scrape should slide.
	var wall := body_box(Vector3(6,3,0),Vector3(1,6,180))
	await reset(Vector3(3,0,30),-.10)
	bus.speed=16
	Input.action_press("accelerate")
	await frames(90)
	metrics["scrape_travel"]=30-bus.position.z
	metrics["scrape_exit_speed"]=bus.speed
	wall.queue_free()
	await frames(2)
	# Frontal collision must stop forward penetration.
	var barrier := body_box(Vector3(0,3,-15),Vector3(30,6,1))
	await reset()
	bus.speed=18
	Input.action_press("accelerate")
	await frames(100)
	metrics["head_on_z"]=bus.position.z
	metrics["head_on_speed"]=bus.speed
	require(bus.position.z>-12,"frontal wall blocks bus")
	barrier.queue_free()
	await frames(2)
	# Recovery from a nose-first wall remains available through the existing S input.
	await reset()
	bus.speed=18
	Input.action_press("accelerate")
	var recovery_wall := body_box(Vector3(0,3,-15),Vector3(30,6,1))
	await frames(90)
	var hit_z := bus.position.z
	Input.action_release("accelerate")
	Input.action_press("reverse")
	await frames(75)
	metrics["reverse_recovery_distance"]=bus.position.z-hit_z
	require(bus.position.z>hit_z+4,"reverse backs out of a frontal collision")
	recovery_wall.queue_free()
	await frames(2)
	# A real physical incline, including the flat-to-hill transition.
	var incline := body_box(Vector3(0,40*sin(hill_angle)-.5*cos(hill_angle),-40),Vector3(20,1,80))
	incline.rotation.x=hill_angle
	await reset(Vector3(0,0,8))
	bus.max_speed=16
	Input.action_press("accelerate")
	await frames(300)
	metrics["hill_test_degrees"]=hill_degrees
	metrics["hill_climb_y"]=bus.position.y
	metrics["hill_pitch_degrees"]=rad_to_deg(bus.visual.rotation.x)
	metrics["hill_climb_on_floor"]=bus.is_on_floor()
	require(bus.position.y>8,"bus climbs sloped road")
	require(absf(bus.visual.rotation.x)>deg_to_rad(7),"bus visibly follows road pitch")
	Input.action_release("accelerate")
	Input.action_press("brake")
	await frames(60)
	var stopped_on_hill := bus.position
	await frames(90)
	metrics["hill_park_drift"]=bus.position.distance_to(stopped_on_hill)
	require(bus.position.distance_to(stopped_on_hill)<.1,"braked bus holds position on hill")
	var downhill_start_y := 40*sin(hill_angle)+34*tan(hill_angle)+.5
	await reset(Vector3(0,downhill_start_y,-74),PI)
	bus.max_speed=16
	Input.action_press("accelerate")
	await frames(300)
	metrics["hill_descent_y"]=bus.position.y
	metrics["hill_descent_on_floor"]=bus.is_on_floor()
	require(bus.position.y<downhill_start_y*.3,"bus descends the hill")
	require(bus.is_on_floor(),"bus remains grounded descending")
	incline.queue_free()
	await frames(2)
	for cruise_speed in [23.0,30.0]:
		await reset()
		bus.max_speed=cruise_speed
		Input.action_press("accelerate")
		await frames(200)
		var braking_start := bus.position
		Input.action_release("accelerate")
		Input.action_press("brake")
		await frames(120)
		metrics["braking_distance_%d"%cruise_speed]=braking_start.distance_to(bus.position)
		require(absf(bus.speed)<.1,"brake stops from highway speed")
	clear_input()
	var file := FileAccess.open("res://captures/driving_probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"  "))
	print("HANDLING_PROBE ",JSON.stringify(metrics))
	print("HANDLING_FAILURES ",failures)
	arena.queue_free()
	await process_frame
	quit(1 if failures else 0)
