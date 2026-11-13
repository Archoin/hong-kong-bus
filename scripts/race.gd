class_name BusRace
extends RefCounted

const D = preload("res://scripts/district.gd")
const DURATION := 180.0
const DRIVER_NAMES = ["You", "Auntie Turbo", "Uncle Siu", "Dim Sum Dave"]
var rng := RandomNumberGenerator.new()
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

func begin(capacity: int = 19, seed_value: int = 0):
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value
	queues.clear()
	drivers.clear()
	remaining = DURATION
	spawn_clock = 0
	settled = false
	active = true
	delivered = 0
	picked_up = 0
	total_fares = 0
	serial = 0
	for i in 6:
		queues.append([])
		for _j in rng.randi_range(7,11): spawn(i)
	for i in 4:
		drivers.append({"name": DRIVER_NAMES[i], "cash": 0, "riders": [], "capacity": capacity if i == 0 else 19, "delivered": 0})

func spawn(stop: int):
	if queues[stop].size() >= 24: return
	var dest := rng.randi_range(0,4)
	if dest >= stop: dest += 1
	var distance: float = D.STOP_POS[stop].distance_to(D.STOP_POS[dest])
	serial += 1
	queues[stop].append({"id": serial, "dest": dest, "fare": 14 + int(distance / 8.0), "origin": stop})

func tick(delta: float):
	if not active: return
	remaining = maxf(0, remaining - delta)
	spawn_clock += delta
	while spawn_clock >= 2.6:
		spawn_clock -= 2.6
		spawn(rng.randi_range(0,5))
		spawn(rng.randi_range(0,5))
	if remaining <= 0: finish()

func service(driver_id: int, stop: int) -> Dictionary:
	if not active or stop < 0 or stop >= queues.size(): return {}
	var driver: Dictionary = drivers[driver_id]
	# Alighting always happens first, including when the bus is full.
	for i in driver.riders.size():
		var rider: Dictionary = driver.riders[i]
		if rider.dest == stop:
			driver.riders.remove_at(i)
			driver.cash += rider.fare
			driver.delivered += 1
			if driver_id == 0:
				delivered += 1
				total_fares += rider.fare
			return {"kind": "drop", "fare": rider.fare, "rider": rider}
	if driver.riders.size() < driver.capacity and not queues[stop].is_empty():
		var rider: Dictionary = queues[stop].pop_front()
		driver.riders.append(rider)
		if driver_id == 0: picked_up += 1
		return {"kind": "board", "fare": 0, "rider": rider}
	return {}

func destinations(driver_id: int = 0) -> Array[int]:
	var counts: Array[int] = [0,0,0,0,0,0]
	if drivers.is_empty(): return counts
	for rider in drivers[driver_id].riders: counts[rider.dest] += 1
	return counts

func ranking() -> Array:
	var order: Array = [0,1,2,3]
	order.sort_custom(func(a,b): return drivers[a].cash > drivers[b].cash if drivers[a].cash != drivers[b].cash else a < b)
	return order

func rank_of(driver_id: int) -> int:
	var place := 1
	for driver in drivers:
		if driver.cash > drivers[driver_id].cash: place += 1
	return place

func finish() -> int:
	if settled: return 0
	active = false
	settled = true
	player_rank = rank_of(0)
	# No medal bonus for a zero-fare race. Ties share the corresponding rank.
	last_bonus = [200,120,60,0][player_rank - 1] if drivers[0].cash > 0 else 0
	return drivers[0].cash + last_bonus
