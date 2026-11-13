extends SceneTree

const D = preload("res://scripts/district.gd")
var finished := false
var game: Node3D
var target_stop := 0
var path: Array[Vector3] = []
var dwell := 0.0
var at_stop := false
var time := 0.0
var next_capture := 10.0
var captured := 0
var slow_time := 0.0
var reverse_recovery := 0.0
var recoveries := 0
var bumps := 0
var rescues := 0
var fps_samples: Array[float] = []

func _initialize(): call_deferred("run")

func run():
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save_path = "user://playtest_sandbox.cfg"
	game.wallet=0
	game.upgrades={"seats":0,"engine":0,"doors":0}
	game.premium_equipped=false
	game.start_race()
	game.race.begin(game.capacity(),20261113)
	game.race.active=false
	game.player.bumped.connect(func(_impact): bumps+=1)
	path = D.lane_route(D.nearest_road(game.player.position),D.STOP_POS[0])
	print("PLAYTEST_STARTED: physical keyboard-input autopilot, no teleportation")

func _physics_process(delta: float):
	if game == null or finished: return
	if game.state=="results":
		Input.action_release("accelerate")
		Input.action_release("left")
		Input.action_release("right")
		Input.action_release("brake")
		game.set_process(false)
		call_deferred("finish")
		finished = true
		return
	if game.state!="race": return
	time+=delta
	if int(time)%5==0: fps_samples.append(Engine.get_frames_per_second())
	if time>=next_capture:
		captured+=1
		next_capture+=40
		call_deferred("capture", "playtest_%02d"%captured)
		print("PLAYTEST t=%.0f cash=%d riders=%d pos=%s target=%d speed=%.1f"%[time,game.race.drivers[0].cash,game.race.drivers[0].riders.size(),str(game.player.position),target_stop,game.player.speed])
		for rival in game.rivals:
			print("AI ",rival.driver_id," cash=",game.race.drivers[rival.driver_id].cash," position=",rival.bus.position," blocked=",snapped(rival.blocked_time,.1)," target=",rival.target_stop)
	if reverse_recovery>0:
		reverse_recovery-=delta
		Input.action_release("accelerate")
		Input.action_release("brake")
		Input.action_release("left")
		Input.action_press("reverse")
		Input.action_press("right",.6)
		return
	Input.action_release("reverse")
	if not at_stop and game.current_stop==target_stop and absf(game.player.speed)<1.1:
		at_stop=true
		dwell=0
		path.clear()
	if at_stop:
		Input.action_release("accelerate")
		Input.action_press("brake")
		dwell+=delta
		if dwell>9 or (dwell>2 and game.race.destinations()[target_stop]==0 and (game.race.queues[target_stop].is_empty() or game.race.drivers[0].riders.size()==game.capacity())):
			choose_stop()
		return
	if path.is_empty():
		at_stop=true
		dwell=0
		return
	var p: Vector3 = game.player.position
	var waypoint: Vector3 = path[0]
	var offset := waypoint-p
	offset.y=0
	var distance := offset.length()
	var last := path.size()==1
	if distance < (5.0 if last else 5.5):
		path.pop_front()
		return
	var desired := atan2(-offset.x,-offset.z)
	var error := wrapf(desired-game.player.rotation.y,-PI,PI)
	Input.action_release("left")
	Input.action_release("right")
	if error>.035: Input.action_press("left",minf(1,error*2))
	elif error<-.035: Input.action_press("right",minf(1,-error*2))
	var target_speed := 17.0
	if distance<22: target_speed=9.0
	if absf(error)>.6: target_speed=7.0
	if last and distance<13: target_speed=5.0
	if game.player.speed>target_speed+1:
		Input.action_release("accelerate")
		Input.action_press("brake")
	else:
		Input.action_release("brake")
		Input.action_press("accelerate",1)
	if absf(game.player.speed)<1: slow_time+=delta
	else: slow_time=0
	if slow_time>2.5:
		print("PLAYTEST_REVERSE_MANEUVER ",game.player.position," target ",waypoint)
		reverse_recovery=1.1
		recoveries+=1
		slow_time=0

func choose_stop():
	var counts: Array = game.race.destinations()
	var best := -INF
	var chosen := (target_stop+1)%6
	for i in 6:
		if i==target_stop: continue
		var score: float = (counts[i]*5+minf(game.race.queues[i].size(),game.capacity()-game.race.drivers[0].riders.size())+1)/(D.STOP_POS[i].distance_to(game.player.position)+40)
		if score>best:
			best=score
			chosen=i
	path = D.lane_route(D.STOP_POS[target_stop],D.STOP_POS[chosen])
	target_stop=chosen
	game.selected_stop=chosen
	at_stop=false
	Input.action_release("brake")

func capture(label: String):
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/"+label+".png")

func finish():
	await capture("playtest_results")
	var report := {"time":time,"player_cash":game.race.drivers[0].cash,"delivered":game.race.delivered,"picked_up":game.race.picked_up,"rank":game.race.player_rank,"bumps":bumps,"rescues":rescues,"reverse_maneuvers":recoveries,"distance_m":game.player.distance_driven,"rival_cash":[game.race.drivers[1].cash,game.race.drivers[2].cash,game.race.drivers[3].cash]}
	var report_path := "res://captures/headless_playtest_report.json" if DisplayServer.get_name()=="headless" else "res://captures/playtest_report.json"
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("PLAYTEST_COMPLETE ",JSON.stringify(report))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	quit()
