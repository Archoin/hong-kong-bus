extends SceneTree

var game: Node3D
var checks := 0
var failures := 0

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+message)

func frames(count: int):
	for i in count: await physics_frame

func _initialize():
	call_deferred("run")

func run():
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save_path = "user://integration_test.cfg"
	game.wallet = 0
	game.upgrades = {"seats":0,"engine":0,"doors":0}
	game.premium_owned = false
	game.premium_equipped = false
	game.start_race()
	game.countdown = .01
	await frames(3)
	check(game.state=="race" and game.race.active,"countdown starts playable race")
	var start_position: Vector3 = game.player.position
	Input.action_press("accelerate")
	await frames(60)
	Input.action_release("accelerate")
	check(game.player.speed>8,"throttle accelerates bus")
	print("THROTTLE_PROBE distance=",game.player.position.distance_to(start_position)," speed=",game.player.speed)
	check(game.player.position.distance_to(start_position)>2,"one second of throttle physically moves bus")
	Input.action_press("brake")
	await frames(40)
	Input.action_release("brake")
	check(absf(game.player.speed)<.1,"brake brings bus to rest")
	game.player.reset_at(game.D.STOP_POS[0],game.D.SPAWN_HEADING)
	await frames(190)
	check(game.race.drivers[0].riders.size()>0,"stopping in bay boards real passengers")
	var riders: int = game.race.drivers[0].riders.size()
	game.pause_race()
	var paused_time: float = game.race.remaining
	var paused_pos: Vector3 = game.player.position
	await frames(20)
	check(game.race.remaining==paused_time and game.player.position==paused_pos,"pause freezes race and bus")
	game.resume_race()
	# Terrain contact is checked here; collision/steering fixtures live in tests/driving.
	check(absf(game.player.position.y-game.D.road_height(game.player.position))<1.0,"bus rests on sampled city road elevation")
	game.run_express((game.current_stop+1)%game.D.STOP_POS.size())
	var express_target: int = game.express_destination
	game.select_stop((express_target+1)%game.D.STOP_POS.size())
	check(game.express_destination==express_target,"navigation pin does not silently change boarding filter")
	game.toggle_express()
	check(not game.express_mode,"E returns to local service")
	# End-to-end service at an actual destination.
	var dest: int = game.race.drivers[0].riders[0].dest
	game.player.reset_at(game.D.STOP_POS[dest])
	await frames(140)
	check(game.race.drivers[0].cash>0,"actual destination awards fares")
	# Deterministic accelerated complete shift. Same gameplay methods and AI logic.
	game.set_process(false)
	game.player.set_physics_process(false)
	game.start_race()
	game.player.set_physics_process(false)
	game.state = "race"
	game.race.active = true
	game.race.begin(game.capacity(),789)
	var stop := 0
	for step in 1800:
		if step%140 == 0:
			if step>0:
				var counts: Array = game.race.destinations()
				var best := -1
				for i in game.D.STOP_POS.size():
					if i!=stop and (best==-1 or counts[i]>counts[best]): best=i
				stop=best
			game.player.reset_at(game.D.STOP_POS[stop])
		game._process(.1)
	game._process(.2)
	check(game.state=="results","full 180-second match reaches results")
	check(game.race.delivered>0,"full shift delivers passengers")
	print("AI_FULL_SHIFT_FARES: ",[game.race.drivers[1].cash,game.race.drivers[2].cash,game.race.drivers[3].cash])
	for i in range(1,4): check(game.race.drivers[i].cash>200,"AI rival %d remains productive across a full shift"%i)
	check(game.wallet==game.last_payout,"earnings deposited in garage")
	var balance: int = game.wallet
	game.end_race()
	check(game.wallet==balance,"results cannot double-credit wallet")
	game.wallet=2500
	game.state="garage"
	game.purchase("seats")
	check(game.capacity()==23 and game.wallet==2240,"capacity upgrade charges correct price")
	game.purchase("bus")
	check(game.premium_owned and game.premium_equipped and game.capacity()==27 and game.wallet==840,"new bus purchase keeps upgrades")
	game.purchase("doors")
	check(game.upgrades.doors==1 and game.wallet==660,"boarding upgrade purchase")
	game.wallet=0
	game.load_progress()
	check(game.wallet==660 and game.premium_owned,"garage save roundtrip")
	game.start_race()
	check(game.race.remaining==180 and game.race.drivers[0].cash==0 and game.race.drivers[0].capacity==27,"replay resets race and applies upgrades")
	check(game.rivals.size()==3,"replay recreates exactly three rivals")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	print("GAMEPLAY_TESTS: %d checks, %d failures; initial passengers %d"%[checks,failures,riders])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
