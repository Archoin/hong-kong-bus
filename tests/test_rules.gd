extends SceneTree

const D = preload("res://scripts/district.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+message)

func _initialize():
	var race := BusRace.new()
	race.begin(19,12345)
	check(race.remaining==180,"default race duration is three minutes")
	for i in D.STOP_POS.size():
		for person in race.queues[i]:
			check(person.dest!=i and person.dest>=0 and person.dest<D.STOP_POS.size(),"valid random destination")
	# Put a known manifest in a stop and prove capacity and alighting ordering.
	race.queues[0].clear()
	for i in 24: race.queues[0].append({"id":1000+i,"dest":1,"fare":23,"origin":0})
	for i in 19: check(race.service(0,0).kind=="board","boarding succeeds up to capacity")
	check(race.drivers[0].riders.size()==19,"19 seats enforced")
	check(race.drivers[0].cash==0,"boarding does not award fares")
	check(race.service(0,0).is_empty(),"full bus rejects boarding")
	check(race.queues[0].size()==5,"unboarded passengers remain in queue")
	var queued: int = race.queues[1].size()
	check(race.service(0,1).kind=="drop","full bus can drop off before boarding")
	check(race.queues[1].size()==queued,"drop-off precedes new boarding")
	check(race.drivers[0].riders.size()==18,"drop-off frees a seat")
	check(race.drivers[0].cash==23,"one drop-off pays exact fare")
	for i in 18: race.service(0,1)
	check(race.drivers[0].cash==437,"19 completed fares paid exactly")
	check(race.delivered==19,"delivery total correct")
	check(race.service(0,1).kind=="board","boarding resumes after alighting")
	# Shared queue: two drivers cannot collect the same passenger.
	race.queues[2] = [{"id":777,"dest":3,"fare":25,"origin":2}]
	race.service(1,2)
	check(race.service(2,2).is_empty(),"AI shares the real queue")
	check(race.drivers[1].riders[0].id==777,"AI receives actual passenger")
	race.service(1,3)
	check(race.drivers[1].cash==25,"AI only earns through delivery")
	# Clock ends the service loop and settlement is idempotent.
	race.tick(181)
	check(race.settled and not race.active and race.remaining==0,"timer ends race at zero")
	check(race.player_rank==1 and race.last_bonus==200,"gold medal bonus")
	check(race.service(0,1).is_empty(),"no boarding after timeout")
	check(race.finish()==0,"second settlement pays nothing")
	for rank in range(1,5):
		race.begin(19,5)
		race.drivers[0].cash=100
		for i in range(1,rank): race.drivers[i].cash=200
		race.finish()
		check(race.player_rank==rank,"rank %d correct"%rank)
		check(race.last_bonus==[200,120,60,0][rank-1],"rank bonus correct")
	race.begin(19,5)
	race.finish()
	check(race.last_bonus==0,"no idle zero-fare bonus farming")
	race.begin(27,3)
	check(race.drivers[0].capacity==27,"upgraded capacity used")
	# Every stop pair follows the actual OSM road graph, including sloped and
	# diagonal streets. Each leg must lie wholly on one recorded road segment;
	# checking endpoints alone would allow cutting across a city block.
	# Stops are lane/bay targets, not centerline nodes: only the first/last
	# leg may connect to its exact nearest-road projection, within eight metres.
	var diagonal_edges := 0
	for edge in D.road_segments():
		if absf(edge.a.x-edge.b.x)>1 and absf(edge.a.z-edge.b.z)>1: diagonal_edges+=1
	check(diagonal_edges>0,"district includes non-orthogonal streets")
	check(not leg_on_road(Vector3(10000,0,10000),Vector3(10100,0,10100)),"road continuity check rejects an off-map shortcut")
	for a in D.STOP_POS.size():
		for b in D.STOP_POS.size():
			if a==b: continue
			var path := D.route(D.STOP_POS[a],D.STOP_POS[b])
			check(not path.is_empty() and path.back().distance_to(D.STOP_POS[b])<=.4,"all stop routes reach destination %d to %d"%[a,b])
			var previous: Vector3 = D.STOP_POS[a]
			var total := 0.0
			for point in path:
				var bay_connector := false
				if previous==D.STOP_POS[a]:
					bay_connector=point.distance_to(D.nearest_road(previous))<=.4 and previous.distance_to(point)<=8.0
				if point==D.STOP_POS[b]:
					bay_connector=bay_connector or (previous.distance_to(D.nearest_road(point))<=.4 and previous.distance_to(point)<=8.0)
				check(bay_connector or leg_on_road(previous,point),"route %d to %d follows roads or its short bay connector"%[a,b])
				total+=previous.distance_to(point)
				previous=point
			check(total+0.01>=D.STOP_POS[a].distance_to(D.STOP_POS[b]),"route distance cannot be shorter than direct distance")
			check(is_equal_approx(total,D.road_distance(D.STOP_POS[a],D.STOP_POS[b])),"fare routing distance matches actual path")
	print("RULE_TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func point_on_segment(point: Vector3, a: Vector3, b: Vector3) -> bool:
	var delta := b-a
	var t := clampf((point-a).dot(delta)/maxf(delta.length_squared(),.0001),0,1)
	return point.distance_to(a+delta*t)<=.4

func leg_on_road(a: Vector3, b: Vector3) -> bool:
	for edge in D.road_segments():
		if point_on_segment(a,edge.a,edge.b) and point_on_segment(b,edge.a,edge.b): return true
	return false
