class_name CoastMona
extends Node3D

const G = preload("res://scripts/geo.gd")
var rig := Node3D.new()
var head := Node3D.new()
var tentacles: Array[Node3D] = []
var tips: Array[Node3D] = []
var eyes: Array[Node3D] = []
var whiskers: Array[Node3D] = []
var tail := Node3D.new()
var spin := Node3D.new()
var phase := 0.0
var lean := 0.0
var land_squash := 0.0
var blink := 0.0
var ink := G.material(Color("111114"),0.80)
var peach := G.material(Color("ffb393"),0.92)
var ivory := G.material(Color("fffaf4"),0.90)
var pupil := G.material(Color("a24f43"),0.93)
var sucker := G.material(Color("c2e5d9"),0.86)

func _init() -> void:
	name = "MonaLisaOctocat"
	for mat in [ink,peach,ivory,pupil,sucker]:
		mat.metallic = 0
		mat.metallic_specular = 0.15
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(rig)
	G.sphere(rig,Vector3(0,0.91,0.04),Vector3(0.50,0.55,0.29),ink)
	G.sphere(rig,Vector3(0,0.48,0.035),Vector3(0.48,0.18,0.28),ink)
	rig.add_child(head)
	head.position = Vector3(0,2.10,-0.025)
	# Contours follow the supplied image. Rounded depth preserves its silhouette in 3D.
	var silhouette: Array[Vector2] = [Vector2(116,28),Vector2(133,30),Vector2(175,50),Vector2(196,46),Vector2(229,44),Vector2(261,47),Vector2(281,50),Vector2(308,33),Vector2(335,28),Vector2(342,50),Vector2(342,81),Vector2(355,107),Vector2(365,136),Vector2(364,167),Vector2(358,190),Vector2(346,214),Vector2(328,232),Vector2(303,245),Vector2(268,251),Vector2(229,253),Vector2(190,251),Vector2(155,243),Vector2(128,230),Vector2(110,211),Vector2(97,186),Vector2(91,159),Vector2(92,136),Vector2(98,112),Vector2(110,83),Vector2(110,57),Vector2(112,39)]
	G.mesh(head,rounded_outline(silhouette,Vector2(229,144),[Vector2(0.30,-0.69),Vector2(0.65,-0.70),Vector2(0.84,-0.68),Vector2(0.97,-0.48),Vector2(1.0,-0.12),Vector2(1.0,0.12),Vector2(0.93,0.44),Vector2(0.72,0.60),Vector2(0.36,0.67)]),ink)
	var face: Array[Vector2] = [Vector2(171,132),Vector2(205,134),Vector2(231,135),Vector2(257,134),Vector2(291,132),Vector2(309,139),Vector2(323,153),Vector2(331,172),Vector2(332,188),Vector2(327,208),Vector2(317,223),Vector2(302,233),Vector2(273,239),Vector2(231,242),Vector2(190,239),Vector2(161,233),Vector2(142,222),Vector2(131,206),Vector2(126,185),Vector2(129,164),Vector2(140,145),Vector2(154,135)]
	G.mesh(head,rounded_outline(face,Vector2(230,187),[Vector2(0.30,-0.805),Vector2(0.70,-0.797),Vector2(0.92,-0.777),Vector2(1.0,-0.70),Vector2(0.95,-0.635)]),peach)
	for side in [-1.0,1.0]:
		var eye := Node3D.new()
		head.add_child(eye)
		eye.position = Vector3(side*0.54,-0.348,-0.809)
		eyes.append(eye)
		G.sphere(eye,Vector3.ZERO,Vector3(0.202,0.287,0.021),ivory,40)
		G.sphere(eye,Vector3(0,-0.012,-0.022),Vector3(0.140,0.202,0.011),pupil,40)
		var whisker_root := Node3D.new()
		head.add_child(whisker_root)
		whiskers.append(whisker_root)
		for i in 2:
			var pts: Array[Vector3] = [Vector3(side*1.04,-0.56-i*0.06,-0.46),Vector3(side*1.49,-0.47-i*0.09,-0.47),Vector3(side*1.91,-0.51-i*0.13,-0.47),Vector3(side*2.10,-0.56-i*0.13,-0.46)]
			G.mesh(whisker_root,curved_tube(pts,[0.012,0.012,0.008,0.002]),ink)
	G.sphere(head,Vector3(0,-0.611,-0.824),Vector3(0.049,0.053,0.016),pupil,24)
	var smile: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 17:
		var angle := PI*i/16.0
		smile.append(Vector3(-cos(angle)*0.102,-0.732-sin(angle)*0.075,-0.794))
		radii.append(0.015)
	G.mesh(head,G.sweep(smile,radii,10),pupil)
	for rear in [false,true]:
		for side in [-1.0,1.0]:
			build_foot(side,rear)
	build_tail()
	build_spin()

func rounded_outline(outline: Array[Vector2], center: Vector2, profile: Array[Vector2]) -> ArrayMesh:
	var smooth: Array[Vector2] = []
	for i in outline.size():
		for j in 5:
			smooth.append(outline[i].cubic_interpolate(outline[(i+1)%outline.size()],outline[posmod(i-1,outline.size())],outline[(i+2)%outline.size()],j/5.0))
	var rings: Array[PackedVector3Array] = []
	for slice in profile:
		var ring := PackedVector3Array()
		for point in smooth:
			var p := center+(point-center)*slice.x
			ring.append(Vector3((p.x-229)*0.0094,(144-p.y)*0.0094,slice.y))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings.size()-1:
		for j in smooth.size():
			var k := (j+1)%smooth.size()
			G.quad(st,rings[i][j],rings[i+1][j],rings[i+1][k],rings[i][k])
	for j in smooth.size():
		var k := (j+1)%smooth.size()
		G.triangle(st,Vector3((center.x-229)*0.0094,(144-center.y)*0.0094,profile[0].y),rings[0][j],rings[0][k])
		G.triangle(st,Vector3((center.x-229)*0.0094,(144-center.y)*0.0094,profile.back().y),rings.back()[k],rings.back()[j])
	return G.finish(st)

func build_foot(side: float, rear: bool) -> void:
	var root := Node3D.new()
	rig.add_child(root)
	root.position = Vector3(side*(0.435 if rear else 0.16),0.43,0.06 if rear else -0.14)
	tentacles.append(root)
	var pts: Array[Vector3] = [Vector3.ZERO,Vector3(0,-0.11,0),Vector3(side*0.012,-0.22,-0.01)]
	G.mesh(root,curved_tube(pts,[0.118,0.105,0.088]),ink)
	var curl := Node3D.new()
	root.add_child(curl)
	curl.position = pts.back()
	tips.append(curl)
	G.sphere(curl,Vector3.ZERO,Vector3.ONE*0.089,ink,20)
	var curl_points: Array[Vector3] = [Vector3.ZERO,Vector3(side*0.015,-0.08,-0.025),Vector3(side*0.055,-0.13,-0.06),Vector3(side*0.14,-0.15,-0.085),Vector3(side*0.20,-0.14,-0.09)]
	G.mesh(curl,curved_tube(curl_points,[0.088,0.09,0.078,0.040,0.004]),ink)

func add_cup(parent: Node3D, pos: Vector3, radius: float) -> void:
	G.sphere(parent,pos,Vector3(radius,radius*0.65,0.012),sucker,20)

func build_tail() -> void:
	rig.add_child(tail)
	tail.position = Vector3(0.38,0.97,0.04)
	tentacles.append(tail)
	var pts: Array[Vector3] = [Vector3.ZERO,Vector3(0.18,-0.09,0),Vector3(0.36,-0.09,-0.02),Vector3(0.51,-0.015,-0.035),Vector3(0.64,0.15,-0.045),Vector3(0.77,0.28,-0.055),Vector3(0.89,0.31,-0.065),Vector3(0.96,0.27,-0.07)]
	G.mesh(tail,curved_tube(pts,[0.10,0.093,0.080,0.069,0.062,0.054,0.043,0.009]),ink)
	for i in range(1,8):
		add_cup(tail,pts[i]+Vector3(0,0,-0.091+i*0.009),0.037-i*0.002)

func curved_tube(points: Array[Vector3], radii: Array[float]) -> ArrayMesh:
	var smooth_points: Array[Vector3] = []
	var smooth_radii: Array[float] = []
	for i in points.size()-1:
		for j in 5:
			var t := j/5.0
			smooth_points.append(points[i].cubic_interpolate(points[i+1],points[maxi(0,i-1)],points[mini(points.size()-1,i+2)],t))
			smooth_radii.append(lerpf(radii[i],radii[i+1],t))
	smooth_points.append(points.back())
	smooth_radii.append(radii.back())
	return G.sweep(smooth_points,smooth_radii,20)

func build_spin() -> void:
	add_child(spin)
	spin.position.y = 1.12
	G.sphere(spin,Vector3.ZERO,Vector3.ONE*0.84,ink,40)
	var curled_head := head.duplicate() as Node3D
	spin.add_child(curled_head)
	curled_head.position = Vector3(0,0.25,-0.40)
	curled_head.scale = Vector3.ONE*0.65
	for i in 4:
		var points: Array[Vector3] = []
		var radii: Array[float] = []
		for j in 16:
			var u := j/15.0
			var angle := i*PI/2+u*2.1
			points.append(Vector3(cos(angle)*0.88,sin(angle)*0.88,0.21-u*0.20))
			radii.append(lerpf(0.16,0.015,u))
		G.mesh(spin,G.sweep(points,radii,16),ink)
		for j in [4,7,10]:
			add_cup(spin,points[j]+Vector3(0,0,-0.10),0.056)
	var streak := G.torus(spin,Vector3.ZERO,0.98,1.015,G.material(Color("c6a9ff"),0.27,0.1,1.1))
	streak.rotation.x = PI/2
	spin.visible = false

func animate(dt: float, speed: float, state: String, steer: float, vertical_speed: float = 0.0) -> void:
	phase += dt*(2.5+minf(absf(speed),65)*0.42)
	var moving := clampf(absf(speed)/10,0,1)
	var sprint := clampf((speed-13)/33,0,1)
	var ball := state in ["spin","homing","roll","charge"]
	var airborne := state in ["jump","fall","spring","homing"]
	rig.visible = not ball
	spin.visible = ball
	spin.rotation.x -= dt*(10+speed*0.38)
	spin.scale = Vector3.ONE*(0.94+0.025*sin(phase*4))
	if state == "homing":
		spin.scale = Vector3(0.83,0.83,1.25)
	var target_lean := (0.07+sprint*0.23)*moving if not airborne else -0.025
	if state == "victory":
		target_lean = 0
	lean = lerpf(lean,target_lean,1-exp(-dt*13))
	land_squash = move_toward(land_squash,0,dt*5)
	rig.scale = Vector3(1+land_squash*0.14,1-land_squash*0.22,1+land_squash*0.12)
	rig.position.y = absf(sin(phase))*0.035*moving+sin(phase*0.43)*0.009*(1-moving)-land_squash*0.035
	rig.rotation.x = -lean
	rig.rotation.z = lerpf(rig.rotation.z,-steer*(0.10+sprint*0.19),1-exp(-dt*10))
	var twist := steer*0.42 if state == "drift" else (-0.36 if state == "grind" else 0.0)
	rig.rotation.y = lerpf(rig.rotation.y,twist,1-exp(-dt*10))
	if state in ["drift","grind"]:
		rig.position.y -= 0.025
	if state == "stumble":
		rig.rotation.x = 0.14
	head.position.y = 2.10+sin(phase*0.43)*0.012*(1-moving)
	head.rotation.x = lean*0.78+clampf(-vertical_speed*0.002,-0.07,0.07)
	head.rotation.y = lerpf(head.rotation.y,-steer*0.20,1-exp(-dt*9))
	head.rotation.z = lerpf(head.rotation.z,-0.09 if state == "victory" else sin(phase*0.19)*0.019*(1-moving),1-exp(-dt*8))
	for i in 4:
		var side := -1.0 if i%2 == 0 else 1.0
		var stride := sin(phase+(0 if i in [0,3] else PI))
		var swing := stride*(0.19+sprint*0.12)*moving
		var spread := side*0.01*moving
		if airborne:
			swing = -0.35 if i < 2 else 0.40
			spread = side*0.13
		elif state == "grind":
			swing = -0.12 if i < 2 else 0.21
			spread = side*0.025
		elif state == "drift":
			swing *= 0.25
			spread = side*0.06
		elif state == "victory":
			swing = sin(phase*0.65+i)*0.07
		tentacles[i].rotation.x = lerpf(tentacles[i].rotation.x,swing,1-exp(-dt*22))
		tentacles[i].rotation.z = lerpf(tentacles[i].rotation.z,spread,1-exp(-dt*15))
		tentacles[i].position.y = 0.43+maxf(0,-stride)*0.06*moving
		tips[i].rotation.x = lerpf(tips[i].rotation.x,-swing*0.40,1-exp(-dt*19))
		tips[i].rotation.z = side*sin(phase*0.65+i)*0.018
	var tail_angle := 0.07+sprint*0.12 if moving > 0 else sin(phase*0.65)*0.025
	if state == "victory":
		tail_angle = 0.08+sin(phase*1.3)*0.11
	tail.rotation.z = lerpf(tail.rotation.z,tail_angle,1-exp(-dt*8))
	tail.rotation.x = lerpf(tail.rotation.x,-sprint*0.45,1-exp(-dt*8))
	for i in whiskers.size():
		whiskers[i].rotation.y = sin(phase*0.9+i)*0.025*moving
	blink += dt
	var closing := maxf(0,1-absf(fmod(blink,4.8)-4.5)/0.10)
	for eye in eyes:
		eye.scale.y = maxf(0.035,1-closing)
