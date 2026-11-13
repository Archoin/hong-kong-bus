class_name BusStopVisual
extends Node3D

var stop_id := 0
var sign_label: Label3D
var people := Node3D.new()
var last_count := -1
var halo: MeshInstance3D
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

func update_display(count: int, drop: int, selected: bool):
	sign_label.text = "%d  %s\n%d waiting%s" % [stop_id+1,D.STOP_SHORT[stop_id],count,"  /  %d DROP OFF"%drop if drop>0 else ""]
	halo.scale = Vector3.ONE*(1.15 if selected else 1.0)
	if count == last_count: return
	last_count = count
	for child in people.get_children():
		people.remove_child(child)
		child.queue_free()
	var horizontal := stop_id==1 or stop_id==4
	var base := Vector3(-5,0,-10.2) if horizontal else Vector3(-10.5,0,-5)
	for i in mini(count,24):
		var p := person(i)
		people.add_child(p)
		p.position = base + (Vector3((i%8)*.85,0,-floori(i/8.0)*.85) if horizontal else Vector3(-floori(i/8.0)*.85,0,(i%8)*.85))

static func person(index: int) -> Node3D:
	var p := Node3D.new()
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
	return p
