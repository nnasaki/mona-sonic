class_name CoastMascot
extends Node3D

const G = preload("res://scripts/geo.gd")
var character: String
var rig := Node3D.new()
var head := Node3D.new()
var spin := Node3D.new()
var eyes: Array[Node3D] = []
var tentacles: Array[Node3D] = []
var phase := 0.0
var land_squash := 0.0

func _init(id: String = "mona") -> void:
	character = id
	name = id.capitalize()
	add_child(rig)
	rig.add_child(head)
	head.position.y = 1.65
	match id:
		"mona": build_mona()
		"copilot": build_copilot()
		"ducky": build_ducky()
	add_child(spin)
	spin.position.y = 1.3
	var curled := head.duplicate() as Node3D
	spin.add_child(curled)
	curled.position = Vector3.ZERO
	curled.scale = Vector3.ONE*0.78
	spin.visible = false

func gradient(top: Color, bottom: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
	render_mode unshaded;
	uniform vec4 top_color : source_color;
	uniform vec4 bottom_color : source_color;
	varying float elevation;
	varying vec3 surface_normal;
	void vertex() { elevation = VERTEX.y; surface_normal = NORMAL; }
	void fragment() {
		// ponytail: object-space toy highlights preserve WebGL colors; use PBR for moving lights.
		float light = max(dot(normalize(surface_normal), normalize(vec3(-0.5, 0.7, -0.8))), 0.0);
		vec3 paint = mix(bottom_color.rgb, top_color.rgb, smoothstep(-0.9, 0.9, elevation));
		ALBEDO = paint * (0.73 + 0.27 * light) + vec3(0.09) * pow(light, 24.0);
	}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("top_color",top)
	mat.set_shader_parameter("bottom_color",bottom)
	return mat

# Rounded, closed extrusions keep the reference silhouettes in every camera angle.
func outline(points: Array[Vector2], profile: Array[Vector2]) -> ArrayMesh:
	var contour: Array[Vector2] = []
	for i in points.size():
		for j in 4:
			contour.append(points[i].cubic_interpolate(points[(i+1)%points.size()],points[posmod(i-1,points.size())],points[(i+2)%points.size()],j/4.0))
	var area := 0.0
	for i in contour.size():
		area += contour[i].cross(contour[(i+1)%contour.size()])
	# Godot uses clockwise front faces.
	if area > 0:
		contour.reverse()
	var slices: Array[Vector2] = []
	for i in profile.size()-1:
		for j in 4:
			slices.append(profile[i].cubic_interpolate(profile[i+1],profile[maxi(0,i-1)],profile[mini(profile.size()-1,i+2)],j/4.0))
	slices.append(profile.back())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in slices.size()-1:
		for j in contour.size():
			var a := contour[j]
			var b := contour[(j+1)%contour.size()]
			G.quad(st,Vector3(a.x*slices[i].x,a.y*slices[i].x,slices[i].y),Vector3(b.x*slices[i].x,b.y*slices[i].x,slices[i].y),Vector3(b.x*slices[i+1].x,b.y*slices[i+1].x,slices[i+1].y),Vector3(a.x*slices[i+1].x,a.y*slices[i+1].x,slices[i+1].y))
	for j in contour.size():
		var a := contour[j]
		var b := contour[(j+1)%contour.size()]
		G.triangle(st,Vector3(0,0,slices[0].y),Vector3(b.x*slices[0].x,b.y*slices[0].x,slices[0].y),Vector3(a.x*slices[0].x,a.y*slices[0].x,slices[0].y))
		G.triangle(st,Vector3(0,0,slices[-1].y),Vector3(a.x*slices[-1].x,a.y*slices[-1].x,slices[-1].y),Vector3(b.x*slices[-1].x,b.y*slices[-1].x,slices[-1].y))
	return G.finish(st)

func rounded_panel(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var points: Array[Vector2] = []
	for i in 24:
		var angle := TAU*i/24.0
		points.append(Vector2(signf(cos(angle))*pow(absf(cos(angle)),0.55),signf(sin(angle))*pow(absf(sin(angle)),0.55)))
	return G.mesh(parent,outline(points,[Vector2(0.4,-1),Vector2(0.8,-0.94),Vector2(1,-0.25),Vector2(0.96,0.45),Vector2(0.65,0.9)]),mat,pos,size)

func build_mona() -> void:
	var purple := gradient(Color("7953ff"),Color("c824f4"))
	var pink := gradient(Color("ffb5ef"),Color("ff55cc"))
	var dark := G.material(Color("352064"),0.27)
	var white := G.material(Color("fff6ff"),0.3)
	var silhouette: Array[Vector2] = [Vector2(-1.06,0.58),Vector2(-1.08,1.03),Vector2(-0.85,1.06),Vector2(-0.53,0.94),Vector2(0,0.96),Vector2(0.53,0.94),Vector2(0.85,1.06),Vector2(1.08,1.03),Vector2(1.06,0.58),Vector2(1.17,0.05),Vector2(1.10,-0.61),Vector2(0.75,-0.91),Vector2(0,-1.0),Vector2(-0.75,-0.91),Vector2(-1.10,-0.61),Vector2(-1.17,0.05)]
	G.mesh(head,outline(silhouette,[Vector2(0.3,-0.94),Vector2(0.65,-0.88),Vector2(0.91,-0.66),Vector2(1,-0.15),Vector2(0.95,0.36),Vector2(0.7,0.77),Vector2(0.25,0.94)]),purple)
	var face: Array[Vector2] = [Vector2(-0.88,0.08),Vector2(-0.72,0.48),Vector2(-0.43,0.58),Vector2(0,0.51),Vector2(0.43,0.58),Vector2(0.72,0.48),Vector2(0.88,0.08),Vector2(0.79,-0.28),Vector2(0.81,-0.64),Vector2(0.50,-0.79),Vector2(0,-0.82),Vector2(-0.50,-0.79),Vector2(-0.81,-0.64),Vector2(-0.79,-0.28)]
	G.mesh(head,outline(face,[Vector2(0.3,-1.04),Vector2(0.75,-1.025),Vector2(0.96,-0.95),Vector2(1,-0.83)]),pink)
	for side in [-1.0,1.0]:
		var ear: Array[Vector2] = [Vector2(-0.18,-0.13),Vector2(-0.16,0.19),Vector2(0.18,0.04)]
		var inset := G.mesh(head,outline(ear,[Vector2(0.25,-0.1),Vector2(0.8,-0.09),Vector2(1,0.02)]),pink,Vector3(side*0.85,0.85,-0.80))
		inset.scale.x = -side
		var eye := Node3D.new()
		head.add_child(eye)
		eye.position = Vector3(side*0.46,0.00,-1.026)
		eyes.append(eye)
		G.sphere(eye,Vector3.ZERO,Vector3(0.239,0.321,0.050),G.material(Color("b632c7"),0.4))
		G.sphere(eye,Vector3(0,0,-0.04),Vector3(0.214,0.293,0.030),white)
		G.sphere(eye,Vector3(0.033,-0.071,-0.066),Vector3(0.166,0.223,0.025),dark)
		G.sphere(eye,Vector3(0.075,0.086,-0.088),Vector3(0.069,0.039,0.009),white,20)
		for i in 2:
			var points: Array[Vector3] = [Vector3(side*0.97,-0.34-i*0.12,-0.58),Vector3(side*1.22,-0.28-i*0.10,-0.63),Vector3(side*1.38,-0.29-i*0.13,-0.60)]
			G.mesh(head,G.sweep(points,[0.033,0.034,0.015],12),purple)
	G.sphere(head,Vector3(0,-0.29,-1.06),Vector3(0.060,0.039,0.027),dark,20)
	var smile: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 15:
		var t := PI*i/14.0
		smile.append(Vector3(-cos(t)*0.12,-0.43-sin(t)*0.045,-1.053))
		radii.append(0.011)
	G.mesh(head,G.sweep(smile,radii,10),dark)

func build_copilot() -> void:
	var shell := gradient(Color("b19aff"),Color("5d45e7"))
	var cyan := gradient(Color("97eaff"),Color("1677ff"))
	var lens := gradient(Color("1038f5"),Color("070d68"))
	var glow := G.material(Color("70eaff"),0.28,0.1,0.75)
	G.sphere(head,Vector3.ZERO,Vector3(1.07,1.02,0.96),shell,48)
	rounded_panel(head,Vector3(0,-0.24,-0.72),Vector3(0.98,0.62,0.24),cyan)
	rounded_panel(head,Vector3(0,-0.24,-0.93),Vector3(0.855,0.50,0.06),lens)
	for side in [-1.0,1.0]:
		var ear := G.cylinder(head,Vector3(side*1.13,-0.01,0.05),0.38,0.30,shell)
		ear.rotation.z = PI/2
		G.sphere(head,Vector3(side*1.30,-0.01,0.05),Vector3(0.06,0.25,0.25),lens)
		var goggle := Node3D.new()
		head.add_child(goggle)
		goggle.position = Vector3(side*0.51,0.65,-0.81)
		goggle.rotation.z = side*-0.08
		rounded_panel(goggle,Vector3.ZERO,Vector3(0.49,0.45,0.23),cyan)
		rounded_panel(goggle,Vector3(0,0,-0.205),Vector3(0.355,0.32,0.07),lens)
		var eye := Node3D.new()
		head.add_child(eye)
		eye.position = Vector3(side*0.28,-0.22,-1.001)
		eyes.append(eye)
		rounded_panel(eye,Vector3.ZERO,Vector3(0.080,0.19,0.020),glow)
		for i in 10:
			G.box(eye,Vector3(0,-0.15+i*0.032,-0.023),Vector3(0.15,0.009,0.004),cyan)
	G.sphere(head,Vector3(0,0.63,-0.86),Vector3(0.15,0.075,0.12),cyan)
	var band: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 25:
		var t := PI*i/24.0
		band.append(Vector3(cos(t)*1.08,sin(t)*1.01,0.16))
		radii.append(0.031)
	G.mesh(head,G.sweep(band,radii,12),cyan)
	G.torus(head,Vector3(0,-0.93,0),0.23,0.34,cyan)
	G.sphere(head,Vector3(0,-0.96,0),Vector3(0.24,0.06,0.24),glow)

func build_ducky() -> void:
	var yellow := gradient(Color("f4fb43"),Color("e7c914"))
	var orange := gradient(Color("ffc139"),Color("ed900d"))
	var dark := G.material(Color("103948"),0.15)
	var white := G.material(Color("fffde9"),0.2)
	G.sphere(head,Vector3(0,-0.55,0.05),Vector3(0.88,0.76,0.75),yellow,48)
	G.sphere(head,Vector3(0,0.41,-0.08),Vector3(0.98,0.94,0.87),yellow,48)
	G.sphere(head,Vector3(0,0.10,-0.98),Vector3(0.47,0.145,0.36),orange,40)
	G.sphere(head,Vector3(0,-0.015,-1.01),Vector3(0.38,0.090,0.27),orange,40)
	for side in [-1.0,1.0]:
		var eye := Node3D.new()
		head.add_child(eye)
		eye.position = Vector3(side*0.51,0.40,-0.828)
		eye.rotation.y = side*-0.22
		eyes.append(eye)
		G.sphere(eye,Vector3.ZERO,Vector3(0.172,0.185,0.045),white)
		G.sphere(eye,Vector3(0,0,-0.037),Vector3(0.150,0.163,0.045),dark)
		G.sphere(eye,Vector3(-0.035,0.071,-0.077),Vector3.ONE*0.044,white,20)
		G.sphere(eye,Vector3(0.042,0.017,-0.083),Vector3.ONE*0.019,white,16)
		var wing := Node3D.new()
		head.add_child(wing)
		wing.position = Vector3(side*0.79,-0.41,0.08)
		tentacles.append(wing)
		G.sphere(wing,Vector3.ZERO,Vector3(0.20,0.41,0.43),yellow)
	var tail := G.sphere(head,Vector3(0,-0.48,0.71),Vector3(0.37,0.26,0.47),yellow)
	tail.rotation.x = -0.45

func animate(dt: float, speed: float, state: String, steer: float, vertical_speed: float = 0.0) -> void:
	phase += dt*(2.4+minf(speed,65)*0.22)
	var ball := state in ["spin","homing","roll","charge"]
	var air := state in ["jump","fall","spring","homing"]
	rig.visible = not ball
	spin.visible = ball
	spin.rotation.x -= dt*(9+speed*0.32)
	land_squash = move_toward(land_squash,0,dt*5)
	rig.scale = Vector3(1+land_squash*0.14,1-land_squash*0.20,1+land_squash*0.12)
	rig.position.y = sin(phase)*0.065 if character == "copilot" else absf(sin(phase))*minf(speed/70,0.18)
	rig.rotation.x = lerpf(rig.rotation.x,-minf(speed/400,0.16) if not air else clampf(-vertical_speed*0.006,-0.13,0.13),1-exp(-dt*12))
	rig.rotation.z = lerpf(rig.rotation.z,-steer*0.15+(sin(phase*0.7)*0.07 if state == "victory" else 0.0),1-exp(-dt*10))
	for i in tentacles.size():
		tentacles[i].rotation.z = (-1 if i == 0 else 1)*(0.15+absf(sin(phase))*0.30 if air or state == "victory" else sin(phase)*0.08)
	var closing := maxf(0,1-absf(fmod(phase*0.15,4.8)-4.5)/0.10)
	for eye in eyes:
		eye.scale.y = maxf(0.045,1-closing)
