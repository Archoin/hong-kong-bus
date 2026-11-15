extends RefCounted

# Real OSM street topology; see docs/MAP_DESIGN.md for projection and attribution.
const STOP_NAMES = ["Western Market", "Macau Ferry Terminal", "Waterfront Park", "Dried Seafood Street", "Bonham Strand", "Hollywood Road Park", "Cat Street / Lok Ku", "Man Mo Temple", "PMQ / Aberdeen St", "Central Market", "SoHo / Gage Street", "Sheung Wan Station"]
const STOP_SHORT = ["WESTERN", "FERRY", "WATERFRONT", "SEAFOOD", "BONHAM", "HOLLYWOOD", "CAT ST", "MAN MO", "PMQ", "CENTRAL", "SOHO", "MTR"]
const STOP_ZONES = ["market", "harbour", "harbour", "market", "market", "heritage", "heritage", "heritage", "creative", "business", "nightlife", "business"]
const STOP_POS = [Vector3(-80.8,18.016,-113.79),Vector3(42.46,10.86,-164.24),Vector3(-434.77,1.975,-267.43),Vector3(-362.11,8.617,-169.67),Vector3(-173.07,21.92,-65.64),Vector3(-301.41,27.273,21.8),Vector3(-221.93,31.123,50.72),Vector3(-104.75,41.753,145.02),Vector3(72.38,43.671,209.91),Vector3(342.94,18.231,124.45),Vector3(173.15,37.895,252.22),Vector3(100.61,22.008,-55.68)]
const STOP_CURBS = [Vector3(-79.65,17.41,-118.24),Vector3(38.09,10.71,-165.67),Vector3(-435.57,1.877,-271.96),Vector3(-361.67,8.106,-174.25),Vector3(-174.15,21.498,-70.11),Vector3(-298.51,26.874,18.23),Vector3(-224.99,30.752,47.29),Vector3(-102.3,41.282,141.13),Vector3(69.05,43.651,206.74),Vector3(339.31,18.569,127.28),Vector3(169.4,38.397,254.89),Vector3(101.76,21.597,-60.13)]
const STOP_TANGENTS = [Vector3(0.96854,0,0.24886),Vector3(0.31053,0,-0.95056),Vector3(0.98489,0,-0.17316),Vector3(0.99546,0,0.09518),Vector3(0.97244,0,-0.23317),Vector3(0.77628,0,0.63039),Vector3(0.74651,0,-0.66537),Vector3(0.84575,0,0.53358),Vector3(0.68942,0,-0.72436),Vector3(-0.61427,0,-0.7891),Vector3(-0.58009,0,-0.81455),Vector3(0.96841,0,0.24938)]
const STOP_COLORS = [Color("efb64b"),Color("5cd9dd"),Color("80c6ad"),Color("ea926d"),Color("e2b789"),Color("badd72"),Color("ed8fbd"),Color("d6da78"),Color("aa9fe3"),Color("ff9175"),Color("d98bcc"),Color("87b9e8")]
const MAP_BOUNDS = Rect2(-560,-330,1120,660)
const SPAWN_POSITION = Vector3(-95.72829,18.242402146086345,-111.94707)
const SPAWN_HEADING = -1.8222992411563148

static var _data: Dictionary = {}
static var _segments: Array = []
static var _graph: AStar3D
static var _distance_cache: Dictionary = {}

static func map_data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map_data/district.json"))
	return _data

static func vector(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

static func road_segments() -> Array:
	if _segments.is_empty():
		for edge in map_data().edges:
			var segment: Dictionary = edge.duplicate()
			segment.a = vector(edge.a)
			segment.b = vector(edge.b)
			_segments.append(segment)
	return _segments

static func graph() -> AStar3D:
	if _graph == null:
		_graph = AStar3D.new()
		var nodes: Array = map_data().nodes
		for i in nodes.size(): _graph.add_point(i,vector(nodes[i]))
		for e in map_data().edges: _graph.connect_points(int(e.i),int(e.j),true)
	return _graph

static func _closest(point: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var distance := INF
	for edge in road_segments():
		var a: Vector3 = edge.a
		var b: Vector3 = edge.b
		var flat := Vector3(b.x-a.x,0,b.z-a.z)
		var t := clampf(Vector3(point.x-a.x,0,point.z-a.z).dot(flat)/maxf(flat.length_squared(),0.001),0,1)
		var p := a.lerp(b,t)
		var score := Vector2(point.x-p.x,point.z-p.z).length_squared()
		if score < distance:
			distance = score
			best = {"edge":edge,"point":p}
	return best

static func nearest_road(point: Vector3) -> Vector3:
	return _closest(point).point

static func route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var g := graph()
	var start := _closest(from)
	var finish := _closest(to)
	var n := g.get_point_count()
	g.add_point(n,start.point)
	g.add_point(n+1,finish.point)
	for k in ["i","j"]:
		g.connect_points(n,int(start.edge[k]),true)
		g.connect_points(n+1,int(finish.edge[k]),true)
	if start.edge.i == finish.edge.i and start.edge.j == finish.edge.j:
		g.connect_points(n,n+1,true)
	var path := g.get_point_path(n,n+1)
	g.remove_point(n)
	g.remove_point(n+1)
	var result: Array[Vector3] = []
	for p in path:
		if result.is_empty() or result[-1].distance_to(p)>0.3: result.append(p)
	if result.is_empty() or result[-1].distance_to(to)>0.3: result.append(to)
	return result

static func lane_route(from: Vector3, to: Vector3, offset: float = 2.6) -> Array[Vector3]:
	var path := route(from,to)
	var result: Array[Vector3] = []
	for i in path.size():
		if i == path.size()-1:
			result.append(to)
			continue
		var before: Vector3 = from if i==0 else path[i-1]
		var incoming := path[i]-before
		var outgoing := path[i+1]-path[i]
		incoming.y=0
		outgoing.y=0
		if incoming.length()<0.1: incoming=outgoing
		var left := Vector3.UP.cross(incoming.normalized())
		var next_left := Vector3.UP.cross(outgoing.normalized())
		var miter := (left+next_left).normalized()
		var p := path[i]+miter*minf(offset/maxf(0.6,miter.dot(left)),offset*1.5)
		p.y=road_height(p)
		result.append(p)
	return result

static func road_height(point: Vector3) -> float:
	var terrain: Dictionary = map_data().terrain
	var xs: Array = terrain.x
	var zs: Array = terrain.z
	var u := clampf((point.x-float(xs[0]))/(float(xs[-1])-float(xs[0]))*(xs.size()-1),0,xs.size()-1.00001)
	var v := clampf((point.z-float(zs[0]))/(float(zs[-1])-float(zs[0]))*(zs.size()-1),0,zs.size()-1.00001)
	var i := int(u)
	var j := int(v)
	var h: Array = terrain.heights
	return lerpf(lerpf(h[j][i],h[j][i+1],u-i),lerpf(h[j+1][i],h[j+1][i+1],u-i),v-j)

static func stop_tangent(stop: int) -> Vector3:
	return STOP_TANGENTS[stop]

static func stop_curb_position(stop: int) -> Vector3:
	return STOP_CURBS[stop]

static func district_name_at(point: Vector3) -> String:
	if point.z < -180: return "VICTORIA HARBOUR"
	if point.x > 220: return "CENTRAL"
	if point.z > 100: return "SOHO / MID-LEVELS" if point.x>0 else "TAI PING SHAN"
	return "SHEUNG WAN"

static func road_distance(a: Vector3,b: Vector3) -> float:
	var distance := 0.0
	var previous := a
	for point in route(a,b):
		distance += previous.distance_to(point)
		previous=point
	return distance

static func stop_distance(a: int,b: int) -> float:
	var key := Vector2i(mini(a,b),maxi(a,b))
	if not _distance_cache.has(key): _distance_cache[key]=road_distance(STOP_POS[a],STOP_POS[b])
	return _distance_cache[key]

static func tram_routes() -> Array:
	var points:Array[Vector3]=[]
	for p in map_data().tram_route:points.append(vector(p))
	return [points]

static func road_name_at(point: Vector3) -> String:
	return str(_closest(point).edge.name)
