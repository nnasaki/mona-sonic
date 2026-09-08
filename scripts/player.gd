class_name CoastPlayer
extends Node3D

signal feedback(kind: String, message: String)
signal finished
const Octocat = preload("res://scripts/mona.gd")
const Mascot = preload("res://scripts/mascot.gd")
var course: CoastCourse
var world: CoastWorld
var character := "mona"
var model = Mascot.new(character)
var s := 2.0
var lateral := 0.0
var lateral_velocity := 0.0
var speed := 0.0
var height := 0.0
var vertical_speed := 0.0
var boost := 100.0
var ring_count := 0
var peak_speed := 0.0
var combo := 0
var best_combo := 0
var elapsed := 0.0
var state := "idle"
var active := false
var complete := false
var grounded := true
var charge := 0.0
var branch := -1
var checkpoint := 2.0
var invincible := 0.0
var air_time := 0.0
var coyote := 0.12
var jump_buffer := 0.0
var drift_charge := 0.0
var target := -1
var homing_target := -1
var homing_time := 0.0
var homing_from := Vector3.ZERO
var surface: Dictionary
var jump_cut := false
var boost_on := false
var last_section := 0
var respawns := 0
var boost_trail: GPUParticles3D
var dust: GPUParticles3D
var auto_run := false
var touch_shift := 0.0

func setup(route: CoastCourse, scenery: CoastWorld) -> void:
	course = route
	world = scenery
	add_child(model)
	surface = course.sample(s)
	transform = Transform3D(surface.basis,surface.p)
	boost_trail = world.particles(global_position,Color("c6b3ff"),38,0.28,Vector3(0.32,0.3,0.15),Vector3(0,1,5),0.8,0.20)
	boost_trail.emitting = false
	dust = world.particles(global_position,Color("f2d69a"),24,0.40,Vector3(0.35,0.04,0.2),Vector3(0,2,3),1.4,0.20)
	dust.emitting = false

func select_character(id: String) -> void:
	if id not in ["mona","copilot","ducky","octocat"] or id == character:
		return
	var facing: Vector3 = model.rotation
	remove_child(model)
	model.queue_free()
	character = id
	model = Octocat.new() if id == "octocat" else Mascot.new(id)
	add_child(model)
	model.rotation = facing

func restart() -> void:
	s = 2.0
	lateral = 0
	lateral_velocity = 0
	speed = 0
	height = 0
	vertical_speed = 0
	boost = 100
	ring_count = 0
	combo = 0
	best_combo = 0
	elapsed = 0
	peak_speed = 0
	branch = -1
	checkpoint = 2
	state = "idle"
	grounded = true
	complete = false
	charge = 0
	respawns = 0
	last_section = 0
	invincible = 0
	homing_target = -1
	surface = course.sample(s)
	transform = Transform3D(surface.basis,surface.p)
	model.rotation = Vector3.ZERO
	world.reset()

func step(dt: float) -> void:
	if not active or complete:
		model.animate(dt,0,"victory" if complete else "idle",0)
		boost_trail.emitting = false
		dust.emitting = false
		return
	elapsed += dt
	invincible = maxf(0,invincible-dt)
	jump_buffer = maxf(0,jump_buffer-dt)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.14
	var throttle := 1.0 if auto_run else Input.get_axis("brake","accelerate")
	var steer := Input.get_axis("left","right")
	var drift := Input.is_action_pressed("drift") and grounded and speed > 14 and absf(steer) > 0.15
	boost_on = Input.is_action_pressed("boost") and boost > 0 and charge == 0
	var previous_s := s
	surface = course.sample(s,branch)
	if homing_target >= 0:
		advance_homing(dt)
	else:
		var slope: float = -surface.f.y*19.0 if grounded else 0.0
		if charge > 0:
			speed = move_toward(speed,0,dt*65)
			charge = minf(1.6,charge+dt)
			if not Input.is_action_pressed("roll"):
				speed = 39+charge*24
				charge = 0
				state = "roll"
				feedback.emit("dash","SPIN DASH")
		elif Input.is_action_pressed("roll") and speed < 8 and grounded:
			charge = 0.01
			state = "charge"
			feedback.emit("charge","")
		else:
			var cap := 83.0 if boost_on else 49.0
			var acceleration := 44.0 if boost_on else 23.0
			if throttle > 0 or boost_on:
				if speed < cap:
					speed = minf(cap,speed+acceleration*dt)
			elif throttle < 0:
				speed = move_toward(speed,0,dt*48)
			else:
				speed = move_toward(speed,0,dt*(1.3 if grounded else 0.25))
			speed = clampf(speed+slope*dt,0,98)
			if speed > cap:
				speed = move_toward(speed,cap,dt*3)
			if boost_on:
				boost = maxf(0,boost-dt*20)
			else:
				boost = minf(100,boost+dt*4)
			if drift:
				drift_charge = minf(1.5,drift_charge+dt)
				speed = maxf(0,speed-dt*1.0)
			elif drift_charge > 0:
				if drift_charge > 0.35:
					speed = minf(94,speed+drift_charge*10)
					boost = minf(100,boost+drift_charge*9)
					feedback.emit("drift","DRIFT RELEASE")
				drift_charge = 0
			var lateral_target := steer*(8.0+speed*0.065)*(1.16 if drift else 1.0)
			lateral_velocity = lerpf(lateral_velocity,lateral_target,1-exp(-dt*(7 if drift else 15)))
			lateral += lateral_velocity*dt+touch_shift
			if surface.mode == "rail" and grounded:
				lateral = lerpf(lateral,roundf(lateral/3.1)*3.1,dt*6) if absf(steer) < 0.2 else lateral
			var metric := 1.0
			if branch >= 0:
				metric = maxf(1,course.sample(s+0.5,branch).p.distance_to(surface.p)*2)
			s = minf(course.length,s+speed*dt/metric)
			update_branch(previous_s)
			update_vertical(dt)
			if grounded:
				if surface.mode == "rail":
					state = "grind"
				elif Input.is_action_pressed("roll"):
					state = "roll"
					speed = minf(98,speed+maxf(0,slope)*dt*0.65)
				elif drift:
					state = "drift"
				elif invincible > 1.6:
					state = "stumble"
				elif boost_on:
					state = "boost"
				elif speed > 28:
					state = "sprint"
				elif speed > 9:
					state = "jog"
				elif speed > 0.8:
					state = "walk"
				else:
					state = "idle"
	touch_shift = 0
	surface = course.sample(s,branch)
	position = surface.p+surface.r*lateral+surface.n*height
	basis = basis.orthonormalized().slerp(surface.basis,1-exp(-dt*22)).orthonormalized()
	model.rotation.y = lerpf(model.rotation.y,-steer*0.12,dt*12)
	model.animate(dt,speed,state,steer,vertical_speed)
	model.visible = invincible <= 0 or fmod(invincible,0.16) > 0.055
	interactions(previous_s)
	target = find_target()
	peak_speed = maxf(peak_speed,speed)
	if height < -32 or absf(lateral) > 23:
		respawn()
	var section := course.section_at(s)
	if section != last_section:
		last_section = section
		if surface.mode not in ["air","waterfall","loop","corkscrew","rail"]:
			checkpoint = maxf(2,course.sections[section].start-3)
		feedback.emit("section",course.sections[section].title)
	if s >= course.length-12:
		complete = true
		active = false
		speed = 0
		model.rotation.y = PI
		feedback.emit("finish","STAGE CLEAR")
		finished.emit()
	boost_trail.position = position+surface.n*1.2
	boost_trail.emitting = boost_on or state == "homing"
	dust.position = position+surface.n*0.10
	dust.emitting = grounded and speed > 17
	var dust_mat := dust.process_material as ParticleProcessMaterial
	dust_mat.color = Color("bff4ff") if state == "grind" else Color("f2d69a")

func update_branch(previous_s: float) -> void:
	if branch >= 0:
		if s > course.shortcuts[branch].y:
			branch = -1
			lateral = clampf(lateral,-4,4)
			feedback.emit("shortcut","PERFECT MERGE")
		return
	for i in course.shortcuts.size():
		var entry: float = course.shortcuts[i].x
		var side := 1.0 if i == 0 else -1.0
		if previous_s < entry and s >= entry and lateral*side > 2.7:
			branch = i
			lateral = 0
			lateral_velocity = 0
			boost = minf(100,boost+20)
			feedback.emit("shortcut","SKYLINE ROUTE")
			break

func update_vertical(dt: float) -> void:
	var has_floor: bool = surface.mode not in ["air","waterfall"] or branch >= 0
	var within: bool = absf(lateral) < surface.width+0.3
	if grounded:
		coyote = 0.12
		if not has_floor or not within:
			grounded = false
			vertical_speed = 0
	else:
		coyote = maxf(0,coyote-dt)
	if jump_buffer > 0:
		if not grounded and target >= 0:
			begin_homing(target)
			jump_buffer = 0
			return
		if grounded or coyote > 0:
			vertical_speed = 17.5
			grounded = false
			height = maxf(height,0.08)
			jump_buffer = 0
			coyote = 0
			jump_cut = false
			state = "jump"
			feedback.emit("jump","")
	if not grounded:
		air_time += dt
		if Input.is_action_just_released("jump") and vertical_speed > 8 and state == "jump" and not jump_cut:
			vertical_speed *= 0.63
			jump_cut = true
		vertical_speed -= 30*dt
		height += vertical_speed*dt
		if state != "spring":
			state = "jump" if vertical_speed > 0 else "fall"
		# Only cross the surface from above; a fall below the island must respawn.
		if height <= 0 and height-vertical_speed*dt >= -0.6 and has_floor and within and vertical_speed < 0:
			height = 0
			vertical_speed = 0
			grounded = true
			model.land_squash = minf(1,air_time*0.8)
			if air_time > 0.3:
				feedback.emit("land","")
			air_time = 0
			combo = 0

func find_target() -> int:
	var closest := 46.0
	var result := -1
	for i in world.enemies.size():
		var enemy := world.enemies[i]
		var ds: float = enemy.s-s
		if enemy.alive and ds > -1.5 and ds < closest and absf(enemy.x-lateral) < 14 and absf(enemy.h-height) < 22 and branch < 0:
			closest = ds
			result = i
	return result

func begin_homing(index: int) -> void:
	homing_target = index
	homing_time = 0
	homing_from = Vector3(s,lateral,height)
	grounded = false
	state = "homing"
	feedback.emit("homing","")

func advance_homing(dt: float) -> void:
	var enemy := world.enemies[homing_target]
	homing_time += dt
	var duration := clampf((enemy.s-homing_from.x)/110,0.11,0.32)
	var t := clampf(homing_time/duration,0,1)
	s = lerpf(homing_from.x,enemy.s,t)
	lateral = lerpf(homing_from.y,enemy.x,t)
	height = lerpf(homing_from.z,enemy.h,t)
	if t >= 1:
		destroy_enemy(homing_target)
		homing_target = -1
		vertical_speed = 12
		speed = maxf(speed,45)
		state = "spring"
		combo += 1
		best_combo = maxi(best_combo,combo)
		feedback.emit("chain","HOMING CHAIN ×%d" % combo)

func destroy_enemy(index: int) -> void:
	var enemy := world.enemies[index]
	enemy.alive = false
	enemy.node.visible = false
	world.burst(enemy.node.position,Color("ffbd46"),25)
	boost = minf(100,boost+12)
	ring_count += 3

func interactions(previous_s: float) -> void:
	for i in world.rings.size():
		var ring := world.rings[i]
		if ring.taken or ring.branch != branch:
			continue
		if ring.s >= previous_s-2.3 and ring.s <= s+2.3 and absf(ring.x-lateral) < (3.2 if boost_on else 1.85) and absf(ring.h-height-1.1) < 2.8:
			world.take_ring(i)
			ring_count += 1
			boost = minf(100,boost+1.8)
			feedback.emit("ring","")
	if branch >= 0:
		return
	for pad in world.pads:
		if pad.cooldown == 0 and previous_s <= pad.s+1.8 and s >= pad.s-1.8 and absf(lateral) < 3.4 and height < 1.7 and height > -0.5:
			speed = maxf(speed,76)
			boost = minf(100,boost+12)
			pad.cooldown = 2
			feedback.emit("dash","DASH PANEL")
	for spring in world.springs:
		if spring.cooldown == 0 and previous_s <= spring.s+1.7 and s >= spring.s-1.7 and absf(lateral) < 3.3 and height < 2.2 and height > -0.5:
			vertical_speed = spring.power
			height = 1.1
			grounded = false
			speed = maxf(speed,67)
			state = "spring"
			spring.cooldown = 2
			feedback.emit("spring","SKYWARD!")
	for i in world.enemies.size():
		var enemy := world.enemies[i]
		if not enemy.alive or invincible > 0 or homing_target >= 0:
			continue
		if enemy.s >= previous_s-1.5 and enemy.s <= s+1.5 and absf(enemy.x-lateral) < 1.6 and absf(enemy.h-height-1) < 1.8:
			if boost_on or state in ["roll","spin"]:
				destroy_enemy(i)
				feedback.emit("hit","SMASH!")
			else:
				var dropped := mini(ring_count,12)
				ring_count -= dropped
				invincible = 2
				speed *= 0.74
				world.burst(position+Vector3.UP,Color("ffdc4c"),maxi(8,dropped))
				feedback.emit("hurt","KEEP MOVING")

func respawn() -> void:
	respawns += 1
	s = checkpoint
	speed = 22
	lateral = 0
	lateral_velocity = 0
	height = 0
	vertical_speed = 0
	branch = -1
	grounded = true
	homing_target = -1
	invincible = 1.5
	ring_count = maxi(0,ring_count-10)
	surface = course.sample(s)
	transform = Transform3D(surface.basis,surface.p)
	feedback.emit("respawn","BACK IN THE FLOW")
