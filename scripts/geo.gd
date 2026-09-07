class_name CoastGeo
extends RefCounted

static func material(color: Color, roughness: float = 0.55, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

static func mesh(parent: Node3D, shape: Mesh, mat: Material, pos := Vector3.ZERO, size := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = mat
	n.position = pos
	n.scale = size
	parent.add_child(n)
	return n

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, detail: int = 32) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = detail
	s.rings = detail / 2
	return mesh(parent, s, mat, pos, size)

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	return mesh(parent, BoxMesh.new(), mat, pos, size)

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var s := CylinderMesh.new()
	s.top_radius = radius if top < 0 else top
	s.bottom_radius = radius
	s.height = height
	s.radial_segments = 20
	return mesh(parent, s, mat, pos)

static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var n := cylinder(parent, (a+b)*0.5, radius, a.distance_to(b), mat)
	var up := (b-a).normalized()
	var right := up.cross(Vector3.FORWARD)
	if right.length_squared() < 0.01:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	n.basis = Basis(right, up, right.cross(up))
	return n

static func torus(parent: Node3D, pos: Vector3, inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var s := TorusMesh.new()
	s.inner_radius = inner
	s.outer_radius = outer
	s.rings = 32
	s.ring_segments = 12
	return mesh(parent, s, mat, pos)

static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua := Vector2.ZERO, ub := Vector2.RIGHT, uc := Vector2.ONE) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)

static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv := Vector2.ONE) -> void:
	triangle(st, a, b, c, Vector2.ZERO, Vector2(uv.x, 0), uv)
	triangle(st, a, c, d, Vector2.ZERO, uv, Vector2(0, uv.y))

static func finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()

static func sweep(points: Array[Vector3], radii: Array[float], sides: int = 16) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	var previous_right := Vector3.ZERO
	for i in points.size():
		var tangent := (points[mini(i+1, points.size()-1)]-points[maxi(i-1, 0)]).normalized()
		# Transport the ring frame through vertical bends without flipping the tube inside out.
		var right := previous_right-tangent*previous_right.dot(tangent)
		if right.length_squared() < 0.001:
			right = tangent.cross(Vector3.UP)
			if right.length_squared() < 0.001:
				right = tangent.cross(Vector3.FORWARD)
		right = right.normalized()
		previous_right = right
		var up := right.cross(tangent).normalized()
		var ring := PackedVector3Array()
		for j in sides:
			var angle := TAU * j / sides
			ring.append(points[i] + (right*cos(angle) + up*sin(angle))*maxf(0.001, radii[i]))
		rings.append(ring)
	for i in rings.size()-1:
		for j in sides:
			var k := (j+1)%sides
			quad(st, rings[i][j], rings[i][k], rings[i+1][k], rings[i+1][j])
	for j in sides:
		triangle(st, points[0], rings[0][(j+1)%sides], rings[0][j])
	return finish(st)
