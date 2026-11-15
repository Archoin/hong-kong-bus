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
var cruising_speed := 15.0
var moving := false
var blocked_time := 0.0
var priority_hold := 0.0
var express_destination := -1
var dock_recorded := false
var total_wait := 0.0
var visits := 0

func setup(game_race: BusRace, id: int, initial_stop: int):
	race=game_race
	driver_id=id
	target_stop=initial_stop
	cruising_speed=[0.0,17.2,14.2,15.8][id]
	bus=Minibus.new()
	bus.controlled=false
	bus.body_color=[Color("d74e45"),Color("3d9b7c"),Color("5587ae"),Color("be8551")][id]
	add_child(bus)
	bus.collision_layer=4
	bus.collision_mask=0
	bus.position=D.STOP_POS[initial_stop]+Vector3(0,.06,0)
	var tangent: Vector3=D.stop_tangent(initial_stop)
	bus.rotation.y=atan2(-tangent.x,-tangent.z)
	race.drivers[id].last_stop=initial_stop
	var label:=Label3D.new()
	label.text=BusRace.DRIVER_NAMES[id]
	label.font_size=28
	label.pixel_size=.016
	label.position.y=4.1
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate=Color("ffe1b2")
	bus.add_child(label)
	choose_boarding_mode()

func tick(delta: float):
	if not race.active: return
	priority_hold=maxf(0,priority_hold-delta)
	bus.door_open=not moving
	if not moving:
		bus.set_remote_motion(Vector3.ZERO,0,delta)
		if not dock_recorded:
			race.record_stop(driver_id,target_stop,.55,true)
			dock_recorded=true
		dwell+=delta
		service_time+=delta
		if service_time>=.29:
			service_time=0
			var event:=race.service(driver_id,target_stop,express_destination)
			var party:=race.active_contract(driver_id)
			var party_ready: bool=not party.is_empty() and party.boarded>=party.party_size and target_stop==party.origin
			var loaded: int=race.drivers[driver_id].riders.size()
			if (event.is_empty() and dwell>1.0) or (party_ready and dwell>1.2) or (dwell>5.0 and loaded>=8) or dwell>8.0:
				choose_target()
		return
	if path.is_empty():
		moving=false
		dwell=0
		service_time=0
		dock_recorded=false
		visits+=1
		choose_boarding_mode()
		return
	var point:=path[0]+Vector3(0,.06,0)
	var difference:=point-bus.position
	if difference.length()<.7:
		bus.position=point
		path.pop_front()
		return
	var direction:=difference.normalized()
	var game=get_parent()
	var blocked:=false
	if game.player:
		var gap: Vector3=game.player.position-bus.position
		var ahead:=gap.dot(direction)
		var sideways: float=(gap-direction*ahead).length()
		blocked=ahead>0 and ahead<8.0 and sideways<2.7
	for tram in game.trams.fleet:
		var gap: Vector3=tram.body.position-bus.position
		var ahead:=gap.dot(direction)
		if ahead>0 and ahead<11.0 and (gap-direction*ahead).length()<2.7: blocked=true
	for other in game.rivals:
		if other==self: continue
		var gap: Vector3=other.bus.position-bus.position
		var ahead:=gap.dot(direction)
		if ahead>0 and ahead<7.5 and (gap-direction*ahead).length()<2.6:
			if other.driver_id<driver_id: blocked=true
			elif priority_hold>0: continue
			elif blocked_time>=2.0: priority_hold=3.0
			else: blocked=true
	if blocked:
		blocked_time+=delta
		total_wait+=delta
		bus.set_remote_motion(Vector3.ZERO,0,delta)
		return
	blocked_time=0
	var speed:=cruising_speed
	if difference.length()<13 and path.size()>1:
		var outgoing: Vector3=(path[1]-path[0]).normalized()
		if direction.dot(outgoing)<.8: speed=minf(speed,9.0)
	if path.size()==1: speed=minf(speed,maxf(3.0,difference.length()*1.6))
	bus.position+=direction*minf(speed*delta,difference.length())
	bus.rotation.y=lerp_angle(bus.rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*6))
	bus.set_remote_motion(direction,speed,delta)

func choose_boarding_mode():
	express_destination=-1
	if driver_id==1:
		var brief:=race.stop_brief(target_stop,driver_id)
		if brief.leading_count>=3: express_destination=brief.leading_dest
	var active:=race.active_contract(driver_id)
	if not active.is_empty() and active.origin==target_stop:
		express_destination=active.dest

func choose_target():
	race.depart_stop(driver_id)
	consider_dispatch()
	var destinations:=race.destinations(driver_id)
	var active:=race.active_contract(driver_id)
	var next: int=-1
	if not active.is_empty():
		if active.boarded>=active.party_size:
			next=active.dest
		elif race.drivers[driver_id].riders.size()<race.drivers[driver_id].capacity:
			next=active.origin
		# A full mixed bus must make room before honoring a new group pickup.
	var best: float=-INF
	if next<0 or next==target_stop:
		for i in D.STOP_POS.size():
			if i==target_stop: continue
			var distance: float=race.stop_distance(target_stop,i)
			var free_seats: int=race.drivers[driver_id].capacity-race.drivers[driver_id].riders.size()
			var pickup_value:=minf(race.boardable_count(driver_id,i),free_seats)*.38
			var delivery_value:=destinations[i]*3.0
			var score: float=(delivery_value+pickup_value+.5)/(distance/cruising_speed+5.0)
			if score>best:
				best=score
				next=i
	if next<0: next=(target_stop+1)%D.STOP_POS.size()
	path=D.lane_route(D.nearest_road(bus.position),D.STOP_POS[next])
	target_stop=next
	moving=true

func consider_dispatch():
	if driver_id==2 or race.elapsed()<14 or not race.active_contract(driver_id).is_empty(): return
	var offers:=race.dispatch_offers(driver_id)
	var best: float=0
	var selected: int=-1
	for offer in offers:
		var approach: float=D.road_distance(bus.position,D.STOP_POS[offer.origin])
		var total: float=approach+offer.distance
		if total/14+24>race.remaining: continue
		var free: int=race.drivers[driver_id].capacity-race.drivers[driver_id].riders.size()
		if free<offer.party_size: continue
		var score: float=(offer.reward+offer.party_size*28.0)/(total/cruising_speed+7.0)
		if score>best:
			best=score
			selected=offer.id
	# Dave actively chases bookings; Auntie only takes a particularly efficient one.
	if selected>=0 and (driver_id==3 or best>9):
		race.accept_contract(driver_id,selected,bus.position)
