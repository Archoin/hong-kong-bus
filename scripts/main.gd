extends Node3D

const D = preload("res://scripts/district.gd")
const QUIPS = ["Auntie says: this is NOT my stop!", "The pineapple bun has right of way.", "Your passengers have discovered prayer.", "That wall does not accept Octopus.", "Five stars for enthusiasm. One for parking."]
var state := "title"
var race := BusRace.new()
var player: Minibus
var camera: Camera3D
var hud: Control
var rivals: Array[RivalDriver] = []
var stops: Array[BusStopVisual] = []
var wallet := 0
var upgrades := {"seats":0,"engine":0,"doors":0}
var premium_owned := false
var premium_equipped := false
var selected_stop := 0
var countdown := 3.0
var service_timer := 0.0
var current_stop := -1
var service_status := "Find a stop. Fill your seats. Follow the money."
var toast := ""
var toast_time := 0.0
var toast_color := Color("ffce73")
var fare_flash := 0.0
var impact_shake := 0.0
var reset_cooldown := 0.0
var show_map := false
var camera_high := false
var muted := false
var sounds := {}
var music: AudioStreamPlayer
var visual_timer := 0.0
var elapsed := 0.0
var payout_committed := false
var last_payout := 0
var best_cash := 0
var races_played := 0
var save_path := "user://garage.cfg"
var capture_mode := ""
var capture_at := 0.0

func _ready():
	configure_input()
	if "--test-mode" in OS.get_cmdline_user_args(): save_path = "user://garage_test.cfg"
	load_progress()
	add_child(preload("res://scenes/district.tscn").instantiate())
	player = Minibus.new()
	player.name = "PlayerMinibus"
	add_child(player)
	player.reset_at(Vector3(-96,0,-27))
	player.apply_livery(Color("348b72") if premium_equipped else Color("c43d38"),capacity())
	player.bumped.connect(_on_bump)
	camera = Camera3D.new()
	camera.fov = 66
	camera.far = 600
	add_child(camera)
	camera.current = true
	camera.position = Vector3(-109,7,-14)
	camera.look_at(player.position+Vector3(0,1.7,0))
	for i in 6:
		var stop := BusStopVisual.new()
		stop.stop_id = i
		add_child(stop)
		stop.position = D.STOP_POS[i]
		stops.append(stop)
	race.begin()
	race.active = false
	update_stop_visuals()
	hud = preload("res://scripts/hud.gd").new()
	hud.game = self
	var layer := CanvasLayer.new()
	layer.add_child(hud)
	add_child(layer)
	for sound in ["horn","coin","board","bump","bell"]:
		var audio := AudioStreamPlayer.new()
		audio.stream = load("res://assets/audio/"+sound+".wav")
		audio.volume_db = -10
		add_child(audio)
		sounds[sound] = audio
	music = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/audio/music.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	music.stream = stream
	music.volume_db = -21
	add_child(music)
	if DisplayServer.get_name() != "headless": music.play()
	if player.engine:
		var eng: AudioStreamWAV = player.engine.stream.duplicate()
		eng.loop_mode = AudioStreamWAV.LOOP_FORWARD
		eng.loop_end = int(eng.get_length()*eng.mix_rate)
		player.engine.stream = eng
		player.engine.play()
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--capture="): capture_mode = arg.trim_prefix("--capture=")
	if "--showcase" in args:
		start_race()
		countdown = 0
		state = "race"
		race.active = true
		player.enabled = true
		player.reset_at(Vector3(-96,0,-37))
		for i in 12: race.service(0,0)
		selected_stop = 1
		notify("FULL-TIME DRIVER. PART-TIME LEGEND.")

func configure_input():
	var bindings := {"accelerate":[KEY_W,KEY_UP],"reverse":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"brake":[KEY_SPACE],"horn":[KEY_H],"reset_bus":[KEY_R],"map":[KEY_M,KEY_TAB],"camera":[KEY_C],"pause":[KEY_ESCAPE],"confirm":[KEY_ENTER],"mute":[KEY_F8]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("mute"):
		muted = not muted
		AudioServer.set_bus_mute(0,muted)
	if event.is_action_pressed("confirm"):
		if state == "title" or state == "garage" or state == "results": start_race()
		elif state == "paused": resume_race()
	if event.is_action_pressed("pause"):
		if state == "race": pause_race()
		elif state == "paused": resume_race()
		elif state == "garage": return_to_title()
	if state != "race": return
	if event.is_action_pressed("horn"):
		play_sound("horn")
		notify(["BEEP BEEP. Small bus, big ambitions.","Auntie has right of way.","Next stop: financial independence."][randi()%3],Color("8ce1cd"),2)
	if event.is_action_pressed("reset_bus"): rescue_bus()
	if event.is_action_pressed("map"): show_map = not show_map
	if event.is_action_pressed("camera"): camera_high = not camera_high
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			selected_stop = event.keycode-KEY_1
			play_sound("board")

func _process(delta: float):
	elapsed += delta
	toast_time = maxf(0,toast_time-delta)
	fare_flash = maxf(0,fare_flash-delta)
	impact_shake = maxf(0,impact_shake-delta*2)
	reset_cooldown = maxf(0,reset_cooldown-delta)
	if state == "countdown":
		countdown -= delta
		if countdown <= 0:
			state = "race"
			race.active = true
			player.enabled = true
			play_sound("bell")
			notify("STOP IN THE GOLD BAY • passengers board automatically",Color("ffce73"),5)
	elif state == "race":
		race.tick(delta)
		if not race.active:
			end_race()
		else:
			for rival in rivals: rival.tick(delta)
			service_player(delta)
			if player.position.y < -8: rescue_bus()
	visual_timer += delta
	if visual_timer > .25:
		visual_timer = 0
		update_stop_visuals()
	update_camera(delta)
	hud.queue_redraw()
	if not capture_mode.is_empty() and elapsed > 2:
		capture_at += delta
		if capture_at > .3:
			var directory := "res://captures" if OS.has_feature("editor") else "user://captures"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
			get_viewport().get_texture().get_image().save_png(directory+"/"+capture_mode+".png")
			print("CAPTURE_SAVED ",capture_mode)
			capture_mode = ""
			get_tree().quit()

func start_race():
	for rival in rivals:
		remove_child(rival)
		rival.queue_free()
	rivals.clear()
	race.begin(capacity())
	race.active = false
	player.set_physics_process(true)
	player.reset_at(Vector3(-96,0,-27))
	player.apply_livery(Color("348b72") if premium_equipped else Color("c43d38"),capacity())
	player.max_speed = (26.0 if premium_equipped else 23.0) + upgrades.engine*2
	player.acceleration = 11.0+upgrades.engine*1.7
	player.distance_driven = 0
	player.enabled = false
	player.door_open = false
	selected_stop = 0
	current_stop = -1
	service_timer = 0
	show_map = false
	toast_time = 0
	payout_committed = false
	for i in range(1,4):
		var rival := RivalDriver.new()
		add_child(rival)
		rival.setup(race,i,[0,2,4,5][i])
		rivals.append(rival)
	countdown = 3
	state = "countdown"
	camera.position = player.position+Vector3(0,9,17)
	update_stop_visuals()

func service_player(delta: float):
	player.door_open = false
	var nearest := -1
	var distance := 8.0
	for i in 6:
		var d: float = Vector2(player.position.x-D.STOP_POS[i].x,player.position.z-D.STOP_POS[i].z).length()
		if d < distance:
			nearest = i
			distance = d
	if nearest != current_stop:
		service_timer = 0
		current_stop = nearest
	if current_stop == -1:
		service_status = "Choose your next stop • 1–6 to pin a destination"
		return
	if absf(player.speed) > 1.1:
		service_status = "HOLD SPACE  •  Stop to open the doors"
		service_timer = 0
		return
	player.door_open = true
	var counts := race.destinations()
	var full: bool = race.drivers[0].riders.size() >= capacity()
	if counts[current_stop] > 0:
		service_status = "ALIGHTING  •  %s" % D.STOP_NAMES[current_stop]
	elif full:
		service_status = "FULL HOUSE!  •  Deliver passengers to free seats"
		service_timer = 0
		return
	elif race.queues[current_stop].is_empty():
		service_status = "ALL ABOARD  •  Pick a destination and go!"
		service_timer = 0
		return
	else:
		service_status = "BOARDING  •  %s" % D.STOP_NAMES[current_stop]
	service_timer += delta
	var interval: float = (.28 if counts[current_stop]>0 else .46) / (1.0+upgrades.doors*.22)
	if service_timer >= interval:
		service_timer = 0
		var event := race.service(0,current_stop)
		if event.is_empty(): return
		if event.kind == "drop":
			play_sound("coin")
			fare_flash = .65
			notify("+HK$%d   •   %s" % [event.fare,["Exact change. Immaculate vibes.","Auntie approves.","Another satisfied bun enthusiast.","Ding! That's the sound of rent money."][race.delivered%4]],Color("a9df90"),2)
		else:
			play_sound("board")
			if selected_stop == current_stop: selected_stop = event.rider.dest
			if race.picked_up % 5 == 1:
				notify("PASSENGER: %s, please!"%D.STOP_NAMES[event.rider.dest],Color("9fddd2"),2.2)
		animate_passenger(event.kind == "board")
		update_stop_visuals()

func animate_passenger(boarding: bool):
	var p := BusStopVisual.person(randi()%6)
	add_child(p)
	var curb: Vector3 = D.STOP_POS[current_stop]+(Vector3(-5,0,-10) if current_stop==1 or current_stop==4 else Vector3(-10,0,-2))
	var door := player.position - player.global_transform.basis.x*1.6 - player.global_transform.basis.z*1.55
	p.position = curb if boarding else door
	var tw := create_tween()
	tw.tween_property(p,"position",door if boarding else curb,.5)
	tw.tween_callback(p.queue_free)

func end_race():
	if payout_committed: return
	if not race.settled: race.finish()
	last_payout = race.drivers[0].cash + race.last_bonus
	wallet += last_payout
	best_cash = maxi(best_cash,race.drivers[0].cash)
	races_played += 1
	payout_committed = true
	player.enabled = false
	state = "results"
	show_map = false
	play_sound("bell")
	save_progress()

func pause_race():
	state = "paused"
	player.enabled = false
	player.set_physics_process(false)

func resume_race():
	state = "race"
	player.enabled = true
	player.set_physics_process(true)

func rescue_bus():
	if reset_cooldown>0: return
	var p := D.nearest_road(player.position)
	player.reset_at(p)
	reset_cooldown = 4
	# A time penalty is predictable and cannot take the score below zero.
	race.remaining = maxf(0,race.remaining-3)
	notify("ROADSIDE RESCUE  •  Back on the road. −3 seconds.",Color("ffb18a"),3)

func _on_bump(_impact: float):
	if state != "race": return
	impact_shake = .3
	play_sound("bump")
	notify(QUIPS[randi()%QUIPS.size()],Color("ffb18a"),3)

func update_camera(delta: float):
	var target := player.global_position+Vector3(0,2.0,0)
	var desired: Vector3
	if state in ["title","garage"]:
		desired = player.position+Vector3(-11.5,6.5,-13.0)
		target += Vector3(4.5,0,-4)
	else:
		var behind := player.global_transform.basis.z
		desired = player.position + behind*(21.0 if camera_high else 13.0) + Vector3(0,17.0 if camera_high else 7.5,0)
		# Pull in before architecture, rather than allowing the chase view through walls.
		var query := PhysicsRayQueryParameters3D.create(target,desired,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): desired = hit.position + hit.normal*.6
	camera.position = camera.position.lerp(desired,1-exp(-delta*6))
	if camera.position.distance_to(target) > .1: camera.look_at(target)
	camera.fov = lerpf(camera.fov,66+absf(player.speed)*.22,delta*2)
	if impact_shake>0: camera.h_offset = sin(elapsed*90)*impact_shake*.2
	else: camera.h_offset = 0

func update_stop_visuals():
	var counts := race.destinations()
	for i in stops.size():
		stops[i].update_display(race.queues[i].size(),counts[i],selected_stop==i)
		stops[i].sign_label.visible = state in ["race","countdown","paused"]

func capacity() -> int:
	return (23 if premium_equipped else 19)+upgrades.seats*4

func upgrade_cost(kind: String) -> int:
	return {"seats":260,"engine":220,"doors":180}[kind]*(upgrades[kind]+1)

func purchase(kind: String):
	if kind == "bus":
		if premium_owned:
			premium_equipped = not premium_equipped
		else:
			if wallet<1400:
				notify("A few more fares! The Jade Express costs HK$1,400.")
				return
			wallet -= 1400
			premium_owned = true
			premium_equipped = true
	else:
		if upgrades[kind] >= 3: return
		var cost := upgrade_cost(kind)
		if wallet < cost:
			notify("Not enough in the biscuit tin. Earn more fares!")
			return
		wallet -= cost
		upgrades[kind] += 1
	player.apply_livery(Color("348b72") if premium_equipped else Color("c43d38"),capacity())
	play_sound("coin")
	notify("GARAGE SORTED  •  Ready for another shift.",Color("a9df90"))
	save_progress()

func load_progress():
	var cfg := ConfigFile.new()
	if cfg.load(save_path)!=OK: return
	wallet = maxi(0,int(cfg.get_value("garage","wallet",0)))
	for kind in upgrades: upgrades[kind] = clampi(int(cfg.get_value("garage",kind,0)),0,3)
	premium_owned = bool(cfg.get_value("garage","premium_owned",false))
	premium_equipped = premium_owned and bool(cfg.get_value("garage","premium_equipped",false))
	best_cash = maxi(0,int(cfg.get_value("stats","best",0)))
	races_played = maxi(0,int(cfg.get_value("stats","races",0)))

func save_progress():
	var cfg := ConfigFile.new()
	cfg.set_value("garage","wallet",wallet)
	for kind in upgrades: cfg.set_value("garage",kind,upgrades[kind])
	cfg.set_value("garage","premium_owned",premium_owned)
	cfg.set_value("garage","premium_equipped",premium_equipped)
	cfg.set_value("stats","best",best_cash)
	cfg.set_value("stats","races",races_played)
	var result := cfg.save(save_path)
	if result != OK: push_warning("Could not save garage: "+str(result))

func notify(message: String, color := Color("ffce73"), duration := 3.0):
	toast = message
	toast_time = duration
	toast_color = color

func play_sound(sound: String):
	if DisplayServer.get_name() == "headless": return
	if sounds.has(sound): sounds[sound].play()

func _exit_tree():
	for audio in sounds.values(): audio.stop()
	if is_instance_valid(music): music.stop()
	if is_instance_valid(player) and is_instance_valid(player.engine): player.engine.stop()

func return_to_title():
	state = "title"
	race.active = false
	player.enabled = false
	player.set_physics_process(true)
	player.reset_at(Vector3(-96,0,-27))
	show_map = false
	for rival in rivals:
		remove_child(rival)
		rival.queue_free()
	rivals.clear()
	update_stop_visuals()
