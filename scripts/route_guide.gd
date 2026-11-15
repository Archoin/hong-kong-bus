class_name RouteGuide
extends Node3D

# A short road-level guide. It helps read the next turn without replacing route choice.
const D = preload("res://scripts/district.gd")
var arrows: MultiMeshInstance3D
var material: StandardMaterial3D
var route_points: Array[Vector3] = []
var road_distance := 0.0
var next_point := Vector3.ZERO
var target_id := -1
var refresh_time := 0.0

func _ready():
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array([
		Vector3(0,0,-1.6),Vector3(-.9,0,.15),Vector3(-.28,0,.15),
		Vector3(0,0,-1.6),Vector3(-.28,0,.15),Vector3(.28,0,.15),
		Vector3(0,0,-1.6),Vector3(.28,0,.15),Vector3(.9,0,.15),
		Vector3(-.28,0,.15),Vector3(-.28,0,1.0),Vector3(.28,0,1.0),
		Vector3(-.28,0,.15),Vector3(.28,0,1.0),Vector3(.28,0,.15)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1,.75,.25,.72)
	mesh.surface_set_material(0,material)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 36
	mm.visible_instance_count = 0
	arrows = MultiMeshInstance3D.new()
	arrows.multimesh = mm
	arrows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arrows)

func refresh(from: Vector3, stop_id: int, delta: float, force := false):
	refresh_time -= delta
	if not force and target_id==stop_id and refresh_time>0: return
	refresh_time = .7
	target_id = stop_id
	var nearest := D.nearest_road(from)
	route_points = D.route(nearest,D.STOP_POS[stop_id])
	road_distance = from.distance_to(nearest)
	var previous := nearest
	for point in route_points:
		road_distance += previous.distance_to(point)
		previous = point
	next_point = D.STOP_POS[stop_id]
	for point in route_points:
		if Vector2(point.x-from.x,point.z-from.z).length()>9:
			next_point = point
			break
	var count := 0
	var traveled := 0.0
	previous = nearest
	for point in route_points:
		var segment := point-previous
		var length := segment.length()
		if length<.1: continue
		var direction := segment/length
		var along := 4.0
		while along<length and count<36 and traveled+along<180:
			var p := previous+direction*along
			if p.distance_to(from)>7:
				p.y = D.road_height(p)+.14
				var basis := Basis.looking_at(direction,Vector3.UP)
				arrows.multimesh.set_instance_transform(count,Transform3D(basis,p))
				count += 1
			along += 6
		traveled += length
		previous = point
	arrows.multimesh.visible_instance_count = count
