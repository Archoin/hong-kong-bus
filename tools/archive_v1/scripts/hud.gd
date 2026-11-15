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
	elif action.begins_with("buy:"): game.purchase(action.trim_prefix("buy:"))
	elif action.begins_with("stop:"):
		game.selected_stop = int(action.trim_prefix("stop:"))
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
		card(Rect2(720-width/2,139,width,49),Color(INK,.96),10)
		centered(game.toast,Vector2(720,171),20,game.toast_color,bold)

func title_screen():
	# Opaque editorial panel leaves the live diorama visible on the right.
	card(Rect2(0,0,610,900),Color("12323c"),0)
	draw_rect(Rect2(0,0,10,900),GOLD)
	txt("HK / 001",Vector2(48,62),20,GOLD,bold)
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
		txt(["STOP at a bay to let passengers board.","DELIVER them to their numbered stops.","OUT-EARN three rival minibus legends."][i],Vector2(84,y),19,PAPER)
	button("START YOUR SHIFT   →",Rect2(48,699,508,62),"start",true)
	button("GARAGE",Rect2(48,778,244,49),"garage")
	button("SOUND: "+("OFF" if game.muted else "ON"),Rect2(307,778,249,49),"mute")
	txt("WASD / ARROWS  drive     SPACE  brake     ENTER  start",Vector2(48,866),15,MUTED)
	card(Rect2(1016,32,390,97),Color(INK,.90),12)
	txt("SHEUNG WAN → CENTRAL",Vector2(1040,69),22,PAPER,bold)
	txt("One district. Six stops. Endless bad parking.",Vector2(1040,101),16,MUTED)
	card(Rect2(875,735,530,130),Color(INK,.94),14)
	txt("JADE ROOF. BIGGER DREAMS." if game.premium_equipped else "RED ROOF. GOLDEN OPPORTUNITY.",Vector2(900,772),20,GOLD,bold)
	paragraph("%d seats • 180 seconds • HK$200 gold bonus. Every passenger has somewhere to be. Preferably alive."%game.capacity(),Vector2(900,807),478,18,PAPER)

func race_hud():
	var driver: Dictionary = game.race.drivers[0]
	card(Rect2(24,24,282,104),Color(INK,.96),13)
	txt("FARE TAKINGS",Vector2(44,53),15,MUTED,bold)
	txt("HK$%s"%driver.cash,Vector2(42,103),43,MINT if game.fare_flash>0 else GOLD,display)
	txt("#%d"%game.race.rank_of(0),Vector2(242,99),28,PAPER,bold)
	card(Rect2(597,24,246,104),Color(INK,.96),13)
	centered("SHIFT ENDS IN",Vector2(720,52),15,MUTED,bold)
	var secs: int = ceili(game.race.remaining)
	centered("%d:%02d"%[floori(secs/60.0),secs%60],Vector2(720,106),49,Color("ff977c") if secs<=30 else PAPER,display)
	card(Rect2(1111,24,305,198),Color(INK,.95),13)
	txt("THE MONEY RACE",Vector2(1132,54),16,GOLD,bold)
	var order: Array = game.race.ranking()
	for row in 4:
		var id: int = order[row]
		var y := 88+row*33
		if id==0: card(Rect2(1124,y-24,278,31),Color("2d5360"),5)
		txt(str(row+1),Vector2(1135,y),17,GOLD if row==0 else MUTED,bold)
		txt(game.race.drivers[id].name,Vector2(1164,y),17,PAPER if id==0 else MUTED,bold if id==0 else regular)
		txt("$%d"%game.race.drivers[id].cash,Vector2(1340,y),17,PAPER,bold)
	# Manifest always exposes actionable destinations, even with the map closed.
	card(Rect2(1160,346,256,323),Color(INK,.94),13)
	txt("ON BOARD",Vector2(1180,377),15,MUTED,bold)
	txt("%02d / %02d"%[driver.riders.size(),driver.capacity],Vector2(1180,421),35,GOLD,display)
	txt("PASSENGERS",Vector2(1180,442),12,MUTED,bold)
	var counts: Array = game.race.destinations()
	for i in 6:
		var y := 475+i*30
		var r := Rect2(1172,y-21,232,29)
		if game.selected_stop==i: card(r,Color("30505a"),5)
		draw_circle(Vector2(1191,y-6),9,D.STOP_COLORS[i])
		centered(str(i+1),Vector2(1191,y-1),12,INK,bold)
		txt(D.STOP_SHORT[i],Vector2(1209,y),14,PAPER if counts[i]>0 else MUTED,bold)
		txt(str(counts[i])+" ↓",Vector2(1362,y),16,D.STOP_COLORS[i] if counts[i]>0 else MUTED,bold)
		buttons.append({"rect":r,"action":"stop:"+str(i)})
	# Map, local stop queue, and main driving instruments.
	card(Rect2(24,575,340,300),Color(INK,.96),14)
	txt("OLD TOWN",Vector2(44,607),17,PAPER,bold)
	txt("N ↑",Vector2(307,607),15,MUTED,bold)
	map_draw(Rect2(40,621,308,216),false)
	txt("1–6 pin stop    M expand map",Vector2(44,860),14,MUTED)
	buttons.append({"rect":Rect2(24,575,340,300),"action":"map"})
	var target: Vector3 = D.STOP_POS[game.selected_stop]
	var dist: int = int(Vector2(target.x-player_pos().x,target.z-player_pos().z).length())
	card(Rect2(426,716,588,56),Color(INK,.95),10)
	draw_circle(Vector2(453,744),13,D.STOP_COLORS[game.selected_stop])
	centered(str(game.selected_stop+1),Vector2(453,750),17,INK,bold)
	txt(D.STOP_NAMES[game.selected_stop],Vector2(478,751),22,PAPER,bold)
	txt("%dm"%dist,Vector2(935,751),22,GOLD,bold)
	card(Rect2(388,785,666,88),Color(INK,.97),12)
	centered(game.service_status,Vector2(721,817),17,PAPER,bold)
	var progress: float = clampf(game.service_timer/.46,0,1) if game.current_stop>=0 and absf(game.player.speed)<1.1 else 0.0
	draw_rect(Rect2(408,833,626,4),Color("37535b"))
	if progress>0: draw_rect(Rect2(408,833,626*progress,4),MINT)
	centered("WASD drive   SPACE brake   H horn   R rescue   C camera   ESC pause",Vector2(721,859),14,MUTED)
	card(Rect2(1174,720,242,155),Color(INK,.95),13)
	txt("%02d"%int(absf(game.player.speed)*3.6),Vector2(1195,798),64,PAPER,display)
	txt("km/h",Vector2(1307,794),19,MUTED)
	txt("R" if game.player.speed<-.3 else ("P" if absf(game.player.speed)<.3 else "D"),Vector2(1368,794),24,GOLD,bold)
	txt("STOP TO BOARD",Vector2(1195,830),14,GOLD,bold)
	txt("Doors open automatically",Vector2(1195,855),14,MUTED)

func player_pos() -> Vector3:
	return game.player.position

func map_point(world: Vector3, rect: Rect2) -> Vector2:
	return rect.position+Vector2((world.x+128)/256.0,(world.z+108)/214.0)*rect.size

func map_draw(rect: Rect2, large: bool):
	card(rect,Color("1b404a"),8)
	draw_rect(Rect2(rect.position,Vector2(rect.size.x,rect.size.y*.12)),Color("34747f"))
	for x in [-64,0,64]:
		for z in [-36,36]:
			var a := map_point(Vector3(x-22,0,z-26),rect)
			var b := map_point(Vector3(x+22,0,z+26),rect)
			card(Rect2(a,b-a),Color("3e5d60"),3)
	for x in D.ROAD_X:
		draw_line(map_point(Vector3(x,0,-81),rect),map_point(Vector3(x,0,81),rect),Color("68817c"),6 if large else 3)
	for z in D.ROAD_Z:
		draw_line(map_point(Vector3(-106,0,z),rect),map_point(Vector3(106,0,z),rect),Color("68817c"),6 if large else 3)
	var nearest: Vector3 = D.nearest_road(player_pos())
	var path: Array[Vector3] = D.route(nearest,D.STOP_POS[game.selected_stop])
	var previous := map_point(player_pos(),rect)
	for point in path:
		var current := map_point(point,rect)
		draw_line(previous,current,GOLD,4 if large else 2,true)
		previous = current
	var counts: Array = game.race.destinations()
	for i in 6:
		var p := map_point(D.STOP_POS[i],rect)
		if i==game.selected_stop: draw_arc(p,16 if large else 12,0,TAU,32,PAPER,2,true)
		draw_circle(p,12 if large else 8,D.STOP_COLORS[i])
		centered(str(i+1),p+Vector2(0,5 if large else 4),16 if large else 12,INK,bold)
		if counts[i]>0:
			card(Rect2(p+Vector2(10,-27),Vector2(43,23)),GOLD,5)
			txt(str(counts[i])+" ↓",p+Vector2(15,-10),14,INK,bold)
		if large:
			txt(D.STOP_SHORT[i],p+Vector2(17,5),14,PAPER,bold)
			buttons.append({"rect":Rect2(p-Vector2(20,20),Vector2(150,50)),"action":"stop:"+str(i)})
	for rival in game.rivals:
		var p := map_point(rival.bus.position,rect)
		draw_circle(p,5 if large else 3,Color("ef8c7d"))
	var bus_marker := map_point(player_pos(),rect)
	var forward := Vector2(-sin(game.player.rotation.y),-cos(game.player.rotation.y))
	var side := forward.orthogonal()
	var s := 12.0 if large else 8.0
	draw_colored_polygon(PackedVector2Array([bus_marker+forward*s,bus_marker-forward*s*.7+side*s*.65,bus_marker-forward*s*.7-side*s*.65]),PAPER)
	draw_circle(bus_marker,2,INK)

func full_map():
	buttons.clear()
	draw_rect(Rect2(0,0,1440,900),Color(INK,.75))
	card(Rect2(121,111,1198,680),Color("14343e"),18,Color("5b7775"))
	txt("YOUR ROUTE. YOUR RULES.",Vector2(151,158),34,PAPER,display)
	txt("Live map • the race clock keeps running",Vector2(152,190),17,MUTED)
	map_draw(Rect2(152,222,748,520),true)
	txt("PIN A STOP",Vector2(931,241),17,GOLD,bold)
	var counts: Array = game.race.destinations()
	for i in 6:
		var y := 267+i*68
		var rect := Rect2(921,y,368,60)
		card(rect,Color("31545b") if game.selected_stop==i else Color("22444d"),8)
		draw_circle(Vector2(946,y+29),12,D.STOP_COLORS[i])
		centered(str(i+1),Vector2(946,y+35),16,INK,bold)
		txt(D.STOP_NAMES[i],Vector2(967,y+25),19,PAPER,bold)
		txt("%d waiting    •    %d to drop off"%[game.race.queues[i].size(),counts[i]],Vector2(967,y+48),15,MUTED)
		buttons.append({"rect":rect,"action":"stop:"+str(i)})
	button("CLOSE MAP  [M]",Rect2(922,694,367,49),"map",true)
	txt("White arrow: you    Coral dots: rivals    Gold line: suggested streets",Vector2(152,769),16,MUTED)

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
	txt("Passenger fares",Vector2(884,288),20,PAPER)
	txt("HK$%d"%game.race.drivers[0].cash,Vector2(1152,288),22,PAPER,bold)
	txt("Medal bonus",Vector2(884,335),20,PAPER)
	txt("+%d"%game.race.last_bonus,Vector2(1185,335),22,GOLD,bold)
	draw_line(Vector2(884,361),Vector2(1265,361),Color("638078"),1)
	txt("BANKED",Vector2(884,401),16,MUTED,bold)
	txt("HK$%d"%game.last_payout,Vector2(879,473),65,GOLD,display)
	txt("%d passengers delivered"%game.race.delivered,Vector2(884,520),20,PAPER)
	txt("%.2f km of glorious chaos"%(game.player.distance_driven/1000),Vector2(884,554),20,MUTED)
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
	paragraph("WASD / arrows: drive • SPACE: brake • H: horn • R: rescue (3-second penalty) • C: camera • M: map • 1–6: pin stop",Vector2(485,623),470,17,MUTED)
