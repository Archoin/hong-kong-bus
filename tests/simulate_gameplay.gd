extends SceneTree

# An abstract scheduling experiment using the real road graph and shared queues.
# It measures route decisions and service pacing, not handling skill or fun.
const D = preload("res://scripts/district.gd")
const MODES = ["always_fill","express","dispatch"]
const SEEDS = [41,73,117,334,789,20261114]
var reports: Array=[]
var player_cruise := 18.0

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cruise="): player_cruise=float(arg.trim_prefix("--cruise="))
	for seed_value in SEEDS:
		for mode in MODES:
			reports.append(run_shift(mode,seed_value))
	var aggregate := {}
	for mode in MODES:
		var rows: Array=reports.filter(func(row): return row.policy==mode)
		var stats := {"cash":0.0,"delivered":0.0,"completion_ratio":0.0,"dwell_fraction":0.0,"distance_m":0.0,"unique_stops":0.0,"contracts":0.0,"boarding_modes":0.0}
		for row in rows:
			for key in stats: stats[key]+=float(row[key])/rows.size()
		aggregate[mode]=stats
	var result := {"stop_count":D.STOP_POS.size(),"seeds":SEEDS,"duration":180,"player_cruise_mps":player_cruise,"method":"Abstract graph-time simulation; no collisions or human skill. Same seed, local demand and three greedy rivals for each policy. All stopping earns NEAT docking only. Service 0.25s board / 0.17s alight with 0.65s opening grace before boarding.","aggregate":aggregate,"runs":reports}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/gameplay_experiments"))
	var path := "res://docs/gameplay_experiments/policy_comparison_%dstops_%dmps.json"%[D.STOP_POS.size(),int(player_cruise)]
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("POLICY_COMPARISON ",JSON.stringify(aggregate))
	print("SAVED ",path)
	quit()

func run_shift(mode: String, seed_value: int) -> Dictionary:
	var race := BusRace.new()
	race.begin(19,seed_value)
	var actors: Array=[]
	for id in 4:
		var initial := 0 if id==0 else int(float(id)*D.STOP_POS.size()/4.0)%D.STOP_POS.size()
		actors.append({"id":id,"mode":mode if id==0 else "always_fill","stop":initial,"target":initial,"phase":"service","travel_left":0.0,"service_clock":0.0,"visit_clock":0.0,"express":-1,"dwell":0.0,"distance":0.0,"visits":[initial],"decisions":[],"boarding_modes":[],"trips":0})
		choose_boarding(race,actors[id])
		race.record_stop(id,initial,.5,true)
	var delta := .1
	for step in 1800:
		race.tick(delta)
		if not race.active: break
		for actor in actors:
			if actor.phase=="travel":
				actor.travel_left-=delta
				if actor.travel_left<=0:
					actor.stop=actor.target
					actor.phase="service"
					actor.visit_clock=0.0
					actor.service_clock=0.0
					actor.visits.append(actor.stop)
					choose_boarding(race,actor)
					race.record_stop(actor.id,actor.stop,.5,true)
				continue
			actor.dwell+=delta
			actor.visit_clock+=delta
			actor.service_clock+=delta
			var counts: Array=race.destinations(actor.id)
			var current_job := race.dispatch_hint(actor.id)
			if not current_job.is_empty() and current_job.phase=="collect" and current_job.target!=actor.stop and counts[actor.stop]==0:
				depart(race,actor)
				continue
			if counts[actor.stop]==0 and actor.visit_clock<.65:
				actor.service_clock=0.0
				continue
			var interval := .17 if counts[actor.stop]>0 else .25
			if actor.service_clock<interval: continue
			actor.service_clock-=interval
			var event := race.service(actor.id,actor.stop,actor.express)
			if event.is_empty() or actor.visit_clock>6.0:
				depart(race,actor)
	var player: Dictionary=race.drivers[0]
	var actor: Dictionary=actors[0]
	var unique: Array=[]
	for stop in actor.visits:
		if not stop in unique: unique.append(stop)
	var modes: Array=[]
	for boarding_mode in actor.boarding_modes:
		if not boarding_mode in modes: modes.append(boarding_mode)
	return {"policy":mode,"seed":seed_value,"cash":player.cash,"delivered":player.delivered,"boarded":player.boarded,"completion_ratio":float(player.delivered)/maxi(1,player.boarded),"dwell_fraction":actor.dwell/180.0,"distance_m":actor.distance,"unique_stops":unique.size(),"contracts":player.contracts_completed,"failed_contracts":player.contracts_failed,"tips":player.tip_total,"dispatch_income":player.dispatch_total,"boarding_modes":modes.size(),"route":actor.visits,"decision_log":actor.decisions,"rival_cash":[race.drivers[1].cash,race.drivers[2].cash,race.drivers[3].cash]}

func choose_boarding(race: BusRace, actor: Dictionary):
	actor.express=-1
	if actor.mode=="dispatch": maybe_accept(race,actor)
	var hint := race.dispatch_hint(actor.id)
	if not hint.is_empty():
		var job := race.active_contract(actor.id)
		actor.express=job.dest
	elif actor.mode!="always_fill":
		var brief := race.stop_brief(actor.stop,actor.id)
		var counts: Array=race.destinations(actor.id)
		var best := -INF
		for target in D.STOP_POS.size():
			if target==actor.stop or brief.destinations[target]==0: continue
			var score: float=(brief.destinations[target]+counts[target]*1.6)*race.fare_for(actor.stop,target)/(race.stop_distance(actor.stop,target)+60.0)
			if score>best:
				best=score
				actor.express=target
	actor.boarding_modes.append("mixed" if actor.express<0 else "express")

func maybe_accept(race: BusRace, actor: Dictionary):
	if not race.active_contract(actor.id).is_empty(): return
	var best := -INF
	var selected := -1
	for offer in race.dispatch_offers(actor.id):
		if race.drivers[actor.id].capacity-race.drivers[actor.id].riders.size()<offer.party_size: continue
		var approach := race.stop_distance(actor.stop,offer.origin)
		var distance: float=approach+offer.distance
		if distance/14.0+offer.party_size*.5+22>race.remaining: continue
		var score: float=(offer.reward+offer.party_size*race.fare_for(offer.origin,offer.dest))/(distance/player_cruise+8.0)
		if score>best:
			best=score
			selected=offer.id
	if selected>=0:
		var accepted := race.accept_contract(actor.id,selected,D.STOP_POS[actor.stop])
		if not accepted.is_empty(): actor.decisions.append({"at":snapped(race.elapsed(),.1),"action":"accept","id":selected,"pickup":accepted.origin,"dest":accepted.dest})

func depart(race: BusRace, actor: Dictionary):
	if actor.mode=="dispatch": maybe_accept(race,actor)
	var hint := race.dispatch_hint(actor.id)
	if not hint.is_empty() and hint.phase=="collect" and hint.target==actor.stop and race.drivers[actor.id].riders.size()<race.drivers[actor.id].capacity:
		actor.express=race.active_contract(actor.id).dest
		actor.service_clock=0.0
		actor.visit_clock=.65
		return
	var next := -1
	var reason := "local"
	if not hint.is_empty() and hint.target!=actor.stop:
		next=hint.target
		reason="dispatch_"+hint.phase
	var counts: Array=race.destinations(actor.id)
	var space: int=race.drivers[actor.id].capacity-race.drivers[actor.id].riders.size()
	if next<0:
		var best := -INF
		for stop in D.STOP_POS.size():
			if stop==actor.stop: continue
			var distance := race.stop_distance(actor.stop,stop)
			var available: int=race.boardable_count(actor.id,stop)
			if actor.mode!="always_fill": available=race.stop_brief(stop,actor.id).leading_count
			var score: float=(counts[stop]*4.0+minf(available,space)*.65+.2)/(distance+45.0)
			if distance/player_cruise+1.5>=race.remaining: score*=.05
			if score>best:
				best=score
				next=stop
	if next<0: return
	var distance := race.stop_distance(actor.stop,next)
	actor.phase="travel"
	actor.target=next
	actor.travel_left=distance/(player_cruise if actor.id==0 else 14.0)+1.5
	actor.distance+=distance
	actor.trips+=1
	actor.decisions.append({"at":snapped(race.elapsed(),.1),"action":"drive","from":actor.stop,"to":next,"reason":reason,"riders":race.drivers[actor.id].riders.size()})
	race.depart_stop(actor.id)
