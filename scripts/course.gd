class_name CoastCourse
extends RefCounted

var points: Array[Vector3] = []
var normals: Array[Vector3] = []
var distances: Array[float] = []
var modes: Array[String] = []
var sections: Array[Dictionary] = []
var length := 0.0
var shortcuts: Array[Vector2] = []

func _init() -> void:
	section("01", "PALM RIDGE", "Find your flow.")
	curve([Vector3(0,72,70), Vector3(0,70,32), Vector3(2,57,-15), Vector3(5,34,-85), Vector3(0,18,-150), Vector3(0,18,-185)], "coast")
	section("02", "THE EMERALD LOOP", "Keep the momentum.")
	for i in range(1, 161):
		var t := TAU * i / 160.0
		var p := Vector3(8*t/TAU, 18+32*(1-cos(t)), -185-32*sin(t)-12*t/TAU)
		var tangent := Vector3(8/TAU, 32*sin(t), -32*cos(t)-12/TAU).normalized()
		append(p, Vector3.RIGHT.cross(tangent).normalized(), "loop")
	curve([points.back(), Vector3(10,19,-228), Vector3(15,25,-266)], "coast")
	section("03", "CORKSCREW SKYWAY", "A different point of view.")
	for i in range(1, 101):
		var u := i/100.0
		var t := TAU*u
		var p := Vector3(15+13*(1-cos(t)),25+18*u+13*sin(t),-266-135*u)
		var f := Vector3(13*TAU*sin(t),18+13*TAU*cos(t),-135).normalized()
		append(p, Vector3.UP.rotated(f, t), "corkscrew")
	section("04", "OCEAN EXPRESS", "Three rails. One perfect line.")
	curve([points.back(),Vector3(45,49,-443),Vector3(89,57,-487),Vector3(101,54,-542)],"rail")
	section("05", "BLUE SKY CHAIN", "Jump, then jump again to lock on.")
	curve([points.back(),Vector3(86,54,-580),Vector3(58,48,-624)], "air")
	section("06", "SUNSTONE RUINS", "Ancient stones. New shortcuts.")
	curve([points.back(),Vector3(18,34,-671),Vector3(-40,27,-710),Vector3(-98,28,-751)],"ruins")
	section("07", "TIDAL WALL", "Lean into the impossible.")
	var wall_start := points.size()
	curve([points.back(),Vector3(-122,40,-799),Vector3(-108,62,-843),Vector3(-61,79,-875),Vector3(-12,86,-909)],"wall")
	for i in range(wall_start, points.size()):
		var u := float(i-wall_start)/maxf(1, points.size()-wall_start-1)
		var f := (points[i]-points[i-1]).normalized()
		normals[i] = Vector3.UP.rotated(f, sin(PI*u)*1.38)
	curve([points.back(),Vector3(-4,93,-943)],"ramp")
	section("08", "THE GREAT CASCADE", "Take the leap.")
	curve([points.back(),Vector3(3,85,-1000),Vector3(12,68,-1058)],"waterfall")
	section("09", "HORIZON RUN", "Leave nothing in the tank.")
	curve([points.back(),Vector3(2,41,-1121),Vector3(-20,26,-1181),Vector3(0,25,-1250),Vector3(0,25,-1340)],"sprint")
	shortcuts = [Vector2(55,213),Vector2(sections[5].start+12,sections[6].start-8)]

func section(number: String, title: String, hint: String) -> void:
	sections.append({"number":number,"title":title,"hint":hint,"start":length})

func append(p: Vector3, n: Vector3, mode: String) -> void:
	if not points.is_empty():
		var step := p.distance_to(points.back())
		if step < 0.001:
			return
		length += step
	points.append(p)
	normals.append(n)
	distances.append(length)
	modes.append(mode)

func curve(knots: Array, mode: String) -> void:
	for i in knots.size()-1:
		var a: Vector3 = knots[maxi(0,i-1)]
		var b: Vector3 = knots[i]
		var c: Vector3 = knots[i+1]
		var d: Vector3 = knots[mini(knots.size()-1,i+2)]
		var count := maxi(8, ceili(b.distance_to(c)/1.6))
		for j in count:
			var t := j/float(count)
			var p := 0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
			append(p, Vector3.UP, mode)
	append(knots.back(), Vector3.UP, mode)

func index_at(s: float) -> int:
	var low := 0
	var high := distances.size()-1
	while low < high:
		var middle := (low+high+1)/2
		if distances[middle] <= s:
			low = middle
		else:
			high = middle-1
	return mini(low, points.size()-2)

func sample(s: float, branch: int = -1) -> Dictionary:
	var i := index_at(clampf(s,0,length))
	var t := clampf((s-distances[i])/(distances[i+1]-distances[i]),0,1)
	var f := (points[i+1]-points[i]).normalized()
	var n := normals[i].lerp(normals[i+1],t).normalized()
	var right := f.cross(n).normalized()
	n = right.cross(f).normalized()
	var p := points[i].lerp(points[i+1],t)
	var width := 6.5
	if branch >= 0 and branch < shortcuts.size():
		var range_s := shortcuts[branch]
		var u := clampf((s-range_s.x)/(range_s.y-range_s.x),0,1)
		var sign_x := 1.0 if branch == 0 else -1.0
		# A fork separates sideways before rising, keeping its underside clear of the main road.
		var wave := sin(PI*u)
		var rise_blend := clampf((wave*29-9.7)/7.3,0,1)
		var rise_factor := rise_blend*rise_blend*(3-2*rise_blend)
		p += right*wave*29*sign_x+n*wave*17*rise_factor
		var derivative := PI*cos(PI*u)/(range_s.y-range_s.x)
		var vertical_derivative := derivative*17*(rise_factor+wave*6*rise_blend*(1-rise_blend)*29/7.3)
		f = (f+right*derivative*29*sign_x+n*vertical_derivative).normalized()
		right = f.cross(n).normalized()
		n = right.cross(f).normalized()
		width = 3.2
	return {"p":p,"f":f,"n":n,"r":right,"basis":Basis(right,n,-f),"mode":modes[i],"width":width}

func section_at(s: float) -> int:
	for i in range(sections.size()-1,-1,-1):
		if s >= sections[i].start:
			return i
	return 0
