extends "res://tools/playtest.gd"

# A short, repeatable physical driving regression for the two occluded corners.
func _physics_process(delta: float):
	super._physics_process(delta)
	if time>=46:
		print("CAMERA_REVIEW_COMPLETE 46 seconds of physical driving")
		quit()

func capture(label: String):
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://captures/v2/camera_"+label+".png")
	print("CAMERA_REVIEW ",label," player=",game.player.position," camera=",game.camera.position," clearance=",game.camera.position.distance_to(game.player.position+Vector3(0,2,0)))
