extends SceneTree

# UI fixture review, not a physical gameplay performance test.
var game: Node3D
var started := Time.get_ticks_msec()
var failures := 0

func _initialize(): call_deferred("run")
func _process(_delta: float):
	if Time.get_ticks_msec()-started>90000:
		push_error("UI review timed out")
		quit(1)

func check(value: bool,label: String):
	print("UI_CHECK ",label,": ",value)
	if not value: failures+=1

func shot(label: String):
	for i in 8: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://captures/v2/"+label+".png")
	print("SCREEN_CAPTURE ",label)

func click_action(action: String):
	for i in 3: await process_frame
	for item in game.hud.buttons:
		if item.action!=action: continue
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=true
		event.position=item.rect.get_center()*game.hud.scale_factor
		root.push_input(event,true)
		await process_frame
		event.pressed=false
		root.push_input(event,true)
		return
	push_error("Missing UI action: "+action)
	failures+=1

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures/v2"))
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_path="user://v2_ui_fixture.cfg"
	await create_timer(1.0).timeout
	await shot("01_title")
	await click_action("start")
	check(game.state=="countdown","Start button")
	await shot("02_countdown")
	await create_timer(3.2).timeout
	game.player.reset_at(game.D.SPAWN_POSITION-game.D.stop_tangent(0)*5,game.D.SPAWN_HEADING)
	await create_timer(.3).timeout
	game.toast_time=0
	await shot("03_approach")
	var brief: Dictionary=game.race.stop_brief(0)
	var destination: int=brief.leading_dest
	await click_action("express:"+str(destination))
	check(game.express_mode and game.express_destination==destination,"Approach queue selects express directly")
	game.player.reset_at(game.D.STOP_POS[0],game.D.SPAWN_HEADING)
	await create_timer(2.3).timeout
	game.toast_time=0
	await shot("04_boarding")
	check(game.race.drivers[0].riders.size()>0,"Physical bay boards selected riders")
	game.show_map=true
	await shot("05_city_map")
	await click_action("stop:11")
	check(game.selected_stop==11,"Map selects twelfth stop")
	check(game.express_destination==destination,"Navigation pin preserves express filter")
	game.show_map=false
	var offers: Array=game.race.dispatch_offers(0)
	if not offers.is_empty():
		await click_action("accept:"+str(offers[0].id))
		check(not game.race.active_contract(0).is_empty(),"Dispatch offer accepts through UI")
		game.toast_time=0
		await shot("06_dispatch")
	game.pause_race()
	await shot("07_pause")
	await click_action("resume")
	check(game.state=="race","Resume button")
	game.race.drivers[0].cash=892
	game.race.drivers[0].fare_total=542
	game.race.drivers[0].tip_total=110
	game.race.drivers[0].dispatch_total=240
	game.race.drivers[0].contracts_completed=2
	game.race.drivers[0].precise_stops=5
	game.race.drivers[1].cash=650
	game.race.drivers[2].cash=492
	game.race.drivers[3].cash=351
	game.race.delivered=21
	game.race.finish()
	game.end_race()
	await shot("08_results_fixture")
	await click_action("garage")
	check(game.state=="garage","Results garage button")
	await shot("09_garage")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	print("V2_UI_REVIEW_COMPLETE failures=",failures,"; result scores are layout fixtures")
	quit(1 if failures else 0)
