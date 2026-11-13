class_name RivalDriver
extends Node3D

const D = preload("res://scripts/district.gd")
var driver_id := 1
var race: BusRace
var bus: Minibus
var target_stop := 0
var path: Array[Vector3] = []
var service_time := 0.0
var dwell := 0.0
var cruising_speed := 10.0
var moving := false
var blocked_time := 0.0
var priority_hold := 0.0

func setup(game_race: BusRace, id: int, initial_stop: int):
	race = game_race
	driver_id = id
	target_stop = initial_stop
	cruising_speed = 9.0 + id*.9
	bus = Minibus.new()
	bus.controlled = false
	bus.body_color = [Color("d74e45"),Color("3d9b7c"),Color("5587ae"),Color("be8551")][id]
	add_child(bus)
	bus.collision_layer = 4
	bus.collision_mask = 0
	bus.position = D.STOP_POS[initial_stop]+Vector3(2.7,.06,0)
	var label := Label3D.new()
	label.text = BusRace.DRIVER_NAMES[id]
	label.font_size = 30
	label.pixel_size = .025
	label.position.y = 4.3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bus.add_child(label)

func tick(delta: float):
	if not race.active: return
	priority_hold = maxf(0,priority_hold-delta)
	bus.door_open = not moving
	if not moving:
		dwell += delta
		service_time += delta
		if service_time >= .55:
			service_time = 0
			var event := race.service(driver_id,target_stop)
			if (event.is_empty() and dwell > 1.2) or dwell > 9:
				choose_target()
		return
	if path.is_empty():
		moving = false
		dwell = 0
		service_time = 0
		return
	var point := path[0] + Vector3(0,.06,0)
	var difference := point-bus.position
	if difference.length() < .65:
		bus.position = point
		path.pop_front()
		return
	var direction := difference.normalized()
	# Yield before entering the player, rather than moving a kinematic bus through them.
	var game = get_parent()
	var blocked := false
	if game.player:
		var gap: Vector3 = game.player.position-bus.position
		var ahead := gap.dot(direction)
		var sideways := (gap-direction*ahead).length()
		blocked = ahead>0 and ahead<8.0 and sideways<3.0
	for other in game.rivals:
		if other == self: continue
		var gap: Vector3 = other.bus.position-bus.position
		var ahead := gap.dot(direction)
		if ahead>0 and ahead<7.5 and (gap-direction*ahead).length()<2.7:
			# Keep a reservation long enough to clear the junction, rather than
			# repeatedly yielding again after a single movement frame.
			if other.driver_id<driver_id:
				blocked = true
			elif priority_hold>0:
				continue
			elif blocked_time>=2.0:
				priority_hold=3.0
			else:
				blocked = true
	if blocked:
		blocked_time += delta
		return
	blocked_time = 0
	bus.position += direction * minf(cruising_speed*delta,difference.length())
	for wheel in bus.wheels: wheel.rotate_object_local(Vector3.UP,cruising_speed*delta/.54)
	bus.rotation.y = lerp_angle(bus.rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*5))

func choose_target():
	var destinations := race.destinations(driver_id)
	var best := -INF
	var next := (target_stop+1)%6
	for i in 6:
		if i == target_stop: continue
		var distance: float = D.STOP_POS[target_stop].distance_to(D.STOP_POS[i])
		var demand := destinations[i]*4.0 + minf(race.queues[i].size(),race.drivers[driver_id].capacity-race.drivers[driver_id].riders.size())
		var score := (demand+1)/(distance+35)
		if score > best:
			best = score
			next = i
	path = D.lane_route(D.STOP_POS[target_stop],D.STOP_POS[next])
	target_stop = next
	moving = true
