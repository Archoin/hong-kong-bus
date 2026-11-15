extends SceneTree
# Runs the normal game through digital driving actions. No teleporting or rescues.
const D = preload("res://scripts/district.gd")
var game: Node3D
var finished := false
var started := false
var policy := "local"
var seed_value := 20261113
var capture_enabled := true
var target_stop := 0
var path: Array[Vector3] = []
var at_stop := false
var dwell := 0.0
var dwell_total := 0.0
var time := 0.0
var sample_at := 0.0
var capture_at := 10.0
var slow_time := 0.0
var reverse_recovery := 0.0
var recoveries := 0
var bumps := 0
var visits: Array = []
var samples: Array = []
var decisions: Array = []
var impacts: Array = []
var visit_cash := 0
var visit_boarded := 0
var visit_delivered := 0
var visit_time := 0.0
var last_position := Vector3.ZERO
var discontinuities: Array = []
var actual_speed := 0.0
var fps_samples: Array[float] = []
var draw_call_samples: Array[float] = []
var focused_render_samples := 0
var capture_index := 0
var traffic_wait := 0.0

func _initialize(): call_deferred("run")

func run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--policy="): policy=argument.get_slice("=",1)
		if argument.begins_with("--seed="): seed_value=int(argument.get_slice("=",1))
		if argument=="--no-capture": capture_enabled=false
	if not policy in ["local","express","dispatch"]:
		push_error("Unknown policy: "+policy)
		quit(2)
		return
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save_path="res://captures/playtest_sandbox_%s_%d.cfg"%[policy,seed_value]
	game.wallet=0
	game.upgrades={"seats":0,"engine":0,"doors":0}
	game.premium_equipped=false
	game.start_race()
	game.race.begin(game.capacity(),seed_value)
	game.race.active=false
	for rival in game.rivals: game.race.drivers[rival.driver_id].last_stop=rival.target_stop
	game.player.bumped.connect(on_bump)
	last_position=game.player.position
	print("PLAYTEST_STARTED policy=",policy," seed=",seed_value," stops=",D.STOP_POS.size()," digital input, no teleportation")

func clear_controls():
	for action in ["accelerate","reverse","brake","left","right"]: Input.action_release(action)

func flat_distance(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func _physics_process(delta: float):
	if game==null or finished: return
	if game.state=="results":
		clear_controls()
		game.set_process(false)
		finished=true
		call_deferred("finish")
		return
	if game.state!="race": return
	if not started:
		started=true
		for rival in game.rivals: rival.choose_boarding_mode()
		choose_stop(true)
	time+=delta
	var movement: float=game.player.position.distance_to(last_position)
	actual_speed=flat_distance(game.player.position,last_position)/maxf(delta,.001)
	if movement>3.5: discontinuities.append({"t":time,"distance":movement,"position":vec(game.player.position)})
	last_position=game.player.position
	if time>=sample_at:
		sample_at+=1.0
		if DisplayServer.get_name()!="headless" and time>10:
			fps_samples.append(Engine.get_frames_per_second())
			if DisplayServer.window_is_focused(): focused_render_samples+=1
			draw_call_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		samples.append({"t":snapped(time,.01),"position":vec(game.player.position),"target":target_stop,"speed":snapped(game.player.speed,.01),"cash":game.race.drivers[0].cash,"riders":game.race.drivers[0].riders.size(),"at_stop":at_stop,"grounded":game.player.is_on_floor(),"waypoint":vec(path[0]) if not path.is_empty() else [],"remaining_waypoints":path.size()})
	if time>=capture_at-2: game.camera_high=capture_index%2==1
	if time>=capture_at:
		call_deferred("capture","%03d_%s"%[int(time),"high" if game.camera_high else "chase"])
		capture_at+=35
		capture_index+=1
		print("PLAYTEST t=%.0f cash=%d riders=%d target=%s position=%s"%[time,game.race.drivers[0].cash,game.race.drivers[0].riders.size(),D.STOP_SHORT[target_stop],game.player.position])
	if time>190:
		push_error("Race did not finish within190 physics seconds")
		finished=true
		call_deferred("finish")
		return
	if reverse_recovery>0:
		reverse_recovery-=delta
		clear_controls()
		Input.action_press("reverse")
		Input.action_press("right" if recoveries%2 else "left")
		if reverse_recovery<=0: rebuild_path()
		return
	Input.action_release("reverse")
	var stop_gap:=flat_distance(game.player.position,D.STOP_POS[target_stop])
	if not at_stop and game.current_stop==target_stop and absf(game.player.speed)<1.1 and stop_gap<7.5:
		at_stop=true
		dwell=0
		visit_time=time
		visit_cash=game.race.drivers[0].cash
		visit_boarded=game.race.picked_up
		visit_delivered=game.race.delivered
		configure_boarding()
	if at_stop:
		clear_controls()
		Input.action_press("brake")
		dwell+=delta
		dwell_total+=delta
		var drops: int=game.race.destinations()[target_stop]
		var boardable: int=game.race.boardable_count(0,target_stop,game.express_destination if game.express_mode else -1)
		var full: bool=game.race.drivers[0].riders.size()>=game.capacity()
		if dwell>.9 and drops==0 and (boardable==0 or full or dwell>6.0):
			visits.append({"stop":target_stop,"name":D.STOP_NAMES[target_stop],"arrival":snapped(visit_time,.01),"dwell":snapped(dwell,.01),"cash":game.race.drivers[0].cash-visit_cash,"boarded":game.race.picked_up-visit_boarded,"delivered":game.race.delivered-visit_delivered,"position_error":stop_gap})
			choose_stop()
		return
	drive_path(delta)

func drive_path(delta: float):
	if path.is_empty(): rebuild_path()
	if path.is_empty(): return
	var position: Vector3=game.player.position
	while path.size()>1 and flat_distance(path[0],position)<6.0: path.pop_front()
	var offset: Vector3=path[0]-position
	offset.y=0
	var distance:=offset.length()
	var last:=path.size()==1
	var error:=wrapf(atan2(-offset.x,-offset.z)-game.player.rotation.y,-PI,PI)
	Input.action_release("left")
	Input.action_release("right")
	if error>.035: Input.action_press("left")
	elif error<-.035: Input.action_press("right")
	var target_speed:=19.0
	if absf(error)>.30: target_speed=11.0
	if absf(error)>.65: target_speed=6.0
	if path.size()>1:
		var outgoing:=path[1]-path[0]
		outgoing.y=0
		var corner:=absf(offset.normalized().signed_angle_to(outgoing.normalized(),Vector3.UP))
		if corner>.30 and distance<24: target_speed=minf(target_speed,10.0)
		if corner>.65 and distance<15: target_speed=minf(target_speed,6.5)
	if last:
		target_speed=minf(target_speed,sqrt(maxf(0,distance-1.6)*24))
		if distance<3.0 or (distance<7.0 and absf(error)>.9): target_speed=0
	# Traffic anticipation belongs to this test driver, not the player controller.
	var traffic_speed := traffic_safe_speed()
	var following_traffic := traffic_speed<target_speed
	if following_traffic: traffic_wait+=delta
	target_speed=minf(target_speed,traffic_speed)
	if game.player.speed>target_speed+.35:
		Input.action_release("accelerate")
		Input.action_press("brake")
	else:
		Input.action_release("brake")
		Input.action_press("accelerate")
	if actual_speed<.8 and target_speed>2 and not following_traffic: slow_time+=delta
	else: slow_time=0
	if slow_time>2.5:
		recoveries+=1
		reverse_recovery=1.25
		slow_time=0
		decisions.append({"t":time,"kind":"reverse_recovery","position":vec(position),"waypoint":vec(path[0])})
		print("PLAYTEST_REVERSE position=",position," waypoint=",path[0])

func traffic_safe_speed() -> float:
	var forward: Vector3=-game.player.global_transform.basis.z
	var right: Vector3=game.player.global_transform.basis.x
	var reach: float=maxf(10,game.player.speed*game.player.speed/48.0+5.0)
	var safe_speed:=INF
	for lateral in [-.9,0.0,.9]:
		var origin: Vector3=game.player.global_position+Vector3.UP*1.3+forward*2.8+right*lateral
		var query:=PhysicsRayQueryParameters3D.create(origin,origin+forward*reach,4)
		query.exclude=[game.player.get_rid()]
		var hit: Dictionary=game.player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var gap: float=origin.distance_to(hit.position)
			safe_speed=minf(safe_speed,sqrt(maxf(0,gap-3.0)*32.0))
	return safe_speed

func maybe_accept_dispatch():
	if policy!="dispatch" or not game.race.active_contract(0).is_empty(): return
	var best:=-INF
	var chosen:=-1
	for offer in game.race.dispatch_offers(0):
		var approach: float=D.road_distance(game.player.position,D.STOP_POS[offer.origin])
		var score: float=(offer.reward+offer.party_size*game.race.fare_for(offer.origin,offer.dest))/(approach+offer.distance+60.0)
		if score>best:
			best=score
			chosen=offer.id
	if chosen>=0: game.accept_dispatch(chosen)

func configure_boarding():
	maybe_accept_dispatch()
	var contract: Dictionary=game.race.active_contract(0)
	if policy=="dispatch" and not contract.is_empty():
		game.run_express(contract.dest)
		return
	if policy=="express":
		var brief: Dictionary=game.race.stop_brief(target_stop)
		var best:=-INF
		var destination:=-1
		for i in D.STOP_POS.size():
			if i==target_stop or brief.destinations[i]==0: continue
			var score: float=brief.destinations[i]*game.race.fare_for(target_stop,i)/(D.stop_distance(target_stop,i)+60.0)
			if score>best:
				best=score
				destination=i
		if destination>=0: game.run_express(destination)
		else: game.express_mode=false
	else: game.express_mode=false

func choose_stop(initial:=false):
	maybe_accept_dispatch()
	var hint: Dictionary=game.race.dispatch_hint(0)
	var counts: Array=game.race.destinations()
	var chosen:=-1
	if policy=="dispatch" and not hint.is_empty():
		chosen=hint.target
		if chosen==target_stop and not initial and game.race.drivers[0].riders.size()<game.capacity():
			# A newly accepted pickup may be at the bay we are already servicing.
			configure_boarding()
			dwell=0
			return
		if chosen==target_stop and game.race.drivers[0].riders.size()>=game.capacity(): chosen=-1
	if chosen<0 and policy=="express" and game.express_mode and counts[game.express_destination]>0:
		chosen=game.express_destination
	if chosen<0:
		var best:=-INF
		for i in D.STOP_POS.size():
			if i==target_stop and not initial: continue
			var pickup: float=minf(game.race.queues[i].size(),game.capacity()-game.race.drivers[0].riders.size())
			var score: float=(counts[i]*5.0+pickup*.55+1)/(D.road_distance(game.player.position,D.STOP_POS[i])+45)
			if score>best:
				best=score
				chosen=i
	if chosen<0: chosen=0
	target_stop=chosen
	game.select_stop(chosen)
	at_stop=false
	rebuild_path()
	decisions.append({"t":snapped(time,.01),"kind":"route","target":chosen,"name":D.STOP_NAMES[chosen],"waypoints":path.size(),"express":game.express_destination if game.express_mode else -1})
	clear_controls()

func rebuild_path():
	path=D.lane_route(D.nearest_road(game.player.position),D.STOP_POS[target_stop])
	while path.size()>1 and flat_distance(path[0],game.player.position)<4: path.pop_front()

func vec(value: Vector3) -> Array:
	return [snapped(value.x,.01),snapped(value.y,.01),snapped(value.z,.01)]

func on_bump(impact: float):
	bumps+=1
	impacts.append({"t":snapped(time,.01),"severity":snapped(impact,.01),"position":vec(game.player.position),"target":target_stop,"collisions":collision_details()})

func collision_details() -> Array:
	var result: Array=[]
	for i in game.player.get_slide_collision_count():
		var hit: KinematicCollision3D=game.player.get_slide_collision(i)
		result.append({"collider":str(hit.get_collider().get_path()),"normal":vec(hit.get_normal()),"point":vec(hit.get_position())})
	return result

func capture(label: String):
	if not capture_enabled or DisplayServer.get_name()=="headless": return
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://captures/playtest_%s_%d_%s.png"%[policy,seed_value,label])

func performance_report() -> Dictionary:
	if fps_samples.is_empty(): return {"rendered":false}
	fps_samples.sort()
	draw_call_samples.sort()
	return {"rendered":true,"fps_valid":focused_render_samples==fps_samples.size(),"focused_samples":focused_render_samples,"fps_caveat":"Engine frame rate may include skipped drawing while the window is occluded; certify only an uninterrupted foreground run.","warmup_seconds":10,"samples":fps_samples.size(),"fps_median":fps_samples[fps_samples.size()/2],"fps_min":fps_samples[0],"draw_calls_median":draw_call_samples[draw_call_samples.size()/2],"draw_calls_max":draw_call_samples[-1]}

func finish():
	await capture("results")
	var player: Dictionary=game.race.drivers[0].duplicate(true)
	player.erase("riders")
	var report: Dictionary={"policy":policy,"seed":seed_value,"time":time,"player":player,"player_cash":game.race.drivers[0].cash,"delivered":game.race.delivered,"picked_up":game.race.picked_up,"rank":game.race.player_rank,"bumps":bumps,"reverse_maneuvers":recoveries,"distance_m":game.player.distance_driven,"traffic_follow_seconds":traffic_wait,"dwell_seconds":dwell_total,"dwell_fraction":dwell_total/maxf(time,1),"rival_cash":[game.race.drivers[1].cash,game.race.drivers[2].cash,game.race.drivers[3].cash],"visits":visits,"decisions":decisions,"impacts":impacts,"samples":samples,"discontinuities":discontinuities,"render_performance":performance_report()}
	var report_path: String="res://captures/playtest_%s_%d_report.json"%[policy,seed_value]
	var file:=FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("PLAYTEST_COMPLETE ",JSON.stringify({"policy":policy,"seed":seed_value,"cash":player.cash,"delivered":game.race.delivered,"rank":game.race.player_rank,"bumps":bumps,"visits":visits.size(),"recoveries":recoveries,"distance_m":game.player.distance_driven,"report":report_path}))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	quit()
