extends "res://tests/driving/render_handling.gd"

func _physics_process(delta: float):
	if not started: return
	t+=delta
	var angle := -.7 if t<2.0 else 2.5
	camera.position=bus.position+Vector3(sin(angle)*10,4.5,cos(angle)*10)
	camera.look_at(bus.position+Vector3(0,1.6,0))
	if t>1.5 and capture_index==0:
		capture_index=1
		call_deferred("vehicle_capture","rear")
	if t>3.5 and capture_index==1:
		capture_index=2
		call_deferred("vehicle_capture","front")
	if t>4:
		started=false
		quit()

func vehicle_capture(view: String):
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/driving_vehicle_%s.png"%view)
