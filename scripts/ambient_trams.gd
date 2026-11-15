class_name AmbientTrams
extends Node3D

# Original low-poly ding-ding, following the actual Des Voeux tram corridor.
# Visual reference: https://www.hktramways.com/en/our-story/
const D = preload("res://scripts/district.gd")
var game: Node3D
var fleet: Array[Dictionary] = []
var paints: Dictionary = {}

func _ready():
	var lines: Array = D.tram_routes()
	if lines.is_empty() or lines[0].size()<2: return
	var path: Array = lines[0]
	for index in 4:
		var reverse := index%2==1
		var points: Array = path.duplicate()
		if reverse: points.reverse()
		var shifted: Array[Vector3] = []
		for i in points.size():
			var tangent: Vector3 = points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]
			tangent.y=0
			var point: Vector3 = points[i]+Vector3.UP.cross(tangent.normalized())*2.075
			point.y=D.road_height(point)+.08
			shifted.append(point)
		var distances: Array[float] = [0.0]
		for i in range(1,shifted.size()): distances.append(distances[-1]+shifted[i-1].distance_to(shifted[i]))
		var body := make_tram(index)
		add_child(body)
		var entry := {"body":body,"points":shifted,"distances":distances,"length":distances[-1],"travel":distances[-1]*(.15+float(index/2)*.5),"speed":0.0,"dwell":0.0,"next_dwell":130.0+index*55}
		fleet.append(entry)
		place(entry)

func material(color: String) -> Material:
	if not paints.has(color):
		var mat := ShaderMaterial.new()
		mat.shader=preload("res://assets/shaders/toon.gdshader")
		mat.set_shader_parameter("paint",Color(color))
		paints[color]=mat
	return paints[color]

func box(parent: Node3D,size: Vector3,at: Vector3,color: String):
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	mesh.material=material(color)
	instance.mesh=mesh
	instance.position=at
	parent.add_child(instance)
	return instance

func label(parent: Node3D,value: String,at: Vector3,angle: float,size: int=36,color:=Color("fff0cd")):
	var node := Label3D.new()
	node.text=value
	node.position=at
	node.rotation.y=angle
	node.font_size=size
	node.pixel_size=.008
	node.modulate=color
	node.outline_size=0
	parent.add_child(node)

func make_tram(index: int) -> AnimatableBody3D:
	var root := AnimatableBody3D.new()
	root.name="DingDing"+str(index)
	root.collision_layer=4
	root.collision_mask=0
	root.sync_to_physics=false
	var color: String = ["2d6659","d5983c","8b3c35","436878"][index]
	box(root,Vector3(2.15,3.75,7.6),Vector3(0,2.4,0),color)
	box(root,Vector3(2.24,.17,7.75),Vector3(0,4.35,0),"e1d7b6")
	box(root,Vector3(2.2,.18,7.65),Vector3(0,2.55,0),"e1d7b6")
	box(root,Vector3(2.08,.36,6.5),Vector3(0,.45,0),"233a3b")
	for side in [-1,1]:
		for deck in [1.65,3.45]:
			for w in 7:
				var z: float = -2.95+w*.98
				box(root,Vector3(.03,.97,.76),Vector3(side*1.083,deck,z),"8daeb1")
				box(root,Vector3(.045,.035,.76),Vector3(side*1.108,deck+.13,z),"e8dcb4")
		for z in [-2.1,2.1]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius=.36
			mesh.bottom_radius=.36
			mesh.height=.15
			mesh.radial_segments=12
			mesh.material=material("253334")
			wheel.mesh=mesh
			wheel.rotation.z=PI/2
			wheel.position=Vector3(side*.94,.38,z)
			root.add_child(wheel)
		label(root,"小巴大夢  •  SMALL BUS, BIG DREAMS",Vector3(side*1.095,2.77,0),side*PI/2,25)
	for end in [-1,1]:
		for deck in [1.7,3.48]:
			box(root,Vector3(1.86,.94,.035),Vector3(0,deck,end*3.815),"8daeb1")
			box(root,Vector3(.07,.94,.05),Vector3(0,deck,end*3.84),"e8dcb4")
		box(root,Vector3(1.78,.31,.04),Vector3(0,4.08,end*3.83),"213a3a")
		label(root,"西港城  WESTERN MARKET" if end<0 else "上環  SHEUNG WAN",Vector3(0,4.09,end*3.865),PI if end<0 else 0,20)
		label(root,str(120+index),Vector3(0,.94,end*3.84),PI if end<0 else 0,32)
		box(root,Vector3(.22,.22,.06),Vector3(-.68,1.02,end*3.85),"ffe1a3")
		box(root,Vector3(.22,.22,.06),Vector3(.68,1.02,end*3.85),"ffe1a3")
	var pole: MeshInstance3D = box(root,Vector3(.055,.055,3.8),Vector3(0,5.08,0),"2a3d3c")
	pole.rotation.x=.36
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(2.15,4.1,7.6)
	collision.shape=shape
	collision.position.y=2.2
	root.add_child(collision)
	return root

func _physics_process(delta: float):
	if not is_instance_valid(game) or game.state in ["paused","results"]: return
	for tram in fleet:
		var body: Node3D = tram.body
		var forward: Vector3 = -body.global_transform.basis.z
		var player_offset: Vector3 = game.player.position-body.position
		var blocked: bool = player_offset.dot(forward)>0 and player_offset.dot(forward)<15 and absf(player_offset.dot(body.global_transform.basis.x))<2.7 and absf(player_offset.y)<4
		tram.dwell=maxf(0,tram.dwell-delta)
		var desired := 0.0 if blocked or tram.dwell>0 else 7.5
		tram.speed=move_toward(tram.speed,desired,delta*3)
		tram.travel+=tram.speed*delta
		tram.next_dwell-=tram.speed*delta
		if tram.next_dwell<0:
			tram.dwell=3.5
			tram.next_dwell=160.0
		if tram.travel>tram.length: tram.travel=0.0
		place(tram)

func place(tram: Dictionary):
	var points: Array = tram.points
	var distances: Array = tram.distances
	var index := 1
	while index<distances.size()-1 and distances[index]<tram.travel: index+=1
	var t: float = clampf((tram.travel-distances[index-1])/maxf(.01,distances[index]-distances[index-1]),0,1)
	var pos: Vector3 = points[index-1].lerp(points[index],t)
	var direction: Vector3 = points[index]-points[index-1]
	tram.body.position=pos
	tram.body.rotation=Vector3(atan2(direction.y,Vector2(direction.x,direction.z).length()),atan2(-direction.x,-direction.z),0)
