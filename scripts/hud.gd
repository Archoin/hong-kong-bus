extends Control

const D = preload("res://scripts/district.gd")
const INK = Color("102e38")
const PAPER = Color("fff0cd")
const GOLD = Color("f4bd59")
const MUTED = Color("a8bebc")
const MINT = Color("a9dfb3")
var game: Node3D
var regular: Font
var bold: Font
var display: Font
var buttons: Array = []
var mouse := Vector2.ZERO
var scale_factor := Vector2.ONE
var quote_cache: Dictionary = {}
var quote_at := -1000.0

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Avenir Next","Noto Sans","Arial"])
	regular = f
	var b := SystemFont.new()
	b.font_names = f.font_names
	b.font_weight = 700
	bold = b
	var d := SystemFont.new()
	d.font_names = PackedStringArray(["Avenir Next Condensed","Impact","Noto Sans"])
	d.font_weight = 800
	display = d

func _input(event: InputEvent):
	if event is InputEventMouseMotion:
		mouse = event.position / scale_factor
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var p: Vector2 = event.position / scale_factor
		for button_data in buttons:
			if button_data.rect.has_point(p):
				act(button_data.action)
				get_viewport().set_input_as_handled()
				return

func act(action: String):
	if action == "start": game.start_race()
	elif action == "garage": game.state = "garage"
	elif action == "title": game.return_to_title()
	elif action == "resume": game.resume_race()
	elif action == "pause": game.pause_race()
	elif action == "map": game.show_map = not game.show_map
	elif action == "quit": get_tree().quit()
	elif action == "express": game.toggle_express()
	elif action.begins_with("express:"): game.run_express(int(action.trim_prefix("express:")))
	elif action.begins_with("accept:"): game.accept_dispatch(int(action.trim_prefix("accept:")))
	elif action.begins_with("buy:"): game.purchase(action.trim_prefix("buy:"))
	elif action.begins_with("stop:"):
		game.select_stop(int(action.trim_prefix("stop:")))
		game.play_sound("board")
	elif action == "mute":
		game.muted = not game.muted
		AudioServer.set_bus_mute(0,game.muted)

func card(rect: Rect2, color := Color("102e38"), radius := 14, border := Color.TRANSPARENT):
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border.a > 0:
		style.set_border_width_all(1)
		style.border_color = border
	draw_style_box(style,rect)

func txt(value: String, p: Vector2, size_px := 20, color := PAPER, font: Font = null):
	draw_string(regular if font==null else font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func centered(value: String, p: Vector2, size_px: int, color := PAPER, font: Font = null):
	var use_font: Font = regular if font==null else font
	var width := use_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
	txt(value,p-Vector2(width/2,0),size_px,color,use_font)

func paragraph(value: String, p: Vector2, width: float, size_px := 20, color := PAPER):
	var line := ""
	var y := p.y
	for word in value.split(" "):
		var attempt := line+word+" "
		if regular.get_string_size(attempt,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x > width and not line.is_empty():
			txt(line,Vector2(p.x,y),size_px,color)
			y += size_px*1.5
			line = word+" "
		else: line = attempt
	txt(line,Vector2(p.x,y),size_px,color)

func button(label: String, rect: Rect2, action: String, primary := false, disabled := false):
	var hover := rect.has_point(mouse)
	var bg := GOLD if primary else Color("224550")
	if disabled: bg = Color("344c52")
	elif hover: bg = bg.lightened(.12)
	card(rect,bg,10,Color("65807d") if not primary else Color.TRANSPARENT)
	centered(label,Vector2(rect.get_center().x,rect.position.y+rect.size.y/2+7),20,MUTED if disabled else (INK if primary else PAPER),bold)
	if not disabled: buttons.append({"rect":rect,"action":action})

func _draw():
	if game == null or regular == null: return
	scale_factor = get_viewport_rect().size/Vector2(1440,900)
	draw_set_transform(Vector2.ZERO,0,scale_factor)
	buttons.clear()
	match game.state:
		"title": title_screen()
		"garage": garage_screen()
		"results": results_screen()
		_: race_hud()
	if game.state == "countdown":
		card(Rect2(563,302,314,226),Color(INK,.93),20)
		centered("YOUR SHIFT STARTS IN",Vector2(720,345),17,GOLD,bold)
		centered(str(maxi(1,ceili(game.countdown))),Vector2(720,462),100,PAPER,display)
		centered("More fares. More glory.",Vector2(720,500),20,MUTED)
	if game.state == "paused": pause_screen()
	if game.show_map and game.state == "race": full_map()
	if game.toast_time>0 and game.state not in ["countdown","results"]:
		var width := minf(960,regular.get_string_size(game.toast,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x+48)
		card(Rect2(720-width/2,185,width,45),Color(INK,.96),10)
		centered(game.toast,Vector2(720,214),20,game.toast_color,bold)

func title_screen():
	# Opaque editorial panel leaves the live diorama visible on the right.
	card(Rect2(0,0,610,900),Color("12323c"),0)
	draw_rect(Rect2(0,0,10,900),GOLD)
	txt("HK / 002",Vector2(48,62),20,GOLD,bold)
	txt("THE OLD TOWN MONEY RUN",Vector2(175,62),16,MUTED,bold)
	draw_line(Vector2(48,87),Vector2(556,87),Color("436069"),1)
	txt("HONG",Vector2(42,214),116,PAPER,display)
	txt("KONG BUS",Vector2(42,329),116,GOLD,display)
	txt("SMALL BUS. BIG HUSTLE.",Vector2(49,383),26,PAPER,bold)
	paragraph("Forget the finish line. Pick up passengers, plot your own route, and turn three minutes of Hong Kong chaos into cold, hard cash.",Vector2(49,432),490,21,MUTED)
	for i in 3:
		var y := 554+i*42
		draw_circle(Vector2(60,y-7),10,GOLD)
		centered(str(i+1),Vector2(60,y-2),13,INK,bold)
		txt(["CHOOSE a mixed load or an express run.","BOOK a party. Beat the dispatch deadline.","DRIVE clean. Keep the tips. Out-earn rivals."][i],Vector2(84,y),19,PAPER)
	button("START YOUR SHIFT   →",Rect2(48,699,508,62),"start",true)
	button("GARAGE",Rect2(48,778,244,49),"garage")
	button("SOUND: "+("OFF" if game.muted else "ON"),Rect2(307,778,249,49),"mute")
	txt("WASD / ARROWS  drive     SPACE  brake     ENTER  start",Vector2(48,866),15,MUTED)
	card(Rect2(1016,32,390,97),Color(INK,.90),12)
	txt("SHEUNG WAN → CENTRAL",Vector2(1040,69),22,PAPER,bold)
	txt("Real streets. Bigger decisions. Same tiny bus.",Vector2(1040,101),16,MUTED)
	card(Rect2(875,735,530,130),Color(INK,.94),14)
	txt("JADE ROOF. BIGGER DREAMS." if game.premium_equipped else "RED ROOF. GOLDEN OPPORTUNITY.",Vector2(900,772),20,GOLD,bold)
	paragraph("%d seats • 180 seconds • HK$200 gold bonus. Every passenger has somewhere to be. Preferably alive."%game.capacity(),Vector2(900,807),478,18,PAPER)

func race_hud():
	var driver: Dictionary = game.race.drivers[0]
	card(Rect2(24,24,252,91),Color(INK,.94),10)
	txt("SHIFT TAKINGS",Vector2(42,48),13,MUTED,bold)
	txt("$%d"%driver.cash,Vector2(40,94),42,MINT if game.fare_flash>0 else GOLD,display)
	txt("#%d"%game.race.rank_of(0),Vector2(220,91),24,PAPER,bold)
	card(Rect2(642,24,156,90),Color(INK,.94),10)
	centered("TIME LEFT",Vector2(720,48),12,MUTED,bold)
	var secs: int = ceili(game.race.remaining)
	centered("%d:%02d"%[floori(secs/60.0),secs%60],Vector2(720,96),43,Color("ff977c") if secs<=30 else PAPER,display)
	card(Rect2(1176,24,240,150),Color(INK,.94),10)
	txt("STREET LEGENDS",Vector2(1193,48),13,GOLD,bold)
	var order: Array = game.race.ranking()
	for row in 4:
		var id: int = order[row]
		var y := 74+row*25
		if id==0: card(Rect2(1186,y-18,220,24),Color("2d5360"),4)
		txt(str(row+1),Vector2(1195,y),14,MUTED,bold)
		txt(game.race.drivers[id].name,Vector2(1216,y),14,PAPER if id==0 else MUTED,bold)
		txt("$%d"%game.race.drivers[id].cash,Vector2(1353,y),14,PAPER,bold)
	dispatch_panel()
	# Show only occupied destinations; the city stays visible through most of the screen.
	var counts: Array = game.race.destinations()
	var destinations: Array = []
	for i in counts.size():
		if counts[i]>0: destinations.append(i)
	destinations.sort_custom(func(a,b): return counts[a]>counts[b])
	var rows := mini(5,destinations.size())
	card(Rect2(1176,338,240,105+rows*28+(22 if rows>0 else 0)+(20 if destinations.size()>5 else 0)),Color(INK,.90),10)
	txt("ON BOARD",Vector2(1193,365),12,MUTED,bold)
	txt("%d / %d"%[driver.riders.size(),driver.capacity],Vector2(1193,405),32,GOLD,display)
	if destinations.is_empty(): txt("Seats are opportunities.",Vector2(1193,430),14,MUTED)
	for row in rows:
		var id: int = destinations[row]
		var y := 438+row*28
		var hit := Rect2(1188,y-20,216,27)
		if game.selected_stop==id: card(hit,Color("31555c"),4)
		draw_circle(Vector2(1203,y-6),9,D.STOP_COLORS[id])
		centered(str(id+1),Vector2(1203,y-1),11,INK,bold)
		txt(D.STOP_SHORT[id].left(15),Vector2(1220,y),13,PAPER,bold)
		txt(str(counts[id])+" ↓",Vector2(1366,y),15,D.STOP_COLORS[id],bold)
		buttons.append({"rect":hit,"action":"stop:"+str(id)})
	if rows>0:
		txt("Tips $%d • drive clean"%game.race.onboard_tip_value(),Vector2(1193,442+rows*28),12,MINT)
	if destinations.size()>5:
		txt("+%d more destinations • M"%(destinations.size()-5),Vector2(1193,462+rows*28),12,MUTED)
	# Show the queue before arrival, so express is a driving decision.
	if game.approach_stop>=0: queue_panel()
	card(Rect2(24,650,286,226),Color(INK,.92),10)
	txt((game.street_label if not game.street_label.is_empty() else game.district_label).to_upper().left(27),Vector2(40,675),12,PAPER,bold)
	txt("N ↑",Vector2(270,675),12,MUTED,bold)
	map_draw(Rect2(38,686,258,164),false)
	txt("M  city map     , / .  next stop",Vector2(40,867),12,MUTED)
	buttons.append({"rect":Rect2(24,650,286,226),"action":"map"})
	card(Rect2(413,731,614,55),Color(INK,.94),9)
	var to_next: Vector3 = game.route_guide.next_point-game.player.position
	var bearing := wrapf(atan2(-to_next.x,-to_next.z)-game.player.rotation.y,-PI,PI)
	arrow(Vector2(442,757),-bearing,GOLD,14)
	txt(D.STOP_NAMES[game.selected_stop],Vector2(470,754),19,PAPER,bold)
	txt("%d to drop  •  %d waiting"%[counts[game.selected_stop],game.race.queues[game.selected_stop].size()],Vector2(470,774),12,MUTED)
	txt("%dm"%int(game.route_guide.road_distance),Vector2(935,765),22,GOLD,bold)
	card(Rect2(413,796,614,79),Color(INK,.94),9)
	centered(game.service_status,Vector2(720,822),16,PAPER,bold)
	var progress: float = clampf(game.service_timer/maxf(.01,game.service_interval),0,1) if game.current_stop>=0 and absf(game.player.speed)<1.1 else 0.0
	draw_rect(Rect2(430,834,580,3),Color("37535b"))
	if progress>0: draw_rect(Rect2(430,834,580*progress,3),MINT)
	centered("E  "+("EXPRESS → "+D.STOP_SHORT[game.express_destination] if game.express_mode else "LOCAL • ALL DESTINATIONS")+"     SPACE brake",Vector2(720,861),13,GOLD if game.express_mode else MUTED,bold)
	buttons.append({"rect":Rect2(413,843,614,32),"action":"express"})
	card(Rect2(1271,755,145,121),Color(INK,.92),10)
	centered("%02d"%int(absf(game.player.speed)*3.6),Vector2(1344,818),46,PAPER,display)
	centered("km/h  •  "+("R" if game.player.speed<-.3 else "D"),Vector2(1344,842),13,MUTED)
	centered("H horn  /  C view",Vector2(1344,865),11,MUTED)
	if game.dock_grade_time>0:
		card(Rect2(563,640,314,58),Color(INK,.93),10)
		centered(game.dock_grade,Vector2(720,678),24,MINT,display)

func dispatch_panel():
	if not game.race.has_method("dispatch_offers"): return
	var active: Dictionary = game.race.active_contract(0)
	if not active.is_empty():
		card(Rect2(24,130,310,148),Color("1c4649"),10,Color("609783"))
		txt("DISPATCH BOOKING",Vector2(42,155),12,MINT,bold)
		txt(str(active.get("title","Private party")).left(29),Vector2(42,182),20,PAPER,bold)
		var hint: Dictionary = game.race.dispatch_hint(0)
		var target: int = hint.get("target",active.get("origin",0))
		txt(("PICK UP  " if active.get("boarded",0)<active.get("party_size",4) else "DELIVER  ")+D.STOP_SHORT[target],Vector2(42,210),15,GOLD,bold)
		txt("%d / %d aboard  •  $%d bonus"%[active.get("boarded",0)-active.get("delivered",0),active.get("party_size",4),active.get("reward",0)],Vector2(42,235),14,MUTED)
		txt("%ds left"%maxi(0,ceili(active.get("time_left",0))),Vector2(42,260),16,PAPER,bold)
		buttons.append({"rect":Rect2(24,130,310,148),"action":"stop:"+str(target)})
		return
	var offers: Array = game.race.dispatch_offers(0)
	if game.elapsed-quote_at>1.0:
		quote_cache.clear()
		quote_at=game.elapsed
	for i in mini(2,offers.size()):
		var offer: Dictionary = offers[i]
		if not quote_cache.has(offer.id): quote_cache[offer.id]=game.race.quote_contract(0,offer.id,game.player.position)
		var quote: Dictionary=quote_cache[offer.id]
		var feasible: bool=quote.get("can_finish",false)
		var y := 130+i*100
		var rect := Rect2(24,y,310,94)
		card(rect,Color(INK,.92),9,Color("446a67"))
		txt(("F" if i==0 else "G")+"  "+str(offer.get("title","Group booking")).left(24),Vector2(40,y+23),16,GOLD if feasible else MUTED,bold)
		txt(D.STOP_SHORT[offer.origin]+" → "+D.STOP_SHORT[offer.dest],Vector2(40,y+47),13,PAPER,bold)
		txt("%d riders  +$%d  •  %dm total"%[offer.party_size,offer.reward,int(quote.get("total_distance",0))],Vector2(40,y+66),12,MUTED)
		txt("Accept • %ds deadline"%ceili(quote.get("budget_seconds",0)) if feasible else "Too far before shift ends",Vector2(40,y+84),12,MINT if feasible else Color("dc9982"))
		if feasible: buttons.append({"rect":rect,"action":"accept:"+str(offer.id)})

func queue_panel():
	var id: int = game.approach_stop
	var counts: Array[int] = []
	counts.resize(D.STOP_POS.size())
	counts.fill(0)
	for rider in game.race.queues[id]: counts[rider.dest]+=1
	var order: Array = []
	for dest in counts.size():
		if counts[dest]>0: order.append(dest)
	order.sort_custom(func(a,b): return counts[a]>counts[b])
	var rows := mini(3,order.size())
	if rows==0: return
	card(Rect2(24,345,310,71+rows*29),Color(INK,.92),10)
	txt(("AT " if game.current_stop==id else "APPROACHING ")+D.STOP_SHORT[id],Vector2(41,370),12,MUTED,bold)
	txt("Click a row to run express →",Vector2(41,394),13,PAPER)
	for row in rows:
		var dest: int = order[row]
		var y := 424+row*29
		draw_circle(Vector2(51,y-6),8,D.STOP_COLORS[dest])
		txt(D.STOP_SHORT[dest],Vector2(68,y),14,PAPER,bold)
		txt(str(counts[dest])+" riders",Vector2(253,y),13,GOLD)
		buttons.append({"rect":Rect2(36,y-20,282,28),"action":"express:"+str(dest)})

func player_pos() -> Vector3:
	return game.player.position

func map_bounds(large: bool) -> Rect2:
	if large: return D.MAP_BOUNDS
	var p := player_pos()
	return Rect2(p.x-145,p.z-92,290,184)

func map_point(world: Vector3, rect: Rect2, large := true) -> Vector2:
	var bounds := map_bounds(large)
	return rect.position+(Vector2(world.x,world.z)-bounds.position)/bounds.size*rect.size

func clipped_line(a: Vector2,b: Vector2,rect: Rect2,color: Color,width: float):
	var delta := b-a
	var t0 := 0.0
	var t1 := 1.0
	var p := [-delta.x,delta.x,-delta.y,delta.y]
	var q := [a.x-rect.position.x,rect.end.x-a.x,a.y-rect.position.y,rect.end.y-a.y]
	for i in 4:
		if absf(p[i])<.0001:
			if q[i]<0: return
		else:
			var r: float = q[i]/p[i]
			if p[i]<0: t0=maxf(t0,r)
			else: t1=minf(t1,r)
			if t0>t1: return
	draw_line(a+delta*t0,a+delta*t1,color,width,true)

func arrow(center: Vector2,angle: float,color: Color,radius: float):
	var points := PackedVector2Array()
	for p in [Vector2(0,-1),Vector2(.65,.7),Vector2(0,.4),Vector2(-.65,.7)]:
		points.append(center+p.rotated(angle)*radius)
	draw_colored_polygon(points,color)

func map_draw(rect: Rect2, large: bool):
	card(rect,Color("1a3e47"),6)
	var bounds := map_bounds(large)
	var coast: Array=D.map_data().coast
	var land:=PackedVector2Array([rect.position+Vector2(0,rect.size.y),rect.end])
	for step in range(40,-1,-1):
		var x:=bounds.position.x+bounds.size.x*step/40.0
		var shore:=float(coast[0][1])
		for i in range(1,coast.size()):
			if float(coast[i][0])>=x:
				var t:=clampf((x-float(coast[i-1][0]))/maxf(.01,float(coast[i][0])-float(coast[i-1][0])),0,1)
				shore=lerpf(float(coast[i-1][1]),float(coast[i][1]),t)
				break
		land.append(Vector2(rect.position.x+rect.size.x*step/40.0,clampf(map_point(Vector3(x,0,shore),rect,large).y,rect.position.y,rect.end.y)))
	draw_colored_polygon(land,Color("29484b"))
	if large:
		for building in D.map_data().buildings:
			var polygon:=PackedVector2Array()
			for point in building.points: polygon.append(map_point(Vector3(point[0],0,point[1]),rect,true))
			if polygon.size()>=3: draw_colored_polygon(polygon,Color("3b5b5c"))
	# Draw the real street graph at the same orientation as the world.
	for segment in D.road_segments():
		var a := map_point(segment.a,rect,large)
		var b := map_point(segment.b,rect,large)
		var width: float = maxf(1.5,float(segment.width)/bounds.size.x*rect.size.x)
		clipped_line(a,b,rect,Color("708784"),width)
	var previous := map_point(player_pos(),rect,large)
	for point in game.route_guide.route_points:
		var current := map_point(point,rect,large)
		clipped_line(previous,current,rect,GOLD,3 if large else 2)
		previous=current
	var counts: Array = game.race.destinations()
	for i in D.STOP_POS.size():
		var p := map_point(D.STOP_POS[i],rect,large)
		if not rect.grow(-13).has_point(p): continue
		if i==game.selected_stop: draw_arc(p,14 if large else 11,0,TAU,24,PAPER,2,true)
		draw_circle(p,10 if large else 7,D.STOP_COLORS[i])
		centered(str(i+1),p+Vector2(0,4),13 if large else 10,INK,bold)
		if counts[i]>0 and rect.grow(-35).has_point(p):
			card(Rect2(p+Vector2(8,-26),Vector2(38,20)),GOLD,4)
			txt(str(counts[i])+" ↓",p+Vector2(12,-11),12,INK,bold)
		if large:
			buttons.append({"rect":Rect2(p-Vector2(18,18),Vector2(36,36)),"action":"stop:"+str(i)})
	for rival in game.rivals:
		var p := map_point(rival.bus.position,rect,large)
		if rect.grow(-5).has_point(p): draw_circle(p,4,Color("ef8c7d"))
	var marker := map_point(player_pos(),rect,large)
	if rect.grow(-12).has_point(marker): arrow(marker,-game.player.rotation.y,PAPER,11 if large else 9)
	if large:
		txt("VICTORIA HARBOUR",rect.position+Vector2(18,25),14,Color("75a6b0"),bold)

func full_map():
	buttons.clear()
	draw_rect(Rect2(0,0,1440,900),Color(INK,.8))
	card(Rect2(28,30,1384,840),Color("14343e"),14,Color("5b7775"))
	txt("KNOW YOUR PATCH.",Vector2(54,82),37,PAPER,display)
	txt("Pin a stop • inspect the queue • choose LOCAL or EXPRESS",Vector2(55,112),17,MUTED)
	card(Rect2(1190,48,194,66),Color("24474e"),8)
	centered("SHIFT TIME LEFT",Vector2(1287,70),11,MUTED,bold)
	var seconds:=ceili(game.race.remaining)
	centered("%d:%02d"%[seconds/60,seconds%60],Vector2(1287,102),29,Color("ff977c") if seconds<=30 else GOLD,bold)
	var outer := Rect2(54,142,902,620)
	var map_size: Vector2 = D.MAP_BOUNDS.size
	var factor := minf(outer.size.x/map_size.x,outer.size.y/map_size.y)
	var map_rect := Rect2(outer.get_center()-map_size*factor*.5,map_size*factor)
	map_draw(map_rect,true)
	var counts: Array = game.race.destinations()
	var row_height := minf(48,540.0/D.STOP_POS.size())
	for i in D.STOP_POS.size():
		var y := 145+i*row_height
		var rect := Rect2(980,y,404,row_height-3)
		card(rect,Color("31545b") if game.selected_stop==i else Color("22444d"),5)
		draw_circle(Vector2(1002,y+row_height*.46),10,D.STOP_COLORS[i])
		centered(str(i+1),Vector2(1002,y+row_height*.46+4),13,INK,bold)
		txt(D.STOP_NAMES[i],Vector2(1021,y+19),16,PAPER,bold)
		txt("%d waiting  ·  %d to drop"%[game.race.queues[i].size(),counts[i]],Vector2(1021,y+36),12,MUTED)
		buttons.append({"rect":rect,"action":"stop:"+str(i)})
	txt("BOARDING: "+("EXPRESS → "+D.STOP_SHORT[game.express_destination] if game.express_mode else "LOCAL • ALL DESTINATIONS"),Vector2(982,704),13,MUTED,bold)
	button("E  "+("SWITCH TO LOCAL" if game.express_mode else "RUN EXPRESS"),Rect2(982,717,402,47),"express",game.express_mode)
	button("BACK TO THE STREETS  [M]",Rect2(982,783,402,51),"map",true)
	txt("Cream arrow: your bus   Coral: rivals   Gold: suggested route",Vector2(55,794),15,MUTED)
	txt("The clock keeps running. Esc closes the map; press Esc again for a tea break.",Vector2(55,824),14,MUTED)
	txt("Map © OpenStreetMap • ODbL 1.0   /   Terrain: Copernicus DEM via Open-Meteo",Vector2(55,848),12,MUTED)

func garage_screen():
	draw_rect(Rect2(0,0,1440,900),Color(INK,.91))
	txt("THE BISCUIT TIN GARAGE",Vector2(54,88),58,PAPER,display)
	txt("Reinvest the hustle. Upgrades apply to both buses and persist between shifts.",Vector2(56,128),21,MUTED)
	card(Rect2(1100,39,284,99),Color("254650"),13)
	txt("AVAILABLE CASH",Vector2(1122,70),15,MUTED,bold)
	txt("HK$%d"%game.wallet,Vector2(1122,119),40,GOLD,display)
	var kinds := ["seats","engine","doors"]
	var names := ["MORE ELBOW ROOM","THE CHILLI ENGINE","EXPRESS BOARDING"]
	var descriptions := ["Four extra seats per level. More passengers, more possibilities.","A little more go. +2 m/s top speed and stronger acceleration per level.","A smoother queue. Boarding and alighting get faster with every level."]
	for i in 3:
		var x := 56+i*448
		var kind: String = kinds[i]
		var level: int = game.upgrades[kind]
		card(Rect2(x,188,432,341),Color("244650"),14,Color("4c696b"))
		txt("0%d"%(i+1),Vector2(x+24,235),32,GOLD,display)
		txt(names[i],Vector2(x+24,282),28,PAPER,display)
		paragraph(descriptions[i],Vector2(x+24,321),380,19,MUTED)
		for j in 3:
			card(Rect2(x+24+j*125,404,112,9),GOLD if j<level else Color("466269"),3)
		txt("LEVEL %d / 3"%level,Vector2(x+24,443),14,MUTED,bold)
		var cost: int = game.upgrade_cost(kind)
		button("MAXED OUT" if level>=3 else "UPGRADE  •  HK$%d"%cost,Rect2(x+24,462,384,45),"buy:"+kind,true,level>=3 or game.wallet<cost)
	card(Rect2(56,553,1328,193),Color("264d4c"),14,Color("668879"))
	txt("THE JADE EXPRESS",Vector2(84,601),35,MINT,display)
	paragraph("A bigger dream on four wheels. 23 base seats, a quicker engine, and all your existing upgrades. More room for big plans. A jade-green roof to match.",Vector2(84,639),740,19,PAPER)
	var bus_label := "EQUIP CLASSIC" if game.premium_equipped else "EQUIP JADE EXPRESS"
	if not game.premium_owned: bus_label = "BUY BUS  •  HK$1,400"
	button(bus_label,Rect2(968,612,386,57),"buy:bus",true,not game.premium_owned and game.wallet<1400)
	txt("CURRENT: "+("JADE EXPRESS" if game.premium_equipped else "RED ROOF CLASSIC")+"   /   %d SEATS"%game.capacity(),Vector2(84,718),15,GOLD,bold)
	button("← MAIN MENU",Rect2(56,791,276,58),"title")
	button("START NEXT SHIFT   →",Rect2(947,791,437,58),"start",true)
	txt("BEST SHIFT  HK$%d     •     SHIFTS COMPLETED  %d"%[game.best_cash,game.races_played],Vector2(364,828),17,MUTED)

func results_screen():
	draw_rect(Rect2(0,0,1440,900),Color(INK,.91))
	centered("SHIFT COMPLETE",Vector2(720,101),64,PAPER,display)
	var rank: int = game.race.player_rank
	centered(["GOLD! THE STREETS KNOW YOUR NAME.","SILVER! AUNTIE IS ALMOST IMPRESSED.","BRONZE! STILL BETTER THAN WALKING.","BIG DREAMS. SMALL TAKINGS. NEXT SHIFT?"][rank-1],Vector2(720,145),22,GOLD,bold)
	card(Rect2(145,194,687,427),Color("23434d"),16)
	txt("FINAL FARE STANDINGS",Vector2(177,237),18,MUTED,bold)
	var order: Array = game.race.ranking()
	for row in 4:
		var id: int = order[row]
		var y := 270+row*78
		if id==0: card(Rect2(164,y,648,69),Color("3d5b5b"),9)
		var medal: int = game.race.rank_of(id)
		draw_circle(Vector2(199,y+34),20,[GOLD,Color("b6cccf"),Color("d49c6c"),Color("53737b")][medal-1])
		centered(str(medal),Vector2(199,y+42),24,INK,bold)
		txt(game.race.drivers[id].name,Vector2(238,y+43),25,PAPER,bold)
		txt("HK$%d"%game.race.drivers[id].cash,Vector2(656,y+43),26,GOLD if id==0 else PAPER,bold)
	card(Rect2(854,194,441,427),Color("294c4c"),16)
	txt("YOUR PAY ENVELOPE",Vector2(884,238),19,MINT,bold)
	var driver: Dictionary = game.race.drivers[0]
	var pay_labels := ["Journey fares", "Tips + neat stops", "Group bookings", "Medal bonus"]
	var pay_values := [driver.fare_total,driver.tip_total,driver.dispatch_total,game.race.last_bonus]
	for row in 4:
		var y := 278+row*32
		txt(pay_labels[row],Vector2(884,y),18,PAPER)
		txt("+$%d"%pay_values[row],Vector2(1168,y),20,GOLD if row>0 else PAPER,bold)
	draw_line(Vector2(884,392),Vector2(1265,392),Color("638078"),1)
	txt("BANKED",Vector2(884,421),14,MUTED,bold)
	txt("HK$%d"%game.last_payout,Vector2(879,477),55,GOLD,display)
	txt("%d delivered  •  %d bookings complete"%[game.race.delivered,driver.contracts_completed],Vector2(884,517),17,PAPER)
	txt("%d neat stops  •  %.2f km"%[driver.precise_stops,game.player.distance_driven/1000],Vector2(884,550),17,MUTED)
	txt("Garage wallet: HK$%d"%game.wallet,Vector2(884,589),20,MINT,bold)
	centered("Only completed journeys earn fares. Ties share medals; zero-fare shifts receive no bonus.",Vector2(720,659),17,MUTED)
	button("GARAGE & UPGRADES",Rect2(145,711,554,67),"garage")
	button("ONE MORE SHIFT   →",Rect2(721,711,574,67),"start",true)
	centered("Same district. New passengers. A completely different plan.",Vector2(720,826),20,MUTED)

func pause_screen():
	buttons.clear()
	draw_rect(Rect2(0,0,1440,900),Color(INK,.8))
	card(Rect2(440,199,560,510),Color("183c47"),18,Color("5c7774"))
	centered("TEA BREAK",Vector2(720,283),60,GOLD,display)
	centered("The meter is paused. The kettle is on.",Vector2(720,330),21,PAPER)
	button("BACK TO THE HUSTLE   [ESC]",Rect2(485,378,470,59),"resume",true)
	button("SOUND: "+("OFF" if game.muted else "ON"),Rect2(485,454,470,51),"mute")
	button("ABANDON SHIFT → MENU",Rect2(485,522,470,51),"title")
	paragraph("WASD / arrows: drive • SPACE: brake • H: horn • R: rescue (3-second penalty) • C: camera • M: map • E: express • F/G: bookings",Vector2(485,623),470,17,MUTED)
