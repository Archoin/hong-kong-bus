extends SceneTree
const D=preload("res://scripts/district.gd")
var world:Node3D
var camera:Camera3D
func _initialize():call_deferred("capture")
func capture():
	world=load("res://scenes/district.tscn").instantiate()
	root.add_child(world)
	camera=Camera3D.new()
	camera.far=2200
	camera.fov=68
	root.add_child(camera)
	camera.current=true
	root.size=Vector2i(1440,900)
	var shots=[
		["map_overview",Vector3(200,620,560),Vector3(0,0,-20)],
		["map_desvoeux",D.nearest_road(D.SPAWN_POSITION)+Vector3(0,4,0),D.SPAWN_POSITION+D.STOP_TANGENTS[0]*70+Vector3(0,8,0)],
		["map_bonham",D.STOP_POS[4]+Vector3(-14,4,6),D.STOP_POS[4]+D.STOP_TANGENTS[4]*50+Vector3(0,5,0)],
		["map_manmo",D.nearest_road(D.STOP_POS[7])+Vector3(0,4,0),Vector3(-109,48,171)],
		["map_rails",D.tram_routes()[0][130]+Vector3(0,3.5,0),D.tram_routes()[0][145]+Vector3(0,3,0)]]
	for shot in shots:
		camera.position=shot[1]
		camera.look_at(shot[2])
		for i in 10:await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://captures/"+shot[0]+".png")
	print("MAP_CAPTURE_COMPLETE")
	quit()
