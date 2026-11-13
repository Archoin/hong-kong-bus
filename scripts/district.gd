extends RefCounted

# Deliberately compressed, fictional street network inspired by Sheung Wan / Central.
const ROAD_X = [-96.0, -32.0, 32.0, 96.0]
const ROAD_Z = [-72.0, 0.0, 72.0]
const STOP_NAMES = ["Western Market", "Harbour Pier", "Central Market", "Pottinger Street", "Man Mo Temple", "Cat Street"]
const STOP_SHORT = ["WESTERN", "PIER", "CENTRAL", "POTTINGER", "MAN MO", "CAT ST"]
const STOP_POS = [Vector3(-96, 0, -37), Vector3(0, 0, -72), Vector3(96, 0, -36), Vector3(96, 0, 36), Vector3(0, 0, 72), Vector3(-96, 0, 36)]
const STOP_COLORS = [Color("efb64b"), Color("5cd9dd"), Color("ff9175"), Color("b6a0ed"), Color("badd72"), Color("ed8fbd")]

static func route(from: Vector3, to: Vector3) -> Array[Vector3]:
	# Insert endpoints into a small road graph; Dijkstra allows arbitrary stop positions.
	var nodes: Array[Vector3] = []
	for x in ROAD_X:
		for z in ROAD_Z:
			nodes.append(Vector3(x, 0, z))
	nodes.append(Vector3(from.x, 0, from.z))
	nodes.append(Vector3(to.x, 0, to.z))
	var count := nodes.size()
	var dist: Array[float] = []
	var prev: Array[int] = []
	var seen: Array[bool] = []
	for i in count:
		dist.append(INF)
		prev.append(-1)
		seen.append(false)
	dist[count - 2] = 0
	for _step in count:
		var best := -1
		for i in count:
			if not seen[i] and (best == -1 or dist[i] < dist[best]):
				best = i
		if best == -1 or dist[best] == INF:
			break
		seen[best] = true
		for j in count:
			if seen[j]:
				continue
			var aligned := (absf(nodes[best].x - nodes[j].x) < 0.1 and _on_axis(nodes[j].x, ROAD_X)) or (absf(nodes[best].z - nodes[j].z) < 0.1 and _on_axis(nodes[j].z, ROAD_Z))
			if aligned:
				var cost := dist[best] + nodes[best].distance_to(nodes[j])
				if cost < dist[j]:
					dist[j] = cost
					prev[j] = best
	var result: Array[Vector3] = []
	var at := count - 1
	while at != -1 and at != count - 2:
		result.push_front(nodes[at])
		at = prev[at]
	return result

static func _on_axis(value: float, axes: Array) -> bool:
	for axis in axes:
		if absf(value - axis) < 0.1:
			return true
	return false

static func nearest_road(p: Vector3) -> Vector3:
	var result := Vector3(p.x, 0, p.z)
	var nearest := INF
	for x in ROAD_X:
		if absf(p.x - x) < nearest:
			nearest = absf(p.x - x)
			result = Vector3(x, 0, clampf(p.z, -72, 72))
	for z in ROAD_Z:
		if absf(p.z - z) < nearest:
			nearest = absf(p.z - z)
			result = Vector3(clampf(p.x, -96, 96), 0, z)
	return result

static func lane_route(from: Vector3, to: Vector3, offset: float = 3.4) -> Array[Vector3]:
	var center_path := route(from,to)
	var lane_path: Array[Vector3] = []
	var previous := from
	for index in center_path.size():
		var point := center_path[index]
		var incoming := (point-previous).normalized()
		var left := Vector3.UP.cross(incoming)*offset
		if index+1<center_path.size():
			var outgoing := (center_path[index+1]-point).normalized()
			left += Vector3.UP.cross(outgoing)*offset
		lane_path.append(point+left)
		previous=point
	return lane_path
