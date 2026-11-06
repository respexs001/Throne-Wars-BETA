class_name MapBuilder
extends RefCounted
## MapBuilder.gd — процедурная детальная карта: текстурированная земля, грунтовые линии, анимированная река с мостом и берегами,
## базы (стены, казармы, фонтаны, обелиски), яма Древнего Стража, скалы по краям, лес из 6 видов деревьев, камни, трава.

const WATER_SHADER: String = """
shader_type spatial;
render_mode cull_disabled;
varying vec3 wpos;
void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float w1 = sin(wpos.x * 0.12 + TIME * 1.2) * sin(wpos.z * 0.14 - TIME * 0.9);
    float w2 = sin((wpos.x + wpos.z) * 0.3 + TIME * 2.0);
    float k = clamp(0.5 + 0.25 * w1 + 0.15 * w2, 0.0, 1.0);
    vec3 deep = vec3(0.03, 0.3, 0.4);
    vec3 shallow = vec3(0.25, 0.64, 0.7);
    ALBEDO = mix(deep, shallow, k);
    ALPHA = 0.9;
    ROUGHNESS = 0.12;
    SPECULAR = 0.8;
    EMISSION = vec3(0.02, 0.07, 0.1) * (0.6 + w2);
}
"""


static var _b: Dictionary = {}
static var _canopy_material: ShaderMaterial


static func build(root: Node3D) -> Dictionary:
	_b = Biome.cfg(Global.biome)
	_canopy_material = ShaderMaterial.new()
	_canopy_material.shader = preload("res://Shaders/tree_canopy.gdshader")
	Global.terrain_amp = float(_b["amp"])
	Global.bake_terrain()
	var out: Dictionary = {"flames": [], "river": null}
	_ground(root)
	_lanes(root)
	_river(root, out)
	_bases(root, out)
	_guardian_pit(root, out)
	_rune_spots(root)
	_border(root)
	_forest(root)
	RenewalArt.decorate(root)
	return out


# ---------- помощники ----------
static func _tex(c1: Color, c2: Color, freq: float, sd: int, size: int = 512) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.seed = sd
	n.fractal_octaves = 4
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	var t := NoiseTexture2D.new()
	t.noise = n
	t.color_ramp = g
	t.width = size
	t.height = size
	t.seamless = true
	return t


static var _ncache: Dictionary = {}


static func _ntex(freq: float) -> NoiseTexture2D:
	var key := str(freq)
	if _ncache.has(key):
		return _ncache[key]
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = freq * 0.05
	n.seed = 303
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 6.0
	_ncache[key] = t
	return t


static func _tmat(tex: Texture2D, scale: float, triplanar: bool, nfreq: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.95
	if nfreq > 0.0:
		m.normal_enabled = true
		m.normal_texture = _ntex(nfreq)
		m.normal_scale = 0.8
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(scale, scale, scale)
	else:
		m.uv1_scale = Vector3(scale, scale, 1.0)
	return m


static func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	root.add_child(mi)
	return mi


static func _cyl(root: Node3D, top: float, bottom: float, h: float, pos: Vector3, mat: Material, segs: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	return mi


static func _ring(root: Node3D, radius: float, thick: float, pos: Vector3, color: Color, glow: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - thick
	tm.outer_radius = radius
	tm.rings = 32
	mi.mesh = tm
	mi.material_override = Global.get_mat(color, glow)
	mi.position = pos
	root.add_child(mi)
	return mi


static func _torch(root: Node3D, pos: Vector3, out: Dictionary) -> void:
	_cyl(root, 0.18, 0.25, 3.0, pos + Vector3(0.0, 1.5, 0.0), Global.get_mat(Color(0.3, 0.2, 0.12)), 6)
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	mi.material_override = Global.get_mat(Color(1.0, 0.6, 0.15), 3.0)
	mi.position = pos + Vector3(0.0, 3.3, 0.0)
	root.add_child(mi)
	(out["flames"] as Array).append(mi)


# ---------- земля, линии, река ----------
static func _ground(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = Vector3(0.0, -0.5, 0.0)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(Global.MAP_HALF * 2.0 + 120.0, 1.0, Global.MAP_HALF * 2.0 + 120.0)
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)
	var terrain := _terrain_mesh()
	var ts := CollisionShape3D.new()
	ts.shape = terrain.create_trimesh_shape()
	ts.position = Vector3(0.0, 0.5, 0.0)
	body.add_child(ts)
	var mi := MeshInstance3D.new()
	mi.mesh = terrain
	var gm := _tmat(_tex(_b["detail_a"], _b["detail_b"], 0.014, 11), 22.0, false, 10.0)
	gm.vertex_color_use_as_albedo = true
	mi.material_override = gm
	root.add_child(mi)


static func _near_lane(p: Vector3, d: float) -> bool:
	for lane in 3:
		var pts: Array = Global.LANES[lane]
		for i in range(pts.size() - 1):
			if Global.dist_to_segment(p, pts[i], pts[i + 1]) < d:
				return true
	return false


static func _near_base(p: Vector3, d: float) -> bool:
	return Global.flat_dist(p, Global.throne_pos(0)) < d or Global.flat_dist(p, Global.throne_pos(1)) < d


static func _lanes(root: Node3D) -> void:
	var dirt := _tmat(load("res://assets/renewal/slate.svg"), 0.025, true)
	dirt.albedo_color = Color(0.48, 0.57, 0.59)
	var edge := _tmat(_tex((_b["dirt_a"] as Color).darkened(0.35), (_b["dirt_b"] as Color).darkened(0.35), 0.05, 32, 256), 0.05, true)
	for lane in 3:
		var pts: Array = Global.LANES[lane]
		for i in range(pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var d := b - a
			var rot := atan2(d.x, d.z)
			_box(root, Vector3(Global.LANE_WIDTH + 5.0, 0.08, d.length()), (a + b) * 0.5 + Vector3(0.0, 0.04, 0.0), edge, rot)
			_box(root, Vector3(Global.LANE_WIDTH, 0.12, d.length()), (a + b) * 0.5 + Vector3(0.0, 0.06, 0.0), dirt, rot)
		for p in pts:
			_cyl(root, Global.LANE_WIDTH * 0.5 + 2.5, Global.LANE_WIDTH * 0.5 + 2.5, 0.08, (p as Vector3) + Vector3(0.0, 0.04, 0.0), edge, 20)
			_cyl(root, Global.LANE_WIDTH * 0.5, Global.LANE_WIDTH * 0.5, 0.12, (p as Vector3) + Vector3(0.0, 0.06, 0.0), dirt, 20)


static func _river(root: Node3D, out: Dictionary) -> void:
	var shore: Color = _b["shore"]
	var sand := _tmat(_tex(shore, shore.lightened(0.15), 0.04, 41), 0.04, true)
	var bank := _box(root, Vector3(1250.0, 0.1, 52.0), Vector3(0.0, 0.08, 0.0), sand, -PI / 4.0)
	bank.name = "RiverBank"
	var sh := Shader.new()
	sh.code = WATER_SHADER2
	var wm := ShaderMaterial.new()
	wm.shader = sh
	wm.set_shader_parameter("deep", _b["water_deep"])
	wm.set_shader_parameter("shallow", _b["water_shallow"])
	wm.set_shader_parameter("alpha", float(_b["water_alpha"]))
	wm.set_shader_parameter("glow", float(_b["water_glow"]))
	wm.set_shader_parameter("speed", float(_b["water_speed"]))
	var water := _box(root, Vector3(1250.0, 0.2, 36.0), Vector3(0.0, 0.14, 0.0), wm, -PI / 4.0)
	water.name = "River"
	out["river"] = wm
	# мост на центральной линии
	var wood := _tmat(_tex(Color(0.3, 0.2, 0.1), Color(0.5, 0.35, 0.18), 0.08, 51, 256), 0.08, true)
	var dir := Vector3(1.0, 0.0, -1.0).normalized()
	var rot := atan2(dir.x, dir.z)
	_box(root, Vector3(Global.LANE_WIDTH * 0.9, 0.9, 62.0), Vector3(0.0, 0.5, 0.0), wood, rot)
	for sx in [-1.0, 1.0]:
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x) * float(sx) * Global.LANE_WIDTH * 0.42
		_box(root, Vector3(0.8, 1.6, 62.0), side + Vector3(0.0, 1.4, 0.0), wood, rot)
		for k in range(-3, 4):
			var post := side + dir * float(k) * 9.0
			_box(root, Vector3(1.0, 3.0, 1.0), post + Vector3(0.0, 1.5, 0.0), wood, rot)


# ---------- базы ----------
static func _bases(root: Node3D, out: Dictionary) -> void:
	# Свет: белый мрамор с золотом. Тьма: чёрный обсидиан с багровыми знаками.
	var marble := _tmat(_tex(Color(0.7, 0.7, 0.72), Color(0.93, 0.91, 0.86), 0.04, 101, 256), 0.04, true, 5.0)
	var obsidian := _tmat(_tex(Color(0.08, 0.07, 0.1), Color(0.24, 0.2, 0.26), 0.05, 102, 256), 0.04, true, 5.0)
	for t in [0, 1]:
		var c := Global.throne_pos(t)
		var f := Global.forward(t)
		var mat: Material = marble if t == 0 else obsidian
		var trim: Color = Color(1.0, 0.82, 0.35) if t == 0 else Color(0.95, 0.2, 0.2)
		var trim_mat := Global.get_mat(trim, 0.8)
		var base_a := atan2(-f.z, -f.x)
		# восьмигранный двор и ступенчатый постамент
		_cyl(root, 52.0, 52.0, 0.3, c + Vector3(0.0, 0.15, 0.0), mat, 8)
		_cyl(root, 30.0, 32.0, 1.0, c + Vector3(0.0, 0.6, 0.0), mat, 8)
		_cyl(root, 22.0, 24.0, 1.0, c + Vector3(0.0, 1.6, 0.0), mat, 8)
		_ring(root, 31.0, 0.6, c + Vector3(0.0, 1.2, 0.0), trim, 1.0)
		# дорожка от ворот к трону
		var path := Vector3(f.x, 0.0, f.z)
		_box(root, Vector3(7.0, 0.12, 52.0), c + path * 40.0 + Vector3(0.0, 0.36, 0.0), trim_mat, atan2(path.x, path.z))
		# внешняя стена-подкова: 14 секций, спереди проход
		for k in 15:
			var a2 := base_a + deg_to_rad(-105.0 + 15.0 * float(k))
			var p := c + Vector3(cos(a2), 0.0, sin(a2)) * 64.0
			if absf(p.x) > Global.MAP_HALF + 6.0 or absf(p.z) > Global.MAP_HALF + 6.0:
				continue
			var th := atan2(-cos(a2), -sin(a2))
			_box(root, Vector3(16.5, 9.0, 3.0), p + Vector3(0.0, 4.5, 0.0), mat, th)
			for m in 3:
				_box(root, Vector3(3.0, 1.6, 3.4), p + Vector3(0.0, 9.8, 0.0) + Vector3(cos(th), 0.0, -sin(th)) * (float(m) - 1.0) * 5.2, mat, th)
		# башенки по краям подковы и колонны ворот
		for end in [-1.0, 1.0]:
			var ea := base_a + deg_to_rad(105.0) * float(end)
			var tp := c + Vector3(cos(ea), 0.0, sin(ea)) * 64.0
			_cyl(root, 4.2, 5.0, 16.0, tp + Vector3(0.0, 8.0, 0.0), mat, 10)
			_cyl(root, 0.0, 6.0, 5.0, tp + Vector3(0.0, 18.5, 0.0), Global.get_mat(trim.darkened(0.5)), 10)
			_torch(root, tp + Vector3(0.0, 15.0, 0.0), out)
			Global.add_obstacle(tp, 5.0)
			var ga := base_a + deg_to_rad(105.0) * float(end) * 0.0 + PI * 0.0
			var gate := c + f * 64.0 + Vector3(-f.z, 0.0, f.x) * 11.0 * float(end)
			_box(root, Vector3(3.2, 14.0, 3.2), gate + Vector3(0.0, 7.0, 0.0), mat)
			_box(root, Vector3(0.5, 5.0, 3.0), gate + Vector3(0.0, 11.0, 0.0), trim_mat)
			Global.add_obstacle(gate, 2.4)
		_box(root, Vector3(26.0, 2.2, 3.2), c + f * 64.0 + Vector3(0.0, 13.5, 0.0), mat, atan2(f.x, f.z) + PI / 2.0)
		# статуи героев вокруг постамента
		for k in 4:
			var sa := TAU / 4.0 * float(k) + PI / 4.0
			var sp := c + Vector3(cos(sa), 0.0, sin(sa)) * 38.0
			_box(root, Vector3(4.0, 3.0, 4.0), sp + Vector3(0.0, 1.5, 0.0), mat)
			var body := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 1.0
			cap.height = 5.0
			body.mesh = cap
			body.material_override = Global.get_mat(trim.darkened(0.3))
			body.position = sp + Vector3(0.0, 5.5, 0.0)
			root.add_child(body)
			Global.add_obstacle(sp, 2.2)
		# жаровни
		for k in 6:
			var ba := TAU / 6.0 * float(k)
			_torch(root, c + Vector3(cos(ba), 0.0, sin(ba)) * 27.0 + Vector3(0.0, 2.0, 0.0), out)
		# фонтан-пруд перед ступенями
		var fp := Global.fountain_pos(t)
		_cyl(root, 11.0, 12.0, 0.8, fp + Vector3(0.0, 0.4, 0.0), mat, 20)
		_cyl(root, 9.5, 9.5, 0.85, fp + Vector3(0.0, 0.45, 0.0), Global.get_mat(Color(0.2, 0.6, 0.85), 0.8), 20)
		_cyl(root, 1.2, 1.8, 5.0, fp + Vector3(0.0, 2.5, 0.0), mat, 10)
		# залы по бокам двора (декор)
		for ang in [-1.0, 1.0]:
			var d: Vector3 = f.rotated(Vector3.UP, float(ang))
			var bp := c + d * 48.0
			var rot := atan2(d.x, d.z)
			_box(root, Vector3(20.0, 7.0, 10.0), bp + Vector3(0.0, 3.5, 0.0), mat, rot)
			var roof := _cyl(root, 0.0, 12.0, 5.5, bp + Vector3(0.0, 9.7, 0.0), Global.get_mat(trim.darkened(0.55)), 4)
			roof.rotation.y = rot + PI / 4.0
			roof.scale = Vector3(1.0, 1.0, 0.55)
			Global.add_obstacle(bp, 8.0)


static func _guardian_pit(root: Node3D, out: Dictionary) -> void:
	var c := Global.GUARDIAN_POS
	var rock := _tmat(_tex(Color(0.2, 0.18, 0.2), Color(0.38, 0.34, 0.38), 0.05, 71, 256), 0.05, true)
	_cyl(root, 34.0, 34.0, 0.2, c + Vector3(0.0, 0.1, 0.0), Global.get_mat(Color(0.1, 0.08, 0.1)), 32)
	_ring(root, 33.0, 1.0, c + Vector3(0.0, 0.3, 0.0), Color(1.0, 0.25, 0.15), 1.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 14:
		var a := TAU / 14.0 * float(k)
		var p := c + Vector3(cos(a), 0.0, sin(a)) * 36.0
		var h := rng.randf_range(6.0, 12.0)
		_box(root, Vector3(3.2, h, 3.2), p + Vector3(0.0, h * 0.5, 0.0), rock, a + rng.randf_range(-0.3, 0.3))
	for k in 16:
		var bp := c + Vector3(rng.randf_range(-24.0, 24.0), 0.4, rng.randf_range(-24.0, 24.0))
		var bone := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = rng.randf_range(0.5, 1.2)
		s.height = s.radius * 1.6
		bone.mesh = s
		bone.material_override = Global.get_mat(Color(0.9, 0.88, 0.8))
		bone.position = bp
		root.add_child(bone)
	for k in 4:
		_torch(root, c + Vector3(cos(TAU / 4.0 * float(k) + PI / 4.0), 0.0, sin(TAU / 4.0 * float(k) + PI / 4.0)) * 40.0, out)


static func _rune_spots(root: Node3D) -> void:
	var stone := Global.get_mat(Color(0.45, 0.45, 0.55))
	for p in Global.RUNE_SPOTS:
		var pos: Vector3 = p
		_cyl(root, 9.0, 9.0, 0.3, pos + Vector3(0.0, 0.25, 0.0), stone, 20)
		_ring(root, 8.5, 0.5, pos + Vector3(0.0, 0.5, 0.0), Color(0.7, 0.9, 1.0), 1.6)
	for p in Global.BOUNTY_SPOTS:
		for q in [p, Global.mirror(p)]:
			var pos2: Vector3 = q
			_cyl(root, 5.0, 5.0, 0.25, pos2 + Vector3(0.0, 0.2, 0.0), stone, 16)
			_ring(root, 4.6, 0.4, pos2 + Vector3(0.0, 0.4, 0.0), Color(1.0, 0.85, 0.3), 1.4)


static func _border(root: Node3D) -> void:
	var rock := _tmat(_tex(_b["rock_a"], _b["rock_b"], 0.04, 81, 256), 0.04, true, 8.0)
	var h := Global.MAP_HALF
	_box(root, Vector3(h * 2.0 + 240.0, 18.0, 60.0), Vector3(0.0, 9.0, -h - 30.0), rock)
	_box(root, Vector3(h * 2.0 + 240.0, 18.0, 60.0), Vector3(0.0, 9.0, h + 30.0), rock)
	_box(root, Vector3(60.0, 18.0, h * 2.0 + 240.0), Vector3(-h - 30.0, 9.0, 0.0), rock)
	_box(root, Vector3(60.0, 18.0, h * 2.0 + 240.0), Vector3(h + 30.0, 9.0, 0.0), rock)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 110:
		var side := rng.randi() % 4
		var t := rng.randf_range(-h, h)
		var p := Vector3.ZERO
		match side:
			0: p = Vector3(t, 0.0, -h - 4.0)
			1: p = Vector3(t, 0.0, h + 4.0)
			2: p = Vector3(-h - 4.0, 0.0, t)
			_: p = Vector3(h + 4.0, 0.0, t)
		var sz := Vector3(rng.randf_range(8.0, 22.0), rng.randf_range(10.0, 28.0), rng.randf_range(8.0, 22.0))
		var mi := _box(root, sz, p + Vector3(0.0, sz.y * 0.4, 0.0), rock, rng.randf() * TAU)
		mi.rotation.x = rng.randf_range(-0.25, 0.25)
		mi.rotation.z = rng.randf_range(-0.25, 0.25)


# ---------- лес, камни, трава, реквизит (по чанкам: невидимые участки не рисуются) ----------
const CHUNK: float = 150.0


static func _mm(root: Node3D, mesh: Mesh, count: int, mat: Material = null) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		mmi.material_override = m
	else:
		mmi.material_override = mat
	root.add_child(mmi)
	return mm


static func _cyl_mesh(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _cone(r: float, h: float, seg: int) -> CylinderMesh:
	return _cyl_mesh(0.0, r, h, seg)


static func _sphere_mesh(r: float, hh: float, seg: int, rings: int) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = hh
	s.radial_segments = seg
	s.rings = rings
	return s


static func _group(points: Array) -> Dictionary:
	var out: Dictionary = {}
	for p in points:
		var k := Vector2i(floori(float(p.x) / CHUNK), floori(float(p.z) / CHUNK))
		if not out.has(k):
			out[k] = []
		(out[k] as Array).append(p)
	return out


static func _forest_ok(p: Vector3) -> bool:
	if absf(p.x) > Global.MAP_HALF - 6.0 or absf(p.z) > Global.MAP_HALF - 6.0:
		return false
	if _near_base(p, 125.0):
		return false
	if absf(p.z - p.x) / 1.4142 < 26.0:
		return false
	if Global.flat_dist(p, Global.GUARDIAN_POS) < 48.0:
		return false
	if _near_lane(p, Global.LANE_WIDTH * 0.5 + 8.0):
		return false
	for c in Global.CAMP_DEFS:
		if Global.flat_dist(p, c) < 26.0 or Global.flat_dist(p, Global.mirror(c)) < 26.0:
			return false
	for r in Global.RUNE_SPOTS:
		if Global.flat_dist(p, r) < 16.0:
			return false
	for bs in Global.BOUNTY_SPOTS:
		if Global.flat_dist(p, bs) < 12.0 or Global.flat_dist(p, Global.mirror(bs)) < 12.0:
			return false
	return true


static func _rand_point(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randf_range(-Global.MAP_HALF, Global.MAP_HALF), 0.0, rng.randf_range(-Global.MAP_HALF, Global.MAP_HALF))


static func _forest(root: Node3D) -> void:
	var touch := Global.is_touch()
	var qm: float = float([0.4, 0.7, 1.0, 1.6][clampi(Global.quality, 0, 3)]) * (0.6 if touch else 1.0) * float(_b["density"])
	var n_trees := int(1100.0 * qm)
	var n_rock := int(260.0 * minf(qm, 1.6))
	var n_grass := int(1500.0 * minf(qm, 1.6))
	var n_prop := int(float(_b["prop_count"]) * (0.4 + 0.6 * minf(qm, 1.6)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.012
	# --- деревья ---
	var pines: Array = []
	var rounds: Array = []
	var tries := 0
	while pines.size() + rounds.size() < n_trees and tries < 40000:
		tries += 1
		var p := _rand_point(rng)
		if noise.get_noise_2d(p.x, p.z) < -0.1 and rng.randf() < 0.75:
			continue
		if not _forest_ok(p):
			continue
		var ph := Vector3(p.x, Global.height_at(p.x, p.z), p.z)
		if rng.randf() < float(_b["pine_ratio"]):
			pines.append(ph)
		else:
			rounds.append(ph)
	var pm: Array = [_cyl_mesh(0.45, 0.75, 3.2, 6), _cone(3.8, 5.5, 7), _cone(2.9, 5.0, 7), _cone(2.0, 4.5, 7)]
	var pg := _group(pines)
	for k in pg:
		_build_pines(root, pg[k], rng, pm)
	var rm: Array = [_cyl_mesh(0.5, 0.9, 4.5, 6), _sphere_mesh(3.4, 5.6, 8, 5)]
	var rg := _group(rounds)
	for k in rg:
		_build_rounds(root, rg[k], rng, rm)
	# --- камни ---
	var rocks: Array = []
	var guard := 0
	while rocks.size() < n_rock and guard < 20000:
		guard += 1
		var p2 := _rand_point(rng)
		if _near_base(p2, 110.0) or _near_lane(p2, Global.LANE_WIDTH * 0.5 + 3.0) or absf(p2.z - p2.x) / 1.4142 < 20.0:
			continue
		rocks.append(Vector3(p2.x, Global.height_at(p2.x, p2.z), p2.z))
	var rkm := _sphere_mesh(1.5, 2.4, 7, 4)
	var rkg := _group(rocks)
	for k in rkg:
		_build_rocks(root, rkg[k], rng, rkm)
	# --- трава ---
	var grass: Array = []
	guard = 0
	while grass.size() < n_grass and guard < 30000:
		guard += 1
		var p3 := _rand_point(rng)
		if _near_base(p3, 100.0) or _near_lane(p3, Global.LANE_WIDTH * 0.5 + 1.0) or absf(p3.z - p3.x) / 1.4142 < 19.0:
			continue
		grass.append(Vector3(p3.x, Global.height_at(p3.x, p3.z), p3.z))
	var gm := _cone(0.55, 1.7, 5)
	var gg := _group(grass)
	for k in gg:
		_build_grass(root, gg[k], rng, gm)
	# --- реквизит ландшафта (кусты, кактусы, кристаллы, лава, тростник) ---
	var props: Array = []
	guard = 0
	while props.size() < n_prop and guard < 20000:
		guard += 1
		var p4 := _rand_point(rng)
		if _forest_ok(p4):
			props.append(Vector3(p4.x, Global.height_at(p4.x, p4.z), p4.z))
	var prg := _group(props)
	for k in prg:
		_build_props(root, prg[k], rng, String(_b["prop"]))


static func _build_pines(root: Node3D, pts: Array, rng: RandomNumberGenerator, meshes: Array) -> void:
	var mt := _mm(root, meshes[0], pts.size())
	var m1 := _mm(root, meshes[1], pts.size(), _canopy_material)
	var m2 := _mm(root, meshes[2], pts.size(), _canopy_material)
	var m3 := _mm(root, meshes[3], pts.size(), _canopy_material)
	var ca: Color = _b["pine_a"]
	var cb: Color = _b["pine_b"]
	var trunk: Color = _b["trunk"]
	for i in pts.size():
		var p: Vector3 = pts[i]
		var s := rng.randf_range(1.0, 1.9)
		var bas := Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)).scaled(Vector3(s, s, s))
		var green := ca.lerp(cb, rng.randf())
		Global.add_obstacle(p, 0.5 * s)
		mt.set_instance_transform(i, Transform3D(bas, p + Vector3(0.0, 1.6 * s, 0.0)))
		mt.set_instance_color(i, trunk)
		m1.set_instance_transform(i, Transform3D(bas, p + Vector3(0.0, 4.6 * s, 0.0)))
		m1.set_instance_color(i, green)
		m2.set_instance_transform(i, Transform3D(bas, p + Vector3(0.0, 7.4 * s, 0.0)))
		m2.set_instance_color(i, green.lightened(0.05))
		m3.set_instance_transform(i, Transform3D(bas, p + Vector3(0.0, 9.9 * s, 0.0)))
		m3.set_instance_color(i, green.lightened(0.1))


static func _build_rounds(root: Node3D, pts: Array, rng: RandomNumberGenerator, meshes: Array) -> void:
	var mt := _mm(root, meshes[0], pts.size())
	var mc := _mm(root, meshes[1], pts.size(), _canopy_material)
	var ca: Color = _b["round_a"]
	var cb: Color = _b["round_b"]
	var alt: Color = _b["round_alt"]
	var trunk: Color = _b["trunk"]
	for i in pts.size():
		var p: Vector3 = pts[i]
		var s := rng.randf_range(1.0, 1.7)
		var bas := Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)).scaled(Vector3(s, s, s))
		var crown := ca.lerp(cb, rng.randf())
		if rng.randf() < 0.22:
			crown = alt
		Global.add_obstacle(p, 0.7 * s)
		mt.set_instance_transform(i, Transform3D(bas, p + Vector3(0.0, 2.2 * s, 0.0)))
		mt.set_instance_color(i, trunk)
		mc.set_instance_transform(i, Transform3D(bas, p + Vector3(0.0, 6.4 * s, 0.0)))
		mc.set_instance_color(i, crown)


static func _build_rocks(root: Node3D, pts: Array, rng: RandomNumberGenerator, mesh: Mesh) -> void:
	var mm := _mm(root, mesh, pts.size())
	var ta: Color = _b["rock_tint_a"]
	var tb: Color = _b["rock_tint_b"]
	for i in pts.size():
		var p: Vector3 = pts[i]
		var s := rng.randf_range(0.6, 2.6)
		var bas := Basis.from_euler(Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)).scaled(Vector3(s * 1.3, s * 0.85, s))
		Global.add_obstacle(p, 1.0 * s)
		mm.set_instance_transform(i, Transform3D(bas, p + Vector3(0.0, 0.5 * s, 0.0)))
		mm.set_instance_color(i, ta.lerp(tb, rng.randf()))


static func _build_grass(root: Node3D, pts: Array, rng: RandomNumberGenerator, mesh: Mesh) -> void:
	var mm := _mm(root, mesh, pts.size())
	var ca: Color = _b["grass_a"]
	var cb: Color = _b["grass_b"]
	for i in pts.size():
		var p: Vector3 = pts[i]
		var s := rng.randf_range(0.7, 1.6)
		mm.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)).scaled(Vector3(s, s, s)), p + Vector3(0.0, 0.8 * s, 0.0)))
		mm.set_instance_color(i, ca.lerp(cb, rng.randf()))


static func _build_props(root: Node3D, pts: Array, rng: RandomNumberGenerator, kind: String) -> void:
	var mesh: Mesh
	var yoff := 1.0
	var tall := 1.0
	match kind:
		"cactus":
			mesh = _cyl_mesh(0.6, 0.8, 5.0, 6)
			yoff = 2.5
		"crystal":
			mesh = _cone(1.0, 4.0, 5)
			yoff = 2.0
		"lava":
			mesh = _sphere_mesh(1.3, 2.2, 7, 4)
			yoff = 0.5
		"reed":
			mesh = _cone(0.25, 3.5, 4)
			yoff = 1.7
			tall = 1.3
		_:
			mesh = _sphere_mesh(1.2, 2.0, 6, 4)
			yoff = 0.9
	var col: Color = _b["prop_color"]
	var glow := float(_b["prop_glow"])
	var mat: Material = null
	if glow > 0.0:
		var gmat := StandardMaterial3D.new()
		gmat.vertex_color_use_as_albedo = true
		gmat.emission_enabled = true
		gmat.emission = col
		gmat.emission_energy_multiplier = glow
		mat = gmat
	var mm := _mm(root, mesh, pts.size(), mat)
	for i in pts.size():
		var p: Vector3 = pts[i]
		var s := rng.randf_range(0.7, 1.6)
		var bas := Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)).scaled(Vector3(s, s * tall, s))
		if kind != "reed" and kind != "bush":
			Global.add_obstacle(p, 0.8 * s)
		mm.set_instance_transform(i, Transform3D(bas, p + Vector3(0.0, yoff * s * tall, 0.0)))
		mm.set_instance_color(i, col.lerp(col.lightened(0.25), rng.randf()))


# ---------- рельеф с окраской вершин: трава, грунт у линий, берег реки, скалы на склонах, камень у баз ----------
static func _lane_dist(p: Vector3) -> float:
	var d := 1e9
	for lane in Global.LANES:
		var pts: Array = lane
		for i in range(pts.size() - 1):
			d = minf(d, Global.dist_to_segment(p, pts[i], pts[i + 1]))
	return d


static func _terrain_mesh() -> ArrayMesh:
	var size := Global.MAP_HALF * 2.0 + 120.0
	var n := Global.HM_N - 1
	var noise := FastNoiseLite.new()
	noise.seed = 21
	noise.frequency = 0.03
	var noise2 := FastNoiseLite.new()
	noise2.seed = 33
	noise2.frequency = 0.12
	var ga: Color = _b["ground_a"]
	var gb: Color = _b["ground_b"]
	var dirt: Color = (_b["dirt_a"] as Color).lerp(_b["dirt_b"], 0.5)
	var shore: Color = _b["shore"]
	var rock: Color = _b["rock"]
	var stone := Color(0.45, 0.45, 0.48)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in n + 1:
		for ix in n + 1:
			var x := -size * 0.5 + size * float(ix) / float(n)
			var z := -size * 0.5 + size * float(iz) / float(n)
			var h := Global.height_at(x, z)
			var col := ga.lerp(gb, noise.get_noise_2d(x, z) * 0.5 + 0.5)
			col = col.darkened(0.14 * (noise2.get_noise_2d(x, z) * 0.5 + 0.5))
			var p := Vector3(x, 0.0, z)
			col = col.lerp(dirt, 1.0 - smoothstep(Global.LANE_WIDTH * 0.5, Global.LANE_WIDTH * 0.5 + 14.0, _lane_dist(p)))
			col = col.lerp(shore, 1.0 - smoothstep(18.0, 34.0, absf(z - x) / 1.4142))
			col = col.lerp(rock, smoothstep(2.0, 8.0, h))
			var db := minf(Global.flat_dist(p, Global.throne_pos(0)), Global.flat_dist(p, Global.throne_pos(1)))
			col = col.lerp(stone, 1.0 - smoothstep(60.0, 110.0, db))
			st.set_color(col)
			st.set_uv(Vector2(float(ix) / float(n), float(iz) / float(n)))
			st.add_vertex(Vector3(x, h, z))
	for iz in n:
		for ix in n:
			var a := iz * (n + 1) + ix
			var b := a + 1
			var c := a + n + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(d)
			st.add_index(a)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	return st.commit()


const WATER_SHADER2: String = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 deep : source_color = vec4(0.03, 0.3, 0.4, 1.0);
uniform vec4 shallow : source_color = vec4(0.25, 0.64, 0.7, 1.0);
uniform float alpha = 0.9;
uniform float glow = 0.0;
uniform float speed = 1.0;
varying vec3 wpos;
void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float t = TIME * speed;
    float w1 = sin(wpos.x * 0.12 + t * 1.2) * sin(wpos.z * 0.14 - t * 0.9);
    float w2 = sin((wpos.x + wpos.z) * 0.3 + t * 2.0);
    float w3 = sin(wpos.x * 0.7 - t * 1.7) * sin(wpos.z * 0.6 + t * 1.3);
    float k = clamp(0.5 + 0.22 * w1 + 0.12 * w2 + 0.06 * w3, 0.0, 1.0);
    vec3 col = mix(deep.rgb, shallow.rgb, k);
    float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
    ALBEDO = col + vec3(0.25) * fres;
    ALPHA = alpha;
    ROUGHNESS = 0.1;
    SPECULAR = 0.9;
    EMISSION = col * glow * (0.5 + 0.5 * w2) + vec3(0.02, 0.06, 0.08) * (0.6 + w2) * (1.0 - clamp(glow, 0.0, 1.0));
}
"""

static func update_canopy_focus(position: Vector3) -> void:
	if _canopy_material != null:
		_canopy_material.set_shader_parameter("focus_position", position)
