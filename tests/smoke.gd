extends SceneTree

var game: Node3D
var p: CoastPlayer
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL: "+description)
		quit(1)
		assert(condition,description)
	checks += 1
	print("PASS: ",description)

func tick(seconds: float) -> void:
	for i in ceili(seconds*120):
		await physics_frame
		p.step(1.0/120)

func clear_input() -> void:
	for action in ["accelerate","brake","left","right","jump","boost","roll","drift"]:
		Input.action_release(action)

func reset_at(distance: float) -> void:
	clear_input()
	p.restart()
	p.active = true
	p.s = distance
	p.surface = game.course.sample(distance)
	p.transform = Transform3D(p.surface.basis,p.surface.p)

func touch(pressed: bool, index: int = 0, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	event.position = root.get_visible_rect().size*0.5
	root.push_input(event,true)

func swipe(relative: Vector2, velocity: Vector2, index: int = 0) -> void:
	var extent := root.get_visible_rect().size
	var unit := minf(extent.x,extent.y)
	var event := InputEventScreenDrag.new()
	event.index = index
	event.relative = relative*unit
	event.velocity = velocity*unit
	root.push_input(event,true)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.record_enabled = false
	p = game.player
	check(p.model.get_script() == preload("res://scripts/mona.gd"),"the playable character is Mona Lisa Octocat")
	var poses_valid := true
	for pose in ["idle","walk","jog","sprint","boost","jump","fall","spring","grind","drift","stumble","victory","charge","spin","roll","homing"]:
		for frame in 30:
			p.model.animate(1.0/120,42 if pose != "idle" else 0,pose,0.4,8)
		var curled: bool = pose in ["charge","spin","roll","homing"]
		poses_valid = poses_valid and p.model.rig.visible != curled and p.model.spin.visible == curled
		for limb in p.model.tentacles:
			poses_valid = poses_valid and limb.transform.is_finite()
	check(poses_valid,"all Mona traversal poses and curled-form transitions are valid")
	var course: CoastCourse = game.course
	check(course.length > 1800 and course.sections.size() == 9,"continuous 1.8 km course and nine landmarks")
	var inverted := false
	var sound_frames := true
	for s in range(0,int(course.length),2):
		var f := course.sample(s)
		sound_frames = sound_frames and absf(f.basis.determinant()-1) < 0.001 and f.p.is_finite()
		inverted = inverted or f.n.y < -0.9
	check(sound_frames and inverted,"orthonormal surface frames through loops, corkscrew and wall")
	reset_at(4)
	Input.action_press("accelerate")
	await tick(1)
	check(p.speed > 20,"responsive acceleration")
	Input.action_release("accelerate")
	var before := p.speed
	await tick(0.2)
	check(p.speed > before*0.9,"coasting preserves momentum")
	Input.action_press("boost")
	await tick(1)
	check(p.speed > 60 and p.boost < 100,"boost adds speed and consumes energy")
	reset_at(25)
	Input.action_press("jump")
	await tick(0.1)
	check(not p.grounded and p.height > 0.7,"jump leaves the track immediately")
	Input.action_release("jump")
	await tick(1.5)
	check(p.grounded and is_zero_approx(p.height),"jump lands on the continuous surface")
	reset_at(25)
	Input.action_press("roll")
	await tick(1.1)
	check(p.charge > 1,"spin dash charges at low speed")
	Input.action_release("roll")
	await tick(0.03)
	check(p.speed > 60,"spin dash release accelerates")
	reset_at(60)
	p.speed = 35
	Input.action_press("right",0.25)
	Input.action_press("drift")
	await tick(0.45)
	before = p.speed
	Input.action_release("drift")
	Input.action_release("right")
	await tick(0.02)
	check(p.speed > before+3,"drift release rewards stored momentum")
	for i in course.shortcuts.size():
		reset_at(course.shortcuts[i].x-0.4)
		p.lateral = 3.1 if i == 0 else -3.1
		p.speed = 35
		await tick(0.03)
		check(p.branch == i,"skyline branch %d is selectable by steering" % i)
		p.s = course.shortcuts[i].y-0.2
		await tick(0.03)
		check(p.branch == -1,"skyline branch %d merges into the main route" % i)
	reset_at(course.sections[3].start+10)
	p.speed = 40
	await tick(0.03)
	check(p.state == "grind" and p.grounded,"rails engage without stopping")
	reset_at(game.world.springs[0].s-2)
	p.speed = 60
	await tick(0.1)
	check(p.state == "spring" and p.vertical_speed > 20,"spring launches preserve forward speed")
	reset_at(course.sections[4].start+1)
	p.height = 6
	p.grounded = false
	p.speed = 45
	for i in 5:
		p.target = p.find_target()
		check(p.target >= 0,"homing chain target %d is reachable" % (i+1))
		p.begin_homing(p.target)
		await tick(0.4)
	check(p.best_combo == 5,"all five airborne enemies can be chained")
	reset_at(120)
	p.checkpoint = 80
	p.height = -40
	p.grounded = false
	await tick(0.02)
	check(p.respawns == 1 and p.s < 82 and p.height == 0,"falling returns to checkpoint cleanly")
	game.mode = "play"
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.mode == "pause" and not p.active,"losing focus pauses the run")
	game.on_command("resume")
	check(game.mode == "play" and p.active,"the run resumes after focus pause")
	game.touch_controls = true
	game.start_run()
	await tick(0.8)
	check(p.speed > 16 and game.touch_index == -1,"touch mode runs automatically without a held finger")
	touch(true)
	swipe(Vector2(0.08,0),Vector2(0.4,0))
	touch(false)
	await tick(0.03)
	check(p.lateral > 1.5 and p.grounded,"a completed right swipe moves sideways without jumping")
	before = p.lateral
	await tick(0.15)
	check(is_equal_approx(p.lateral,before),"sideways movement stops when the swipe ends")
	before = p.speed
	await tick(0.15)
	check(p.speed > before,"automatic acceleration continues after finger-up")
	touch(true)
	swipe(Vector2(-0.08,0),Vector2(-0.4,0))
	touch(false)
	await tick(0.03)
	check(absf(p.lateral) < 0.1 and p.grounded,"a left swipe moves back without jumping")
	touch(true)
	touch(false)
	await tick(0.03)
	check(not p.grounded and p.vertical_speed > 15,"a short tap jumps on finger-up")
	p.jump_buffer = 0
	touch(true)
	swipe(Vector2(0,-0.08),Vector2(0,-1.5))
	touch(false)
	check(is_zero_approx(p.jump_buffer),"vertical swipes no longer trigger jumps")
	touch(true)
	swipe(Vector2(0.08,0),Vector2(0.4,0))
	swipe(Vector2(-0.08,0),Vector2(-0.4,0))
	touch(false)
	check(is_zero_approx(p.jump_buffer),"an out-and-back swipe is not mistaken for a tap")
	touch(true)
	game.touch_started -= game.TAP_MAX_MS+1
	touch(false)
	check(is_zero_approx(p.jump_buffer),"a long press is not mistaken for a tap")
	touch(true)
	touch(true,1)
	swipe(Vector2(-0.15,0),Vector2(-1,0),1)
	touch(false,1)
	check(game.touch_index == 0 and is_zero_approx(p.touch_shift) and is_zero_approx(p.jump_buffer),"a second finger cannot move or jump for the driving touch")
	touch(false,0,true)
	check(game.touch_index == -1 and is_zero_approx(p.jump_buffer),"canceled touches do not jump")
	touch(true)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	before = p.s
	await tick(0.1)
	check(is_equal_approx(p.s,before),"pause stops automatic running")
	touch(false)
	game.on_command("resume")
	await tick(0.03)
	check(p.s > before and game.touch_index == -1 and is_zero_approx(p.jump_buffer),"resume continues auto-run without a stale tap")
	touch(true)
	game.start_run()
	check(p.auto_run and game.touch_index == -1 and is_zero_approx(p.touch_shift),"restart starts auto-run and clears the old gesture")
	reset_at(course.sections[4].start+1)
	p.height = 6
	p.grounded = false
	p.coyote = 0
	p.speed = 45
	p.target = p.find_target()
	touch(true)
	touch(false)
	await tick(0.03)
	check(p.homing_target >= 0,"an airborne tap triggers the existing homing attack")
	p.auto_run = false
	for point in [Vector2(0,0.25),Vector2(1,0.50),Vector2(2,0.75)]:
		var section := int(point.x)
		var distance := lerpf(course.sections[section].start,course.sections[section+1].start,point.y)
		reset_at(distance)
		game.update_camera(1,true)
		var focus: Vector3 = p.position+p.surface.n*1.8
		check(game.camera.position.distance_to(focus) >= 6,"camera stays outside Mona at section %d" % section)
	reset_at(course.length-13)
	p.speed = 50
	await tick(0.05)
	check(p.complete and game.mode == "finish","finish line produces a result screen")
	clear_input()
	print("ALL %d CHECKS PASSED" % checks)
	game.queue_free()
	await process_frame
	quit(0)
