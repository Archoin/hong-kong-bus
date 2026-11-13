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
	for i in 6:
		for person in race.queues[i]:
			check(person.dest!=i and person.dest>=0 and person.dest<6,"valid random destination")
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
	# Every pair of stops is connected by orthogonal streets.
	for a in 6:
		for b in 6:
			if a==b: continue
			var path := D.route(D.STOP_POS[a],D.STOP_POS[b])
			check(not path.is_empty() and path.back()==D.STOP_POS[b],"all stops connected")
			var previous: Vector3 = D.STOP_POS[a]
			for point in path:
				check(is_equal_approx(previous.x,point.x) or is_equal_approx(previous.z,point.z),"routes stay on orthogonal roads")
				previous = point
	print("RULE_TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
