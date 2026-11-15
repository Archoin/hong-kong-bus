class_name BusRace
extends RefCounted

const D = preload("res://scripts/district.gd")
const DURATION := 180.0
const DRIVER_NAMES = ["You", "Auntie Turbo", "Uncle Siu", "Dim Sum Dave"]
const DISPATCH_TITLES = ["The dim sum aunties", "Last ferry, big hurry", "Wedding photo emergency", "The noodle night shift", "Mahjong club outing", "Pineapple bun pilgrimage", "The lost hiking club", "One very late lunch"]
const DISPATCH_LINES = ["The tea is already getting cold.", "They have opinions about your shortcut.", "Four cousins. One extremely loud group chat.", "Nobody is leaving without their takeaway.", "Auntie promised she knew the way.", "The buns deserve a smooth ride.", "They wore hiking boots to a tram stop.", "The table booking is a matter of honour."]

var rng := RandomNumberGenerator.new()
var dispatch_rng := RandomNumberGenerator.new()
var queues: Array = []
var drivers: Array = []
var remaining := DURATION
var spawn_clock := 0.0
var active := false
var settled := false
var delivered := 0
var picked_up := 0
var total_fares := 0
var last_bonus := 0
var player_rank := 4
var serial := 0
var contracts: Array = []
var contract_serial := 0
var event_queues: Array = []
var distance_matrix: Array = []
var nearby_stops: Array = []
var next_offer_at := 0.0
var dispatch_enabled := true
var tips_enabled := true
var local_clusters_enabled := true

func elapsed() -> float:
	return DURATION - remaining

func begin(capacity: int = 19, seed_value: int = 0):
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value
	dispatch_rng.seed = int(rng.seed) ^ 0x51D15A
	queues.clear()
	drivers.clear()
	contracts.clear()
	event_queues.clear()
	remaining = DURATION
	spawn_clock = 0
	settled = false
	active = true
	delivered = 0
	picked_up = 0
	total_fares = 0
	last_bonus = 0
	player_rank = 4
	serial = 0
	contract_serial = 0
	next_offer_at = 0
	_cache_distances()
	for i in D.STOP_POS.size(): queues.append([])
	for i in DRIVER_NAMES.size():
		drivers.append({"name":DRIVER_NAMES[i],"cash":0,"riders":[],"capacity":capacity if i==0 else 19,"delivered":0,"fare_total":0,"tip_total":0,"dispatch_total":0,"contracts_completed":0,"contracts_failed":0,"precise_stops":0,"impacts":0,"last_stop":0,"dock_stop":-1,"dock_bonus":0,"dock_grade":"","last_dock_at":-100.0,"stops_served":[],"boarded":0})
		event_queues.append([])
	for i in queues.size():
		for _j in rng.randi_range(9,13): spawn(i)
	if dispatch_enabled: _refill_offers(true)

func _cache_distances():
	var count := D.STOP_POS.size()
	if distance_matrix.size()==count: return
	distance_matrix.clear()
	nearby_stops.clear()
	for a in count:
		var row: Array[float] = []
		var near: Array[int] = []
		for b in count:
			row.append(0.0 if a==b else D.stop_distance(a,b))
			if a!=b: near.append(b)
		distance_matrix.append(row)
		near.sort_custom(func(left,right): return row[left]<row[right])
		nearby_stops.append(near)

func stop_distance(a: int, b: int) -> float:
	if a<0 or b<0 or a>=distance_matrix.size() or b>=distance_matrix.size(): return INF
	return distance_matrix[a][b]

func fare_for(a: int, b: int) -> int:
	# The expanded district should pay for useful distance without making
	# a single cross-map trip dominate a three-minute race.
	return 18 + mini(36,int(stop_distance(a,b)/28.0))

func spawn(stop: int):
	if stop<0 or stop>=queues.size() or queues[stop].size()>=24: return
	var choices: Array = nearby_stops[stop]
	if choices.is_empty(): return
	var dest: int
	if not local_clusters_enabled:
		dest = choices[rng.randi_range(0,choices.size()-1)]
	else:
		# Visible local waves create batches worth taking express. They rotate
		# on a 45-second rhythm, while a minority still want longer journeys.
		var local_count := mini(3,choices.size())
		var favourite := (stop+int(elapsed()/45.0))%local_count
		var roll := rng.randf()
		if roll<.58: dest=choices[favourite]
		elif roll<.86: dest=choices[rng.randi_range(0,local_count-1)]
		else: dest=choices[rng.randi_range(0,choices.size()-1)]
	var kind := "regular"
	var kind_roll := rng.randf()
	if kind_roll<.27: kind="commuter"
	elif kind_roll<.40: kind="sightseer"
	serial += 1
	queues[stop].append({"id":serial,"dest":dest,"fare":fare_for(stop,dest),"origin":stop,"kind":kind,"tip":rng.randi_range(8,15) if kind=="commuter" else (7 if kind=="sightseer" else 0),"tip_integrity":1.0,"tip_due":-1.0,"boarded_at":-1.0,"contract_id":-1,"reserved_for":-1})

func tick(delta: float):
	if not active: return
	remaining=maxf(0,remaining-delta)
	spawn_clock+=delta
	while spawn_clock>=2.1:
		spawn_clock-=2.1
		spawn(rng.randi_range(0,queues.size()-1))
		spawn(rng.randi_range(0,queues.size()-1))
	for contract in contracts:
		if contract.status=="offered" and elapsed()>=contract.offer_expires:
			contract.status="expired"
		elif contract.status=="active" and elapsed()>contract.deadline:
			_fail_contract(contract,"Time's up. Ordinary fares still count.")
	if remaining<=0:
		finish()
		return
	if dispatch_enabled and elapsed()>=next_offer_at: _refill_offers()

func service(driver_id: int, stop: int, express_dest: int = -1) -> Dictionary:
	if not active or driver_id<0 or driver_id>=drivers.size() or stop<0 or stop>=queues.size(): return {}
	var driver: Dictionary=drivers[driver_id]
	driver.last_stop=stop
	# Unload first regardless of express sign or spare capacity.
	for i in driver.riders.size():
		var rider: Dictionary=driver.riders[i]
		if rider.dest!=stop: continue
		driver.riders.remove_at(i)
		var base_fare: int=rider.fare
		var tip := _earned_tip(rider)
		var dock_tip: int=driver.dock_bonus if driver.dock_stop==stop and tips_enabled else 0
		tip+=dock_tip
		var contract_bonus := _complete_party_rider(driver_id,rider)
		var paid := base_fare+tip+contract_bonus
		driver.cash+=paid
		driver.fare_total+=base_fare
		driver.tip_total+=tip
		driver.delivered+=1
		if not stop in driver.stops_served: driver.stops_served.append(stop)
		if driver_id==0:
			delivered+=1
			total_fares+=base_fare+tip
		return {"kind":"drop","fare":paid,"base_fare":base_fare,"tip":tip,"dispatch_bonus":contract_bonus,"contract_completed":contract_bonus>0,"rider":rider}
	if driver.riders.size()>=driver.capacity: return {}
	var board_index := _boarding_index(driver_id,stop,express_dest)
	if board_index<0: return {}
	var rider: Dictionary=queues[stop][board_index]
	queues[stop].remove_at(board_index)
	rider.boarded_at=elapsed()
	if rider.get("kind","regular")=="commuter":
		rider.tip_due=elapsed()+maxf(24.0,stop_distance(stop,rider.dest)/14.0+21.0)
	driver.riders.append(rider)
	driver.boarded+=1
	var contract_id: int=rider.get("contract_id",-1)
	if contract_id>=0:
		var contract := _contract(contract_id)
		if not contract.is_empty() and contract.status=="active":
			contract.boarded+=1
			if contract.boarded==contract.party_size:
				_event(driver_id,"party_aboard","Everyone's in! Next stop: "+D.STOP_NAMES[contract.dest],{"contract_id":contract.id,"target":contract.dest})
	if driver_id==0: picked_up+=1
	return {"kind":"board","fare":0,"base_fare":0,"tip":0,"dispatch_bonus":0,"contract_completed":false,"rider":rider}

func _boarding_index(driver_id: int, stop: int, express_dest: int) -> int:
	# The accepted party is the driver's explicit commitment; unrelated
	# reserved parties cannot be stolen or block the public queue.
	for i in queues[stop].size():
		var rider: Dictionary=queues[stop][i]
		if rider.get("reserved_for",-1)==driver_id: return i
	for i in queues[stop].size():
		var rider: Dictionary=queues[stop][i]
		if rider.get("reserved_for",-1)>=0: continue
		if express_dest<0 or rider.dest==express_dest: return i
	return -1

func boardable_count(driver_id: int, stop: int, express_dest: int = -1) -> int:
	if stop<0 or stop>=queues.size(): return 0
	var count := 0
	for rider in queues[stop]:
		var owner: int=rider.get("reserved_for",-1)
		if owner==driver_id or (owner<0 and (express_dest<0 or rider.dest==express_dest)): count+=1
	return count

func destinations(driver_id: int = 0) -> Array[int]:
	var counts: Array[int]=[]
	counts.resize(D.STOP_POS.size())
	counts.fill(0)
	if driver_id<0 or driver_id>=drivers.size(): return counts
	for rider in drivers[driver_id].riders: counts[rider.dest]+=1
	return counts

func stop_brief(stop: int, driver_id: int = 0, express_dest: int = -1) -> Dictionary:
	var counts: Array[int]=[]
	counts.resize(queues.size())
	counts.fill(0)
	var hurry := 0
	for rider in queues[stop]:
		if rider.get("reserved_for",-1)>=0 and rider.get("reserved_for",-1)!=driver_id: continue
		counts[rider.dest]+=1
		if rider.get("kind","")=="commuter": hurry+=1
	var leading := -1
	for i in counts.size():
		if counts[i]>0 and (leading<0 or counts[i]>counts[leading]): leading=i
	return {"waiting":queues[stop].size(),"destinations":counts,"boardable":boardable_count(driver_id,stop),"express_count":boardable_count(driver_id,stop,express_dest),"commuters":hurry,"leading_dest":leading,"leading_count":counts[leading] if leading>=0 else 0}

func _earned_tip(rider: Dictionary) -> int:
	if not tips_enabled: return 0
	var offered: int=rider.get("tip",0)
	if rider.get("kind","")=="commuter" and elapsed()>float(rider.get("tip_due",-1.0)): return 0
	return int(round(offered*float(rider.get("tip_integrity",1.0))))

func onboard_tip_value(driver_id: int = 0) -> int:
	var total := 0
	for rider in drivers[driver_id].riders: total+=_earned_tip(rider)
	return total

func earliest_tip_deadline(driver_id: int = 0) -> Dictionary:
	var soonest := INF
	var target := -1
	var amount := 0
	for rider in drivers[driver_id].riders:
		if rider.get("kind","")!="commuter" or _earned_tip(rider)<=0: continue
		var due: float=rider.get("tip_due",INF)
		if due<soonest:
			soonest=due
			target=rider.dest
			amount=_earned_tip(rider)
	return {} if target<0 else {"dest":target,"time_left":maxf(0,soonest-elapsed()),"tip":amount}

func record_stop(driver_id: int, stop: int, precision: float, clean: bool = true) -> Dictionary:
	if not active: return {}
	var driver: Dictionary=drivers[driver_id]
	if driver.dock_stop==stop and elapsed()-driver.last_dock_at<2.0: return {}
	driver.last_stop=stop
	driver.dock_stop=stop
	driver.last_dock_at=elapsed()
	driver.dock_bonus=0
	driver.dock_grade="WIDE"
	if clean and precision>=.75:
		driver.dock_bonus=4
		driver.dock_grade="PERFECT"
		driver.precise_stops+=1
	elif clean and precision>=.4:
		driver.dock_bonus=2
		driver.dock_grade="NEAT"
	# The reward is attached to delivered passengers; visiting an empty bay
	# repeatedly never creates money.
	return {"grade":driver.dock_grade,"tip_per_rider":driver.dock_bonus,"precision":precision}

func depart_stop(driver_id: int):
	if driver_id<0 or driver_id>=drivers.size(): return
	drivers[driver_id].dock_stop=-1
	drivers[driver_id].dock_bonus=0
	drivers[driver_id].dock_grade=""

func apply_bump(driver_id: int, severity: float) -> Dictionary:
	if not active or severity<4.0: return {}
	var driver: Dictionary=drivers[driver_id]
	var before := onboard_tip_value(driver_id)
	var damage := clampf(severity*.025,.15,.65)
	for rider in driver.riders: rider.tip_integrity=maxf(0,float(rider.get("tip_integrity",1.0))-damage)
	driver.impacts+=1
	driver.dock_bonus=0
	var lost := before-onboard_tip_value(driver_id)
	if lost>0: _event(driver_id,"tips_spilled","The milk tea survived. HK$%d in tips did not."%lost,{"lost":lost})
	return {"lost_tips":lost,"severity":severity}

func dispatch_offers(driver_id: int = 0) -> Array:
	var result: Array=[]
	if not dispatch_enabled: return result
	for contract in contracts:
		if contract.status=="offered" and elapsed()<contract.offer_expires and not driver_id in contract.ignored_by:
			result.append(_contract_snapshot(contract))
			if result.size()==2: break
	return result

func active_contract(driver_id: int = 0) -> Dictionary:
	for contract in contracts:
		if contract.owner==driver_id and contract.status=="active": return _contract_snapshot(contract)
	return {}

func dispatch_hint(driver_id: int = 0) -> Dictionary:
	var contract := active_contract(driver_id)
	if contract.is_empty(): return {}
	var collecting: bool=contract.boarded<contract.party_size
	return {"target":contract.origin if collecting else contract.dest,"phase":"collect" if collecting else "deliver","contract_id":contract.id,"boarded":contract.boarded,"delivered":contract.delivered,"party_size":contract.party_size,"time_left":contract.time_left,"reward":contract.reward}

# Read-only quote. available means eligible to claim; can_finish additionally
# requires enough shift time. Distances are road metres, budget is seconds.
func quote_contract(driver_id: int, offer_id: int, from_position: Vector3 = Vector3.INF) -> Dictionary:
	var quote := {"available":false,"approach_distance":0.0,"total_distance":0.0,"budget_seconds":0.0,"can_finish":false,"reason":"Booking unavailable"}
	if not active or not dispatch_enabled or driver_id<0 or driver_id>=drivers.size(): return quote
	if not active_contract(driver_id).is_empty():
		quote.reason="Finish your current booking first"
		return quote
	var contract := _contract(offer_id)
	if contract.is_empty() or contract.status!="offered" or elapsed()>=contract.offer_expires: return quote
	if driver_id in contract.ignored_by:
		quote.reason="Booking declined"
		return quote
	var approach := stop_distance(drivers[driver_id].last_stop,contract.origin) if from_position==Vector3.INF else D.road_distance(from_position,D.STOP_POS[contract.origin])
	quote.available=true
	quote.approach_distance=approach
	quote.total_distance=approach+contract.distance
	quote.budget_seconds=_delivery_budget(approach,contract.distance,contract.party_size)
	quote.can_finish=quote.budget_seconds<=remaining-2.0
	quote.reason="" if quote.can_finish else "Too far before shift ends"
	return quote

func accept_contract(driver_id: int, offer_id: int, from_position: Vector3 = Vector3.INF) -> Dictionary:
	var quote := quote_contract(driver_id,offer_id,from_position)
	if not quote.available: return {}
	if not quote.can_finish:
		_event(driver_id,"contract_too_late","Not enough shift left for that pickup. Try a nearer fare.")
		return {}
	var contract := _contract(offer_id)
	var budget: float=quote.budget_seconds
	contract.owner=driver_id
	contract.status="active"
	contract.accepted_at=elapsed()
	contract.deadline=elapsed()+budget
	for i in contract.party_size:
		serial+=1
		queues[contract.origin].push_front({"id":serial,"dest":contract.dest,"fare":fare_for(contract.origin,contract.dest),"origin":contract.origin,"kind":"party","tip":0,"tip_integrity":1.0,"tip_due":-1.0,"boarded_at":-1.0,"contract_id":contract.id,"reserved_for":driver_id})
	_event(driver_id,"contract_accepted","DISPATCH: "+contract.title,{"contract_id":contract.id,"target":contract.origin})
	for other in drivers.size():
		if other!=driver_id: _event(other,"contract_claimed",DRIVER_NAMES[driver_id]+" booked "+contract.title,{"contract_id":contract.id,"owner":driver_id})
	next_offer_at=minf(next_offer_at,elapsed()+3.0)
	return _contract_snapshot(contract)

func decline_offer(driver_id: int, offer_id: int) -> bool:
	var contract := _contract(offer_id)
	if contract.is_empty() or contract.status!="offered": return false
	if not driver_id in contract.ignored_by: contract.ignored_by.append(driver_id)
	return true

func _delivery_budget(approach: float, distance: float, party_size: int) -> float:
	# Graph distance, conservative arcade cruising speed, two service visits,
	# then a fixed grace interval for turns and a small route-planning detour.
	return maxf((approach+distance)/14.0+party_size*.5+20.0,32.0)

func _refill_offers(initial: bool = false):
	next_offer_at=elapsed()+5.0
	if remaining<38.0: return
	var available := 0
	for contract in contracts:
		if contract.status=="offered": available+=1
	while available<2:
		_create_offer(initial,available)
		available+=1

func _create_offer(initial: bool, slot: int):
	var base: int=drivers[0].last_stop
	var near: Array=nearby_stops[base]
	var origin: int = base if initial and slot==0 else (near[dispatch_rng.randi_range(0,mini(3,near.size()-1))] if not near.is_empty() else base)
	var destinations_near: Array=nearby_stops[origin]
	var destination_index := dispatch_rng.randi_range(0,mini(4,destinations_near.size()-1))
	# Second slot leans farther away: a deliberate local-vs-express tradeoff.
	if slot==1 and destinations_near.size()>3: destination_index=mini(destinations_near.size()-1,dispatch_rng.randi_range(2,4))
	var destination: int=destinations_near[destination_index]
	var party_size := dispatch_rng.randi_range(3,5)
	var distance := stop_distance(origin,destination)
	contract_serial+=1
	var flavour := dispatch_rng.randi_range(0,DISPATCH_TITLES.size()-1)
	var reward := 70+party_size*12+mini(180,int(distance*.20))
	contracts.append({"id":contract_serial,"title":DISPATCH_TITLES[flavour],"line":DISPATCH_LINES[flavour],"origin":origin,"dest":destination,"party_size":party_size,"reward":reward,"offer_expires":elapsed()+34.0,"deadline":elapsed()+_delivery_budget(stop_distance(base,origin),distance,party_size),"distance":distance,"status":"offered","owner":-1,"boarded":0,"delivered":0,"accepted_at":-1.0,"ignored_by":[]})

func _contract(id: int) -> Dictionary:
	for contract in contracts:
		if contract.id==id: return contract
	return {}

func _contract_snapshot(contract: Dictionary) -> Dictionary:
	var result: Dictionary=contract.duplicate(true)
	result.time_left=maxf(0,float(contract.deadline)-elapsed())
	result.offer_time_left=maxf(0,float(contract.offer_expires)-elapsed())
	return result

func _complete_party_rider(driver_id: int, rider: Dictionary) -> int:
	var id: int=rider.get("contract_id",-1)
	if id<0: return 0
	var contract := _contract(id)
	if contract.is_empty() or contract.owner!=driver_id or contract.status!="active": return 0
	contract.delivered+=1
	if contract.delivered<contract.party_size: return 0
	contract.status="completed"
	contract.completed_at=elapsed()
	drivers[driver_id].contracts_completed+=1
	drivers[driver_id].dispatch_total+=contract.reward
	_event(driver_id,"contract_completed","PARTY DELIVERED! +HK$%d • %s"%[contract.reward,contract.title],{"contract_id":id,"reward":contract.reward})
	return contract.reward

func _fail_contract(contract: Dictionary, reason: String):
	contract.status="failed"
	var owner: int=contract.owner
	if owner<0: return
	drivers[owner].contracts_failed+=1
	# Waiting party members rejoin the public queue; onboard riders retain
	# their destination and ordinary fare, so a late job never becomes dead cargo.
	for queue in queues:
		for rider in queue:
			if rider.get("contract_id",-1)==contract.id:
				rider.reserved_for=-1
				rider.contract_id=-1
	_event(owner,"contract_failed",reason,{"contract_id":contract.id})

func _event(driver_id: int, kind: String, message: String, data: Dictionary = {}):
	var event := data.duplicate()
	event.kind=kind
	event.message=message
	event.at=elapsed()
	event_queues[driver_id].append(event)
	if event_queues[driver_id].size()>64: event_queues[driver_id].pop_front()

func pop_events(driver_id: int = 0) -> Array:
	if driver_id<0 or driver_id>=event_queues.size(): return []
	var result: Array=event_queues[driver_id].duplicate(true)
	event_queues[driver_id].clear()
	return result

func ranking() -> Array:
	var order: Array=[]
	for i in drivers.size(): order.append(i)
	order.sort_custom(func(a,b): return drivers[a].cash>drivers[b].cash if drivers[a].cash!=drivers[b].cash else a<b)
	return order

func rank_of(driver_id: int) -> int:
	var place := 1
	for driver in drivers:
		if driver.cash>drivers[driver_id].cash: place+=1
	return place

func finish() -> int:
	if settled: return 0
	active=false
	settled=true
	for contract in contracts:
		if contract.status=="active": _fail_contract(contract,"Shift over. Incomplete dispatch bonus not paid.")
	player_rank=rank_of(0)
	last_bonus=[200,120,60,0][player_rank-1] if drivers[0].cash>0 else 0
	return drivers[0].cash+last_bonus
