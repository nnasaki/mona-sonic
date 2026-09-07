class_name CoastWorld
extends Node3D

const G = preload("res://scripts/geo.gd")
var course: CoastCourse
var rng := RandomNumberGenerator.new()
var rings: Array[Dictionary] = []
var rings_mesh := MultiMesh.new()
var enemies: Array[Dictionary] = []
var pads: Array[Dictionary] = []
var springs: Array[Dictionary] = []
var crumble: Array[Dictionary] = []
var birds: Array[Dictionary] = []
var gold := G.material(Color("ffbc24"),0.23,0.73,0.15)
var white := G.material(Color("fff4dc"),0.72)
var green := G.material(Color("369831"),0.89)
var trim := G.material(Color("e8c082"),0.67)
var stone := G.material(Color("e2c18d"),0.9)
var dark_stone := G.material(Color("80724f"),0.9)
var metal := G.material(Color("284352"),0.35,0.65)
var cyan := G.material(Color("46f2ff"),0.22,0.3,1.5)
var red := G.material(Color("ef4050"),0.34,0.2)
var checker: ShaderMaterial
var sand: ShaderMaterial
var foliage: ShaderMaterial
var elapsed := 0.0
var mist: GPUParticles3D
var palm_transforms: Array[Transform3D] = []
var grass_transforms: Array[Transform3D] = []
var flowers: Array[Transform3D] = []

func build(route: CoastCourse) -> void:
	course = route
	rng.seed = 21061991
	checker = ShaderMaterial.new()
	checker.shader = load("res://shaders/terrain.gdshader")
	sand = ShaderMaterial.new()
	sand.shader = checker.shader
	sand.set_shader_parameter("checkered",false)
	sand.set_shader_parameter("base_color",Color("dba969"))
	sand.set_shader_parameter("second_color",Color("efcd8e"))
	foliage = ShaderMaterial.new()
	foliage.shader = load("res://shaders/foliage.gdshader")
	build_lighting()
	build_ocean()
	build_road(0,course.length,-1)
	for i in course.shortcuts.size():
		build_road(course.shortcuts[i].x,course.shortcuts[i].y,i)
	build_islands()
	build_landmarks()
	build_props()
	build_collectibles()
	build_vegetation()
	build_birds()
	build_camera_collision(self)

func build_camera_collision(parent: Node3D) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D and child.material_override in [checker,sand,stone,trim,green]:
			if child.mesh is ArrayMesh or child.mesh is BoxMesh or child.mesh is CylinderMesh:
				var body := StaticBody3D.new()
				var shape := CollisionShape3D.new()
				shape.shape = child.mesh.create_trimesh_shape()
				body.collision_layer = 1
				body.collision_mask = 0
				body.add_child(shape)
				child.add_child(body)
		elif child is Node3D:
			build_camera_collision(child)

func build_lighting() -> void:
	var forward_plus := RenderingServer.get_current_rendering_method() == "forward_plus"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("1684d9")
	sky_mat.sky_horizon_color = Color("b6e9ef")
	sky_mat.ground_bottom_color = Color("56b5c5")
	sky_mat.ground_horizon_color = Color("b6e9ef")
	sky_mat.sky_curve = 0.18
	sky_mat.sun_angle_max = 18
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("bfdefb")
	env.ambient_light_energy = 0.43 if forward_plus else 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color("78bfd5")
	env.fog_density = 0.00045
	env.fog_sky_affect = 0.15
	env.fog_depth_begin = 380
	env.fog_depth_end = 2100
	env.ssao_enabled = forward_plus
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.3
	env.ssr_enabled = forward_plus
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-32,-8)
	sun.light_color = Color("fff1d8")
	# Compatibility lights in a different color pipeline; keep Mona's peach face below clipping.
	sun.light_energy = 1.22 if forward_plus else 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220
	sun.light_angular_distance = 0.7 if forward_plus else 0.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,145,0)
	fill.light_color = Color("8edaff")
	fill.light_energy = 0.20 if forward_plus else 0.10
	add_child(fill)

func build_ocean() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4600,4600)
	plane.subdivide_width = 130
	plane.subdivide_depth = 130
	var ocean := ShaderMaterial.new()
	ocean.shader = load("res://shaders/ocean.gdshader")
	G.mesh(self,plane,ocean,Vector3(0,-1,-650))
	# Large, soft cloud forms sit in the sky rather than in a downloaded skybox.
	var cloud := G.material(Color("f8ffff"),1)
	for i in 35:
		var p := Vector3(rng.randf_range(-1300,1300),rng.randf_range(210,350),rng.randf_range(-1900,180))
		for j in 3:
			G.sphere(self,p+Vector3(j*24,rng.randf_range(-5,6),0),Vector3(40,10+j*2,19),cloud,16)

func build_road(start: float, end: float, branch: int) -> void:
	var s := start
	while s < end-0.1:
		var until := minf(s+80,end)
		var top := SurfaceTool.new()
		var edge := SurfaceTool.new()
		var sides := SurfaceTool.new()
		var stripes := SurfaceTool.new()
		for st in [top,edge,sides,stripes]:
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segments := 0
		var shoulder_segments := 0
		var rail_points: Array[Vector3] = []
		var rail_radii: Array[float] = []
		while s < until-0.01:
			var next := minf(s+1.7,until)
			var a := course.sample(s,branch)
			var b := course.sample(next,branch)
			var mode: String = a.mode
			if branch >= 0:
				mode = "shortcut"
			if mode == "rail":
				for lane in [-3.1,0.0,3.1]:
					var ra: Vector3 = a.p+a.r*lane
					var rb: Vector3 = b.p+b.r*lane
					G.quad(top,ra-a.r*0.16,ra+a.r*0.16,rb+b.r*0.16,rb-b.r*0.16)
					G.quad(sides,ra-a.r*0.13,ra-a.r*0.13-a.n*0.45,rb-b.r*0.13-b.n*0.45,rb-b.r*0.13)
					G.quad(sides,ra+a.r*0.13,rb+b.r*0.13,rb+b.r*0.13-b.n*0.45,ra+a.r*0.13-a.n*0.45)
				segments += 1
			elif mode not in ["air","waterfall"]:
				shoulder_segments += 1
				var w: float = a.width
				var bw: float = b.width
				var road_width := w-1.25 if branch < 0 else w-0.4
				var rb_width := bw-1.25 if branch < 0 else bw-0.4
				G.quad(top,a.p-a.r*road_width,a.p+a.r*road_width,b.p+b.r*rb_width,b.p-b.r*rb_width,Vector2(road_width*2,1.7))
				for sign_x in [-1.0,1.0]:
					G.quad(edge,a.p+a.r*road_width*sign_x,a.p+a.r*w*sign_x,b.p+b.r*bw*sign_x,b.p+b.r*rb_width*sign_x)
					G.quad(sides,a.p+a.r*w*sign_x,a.p+a.r*w*sign_x-a.n*3.4,b.p+b.r*bw*sign_x-b.n*3.4,b.p+b.r*bw*sign_x)
					G.quad(stripes,a.p+a.r*(w-0.12)*sign_x+a.n*0.04,a.p+a.r*(w+0.10)*sign_x+a.n*0.04,b.p+b.r*(bw+0.10)*sign_x+b.n*0.04,b.p+b.r*(bw-0.12)*sign_x+b.n*0.04)
				G.quad(sides,a.p-a.r*w-a.n*3.4,a.p+a.r*w-a.n*3.4,b.p+b.r*bw-b.n*3.4,b.p-b.r*bw-b.n*3.4)
				segments += 1
			s = next
		if segments:
			var mode: String = course.sample((s+until)*0.5).mode
			G.mesh(self,G.finish(top),gold if mode == "rail" else sand)
			G.mesh(self,G.finish(sides),checker)
			# Rail-only chunks contain no shoulder triangles.
			if shoulder_segments > 0:
				G.mesh(self,G.finish(edge),green)
				G.mesh(self,G.finish(stripes),trim)

func island(p: Vector3, radius: Vector2, height: float, seed_phase: float = 0.0, beach: bool = true, top_normal := Vector3.UP) -> void:
	var wall := SurfaceTool.new()
	var grass := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 28
	for i in count:
		var a := TAU*i/count
		var b := TAU*(i+1)/count
		var wa := 1+0.09*sin(a*5+seed_phase)+0.055*cos(a*9)
		var wb := 1+0.09*sin(b*5+seed_phase)+0.055*cos(b*9)
		var va := p+Vector3(cos(a)*radius.x*wa,0,sin(a)*radius.y*wa)
		var vb := p+Vector3(cos(b)*radius.x*wb,0,sin(b)*radius.y*wb)
		va.y -= ((va.x-p.x)*top_normal.x+(va.z-p.z)*top_normal.z)/maxf(0.2,top_normal.y)
		vb.y -= ((vb.x-p.x)*top_normal.x+(vb.z-p.z)*top_normal.z)/maxf(0.2,top_normal.y)
		var ma := va+Vector3(cos(a)*radius.x*0.1,-height*0.45,sin(a)*radius.y*0.1)
		var mb := vb+Vector3(cos(b)*radius.x*0.1,-height*0.45,sin(b)*radius.y*0.1)
		var ba := p+Vector3(cos(a)*radius.x*0.91,-height,sin(a)*radius.y*0.91)
		var bb := p+Vector3(cos(b)*radius.x*0.91,-height,sin(b)*radius.y*0.91)
		G.quad(wall,va,vb,mb,ma)
		G.quad(wall,ma,mb,bb,ba)
		G.triangle(grass,p+Vector3(0,0.04,0),va,vb)
		G.quad(grass,va,vb,vb-Vector3.UP*1.4,va-Vector3.UP*1.4)
	G.mesh(self,G.finish(wall),checker)
	G.mesh(self,G.finish(grass),green)
	if beach:
		G.sphere(self,Vector3(p.x,-0.3,p.z),Vector3(radius.x*1.32,2.1,radius.y*1.3),sand,28)

func build_islands() -> void:
	var s := 0.0
	while s < course.length:
		var f := course.sample(s)
		if f.mode in ["coast","ruins","sprint"]:
			island(f.p-Vector3.UP*2.1,Vector2(rng.randf_range(15,22),23),f.p.y+3,s*0.05,true,f.n)
			for side in [-1.0,1.0]:
				var at: Vector3 = f.p+f.r*side*rng.randf_range(9,13)-Vector3.UP*2.0
				palm_transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(0.82,1.28)),at))
				for j in 12:
					var spot: Vector3 = f.p+f.r*side*rng.randf_range(6.6,12.8)+f.f*rng.randf_range(-9,9)-Vector3.UP*1.8
					grass_transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(0.65,1.45)),spot))
					if j%3 == 0:
						flowers.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU),spot+Vector3.UP*0.1))
		s += 27
	# Offshore stacks, layered headlands and beaches establish the large continuous bay.
	for i in 32:
		var p := Vector3(rng.randf_range(-450,470),rng.randf_range(22,104),rng.randf_range(-1510,-70))
		if absf(p.x) < 150:
			p.x += 195*signf(p.x+0.01)
		island(p,Vector2(rng.randf_range(24,75),rng.randf_range(23,68)),p.y+4,i)
		for j in 3:
			palm_transforms.append(Transform3D(Basis(Vector3.UP,j*2.1),p+Vector3(j*6-6,0,j*3)))
	# Two flanking towers frame the main loop without obstructing the racing surface.
	island(Vector3(-27,44,-192),Vector2(13,22),48,3)
	island(Vector3(38,37,-191),Vector2(13,23),42,1)
	palm_transforms.append(Transform3D(Basis.IDENTITY,Vector3(-27,44,-192)))
	palm_transforms.append(Transform3D(Basis.IDENTITY,Vector3(38,37,-191)))

func waterfall(p: Vector3, width: float, height: float) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/waterfall.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2(width,height)
	plane.orientation = PlaneMesh.FACE_Z
	plane.subdivide_width = 12
	plane.subdivide_depth = 36
	G.mesh(self,plane,m,p+Vector3(0,-height*0.5,0))
	for i in 4:
		G.sphere(self,p+Vector3((i-1.5)*width*0.21,-height,1.8),Vector3(width*0.22,1.2,5.5),G.material(Color("b8ffff"),0.4),20)
	var fx := particles(p+Vector3(0,-height+4,1),Color("e3ffff"),85,5.0,Vector3(width*0.46,2,3),Vector3(0,4,1),4.0,3.0)
	fx.visibility_aabb = AABB(Vector3(-width,-10,-30),Vector3(width*2,height+30,60))

func build_landmarks() -> void:
	var lookout := course.sample(0)
	G.cylinder(self,lookout.p-Vector3.UP*1.0,8.8,1.2,sand)
	G.cylinder(self,lookout.p-Vector3.UP*1.6,9.0,0.26,trim)
	waterfall(Vector3(-38,60,-132),15,60)
	waterfall(Vector3(172,83,-435),24,84)
	island(Vector3(158,84,-453),Vector2(43,29),90,2)
	# A wide curtain of falling water beside the playable gorge jump.
	island(Vector3(58,139,-1085),Vector2(28,39),144,7)
	island(Vector3(-63,108,-1065),Vector2(24,39),113,4)
	waterfall(Vector3(47,140,-1054),36,141)
	waterfall(Vector3(-59,109,-1036),23,110)
	particles(Vector3(24,80,-1030),Color("d8f5ff"),32,4,Vector3(9,5,10),Vector3(-4,1,0),2,3)
	var rail_start: float = course.sections[3].start
	var rail_end: float = course.sections[4].start
	for s in range(int(rail_start+14),int(rail_end-5),25):
		var f := course.sample(s)
		G.rod(self,f.p-f.r*4.0-f.n*0.5,f.p+f.r*4.0-f.n*0.5,0.19,metal)
		G.rod(self,f.p-f.r*3-f.n*0.6,Vector3(f.p.x-3,0,f.p.z),0.42,white)
		G.rod(self,f.p+f.r*3-f.n*0.6,Vector3(f.p.x+3,0,f.p.z),0.42,white)
		G.rod(self,f.p-f.r*3-f.n*6,f.p+f.r*3-f.n*0.6,0.15,gold)
	# Sunstone arches form a long, readable tunnel with alternating pools of sunlight.
	var ruins_start: float = course.sections[5].start
	var wall_start: float = course.sections[6].start
	for s in range(int(ruins_start+22),int(wall_start-8),13):
		var f := course.sample(s)
		var root := Node3D.new()
		add_child(root)
		root.transform = Transform3D(f.basis,f.p)
		for side in [-1.0,1.0]:
			G.box(root,Vector3(side*7.7,5.1,0),Vector3(2.1,10.2,3.2),stone)
			G.box(root,Vector3(side*7.7,0.4,0),Vector3(2.8,0.8,3.8),trim)
			G.box(root,Vector3(side*7.7,8.9,0),Vector3(2.7,0.8,3.8),trim)
			for j in 3:
				G.box(root,Vector3(side*7.7,2.7+j*2.2,-1.63),Vector3(1.7,0.08,0.04),dark_stone)
		G.box(root,Vector3(0,10.4,0),Vector3(17.7,1.8,3.5),stone)
		G.box(root,Vector3(0,11.6,0),Vector3(18.2,0.65,3.9),green)
		G.box(root,Vector3(0,10.3,-1.81),Vector3(1.5,1.1,0.15),gold)
		if s > ruins_start+60:
			G.box(root,Vector3(-9,4.5,4),Vector3(1.4,9,13),checker)
			G.box(root,Vector3(9,4.5,4),Vector3(1.4,9,13),checker)
			G.box(root,Vector3(0,11.5,4),Vector3(19,2,13),checker)
			var light := OmniLight3D.new()
			root.add_child(light)
			light.position = Vector3(0,5,0)
			light.light_color = Color("4de2f0")
			light.light_energy = 1.4
			light.omni_range = 13
			G.sphere(root,Vector3(-6.8,4.1,0),Vector3(0.25,0.6,0.25),cyan)
	# Roadside red-and-white chevrons keep high-speed turns readable.
	for sec in [1,2,3,6,8]:
		var f := course.sample(course.sections[sec].start+8)
		for side in [-1.0,1.0]:
			var root := Node3D.new()
			add_child(root)
			root.transform = Transform3D(f.basis,f.p+f.r*side*7.8)
			G.cylinder(root,Vector3(0,1.5,0),0.12,3,metal)
			G.box(root,Vector3(0,2.8,0),Vector3(2.0,1.3,0.14),red)
			for j in 2:
				var mark := G.box(root,Vector3((j-0.5)*0.7,2.8,-0.09),Vector3(0.15,0.72,0.045),white)
				mark.rotation.z = -0.48
	# The finish is a landmark visible well before the final sprint ends.
	var finish := course.sample(course.length-12)
	var arch := Node3D.new()
	add_child(arch)
	arch.transform = Transform3D(finish.basis,finish.p)
	for side in [-1.0,1.0]:
		G.cylinder(arch,Vector3(side*7,6,0),0.6,12,white)
		G.cylinder(arch,Vector3(side*7,10,0),0.63,1.1,gold)
	var ring := G.torus(arch,Vector3(0,7.2,0),7.5,8.1,gold)
	ring.rotation.x = PI/2
	var label := Label3D.new()
	arch.add_child(label)
	label.text = "FINISH"
	label.font = load("res://assets/fonts/display.ttf")
	label.font_size = 100
	label.pixel_size = 0.019
	label.position = Vector3(0,11.8,-0.2)
	label.outline_size = 10
	label.modulate = Color("fff2c5")
	label.no_depth_test = false

func build_props() -> void:
	for s in [45.0,149.0,course.sections[1].start-15,course.sections[2].start-12,course.sections[3].start-12,course.sections[6].start-15,course.sections[8].start+40,course.length-100]:
		var f := course.sample(s)
		var root := Node3D.new()
		add_child(root)
		root.transform = Transform3D(f.basis,f.p+f.n*0.10)
		G.box(root,Vector3.ZERO,Vector3(4.4,0.18,3.4),metal)
		for side in [-1.0,1.0]:
			G.box(root,Vector3(side*2.1,0.17,0),Vector3(0.15,0.1,3.1),cyan)
		for j in 3:
			for side in [-1.0,1.0]:
				var mark := G.box(root,Vector3(side*0.49,0.16,(j-1)*0.87),Vector3(1.34,0.07,0.18),G.material(Color("ffe67c"),0.3,0.1,1))
				mark.rotation.y = side*0.62
		pads.append({"s":s,"x":0.0,"node":root,"cooldown":0.0})
	for section_id in [4,7]:
		var s: float = course.sections[section_id].start-4.0
		var f := course.sample(s)
		var root := Node3D.new()
		add_child(root)
		root.transform = Transform3D(f.basis,f.p)
		G.cylinder(root,Vector3(0,0.18,0),1.7,0.35,metal)
		for j in 5:
			G.torus(root,Vector3(0,0.30+j*0.13,0),0.68,0.84,white)
		G.cylinder(root,Vector3(0,1.0,0),1.62,0.27,red)
		G.cylinder(root,Vector3(0,1.145,0),1.2,0.025,gold)
		G.sphere(root,Vector3(0,1.18,0),Vector3(0.33,0.07,0.33),white)
		springs.append({"s":s,"node":root,"power":24.0 if section_id == 4 else 29.0,"cooldown":0.0})
	# Collapsing bridge slabs move only after the player has safely crossed each one.
	var bridge_start: float = course.sections[5].start+2
	for i in 8:
		var s := bridge_start+i*2.4
		var f := course.sample(s)
		var plank := G.box(self,f.p+f.n*0.07,Vector3(12.6,0.2,2.1),stone)
		plank.basis = f.basis.scaled(Vector3(12.6,0.2,2.1))
		crumble.append({"node":plank,"s":s,"age":-1.0,"origin":plank.position})
	for s in [108.0,185.0,course.sections[5].start+47,course.sections[5].start+95,course.length-145,course.length-84]:
		make_enemy(s,[-2.8,2.6,0.0][rngi()%3],1.3,false)
	var chain_start: float = course.sections[4].start
	var chain_end: float = course.sections[5].start
	for i in 5:
		make_enemy(lerpf(chain_start+7,chain_end-10,i/4.0),sin(i*1.3)*2.5,4.5+sin(i*PI/4)*6.0,true)

func rngi() -> int:
	return int(rng.randi()%2147483647)

func make_enemy(s: float, x: float, h: float, flying: bool) -> void:
	var f := course.sample(s)
	var root := Node3D.new()
	add_child(root)
	root.transform = Transform3D(f.basis,f.p+f.r*x+f.n*h)
	G.sphere(root,Vector3.ZERO,Vector3(0.95,0.64,0.76),red)
	G.sphere(root,Vector3(0,0.11,-0.61),Vector3(0.72,0.30,0.17),metal)
	for side in [-1.0,1.0]:
		G.sphere(root,Vector3(side*0.31,0.14,-0.755),Vector3(0.17,0.13,0.045),G.material(Color("ffdc35"),0.3,0,1.5))
		if flying:
			G.box(root,Vector3(side*1.17,0,0),Vector3(1.1,0.12,0.6),white)
			G.torus(root,Vector3(side*1.5,0.1,0),0.39,0.53,metal)
		else:
			G.rod(root,Vector3(side*0.6,-0.2,0),Vector3(side*1.15,-0.77,-0.12),0.13,metal)
			G.sphere(root,Vector3(side*1.20,-0.66,-0.15),Vector3(0.3,0.16,0.5),red)
	G.cylinder(root,Vector3(0,0.77,0),0.06,0.46,metal)
	G.sphere(root,Vector3(0,1.01,0),Vector3.ONE*0.13,cyan,16)
	enemies.append({"s":s,"x":x,"h":h,"flying":flying,"node":root,"alive":true,"origin":root.position})

func build_collectibles() -> void:
	for branch in range(-1,course.shortcuts.size()):
		var start := 10.0 if branch < 0 else course.shortcuts[branch].x+6
		var end := course.length-18 if branch < 0 else course.shortcuts[branch].y-4
		var s := start
		while s < end:
			var f := course.sample(s,branch)
			var lane := sin(s*0.020)*2.7 if branch < 0 else 0.0
			if f.mode == "rail":
				lane = 0
			var h := 1.5
			if f.mode in ["air","waterfall"]:
				var sec := course.section_at(s)
				var u: float = (s-course.sections[sec].start)/(course.sections[sec+1].start-course.sections[sec].start)
				h += sin(u*PI)*14
			var tr := Transform3D(f.basis.rotated(f.r,PI/2),f.p+f.r*lane+f.n*h)
			rings.append({"s":s,"x":lane,"h":h,"branch":branch,"taken":false,"transform":tr})
			s += 5.8
	rings_mesh.transform_format = MultiMesh.TRANSFORM_3D
	var torus := TorusMesh.new()
	torus.inner_radius = 0.47
	torus.outer_radius = 0.64
	torus.rings = 20
	torus.ring_segments = 8
	rings_mesh.mesh = torus
	rings_mesh.instance_count = rings.size()
	for i in rings.size():
		rings_mesh.set_instance_transform(i,rings[i].transform)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = rings_mesh
	mi.material_override = gold
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func build_vegetation() -> void:
	var palm := SurfaceTool.new()
	palm.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 9:
		var t := i/9.0
		var a := Vector3(sin(t*1.2)*1.4,t*9,0)
		var b := Vector3(sin((t+1.0/9)*1.2)*1.4,(t+1.0/9)*9,0)
		palm.set_color(Color(0.43+t*0.13,0.28+t*0.1,0.12,0).srgb_to_linear())
		for j in 9:
			var ang := TAU*j/9
			var next := TAU*(j+1)/9
			var ra := 0.42-t*0.19
			G.quad(palm,a+Vector3(cos(ang),0,sin(ang))*ra,a+Vector3(cos(next),0,sin(next))*ra,b+Vector3(cos(next),0,sin(next))*(ra-0.023),b+Vector3(cos(ang),0,sin(ang))*(ra-0.023))
	var crown := Vector3(sin(1.2)*1.4,9,0)
	for leaf in 10:
		var angle := leaf*TAU/10
		var direction := Vector3(cos(angle),0,sin(angle))
		var side := direction.cross(Vector3.UP)
		var leaf_length := rng.randf_range(4.4,6.2)
		for j in 9:
			var t := j/9.0
			var u := (j+1)/9.0
			var a := crown+direction*t*leaf_length+Vector3.UP*(sin(t*PI)*1.45-t*1.4)
			var b := crown+direction*u*leaf_length+Vector3.UP*(sin(u*PI)*1.45-u*1.4)
			var w := sin(t*PI)*0.83+0.035
			var wb := sin(u*PI)*0.83+0.015
			palm.set_color(Color(0.14+leaf%3*0.034,0.43+leaf%3*0.045,0.10,0.3+t*0.7).srgb_to_linear())
			G.quad(palm,a-side*w,a+Vector3.UP*0.11,b+Vector3.UP*0.11,b-side*wb)
			palm.set_color(Color(0.22+leaf%3*0.025,0.59+leaf%3*0.034,0.13,0.3+t*0.7).srgb_to_linear())
			G.quad(palm,a+Vector3.UP*0.11,a+side*w,b+side*wb,b+Vector3.UP*0.11)
	instance_batch(G.finish(palm),foliage,palm_transforms)
	var grass := SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 8:
		var angle := j*2.4
		var p := Vector3(cos(angle),0,sin(angle))*0.22
		var tip := p+Vector3(cos(angle)*0.34,rng.randf_range(0.45,0.96),sin(angle)*0.34)
		grass.set_color(Color(0.34+j%2*0.11,0.64+j%3*0.05,0.10,0.5).srgb_to_linear())
		G.triangle(grass,p-Vector3(0.12,0,0),p+Vector3(0.12,0,0),tip)
	instance_batch(G.finish(grass),foliage,grass_transforms)
	var flower := SurfaceTool.new()
	flower.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 6:
		var t := j*TAU/6
		flower.set_color(Color(1.0,0.91,0.65,0.3))
		G.triangle(flower,Vector3(0,0.55,0),Vector3(cos(t)*0.39,0.53,sin(t)*0.39),Vector3(cos(t+0.6)*0.39,0.53,sin(t+0.6)*0.39))
	flower.set_color(Color(1,0.6,0.1,0.3))
	G.triangle(flower,Vector3(-0.13,0.57,-0.13),Vector3(0.15,0.57,-0.09),Vector3(0,0.57,0.17))
	instance_batch(G.finish(flower),foliage,flowers)

func instance_batch(shape: Mesh, mat: Material, transforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = shape
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i,transforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)

func build_birds() -> void:
	for i in 20:
		var root := Node3D.new()
		add_child(root)
		var origin := Vector3(rng.randf_range(-100,100),rng.randf_range(78,105),rng.randf_range(-300,20))
		root.position = origin
		var wings: Array[Node3D] = []
		for side in [-1.0,1.0]:
			var wing := G.sphere(root,Vector3(side*0.55,0,0),Vector3(0.66,0.045,0.19),white,12)
			wings.append(wing)
		birds.append({"node":root,"origin":origin,"wings":wings,"phase":i*1.3,"scared":false})

func particles(pos: Vector3, color: Color, count: int, lifetime: float, area: Vector3, velocity: Vector3, spread: float, size: float, one_shot: bool = false) -> GPUParticles3D:
	var fx := GPUParticles3D.new()
	fx.position = pos
	fx.amount = count
	fx.lifetime = lifetime
	fx.one_shot = one_shot
	fx.explosiveness = 1.0 if one_shot else 0.0
	var process := ParticleProcessMaterial.new()
	process.direction = velocity.normalized() if velocity.length() > 0 else Vector3.UP
	process.initial_velocity_min = velocity.length()*0.6
	process.initial_velocity_max = velocity.length()
	process.spread = spread*12
	process.gravity = Vector3(0,-3,0) if one_shot else Vector3(0,0.1,0)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = area
	process.scale_min = size*0.4
	process.scale_max = size
	process.color = color
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,1,0.6))
	gradient.set_color(1,Color(1,1,1,0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	fx.process_material = process
	var draw := SphereMesh.new()
	draw.radius = 0.5
	draw.height = 1
	draw.radial_segments = 8
	draw.rings = 4
	var mat := G.material(color,0.8,0,0.25)
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.material = mat
	fx.draw_pass_1 = draw
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fx)
	fx.emitting = true
	if one_shot:
		get_tree().create_timer(lifetime+0.2).timeout.connect(fx.queue_free)
	return fx

func burst(pos: Vector3, color: Color, count: int = 16) -> void:
	particles(pos,color,count,0.6,Vector3.ONE*0.1,Vector3(0,8,0),8.0,0.22,true)

func take_ring(i: int) -> void:
	rings[i].taken = true
	rings_mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))

func reset() -> void:
	for i in rings.size():
		rings[i].taken = false
		rings_mesh.set_instance_transform(i,rings[i].transform)
	for enemy in enemies:
		enemy.alive = true
		enemy.node.visible = true
	for slab in crumble:
		slab.age = -1.0
		slab.node.position = slab.origin
		slab.node.rotation = Vector3.ZERO
	for item in pads+springs:
		item.cooldown = 0

func update(dt: float, player_s: float, player_pos: Vector3) -> void:
	elapsed += dt
	for i in rings.size():
		var ring := rings[i]
		if not ring.taken and absf(ring.s-player_s) < 100:
			var tr: Transform3D = ring.transform
			tr.basis = tr.basis*Basis(Vector3.FORWARD,elapsed*1.6)
			rings_mesh.set_instance_transform(i,tr)
	for enemy in enemies:
		if enemy.alive and enemy.flying:
			enemy.node.position = enemy.origin+Vector3.UP*sin(elapsed*3+enemy.s)*0.32
	for item in pads+springs:
		item.cooldown = maxf(0,item.cooldown-dt)
	for slab in crumble:
		if player_s > slab.s+4 and slab.age < 0:
			slab.age = 0.0
		if slab.age >= 0 and slab.age < 3:
			slab.age += dt
			slab.node.position.y = slab.origin.y-pow(slab.age,2)*9
			slab.node.rotate_x(dt*0.25)
	for bird in birds:
		if bird.node.position.distance_to(player_pos) < 30:
			bird.scared = true
		var t: float = elapsed*0.35+bird.phase
		bird.node.position = bird.origin+Vector3(sin(t)*28,sin(t*1.3)*3+(12 if bird.scared else 0),cos(t)*15)
		bird.node.rotation.y = t+PI/2
		for i in 2:
			bird.wings[i].rotation.z = sin(elapsed*5+bird.phase)*0.4*(1 if i == 0 else -1)
