extends SceneTree
const D=preload("res://scripts/district.gd")
func _initialize():
	var failed:=false
	var min_dist:=INF
	var max_dist:=0.0
	for i in D.STOP_POS.size():
		for j in D.STOP_POS.size():
			if i==j:continue
			var path:=D.route(D.STOP_POS[i],D.STOP_POS[j])
			if path.size()<2:failed=true;push_error("No route %d→%d"%[i,j])
			var length:=D.stop_distance(i,j)
			min_dist=minf(min_dist,length)
			max_dist=maxf(max_dist,length)
	var trams:=D.tram_routes()
	print("MAP_GRAPH stops=",D.STOP_POS.size()," all_pairs=",D.STOP_POS.size()*(D.STOP_POS.size()-1)," distance_range=",min_dist,"..",max_dist," tram_points=",trams[0].size())
	if trams[0].size()<50:failed=true;push_error("Tram spine disconnected")
	quit(1 if failed else 0)
