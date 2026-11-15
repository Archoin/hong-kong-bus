extends SceneTree

const D = preload("res://scripts/district.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String):
	checks+=1
	if not condition:
		failures+=1
		push_error("FAIL: "+message)

func rider(id: int, origin: int, dest: int, fare: int = 25) -> Dictionary:
	return {"id":id,"origin":origin,"dest":dest,"fare":fare,"kind":"regular","tip":0,"tip_integrity":1.0,"contract_id":-1,"reserved_for":-1}

func _initialize():
	var race := BusRace.new()
	race.begin(19,334)
	check(race.queues.size()==D.STOP_POS.size(),"queues support the district's actual stop count")
	check(race.destinations().size()==D.STOP_POS.size(),"manifest supports dynamic stop count")
	for origin in race.queues.size():
		for person in race.queues[origin]:
			check(person.dest!=origin,"spawn never sends a rider to their origin")
			check(person.fare>=18 and person.fare<=54,"expanded map fare bounds")
	# Mixed/express are real alternatives: a selected rider is taken without
	# deleting or moving unrelated waiting passengers.
	race.queues[0]=[rider(1,0,1),rider(2,0,2),rider(3,0,1),rider(4,0,2)]
	var e := race.service(0,0,2)
	check(e.kind=="board" and e.rider.id==2,"express selects the pinned destination")
	check(race.queues[0][0].id==1 and race.queues[0].size()==3,"express preserves unrelated queue order")
	check(race.boardable_count(0,0,1)==2,"express boardable count is honest")
	var brief := race.stop_brief(0,0,1)
	check(brief.destinations[1]==2 and brief.leading_dest==1,"local demand is inspectable")
	race.drivers[0].riders.append(rider(5,1,0))
	e=race.service(0,0,2)
	check(e.kind=="drop" and e.rider.id==5,"express never blocks alighting")
	# An empty bay cannot pay out a docking reward by itself.
	race.record_stop(0,0,1.0,true)
	var cash_before: int=race.drivers[0].cash
	check(race.record_stop(0,0,1.0,true).is_empty(),"same docking event is debounced")
	check(race.drivers[0].cash==cash_before,"docking alone does not manufacture money")
	race.drivers[0].riders=[rider(6,1,0)]
	e=race.service(0,0)
	check(e.base_fare==25 and e.tip==4 and e.fare==29,"precise docking reward is attached to delivery")
	race.depart_stop(0)
	check(race.drivers[0].dock_bonus==0,"departing clears docking reward")
	# Timely tips and collision risk never remove earned or promised base fares.
	race.begin(19,334)
	var commuter := rider(11,0,1)
	commuter.kind="commuter"
	commuter.tip=12
	race.queues[0]=[commuter]
	race.service(0,0)
	check(not race.earliest_tip_deadline().is_empty(),"commuter creates visible deadline")
	check(race.onboard_tip_value()==12,"tip opportunity visible onboard")
	var hit := race.apply_bump(0,20)
	check(hit.lost_tips==6 and race.onboard_tip_value()==6,"impact reduces optional onboard tips")
	e=race.service(0,1)
	check(e.base_fare==25 and e.tip==6 and e.fare==31,"impact preserves base fare")
	race.begin(19,334)
	commuter=rider(12,0,1)
	commuter.kind="commuter"
	commuter.tip=12
	race.queues[0]=[commuter]
	race.service(0,0)
	var due: float=race.drivers[0].riders[0].tip_due
	race.tick(due+1.0)
	e=race.service(0,1)
	check(e.base_fare==25 and e.tip==0,"late commuter still pays ordinary fare")
	# Explicit acceptance, party reservation, progress, exact once-only bonus.
	race.begin(19,334)
	check(race.dispatch_offers().size()==2,"two distinct visible opportunities")
	var offer: Dictionary=race.dispatch_offers()[0]
	var job := race.accept_contract(0,offer.id,D.STOP_POS[offer.origin])
	check(not job.is_empty() and job.owner==0,"explicit accept owns a job")
	check(race.accept_contract(1,offer.id).is_empty(),"rival cannot double-claim a shared offer")
	check(race.accept_contract(0,race.dispatch_offers()[0].id).is_empty(),"one active commitment per driver")
	check(race.dispatch_hint().target==job.origin and race.dispatch_hint().phase=="collect","first phase points to pickup")
	var reserved := 0
	for person in race.queues[job.origin]:
		if person.get("reserved_for",-1)==0: reserved+=1
	check(reserved==job.party_size,"acceptance creates actual reserved party riders")
	# Fill the public queue with reserved riders only: the rival cannot steal them.
	var public_backup: Array=race.queues[job.origin].duplicate(true)
	race.queues[job.origin]=race.queues[job.origin].filter(func(person): return person.get("reserved_for",-1)==0)
	check(race.service(1,job.origin).is_empty(),"accepted party is protected from rivals")
	race.queues[job.origin]=public_backup
	for i in job.party_size:
		e=race.service(0,job.origin,(job.dest+1)%D.STOP_POS.size())
		check(e.rider.get("contract_id",-1)==job.id,"party commitment has boarding priority over express sign")
	check(race.dispatch_hint().phase=="deliver" and race.dispatch_hint().target==job.dest,"all aboard changes the objective")
	var expected_base := race.fare_for(job.origin,job.dest)*int(job.party_size)
	var bonuses := 0
	for i in job.party_size:
		e=race.service(0,job.dest)
		bonuses+=int(e.dispatch_bonus)
	check(bonuses==job.reward,"party bonus is paid exactly once")
	check(race.drivers[0].cash==expected_base+job.reward,"all party fares plus bonus accounted")
	check(race.active_contract().is_empty() and race.drivers[0].contracts_completed==1,"completed job releases the commitment slot")
	check(race.drivers[0].dispatch_total==job.reward,"dispatch earnings are separately inspectable")
	var messages := race.pop_events()
	check(messages.any(func(ev): return ev.kind=="party_aboard") and messages.any(func(ev): return ev.kind=="contract_completed"),"job progress has event feedback")
	check(race.pop_events().is_empty(),"notification drain does not repeat messages")
	# Failure preserves onboard base fares and releases remaining party seats.
	race.begin(19,334)
	offer=race.dispatch_offers()[0]
	job=race.accept_contract(0,offer.id,D.STOP_POS[offer.origin])
	race.service(0,job.origin)
	var boarded_fare: int=race.drivers[0].riders[0].fare
	race.tick(job.time_left+0.1)
	check(race.active_contract().is_empty() and race.drivers[0].contracts_failed==1,"deadline expires the bonus")
	check(race.boardable_count(1,job.origin)==race.queues[job.origin].size(),"uncollected expired party returns to public queue")
	e=race.service(0,job.dest)
	check(e.base_fare==boarded_fare and e.dispatch_bonus==0,"failed contract rider still pays the base fare")
	# Approach distance matters: same offer accepted farther away gets a larger
	# budget, rather than silently relying on pickup-to-dropoff distance alone.
	var near_race := BusRace.new()
	var far_race := BusRace.new()
	near_race.begin(19,335)
	far_race.begin(19,335)
	offer=near_race.dispatch_offers()[0]
	var farthest := 0
	for i in D.STOP_POS.size():
		if near_race.stop_distance(i,offer.origin)>near_race.stop_distance(farthest,offer.origin): farthest=i
	var near_quote := near_race.quote_contract(0,offer.id,D.STOP_POS[offer.origin])
	var far_quote := far_race.quote_contract(0,offer.id,D.STOP_POS[farthest])
	check(near_quote.available and near_quote.can_finish,"valid offer has a feasible quote")
	check(far_quote.total_distance>near_quote.total_distance,"quote includes approach road distance")
	check(near_race.active_contract().is_empty(),"quoting never claims a booking")
	var near_job := near_race.accept_contract(0,offer.id,D.STOP_POS[offer.origin])
	var far_job := far_race.accept_contract(0,offer.id,D.STOP_POS[farthest])
	check(is_equal_approx(near_job.time_left,near_quote.budget_seconds) and is_equal_approx(far_job.time_left,far_quote.budget_seconds),"quotes exactly match accepted deadline budgets")
	check(not near_race.quote_contract(0,offer.id).available,"active booking blocks another quote")
	check(not far_job.is_empty() and far_job.time_left>near_job.time_left,"acceptance deadline includes approach distance")
	var late_offer_id: int=far_race.dispatch_offers()[0].id
	far_race.remaining=4
	far_race._contract(late_offer_id).offer_expires=181.0
	var late_quote := far_race.quote_contract(1,late_offer_id,D.STOP_POS[0])
	check(late_quote.available and not late_quote.can_finish and not late_quote.reason.is_empty(),"late quote explains infeasibility before acceptance")
	check(far_race.accept_contract(1,late_offer_id,D.STOP_POS[0]).is_empty(),"reject impossible end-of-shift acceptance")
	print("GAMEPLAY_SYSTEMS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
