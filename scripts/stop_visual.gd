class_name BusStopVisual
extends Node3D

var stop_id := 0
var sign_label: Label3D
var people := Node3D.new()
var last_count := -1
var last_queue_key := ""
var halo: MeshInstance3D
var booking_marker: Label3D
static var person_meshes: Dictionary = {}
const D = preload("res://scripts/district.gd")

func _ready():
	add_child(people)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 4.2
	cylinder.bottom_radius = 4.2
	cylinder.height = .04
	cylinder.radial_segments = 48
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(D.STOP_COLORS[stop_id],.24)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cylinder.material = mat
	halo = MeshInstance3D.new()
	halo.mesh = cylinder
	halo.position.y = .16
	add_child(halo)
	sign_label = Label3D.new()
	sign_label.position.y = 5.3
	sign_label.font_size = 40
	sign_label.pixel_size = .013
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.modulate = D.STOP_COLORS[stop_id]
	sign_label.outline_modulate = Color("18333c")
	sign_label.outline_size = 8
	add_child(sign_label)
	booking_marker=Label3D.new()
	booking_marker.position=D.stop_curb_position(stop_id)-D.STOP_POS[stop_id]+Vector3(0,2.5,0)
	booking_marker.text=""
	booking_marker.font_size=28
	booking_marker.pixel_size=.012
	booking_marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	booking_marker.modulate=Color("f4bd59")
	booking_marker.outline_size=7
	booking_marker.outline_modulate=Color("18333c")
	booking_marker.visibility_range_end=85
	add_child(booking_marker)

func update_display(count: int, drop: int, selected: bool, queue: Array = []):
	sign_label.text = "%d  %s\n%d waiting%s" % [stop_id+1,D.STOP_SHORT[stop_id],count,"  /  %d DROP OFF"%drop if drop>0 else ""]
	var reserved := 0
	for rider in queue:
		if rider.get("reserved_for",-1)==0: reserved+=1
	booking_marker.text="★ YOUR BOOKING ×%d"%reserved if reserved>0 else ""
	halo.scale = Vector3.ONE*(1.15 if selected else 1.0)
	var queue_key := str(count)
	for rider in queue.slice(0,24): queue_key += ":%s:%s"%[rider.id,rider.get("reserved_for",-1)]
	if queue_key == last_queue_key: return
	last_queue_key = queue_key
	last_count = count
	for child in people.get_children():
		people.remove_child(child)
		child.queue_free()
	var tangent: Vector3 = D.stop_tangent(stop_id)
	var outward := Vector3.UP.cross(tangent)
	var base: Vector3 = D.stop_curb_position(stop_id)-D.STOP_POS[stop_id]
	for i in mini(count,24):
		var kind: String = queue[i].get("kind","regular") if i<queue.size() else "regular"
		var p := person(i,kind)
		people.add_child(p)
		p.position = base + tangent*((i%8)*.68-2.4) + outward*(floori(i/8.0)*.65)
		var world := position+p.position
		p.position.y = D.road_height(world)-position.y+.18
		p.rotation.y = atan2(-outward.x,-outward.z)

static func person(index: int, kind := "regular") -> Node3D:
	var p := Node3D.new()
	var cache_key := str(index%6)+":"+kind
	if person_meshes.has(cache_key):
		var instance := MeshInstance3D.new()
		instance.mesh=person_meshes[cache_key]
		instance.visibility_range_end=95
		p.add_child(instance)
		return p
	var colors = ["dc7955","5c9fa0","e3bc56","647596","b57ea6","869c5e"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(colors[index%colors.size()])
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = .22
	mesh.height = .85
	mesh.radial_segments = 6
	mesh.rings = 2
	mesh.material = m
	body.mesh = mesh
	body.position.y = .95
	p.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .19
	sphere.height = .38
	sphere.radial_segments = 8
	sphere.rings = 4
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("e7b487")
	skin.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	sphere.material = skin
	head.mesh = sphere
	head.position.y = 1.53
	p.add_child(head)
	var legs := MeshInstance3D.new()
	var legmesh := BoxMesh.new()
	legmesh.size = Vector3(.27,.52,.23)
	var trousers := StandardMaterial3D.new()
	trousers.albedo_color = Color("344854")
	legmesh.material = trousers
	legs.mesh = legmesh
	legs.position.y = .28
	p.add_child(legs)
	# Readable silhouettes: commuter briefcase, sightseer hat/camera, matching party caps.
	var hair_color := Color("332b2b")
	piece(p,Vector3(.34,.13,.32),Vector3(0,1.69,.02),hair_color)
	for side in [-1,1]:
		var arm := piece(p,Vector3(.11,.56,.14),Vector3(side*.26,.96,0),m.albedo_color)
		arm.rotation.z=side*.12
		piece(p,Vector3(.12,.12,.14),Vector3(side*.29,.65,0),skin.albedo_color)
		piece(p,Vector3(.14,.12,.31),Vector3(side*.11,.08,-.04),Color("242e35"))
	if kind=="commuter":
		piece(p,Vector3(.13,.30,.34),Vector3(.34,.48,0),Color("624738"))
		piece(p,Vector3(.09,.35,.03),Vector3(0,1.07,-.205),Color("f0debc"))
	elif kind=="sightseer":
		piece(p,Vector3(.53,.065,.48),Vector3(0,1.73,0),Color("e7ca8a"))
		piece(p,Vector3(.32,.17,.32),Vector3(0,1.81,0),Color("e7ca8a"))
		piece(p,Vector3(.25,.17,.13),Vector3(0,.94,-.26),Color("33434c"))
	elif kind=="party":
		piece(p,Vector3(.40,.13,.42),Vector3(0,1.75,-.04),Color("f3bd59"))
		piece(p,Vector3(.22,.34,.18),Vector3(0,1.03,.26),Color("f3bd59"))
		piece(p,Vector3(.31,.4,.24),Vector3(.38,.26,0),Color("a34a46"))
	else:
		piece(p,Vector3(.10,.32,.26),Vector3(-.32,.46,0),Color("a5bf88"))
	# Merge the tiny pieces into one vertex-coloured surface; hundreds of riders
	# should not create thousands of separate draw calls on the enlarged map.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors_array := PackedColorArray()
	var indices := PackedInt32Array()
	for child in p.get_children():
		if not child is MeshInstance3D: continue
		var arrays: Array=child.mesh.surface_get_arrays(0)
		var source_vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var source_indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var offset:=vertices.size()
		var color: Color=child.mesh.surface_get_material(0).albedo_color
		for i in source_vertices.size():
			vertices.append(child.transform*source_vertices[i])
			normals.append((child.basis*source_normals[i]).normalized())
			colors_array.append(color)
		for source_index in source_indices: indices.append(offset+source_index)
		child.free()
	var merged_arrays:=[]
	merged_arrays.resize(Mesh.ARRAY_MAX)
	merged_arrays[Mesh.ARRAY_VERTEX]=vertices
	merged_arrays[Mesh.ARRAY_NORMAL]=normals
	merged_arrays[Mesh.ARRAY_COLOR]=colors_array
	merged_arrays[Mesh.ARRAY_INDEX]=indices
	var merged:=ArrayMesh.new()
	merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,merged_arrays)
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
	merged.surface_set_material(0,material)
	person_meshes[cache_key]=merged
	var instance:=MeshInstance3D.new()
	instance.mesh=merged
	instance.visibility_range_end=95
	p.add_child(instance)
	return p

static func piece(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color
	mat.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
	mesh.material=mat
	node.mesh=mesh
	node.position=at
	parent.add_child(node)
	return node
