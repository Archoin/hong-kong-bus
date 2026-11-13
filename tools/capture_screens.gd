extends SceneTree

var started := Time.get_ticks_msec()
var game: Node3D
func _process(_delta: float):
	if Time.get_ticks_msec()-started>45000:
		push_error("UI test timed out")
		quit(1)
func _initialize(): call_deferred("run")

func shot(label: String):
	for i in 25: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/"+label+".png")
	print("SCREEN_CAPTURE ",label)

func click_ui(p: Vector2):
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	event.position=p*game.hud.scale_factor
	print("UI_CLICK ",p," viewport ",root.get_visible_rect()," scale ",game.hud.scale_factor)
	root.push_input(event,true)
	await process_frame
	event.pressed=false
	root.push_input(event,true)

func run():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_path="user://screens_test.cfg"
	await create_timer(1.5).timeout
	await shot("review_title")
	await click_ui(Vector2(280,728))
	assert(game.state=="countdown","Start button works")
	await shot("review_countdown")
	await create_timer(3).timeout
	game.player.reset_at(Vector3(-96,0,-37))
	await create_timer(4).timeout
	game.selected_stop=1
	game.toast_time=0
	await shot("review_driving")
	game.show_map=true
	await shot("review_map")
	await click_ui(Vector2(1078,430))
	assert(game.selected_stop==2,"Expanded map selects stop")
	game.show_map=false
	game.pause_race()
	await shot("review_pause")
	await click_ui(Vector2(690,405))
	assert(game.state=="race","Resume button works")
	game.race.drivers[0].cash=784
	game.race.drivers[1].cash=650
	game.race.drivers[2].cash=492
	game.race.drivers[3].cash=351
	game.race.delivered=27
	game.race.finish()
	game.end_race()
	await shot("review_results_layout")
	await click_ui(Vector2(420,740))
	assert(game.state=="garage","Results garage button works")
	await shot("review_garage")
	game.wallet=2500
	await process_frame
	await process_frame
	await click_ui(Vector2(280,480))
	assert(game.upgrades.seats==1,"Seat upgrade button works")
	await process_frame
	await process_frame
	await click_ui(Vector2(1120,638))
	assert(game.premium_equipped,"New bus purchase works")
	game.return_to_title()
	await create_timer(.6).timeout
	await shot("review_jade_bus")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	print("SCREEN_TEST: all six UI interactions passed; results layout uses fixture scores")
	quit()
