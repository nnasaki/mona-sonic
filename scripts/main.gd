extends Node3D

const Course = preload("res://scripts/course.gd")
const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const HUD = preload("res://scripts/hud.gd")
const Sound = preload("res://scripts/audio.gd")
var course: CoastCourse
var world: CoastWorld
var player: CoastPlayer
var camera := Camera3D.new()
var hud: CoastHUD
var audio: CoastAudio
var mode := "title"
var transition := 1.0
var camera_up := Vector3.UP
var camera_target := Vector3.ZERO
var reduced_motion := false
var muted := false
var best_time := 0.0
var record_enabled := true
var clock := 0.0
var demo := false
var demo_jump_timer := 0.0
var capture_dir := ""
var capture_marks: Dictionary = {}
var capture_pending := false
var touch_controls := DisplayServer.is_touchscreen_available()
var touch_index := -1
var touch_offset := 0.0
var flick_distance := 0.0
var flick_fired := false
# Gesture distances are fractions of the viewport's shorter side.
const TOUCH_STEER_RANGE := 0.16
const TOUCH_DEADZONE := 0.015
const FLICK_DISTANCE := 0.055
const FLICK_SPEED := 0.8

func _ready() -> void:
	DisplayServer.window_set_title("MONA • Azure Coast")
	record_enabled = not Array(OS.get_cmdline_user_args()).any(func(arg): return arg in ["--demo","--no-record"] or arg.begins_with("--section=") or arg.begins_with("--capture-dir="))
	setup_input()
	load_record()
	course = Course.new()
	world = World.new()
	add_child(world)
	world.build(course)
	player = Player.new()
	add_child(player)
	player.setup(course,world)
	player.feedback.connect(on_feedback)
	player.finished.connect(on_finish)
	add_child(camera)
	camera.current = true
	camera.near = 0.1
	camera.far = 2800
	camera.fov = 60
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	hud.game = self
	layer.add_child(hud)
	hud.command.connect(on_command)
	audio = Sound.new()
	add_child(audio)
	player.model.rotation.y = 3.26
	update_camera(1.0,true)
	for argument in OS.get_cmdline_user_args():
		if argument == "--demo":
			demo = true
			start_run()
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
		if argument.begins_with("--section="):
			start_run()
			var section := clampi(argument.trim_prefix("--section=").to_int(),0,8)
			player.s = course.sections[section].start+8
			player.speed = 38
			player.surface = course.sample(player.s)
			player.position = player.surface.p
			player.basis = player.surface.basis
			update_camera(1.0,true)
	print("AZURE COAST READY | %.0f m | %d rings | %d enemies | all assets local" % [course.length,world.rings.size(),world.enemies.size()])

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "play" and player and hud:
		on_command("pause")

func setup_input() -> void:
	var mappings := {
		"accelerate":[KEY_W,KEY_UP],"brake":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],
		"jump":[KEY_SPACE],"boost":[KEY_SHIFT],"roll":[KEY_CTRL],"drift":[KEY_Q,KEY_E],
		"start":[KEY_ENTER],"pause":[KEY_ESCAPE],"restart":[KEY_R],"fullscreen":[KEY_F,KEY_F11],"help":[KEY_H]
	}
	for action in mappings:
		if not InputMap.has_action(action):
			InputMap.add_action(action,0.18)
		for key in mappings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)
	var joy_buttons := {"jump":JOY_BUTTON_A,"boost":JOY_BUTTON_RIGHT_SHOULDER,"roll":JOY_BUTTON_X,"drift":JOY_BUTTON_LEFT_SHOULDER,"pause":JOY_BUTTON_START}
	for action in joy_buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = joy_buttons[action]
		InputMap.action_add_event(action,event)
	var axes := {"left":[JOY_AXIS_LEFT_X,-1.0],"right":[JOY_AXIS_LEFT_X,1.0],"accelerate":[JOY_AXIS_LEFT_Y,-1.0],"brake":[JOY_AXIS_LEFT_Y,1.0],"boost":[JOY_AXIS_TRIGGER_RIGHT,1.0],"drift":[JOY_AXIS_TRIGGER_LEFT,1.0]}
	for action in axes:
		var event := InputEventJoypadMotion.new()
		event.axis = axes[action][0]
		event.axis_value = axes[action][1]
		InputMap.action_add_event(action,event)

func clear_touch() -> void:
	touch_index = -1
	touch_offset = 0
	flick_distance = 0
	flick_fired = false
	player.touch_running = false
	player.touch_steer = 0
	player.jump_buffer = 0

func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	touch_controls = true
	get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if event.index == touch_index:
				# Preserve a flick queued just before finger-up until the physics tick.
				var jump := 0.0 if event.canceled else player.jump_buffer
				clear_touch()
				player.jump_buffer = jump
			return
		var at: Vector2 = event.position*Vector2(1600,900)/hud.size
		for id in hud.buttons:
			if hud.buttons[id].has_point(at):
				on_command(id)
				return
		if mode == "play" and not hud.help_open and not demo and touch_index == -1:
			touch_index = event.index
			player.touch_running = true
	elif event.index == touch_index and mode == "play":
		var extent := get_viewport().get_visible_rect().size
		var unit := minf(extent.x,extent.y)
		var movement: Vector2 = event.relative/unit
		touch_offset = clampf(touch_offset+movement.x,-TOUCH_STEER_RANGE,TOUCH_STEER_RANGE)
		player.touch_steer = signf(touch_offset)*clampf((absf(touch_offset)-TOUCH_DEADZONE)/(TOUCH_STEER_RANGE-TOUCH_DEADZONE),0,1)
		if -event.velocity.y/unit >= FLICK_SPEED and -movement.y > absf(movement.x):
			flick_distance -= movement.y
			if flick_distance >= FLICK_DISTANCE and not flick_fired:
				player.jump_buffer = 0.14
				flick_fired = true
		else:
			flick_distance = 0
			flick_fired = false

func _unhandled_input(event: InputEvent) -> void:
	if mode in ["title","pause","finish"] or hud.help_open:
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
			hud.using_keyboard = true
			hud.selection = posmod(hud.selection+(1 if event.is_action_pressed("ui_down") else -1),maxi(1,hud.buttons.size()))
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept") and not hud.buttons.is_empty():
			on_command(hud.buttons.keys()[clampi(hud.selection,0,hud.buttons.size()-1)])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("fullscreen") and not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("help"):
		clear_touch()
		hud.help_open = not hud.help_open
		if mode == "play":
			mode = "pause"
			player.active = false
	if event.is_action_pressed("pause"):
		if hud.help_open:
			hud.help_open = false
		elif mode == "play":
			on_command("pause")
		elif mode == "pause":
			on_command("resume")
		elif mode == "title":
			start_run()
	if (event.is_action_pressed("start") or event.is_action_pressed("jump")) and mode in ["title","finish"]:
		if hud.help_open:
			hud.help_open = false
		else:
			start_run()
	if event.is_action_pressed("restart") and mode != "title":
		start_run()

func start_run() -> void:
	clear_touch()
	player.restart()
	player.active = true
	mode = "play"
	hud.help_open = false
	hud.section_age = 0
	transition = 0.32
	update_camera(1.0,true)
	audio.play("dash") if audio else null

func on_command(action: String) -> void:
	clear_touch()
	if action not in ["motion","audio"]:
		hud.selection = 0
	match action:
		"start","restart": start_run()
		"pause":
			mode = "pause"
			player.active = false
		"resume":
			mode = "play"
			player.active = true
		"help": hud.help_open = true
		"close_help": hud.help_open = false
		"motion": reduced_motion = not reduced_motion
		"audio":
			muted = not muted
			AudioServer.set_bus_mute(0,muted)
		"title":
			mode = "title"
			player.restart()
			player.active = false
			player.model.rotation.y = 3.26
			transition = 0.6
			update_camera(1.0,true)

func _physics_process(dt: float) -> void:
	if not player:
		return
	if demo and mode == "play":
		drive_demo(dt)
	player.step(dt)

func _process(dt: float) -> void:
	if not player:
		return
	clock += dt
	transition = move_toward(transition,0,dt*1.5)
	if mode != "pause":
		world.update(dt,player.s,player.position)
		update_camera(dt)
	audio.update(player.speed if mode == "play" else 0.0,mode == "play")
	if not capture_dir.is_empty() and clock > 2.0 and not capture_pending:
		var mark := "title" if mode == "title" else ("finish" if mode == "finish" else "section_%02d" % course.section_at(player.s))
		if not capture_marks.has(mark):
			capture_marks[mark] = true
			capture_pending = true
			capture_frame.call_deferred(mark)
	if demo and mode == "finish" and clock > player.elapsed+4:
		print("DEMO COMPLETE | time=%.2f rings=%d max_speed=%.1f combo=%d respawns=%d" % [player.elapsed,player.ring_count,player.peak_speed,player.best_combo,player.respawns])
		if OS.has_feature("web"):
			demo = false
			for action in ["accelerate","boost","left","right","jump"]:
				Input.action_release(action)
		else:
			get_tree().quit()

func update_camera(dt: float, snap: bool = false) -> void:
	var f: Dictionary = player.surface
	var desired: Vector3
	var target: Vector3
	var up := Vector3.UP
	var fov := 62.0
	if mode == "title":
		var hero := player.position
		desired = hero+Vector3(0.9,3.1,8.3)
		target = hero+Vector3(-3.4,1.7,-3.5)
		fov = 49
	elif mode == "finish":
		desired = player.position+f.r*5-f.f*8+Vector3.UP*3.5
		target = player.position-f.r*2.3+Vector3.UP*1.7
		fov = 48
	else:
		var speed_ratio := clampf(player.speed/83,0,1)
		var distance := 9.0+speed_ratio*2.2
		var camera_normal: Vector3 = f.n
		var ahead: Dictionary = course.sample(minf(player.s+12,course.length),player.branch)
		desired = player.position-f.f*distance+camera_normal*(4.1+speed_ratio*1.2)
		target = player.position+camera_normal*1.5+f.f*(5.0+speed_ratio*3)
		up = camera_normal
		if f.mode in ["loop","corkscrew"] and not reduced_motion:
			desired = player.position+f.r*12+f.n*7-f.f*8
			target = player.position+f.f*3+f.n*1.5
			up = Vector3.UP
		elif f.mode == "wall":
			up = Vector3.UP.lerp(f.n,0.6).normalized()
			desired += Vector3.UP*2
		elif f.mode == "waterfall":
			desired += f.r*3+Vector3.UP*2
			target += f.f*6
		elif f.mode == "rail":
			desired += f.r*2+Vector3.UP*1.5
		if f.mode not in ["loop","corkscrew","wall"]:
			var behind := course.sample(maxf(0,player.s-distance),player.branch)
			desired.y = maxf(desired.y,behind.p.y+3.8)
		if not reduced_motion:
			var bank := clampf(f.f.signed_angle_to(ahead.f,f.n),-0.35,0.35)*speed_ratio*0.45
			up = up.rotated(f.f,-bank-player.lateral_velocity*0.004)
		fov = 65+speed_ratio*(3 if reduced_motion else 12)
	var blend := 1.0 if snap else 1-exp(-dt*7.5)
	camera.position = camera.position.lerp(desired,blend)
	# The character uses continuous surface motion; native physics only keeps the camera out of scenery.
	if mode in ["play","pause"]:
		var focus: Vector3 = player.position+f.n*1.8
		var candidates: Array[Vector3] = [camera.position,desired,focus-f.f*8+f.n*4,focus-f.f*6+f.r*8+f.n*5,focus-f.f*6-f.r*8+f.n*5,focus+f.n*11-f.f*2]
		for candidate in candidates:
			var query := PhysicsRayQueryParameters3D.create(focus,candidate,1)
			query.hit_back_faces = true
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			var safe: Vector3 = candidate if hit.is_empty() else hit.position+(focus-hit.position).normalized()*0.8
			if safe.distance_to(focus) >= 6.0:
				camera.position = safe
				break
	camera_target = camera_target.lerp(target,1.0 if snap else 1-exp(-dt*12))
	camera_up = camera_up.lerp(up,1.0 if snap else 1-exp(-dt*6)).normalized()
	if camera.position.distance_squared_to(camera_target) > 0.1:
		camera.look_at(camera_target,camera_up)
	camera.fov = lerpf(camera.fov,fov,1.0 if snap else 1-exp(-dt*4))

func on_feedback(kind: String, message: String) -> void:
	if hud:
		hud.message(kind,message)
	if audio:
		audio.play(kind)
	if kind in ["spring","dash","drift"]:
		world.burst(player.position+Vector3.UP,Color("a3f5ff"),12)
	if kind == "respawn":
		transition = 0.65
		update_camera(1,true)

func on_finish() -> void:
	clear_touch()
	mode = "finish"
	if record_enabled and (best_time == 0 or player.elapsed < best_time):
		best_time = player.elapsed
		var record := ConfigFile.new()
		record.set_value("coast","best_time",best_time)
		var result := record.save("user://record.cfg")
		if result != OK:
			push_warning("Could not save personal best: %s" % error_string(result))

func load_record() -> void:
	var record := ConfigFile.new()
	if record.load("user://record.cfg") == OK:
		best_time = maxf(0,float(record.get_value("coast","best_time",0)))
		if best_time < 10:
			best_time = 0

func drive_demo(dt: float) -> void:
	Input.action_press("accelerate")
	Input.action_press("boost")
	var desired := sin(player.s*0.020)*2.7
	var frame: Dictionary = course.sample(player.s)
	if frame.mode in ["rail","air","waterfall"]:
		desired = 0
	for spring in world.springs:
		if spring.s-player.s > 0 and spring.s-player.s < 24:
			desired = 0
	Input.action_release("left")
	Input.action_release("right")
	if absf(desired-player.lateral) > 0.20:
		Input.action_press("right" if desired > player.lateral else "left",minf(1,absf(desired-player.lateral)*0.45))
	demo_jump_timer -= dt
	Input.action_release("jump")
	if not player.grounded and player.target >= 0 and player.homing_target < 0 and demo_jump_timer <= 0:
		Input.action_press("jump")
		demo_jump_timer = 0.22

func capture_frame(mark: String) -> void:
	await RenderingServer.frame_post_draw
	var file := capture_dir.path_join(mark+".png")
	var error := get_viewport().get_texture().get_image().save_png(file)
	print("CAPTURE ",file," ",error_string(error))
	capture_pending = false
