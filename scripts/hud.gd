class_name CoastHUD
extends Control

signal command(action: String)
var game: Node3D
var display_font := preload("res://assets/fonts/display.ttf")
var body_font := preload("res://assets/fonts/body.ttf")
var number_font := preload("res://assets/fonts/numbers.ttf")
var clock := 0.0
var banner := ""
var banner_age := 10.0
var section_age := 0.0
var last_section := -1
var ring_flash := 0.0
var hover := ""
var buttons: Dictionary = {}
var ink := Color("092e45")
var cream := Color("fff8e7")
var yellow := Color("ffe05b")
var turquoise := Color("7df4ed")
var help_open := false
var title_shade := GradientTexture2D.new()
var selection := 0
var using_keyboard := false

func _ready() -> void:
	number_font.fallbacks = [body_font]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0.012,0.065,0.12,0.80))
	gradient.set_color(1,Color(0.012,0.065,0.12,0.0))
	title_shade.gradient = gradient
	title_shade.fill_from = Vector2.ZERO
	title_shade.fill_to = Vector2.RIGHT
	title_shade.width = 512
	title_shade.height = 8

func _process(dt: float) -> void:
	clock += dt
	banner_age += dt
	section_age += dt
	ring_flash = maxf(0,ring_flash-dt*4)
	if game and game.player:
		var section: int = game.course.section_at(game.player.s)
		if section != last_section:
			last_section = section
			section_age = 0
	queue_redraw()

func message(kind: String, text_value: String) -> void:
	if kind == "ring":
		ring_flash = 1
	if not text_value.is_empty() and kind != "section":
		banner = text_value
		banner_age = 0

func text_at(value: String, pos: Vector2, font: Font, font_size: int, color: Color, shadow: bool = true) -> void:
	if shadow:
		draw_string(font,pos+Vector2(0,2),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0.025,0.10,0.15,0.24))
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func centered(value: String, y: float, font: Font, font_size: int, color: Color, center_x: float = 800) -> void:
	text_at(value,Vector2(center_x-font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5,y),font,font_size,color)

func pill(rect: Rect2, color: Color, cut: float = 9.0) -> void:
	draw_colored_polygon(PackedVector2Array([rect.position+Vector2(cut,0),rect.position+Vector2(rect.size.x,0),rect.end-Vector2(cut,0),rect.position+Vector2(0,rect.size.y)]),color)

func button(id: String, label: String, rect: Rect2, primary: bool = false) -> void:
	buttons[id] = rect
	var over := buttons.size()-1 == selection if using_keyboard else rect.has_point(get_local_mouse_position()*Vector2(1600,900)/size)
	var color := yellow if primary else Color(1,1,1,0.10)
	if over:
		color = Color("fff2ad") if primary else Color(1,1,1,0.22)
	pill(rect,color)
	text_at(label,rect.position+Vector2(24,rect.size.y*0.5+7),display_font,17,ink if primary else cream,false)
	text_at("→",rect.position+Vector2(rect.size.x-42,rect.size.y*0.5+8),body_font,24,ink if primary else cream,false)

func _draw() -> void:
	if not game or not game.player:
		return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1600,900))
	buttons.clear()
	var p: CoastPlayer = game.player
	if game.mode == "title":
		draw_title()
	elif game.mode == "finish":
		draw_finish()
	else:
		draw_gameplay(p)
		if game.mode == "pause":
			draw_pause()
	if help_open:
		draw_help()
	if game.transition > 0:
		draw_rect(Rect2(0,0,1600,900),Color(0.015,0.10,0.16,game.transition))

func draw_title() -> void:
	draw_texture_rect(title_shade,Rect2(0,0,1100,900),false)
	draw_line(Vector2(72,63),Vector2(124,63),yellow,3)
	text_at("A  S E A S I D E  S P E E D  A D V E N T U R E",Vector2(141,69),number_font,15,cream)
	text_at("MONA",Vector2(63,290),display_font,119,Color("32204f"))
	text_at("MONA",Vector2(63,282),display_font,119,cream)
	pill(Rect2(75,307,342,49),yellow,12)
	text_at("A Z U R E  C O A S T",Vector2(94,341),number_font,30,ink,false)
	text_at("Chase the horizon.",Vector2(77,420),display_font,28,cream)
	text_at("An endless blue. An impossible line.",Vector2(79,458),body_font,20,Color("e2eef0"))
	text_at("One unforgettable run.",Vector2(79,488),body_font,20,Color("e2eef0"))
	button("start","LET'S ROLL",Rect2(76,545,310,67),true)
	text_at("ENTER  /  A",Vector2(91,638),number_font,15,Color("d6e9e9"))
	button("help","HOW TO PLAY",Rect2(77,675,236,45))
	draw_line(Vector2(77,806),Vector2(500,806),Color(1,1,1,0.3),1)
	text_at("01",Vector2(77,851),number_font,30,yellow)
	text_at("PALM RIDGE  →  THE GREAT CASCADE",Vector2(130,838),number_font,14,cream)
	text_at("9 landmarks   /   2 skyline routes   /   one continuous coast",Vector2(131,859),body_font,13,Color("c5dfe0"))
	text_at("AZURE ISLAND",Vector2(1315,65),number_font,18,cream)
	text_at("28° N   /   16° W",Vector2(1335,87),number_font,13,cream)
	draw_circle(Vector2(1289,59),5,turquoise)
	text_at("SPEED IS A FEELING.",Vector2(1266,839),number_font,19,cream)
	text_at("F  FULLSCREEN  /  H  CONTROLS",Vector2(1260,859),number_font,11,Color(1,1,1,0.64))

func draw_gameplay(p: CoastPlayer) -> void:
	# Small translucent backing keeps white numerals readable against spray and sky.
	pill(Rect2(36,30,290,102),Color(0.015,0.10,0.16,0.42))
	draw_arc(Vector2(73,69),17+ring_flash*3,0,TAU,40,yellow,6,true)
	draw_arc(Vector2(73,69),12,PI*1.05,PI*1.7,12,Color("fff9cc"),2,true)
	text_at("%03d" % p.ring_count,Vector2(106,88),number_font,51,cream)
	text_at("RINGS",Vector2(213,59),number_font,12,yellow)
	text_at("TIME  " + format_time(p.elapsed),Vector2(61,115),number_font,21,cream)
	var sec: Dictionary = game.course.sections[game.course.section_at(p.s)]
	pill(Rect2(1240,30,321,69),Color(0.015,0.10,0.16,0.36))
	text_at(sec.number,Vector2(1261,77),number_font,35,yellow)
	text_at(sec.title,Vector2(1320,60),number_font,17,cream)
	text_at("AZURE COAST  /  ACT 01",Vector2(1320,82),number_font,12,Color("bfe8e8"))
	text_at("ESC  PAUSE",Vector2(1454,121),number_font,12,cream)
	# Slim telemetry hugs the lower corners; the racing line remains unobstructed.
	pill(Rect2(36,738,212,123),Color(0.015,0.10,0.16,0.42))
	text_at("VELOCITY",Vector2(59,765),number_font,12,turquoise)
	text_at("%03d" % int(p.speed*3.6),Vector2(55,828),number_font,68,cream)
	text_at("KM/H",Vector2(176,823),number_font,12,cream)
	for i in 20:
		draw_rect(Rect2(59+i*8,845,5,4),turquoise if i < p.speed/5 else Color(1,1,1,0.2))
	var bar := Rect2(578,818,444,12)
	pill(Rect2(548,775,504,94),Color(0.015,0.10,0.16,0.42))
	text_at("BOOST",Vector2(578,801),number_font,15,cream)
	text_at("SHIFT  /  RT",Vector2(929,800),number_font,12,cream)
	pill(bar,Color(1,1,1,0.18),3)
	if p.boost > 1:
		pill(Rect2(bar.position,Vector2(bar.size.x*p.boost/100,12)),yellow if p.boost_on else turquoise,3)
	for i in 9:
		draw_line(Vector2(578+i*49.3,818),Vector2(578+i*49.3,830),Color(0.01,0.1,0.2,0.4),2)
	centered("WASD  MOVE     SPACE  JUMP / HOMING     CTRL  ROLL     Q / E  DRIFT",852,number_font,11,Color("d5e8e9"))
	if p.charge > 0:
		centered("SPIN DASH  ·  RELEASE CTRL",710,number_font,19,yellow)
		draw_arc(Vector2(800,654),29,-PI/2,-PI/2+TAU*p.charge/1.6,44,yellow,5,true)
	if p.branch >= 0:
		pill(Rect2(668,139,264,33),yellow,8)
		centered("SKYLINE ROUTE",162,number_font,15,ink)
	if section_age < 3.4 and p.speed > 2:
		var alpha := minf(1,section_age*3)*minf(1,(3.4-section_age)*2)
		text_at(sec.number+"  /  "+sec.title,Vector2(45,189),display_font,22,Color(1,1,1,alpha))
		text_at(sec.hint,Vector2(47,220),body_font,17,Color(1,1,1,alpha*0.9))
	if banner_age < 1.7:
		var alpha := minf(1,(1.7-banner_age)*3)
		centered(banner,271-minf(banner_age,0.18)*26,number_font,25,Color(1,0.91,0.43,alpha))
	if p.target >= 0 and not p.grounded:
		var target: Node3D = game.world.enemies[p.target].node
		if not game.camera.is_position_behind(target.global_position):
			var pos: Vector2 = game.camera.unproject_position(target.global_position)*Vector2(1600,900)/size
			var radius := 30.0+sin(clock*9)*2
			for i in 4:
				var angle := i*PI/2+clock*0.5
				draw_arc(pos,radius,angle,angle+0.85,12,turquoise,3,true)
			text_at("SPACE",pos+Vector2(-22,radius+23),number_font,12,cream)
	draw_minimap(p)
	if p.speed > 62 and not game.reduced_motion:
		for i in 22:
			var angle := i*TAU/22+0.18
			var r := 560+fmod(clock*290+i*31,220)
			var center := Vector2(800,450)
			var v := Vector2(cos(angle)*1.45,sin(angle))
			draw_line(center+v*r,center+v*(r+34+(p.speed-62)),Color(0.83,0.99,1,0.12*clampf((p.speed-62)/20,0,1)),1.1,true)

func draw_minimap(p: CoastPlayer) -> void:
	var a := Vector2(1290,809)
	var b := Vector2(1548,809)
	draw_line(a,b,Color(1,1,1,0.32),2,true)
	draw_line(a,a.lerp(b,p.s/game.course.length),turquoise,3,true)
	for section in game.course.sections:
		var at: Vector2 = a.lerp(b,section.start/game.course.length)
		draw_circle(at,3,cream)
	draw_circle(a.lerp(b,p.s/game.course.length),6,yellow)
	text_at("COASTLINE",Vector2(1290,787),number_font,12,cream)
	text_at("%d%%" % int(p.s/game.course.length*100),Vector2(1509,787),number_font,14,cream)
	text_at("R  RESTART",Vector2(1458,851),number_font,12,cream)

func draw_pause() -> void:
	draw_rect(Rect2(0,0,1600,900),Color(0.015,0.07,0.12,0.70))
	centered("CATCH YOUR BREATH.",280,display_font,41,cream)
	centered("The horizon can wait.",320,body_font,20,Color("bedadd"))
	button("resume","BACK TO THE COAST",Rect2(593,374,414,63),true)
	button("restart","RESTART RUN",Rect2(593,452,414,54))
	button("help","CONTROLS",Rect2(593,519,414,54))
	button("motion","MOTION  ·  "+("REDUCED" if game.reduced_motion else "CINEMATIC"),Rect2(593,586,414,54))
	button("audio","AUDIO  ·  "+("OFF" if game.muted else "ON"),Rect2(593,653,414,54))
	button("title","TITLE SCREEN",Rect2(593,720,414,54))

func draw_finish() -> void:
	draw_texture_rect(title_shade,Rect2(0,0,1150,900),false)
	text_at("AZURE COAST  /  ACT 01",Vector2(79,125),number_font,18,turquoise)
	text_at("STAGE",Vector2(73,218),display_font,68,cream)
	text_at("CLEAR!",Vector2(73,299),display_font,79,yellow)
	var p: CoastPlayer = game.player
	var grade := "S" if p.elapsed < 45 and p.respawns == 0 else ("A" if p.elapsed < 65 else "B")
	draw_circle(Vector2(475,227),61,yellow)
	text_at(grade,Vector2(435,257),display_font,82,ink,false)
	text_at("That was a beautiful blur.",Vector2(80,354),body_font,23,cream)
	var rows := [["YOUR TIME",format_time(p.elapsed)],["RINGS",str(p.ring_count)],["TOP SPEED","%d KM/H" % int(p.peak_speed*3.6)],["BEST CHAIN","×%d" % p.best_combo]]
	for i in rows.size():
		var y := 425+i*51
		text_at(rows[i][0],Vector2(80,y),number_font,16,Color("cbe2e2"))
		text_at(rows[i][1],Vector2(360,y),number_font,27,cream)
		draw_line(Vector2(80,y+15),Vector2(536,y+15),Color(1,1,1,0.16),1)
	if game.best_time > 0:
		text_at("PERSONAL BEST  "+format_time(game.best_time),Vector2(81,661),number_font,17,yellow)
	button("restart","ONE MORE RUN",Rect2(77,710,356,67),true)
	button("title","BACK TO TITLE",Rect2(78,796,276,45))

func draw_help() -> void:
	draw_rect(Rect2(0,0,1600,900),Color(0.01,0.06,0.1,0.94))
	buttons.clear()
	text_at("FIND YOUR FLOW.",Vector2(230,153),display_font,42,cream)
	text_at("Every action carries your momentum forward.",Vector2(233,195),body_font,21,Color("bfdfdf"))
	var rows := [
		["W / ↑   ·   LEFT STICK","Accelerate. Release to coast; S / ↓ brakes."],
		["A D / ← →   ·   LEFT STICK","Steer freely across the track and switch rails."],
		["SPACE   ·   A","Jump. Press again in the air to attack a locked target."],
		["SHIFT   ·   RT / RB","Boost. Rings, enemies and drifting refill energy."],
		["CTRL   ·   X","Hold to roll. At low speed, charge and release a spin dash."],
		["Q / E   ·   LT / LB","Hold while steering to drift; release for a speed kick."],
		["R   /   ESC   ·   START","Restart your run / pause. F or F11 toggles fullscreen."]
	]
	for i in rows.size():
		var y := 269+i*57
		text_at(rows[i][0],Vector2(235,y),number_font,18,yellow)
		text_at(rows[i][1],Vector2(615,y),body_font,17,cream)
		draw_line(Vector2(235,y+18),Vector2(1366,y+18),Color(1,1,1,0.13),1)
	text_at("TAKE THE HIGH ROAD",Vector2(235,721),number_font,17,turquoise)
	text_at("Steer right after the opening, or left entering the ruins, to discover the skyline routes.",Vector2(235,753),body_font,19,cream)
	button("close_help","GOT IT",Rect2(1130,784,240,58),true)

static func format_time(seconds: float) -> String:
	return "%02d:%02d.%02d" % [int(seconds)/60,int(seconds)%60,int(seconds*100)%100]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		using_keyboard = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = event.position*Vector2(1600,900)/size
		for id in buttons:
			if buttons[id].has_point(at):
				command.emit(id)
				accept_event()
				return
