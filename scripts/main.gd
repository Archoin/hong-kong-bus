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
var route_guide: RouteGuide
var trams: AmbientTrams
var express_mode := false
var express_destination := 0
var approach_stop := -1
var door_open_time := 0.0
var dispatch_focus := 0
var last_service_stop := -1
var service_interval := .25
var dock_grade := ""
var dock_grade_time := 0.0
var district_label := "Sheung Wan"
var street_label := ""
var street_label_timer := 0.0
var map_page := 0
var toast_priority := 0
var dispatch_auto_pin := false
var last_fares_announced := false

func _ready():
	configure_input()
	if "--test-mode" in OS.get_cmdline_user_args(): save_path = "user://garage_test.cfg"
	load_progress()
	add_child(preload("res://scenes/district.tscn").instantiate())
	player = Minibus.new()
	player.name = "PlayerMinibus"
	add_child(player)
	player.reset_at(D.SPAWN_POSITION,D.SPAWN_HEADING)
	player.apply_livery(Color("348b72") if premium_equipped else Color("c43d38"),capacity())
	player.bumped.connect(_on_bump)
	trams = AmbientTrams.new()
	trams.game=self
	add_child(trams)
	camera = Camera3D.new()
	camera.fov = 66
	camera.far = 1700
	add_child(camera)
	camera.current = true
	camera.position = player.position+Vector3(-11.5,7.0,-13.0)
	camera.look_at(player.position+Vector3(0,1.7,0))
	for i in D.STOP_POS.size():
		var stop := BusStopVisual.new()
		stop.stop_id = i
		add_child(stop)
		stop.position = D.STOP_POS[i]
		stops.append(stop)
	route_guide = RouteGuide.new()
	add_child(route_guide)
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
		player.reset_at(D.STOP_POS[0],D.SPAWN_HEADING)
		for i in 12: race.service(0,0)
		selected_stop = 1
		notify("FULL-TIME DRIVER. PART-TIME LEGEND.")

func configure_input():
	var bindings := {"accelerate":[KEY_W,KEY_UP],"reverse":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"brake":[KEY_SPACE],"horn":[KEY_H],"reset_bus":[KEY_R],"map":[KEY_M,KEY_TAB],"camera":[KEY_C],"pause":[KEY_ESCAPE],"confirm":[KEY_ENTER],"mute":[KEY_F8],"express":[KEY_E],"dispatch_a":[KEY_F],"dispatch_b":[KEY_G],"next_stop":[KEY_PERIOD],"previous_stop":[KEY_COMMA]}
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
		if state == "race":
			if show_map: show_map=false
			else: pause_race()
		elif state == "paused": resume_race()
		elif state == "garage": return_to_title()
	if state != "race": return
	if event.is_action_pressed("horn"):
		play_sound("horn")
		notify(["BEEP BEEP. Small bus, big ambitions.","Auntie has right of way.","Next stop: financial independence."][randi()%3],Color("8ce1cd"),2)
	if event.is_action_pressed("reset_bus"): rescue_bus()
	if event.is_action_pressed("map"): show_map = not show_map
	if event.is_action_pressed("camera"): camera_high = not camera_high
	if event.is_action_pressed("express"): toggle_express()
	if event.is_action_pressed("dispatch_a"): accept_offer_slot(0)
	if event.is_action_pressed("dispatch_b"): accept_offer_slot(1)
	if event.is_action_pressed("next_stop"): select_stop((selected_stop+1)%D.STOP_POS.size())
	if event.is_action_pressed("previous_stop"): select_stop(posmod(selected_stop-1,D.STOP_POS.size()))
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9 and event.keycode-KEY_1 < D.STOP_POS.size():
			select_stop(event.keycode-KEY_1)
			play_sound("board")

func _process(delta: float):
	elapsed += delta
	dock_grade_time = maxf(0,dock_grade_time-delta)
	toast_time = maxf(0,toast_time-delta)
	if toast_time<=0: toast_priority=0
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
			if race.remaining<=30 and not last_fares_announced:
				last_fares_announced=true
				notify("LAST FARES • Deliver your onboard riders before the buzzer!",Color("ffce73"),4,3)
			service_player(delta)
			process_race_events()
			if player.position.y < D.road_height(player.position)-14: rescue_bus()
			route_guide.refresh(player.position,selected_stop,delta)
			district_label = D.district_name_at(player.position)
			street_label_timer-=delta
			if street_label_timer<=0:
				street_label_timer=1.0
				street_label=D.road_name_at(player.position)
	visual_timer += delta
	if visual_timer > .25:
		visual_timer = 0
		update_stop_visuals()
	update_camera(delta)
	route_guide.visible = state in ["race","countdown"] and not show_map
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
	player.reset_at(D.SPAWN_POSITION,D.SPAWN_HEADING)
	player.apply_livery(Color("348b72") if premium_equipped else Color("c43d38"),capacity())
	player.max_speed = (26.0 if premium_equipped else 23.0) + upgrades.engine*2
	player.acceleration = 11.0+upgrades.engine*1.7
	player.distance_driven = 0
	player.enabled = false
	player.door_open = false
	selected_stop = 0
	current_stop = -1
	last_service_stop = -1
	dock_grade_time = 0
	express_mode = false
	express_destination = 0
	dispatch_auto_pin = false
	last_fares_announced = false
	toast_priority = 0
	door_open_time = 0
	service_timer = 0
	show_map = false
	toast_time = 0
	payout_committed = false
	for i in range(1,4):
		var rival := RivalDriver.new()
		add_child(rival)
		rival.setup(race,i,int(floor(float(i)*D.STOP_POS.size()/4.0)))
		rivals.append(rival)
	countdown = 3
	state = "countdown"
	camera.position = player.position+player.global_transform.basis.z*16+Vector3(0,8,0)
	route_guide.refresh(player.position,selected_stop,0,true)
	update_stop_visuals()

func service_player(delta: float):
	player.door_open = false
	var nearest := -1
	var distance := 8.0
	var approach_distance := 48.0
	approach_stop = -1
	for i in D.STOP_POS.size():
		var d: float = Vector2(player.position.x-D.STOP_POS[i].x,player.position.z-D.STOP_POS[i].z).length()
		if d < approach_distance and absf(player.position.y-D.STOP_POS[i].y)<10:
			approach_distance = d
			approach_stop = i
		if d < distance and absf(player.position.y-D.STOP_POS[i].y)<4:
			nearest = i
			distance = d
	if nearest != current_stop:
		race.depart_stop(0)
		last_service_stop = -1
		service_timer = 0
		current_stop = nearest
		door_open_time = 0
	if current_stop == -1:
		service_status = "BRAKE IN THE BAY • Passengers board automatically" if approach_stop>=0 else "Choose a stop on the map • M"
		return
	if absf(player.speed) > 1.1:
		door_open_time = 0
		service_status = "HOLD SPACE  •  Stop to open the doors"
		service_timer = 0
		return
	player.door_open = true
	door_open_time += delta
	if last_service_stop!=current_stop:
		last_service_stop=current_stop
		var position_error := Vector2(player.position.x-D.STOP_POS[current_stop].x,player.position.z-D.STOP_POS[current_stop].z).length()
		var align := absf((-player.global_transform.basis.z).dot(D.stop_tangent(current_stop).normalized()))
		var precision := (1.0-clampf(position_error/7.5,0,1))*.8+align*.2
		var grade := race.record_stop(0,current_stop,precision,player.seconds_since_impact>2.0)
		if not grade.is_empty() and grade.tip_per_rider>0:
			dock_grade=grade.grade+" STOP  +$%d / rider"%grade.tip_per_rider
			dock_grade_time=2.2
	var counts := race.destinations()
	var full: bool = race.drivers[0].riders.size() >= capacity()
	if counts[current_stop] > 0:
		service_status = "ALIGHTING  •  %s" % D.STOP_NAMES[current_stop]
	elif full:
		service_status = "FULL HOUSE!  •  Deliver passengers to free seats"
		service_timer = 0
		return
	elif race.boardable_count(0,current_stop,express_destination if express_mode else -1)==0:
		service_status = "EXPRESS LOADED • Next: "+D.STOP_SHORT[express_destination] if express_mode else "ALL ABOARD • Pick a destination and go!"
		service_timer = 0
		return
	else:
		service_status = ("EXPRESS BOARDING → "+D.STOP_SHORT[express_destination]) if express_mode else ("BOARDING • "+D.STOP_NAMES[current_stop])
	var booking: Dictionary = race.active_contract(0)
	if counts[current_stop]==0 and not booking.is_empty() and booking.origin==current_stop and booking.boarded<booking.party_size:
		service_status="DISPATCH PARTY → %s • %d/%d aboard"%[D.STOP_SHORT[booking.dest],booking.boarded,booking.party_size]
	if counts[current_stop]==0 and door_open_time<.65:
		service_status = "DOORS OPENING • Choose express, or take a mixed load"
		return
	service_timer += delta
	var interval: float = (.17 if counts[current_stop]>0 else .25) / (1.0+upgrades.doors*.22)
	service_interval = interval
	if service_timer >= interval:
		service_timer = 0
		var event := race.service(0,current_stop,express_destination if express_mode else -1)
		if event.is_empty(): return
		if event.kind == "drop":
			play_sound("coin")
			fare_flash = .65
			notify("+HK$%d   •   %s" % [event.fare,["Exact change. Immaculate vibes.","Auntie approves.","Another satisfied bun enthusiast.","Ding! That's the sound of rent money."][race.delivered%4]],Color("a9df90"),2)
		else:
			play_sound("board")
			if selected_stop == current_stop and not express_mode: select_stop(event.rider.dest,true)
			if race.picked_up % 5 == 1:
				notify("PASSENGER: %s, please!"%D.STOP_NAMES[event.rider.dest],Color("9fddd2"),2.2)
		animate_passenger(event.kind == "board",event.rider.get("kind","regular"))
		update_stop_visuals()

func animate_passenger(boarding: bool, kind := "regular"):
	var p := BusStopVisual.person(randi()%6,kind)
	add_child(p)
	var curb: Vector3 = D.stop_curb_position(current_stop)
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
	player.reset_at(p,nearest_road_heading(p))
	reset_cooldown = 4
	# A time penalty is predictable and cannot take the score below zero.
	race.remaining = maxf(0,race.remaining-3)
	notify("ROADSIDE RESCUE  •  Back on the road. −3 seconds.",Color("ffb18a"),3)

func _on_bump(_impact: float):
	if state != "race": return
	race.apply_bump(0,_impact)
	impact_shake = .3
	play_sound("bump")
	notify(QUIPS[randi()%QUIPS.size()],Color("ffb18a"),3)

func update_camera(delta: float):
	var target := player.global_position+Vector3(0,2.0,0)
	var desired: Vector3
	if state in ["title","garage"]:
		desired = player.position-player.global_transform.basis.z*12.5+player.global_transform.basis.x*2.8+Vector3(0,5.5,0)
		target += player.global_transform.basis.x*4.0
	else:
		var behind := player.global_transform.basis.z
		desired = player.position + behind*(21.0 if camera_high else 13.0) + Vector3(0,17.0 if camera_high else 7.5,0)
		# Sweep a volume, not just a centre ray, to keep the camera's near plane
		# outside walls. A high fallback keeps a clipped chase view out of the bus.
		var best_score: float = -INF
		var base_desired:=desired
		var candidates: Array[Dictionary]=[]
		for shoulder in [0.0,-3.5,3.5]:
			candidates.append({"point":base_desired+player.global_transform.basis.x*shoulder,"penalty":absf(shoulder)*6.0})
		candidates.append({"point":player.position+behind*4.5+Vector3(0,12.0,0),"penalty":65.0})
		candidates.append({"point":player.position+behind*1.5+Vector3(0,15.0,0),"penalty":145.0})
		for option in candidates:
			var candidate:=clear_camera_position(target,option.point)
			var clearance:=candidate.distance_to(target)
			var score:float=clearance*clearance-option.penalty
			if clearance<6.5: score-=300.0
			if score>best_score:
				best_score=score
				desired=candidate
	camera.position = camera.position.lerp(desired,1-exp(-delta*6))
	if state not in ["title","garage"]:
		camera.position=clear_camera_position(target,camera.position)
		if camera.position.distance_to(target)<5.0 and desired.distance_to(target)>6.5:
			camera.position=desired
	if camera.position.distance_to(target) > .1: camera.look_at(target)
	camera.fov = lerpf(camera.fov,66+absf(player.speed)*.22,delta*2)
	if impact_shake>0: camera.h_offset = sin(elapsed*90)*impact_shake*.2
	else: camera.h_offset = 0

func clear_camera_position(anchor: Vector3, candidate: Vector3) -> Vector3:
	var query:=PhysicsShapeQueryParameters3D.new()
	var sphere:=SphereShape3D.new()
	sphere.radius=.85
	query.shape=sphere
	query.transform=Transform3D(Basis.IDENTITY,anchor)
	query.motion=candidate-anchor
	query.collision_mask=1
	var fractions:=get_world_3d().direct_space_state.cast_motion(query)
	if fractions[0]<1.0:
		return anchor+query.motion*maxf(0,fractions[0]-.015)
	return candidate

func update_stop_visuals():
	var counts := race.destinations()
	for i in stops.size():
		stops[i].update_display(race.queues[i].size(),counts[i],selected_stop==i,race.queues[i])
		stops[i].sign_label.visible = state in ["race","countdown","paused"] and stops[i].position.distance_to(player.position)<180

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

func notify(message: String, color := Color("ffce73"), duration := 3.0, priority := 0):
	if toast_time>0 and priority<toast_priority: return
	toast_priority=priority
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
	player.reset_at(D.SPAWN_POSITION,D.SPAWN_HEADING)
	show_map = false
	for rival in rivals:
		remove_child(rival)
		rival.queue_free()
	rivals.clear()
	update_stop_visuals()

func select_stop(index: int, automatic := false):
	if not automatic: dispatch_auto_pin=false
	selected_stop = clampi(index,0,D.STOP_POS.size()-1)
	if is_instance_valid(route_guide): route_guide.refresh(player.position,selected_stop,0,true)

func nearest_road_heading(at: Vector3) -> float:
	var closest := INF
	var tangent := Vector3.FORWARD
	for segment in D.road_segments():
		var a: Vector3 = segment.a
		var b: Vector3 = segment.b
		var ab := b-a
		var t := clampf((at-a).dot(ab)/maxf(.01,ab.length_squared()),0,1)
		var distance := at.distance_squared_to(a+ab*t)
		if distance<closest:
			closest=distance
			tangent=ab.normalized()
	return atan2(-tangent.x,-tangent.z)

func run_express(destination: int):
	express_destination = clampi(destination,0,D.STOP_POS.size()-1)
	express_mode = true
	select_stop(express_destination)
	play_sound("board")
	notify("EXPRESS: only riders for "+D.STOP_NAMES[express_destination],Color("8ce1cd"),2.5)

func toggle_express():
	if express_mode:
		express_mode = false
		play_sound("board")
		notify("LOCAL: all destinations welcome",Color("8ce1cd"),2.5)
	else:
		var destination := selected_stop
		if approach_stop>=0 and destination==approach_stop:
			var brief: Dictionary = race.stop_brief(approach_stop)
			destination = brief.leading_dest
		run_express(destination)

func accept_dispatch(offer_id: int):
	var result: Dictionary = race.accept_contract(0,offer_id,player.position)
	if not result.is_empty():
		dispatch_auto_pin=true
		var hint: Dictionary = race.dispatch_hint(0)
		if hint.has("target"): select_stop(hint.target,true)
		play_sound("bell")
	else:
		notify("Booking unavailable • finish your current party or try another offer",Color("ffb18a"),2.5,2)
	process_race_events()

func accept_offer_slot(index: int):
	if not race.active_contract(0).is_empty():
		var hint := race.dispatch_hint(0)
		select_stop(hint.target,true)
		return
	var offers: Array = race.dispatch_offers(0)
	if index<offers.size(): accept_dispatch(offers[index].id)

func process_race_events():
	for event in race.pop_events(0):
		match event.kind:
			"party_aboard":
				if dispatch_auto_pin: select_stop(event.target,true)
				notify(event.message,Color("a9dfb3"),3,3)
			"contract_completed":
				play_sound("bell")
				notify(event.message,Color("a9dfb3"),4,4)
			"contract_accepted": notify(event.message,Color("8ce1cd"),3,3)
			"contract_failed","contract_too_late","tips_spilled": notify(event.message,Color("ffb18a"),3,2)
			_: pass
