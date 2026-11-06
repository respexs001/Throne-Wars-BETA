class_name Minimap
extends Control
## Minimap.gd — миникарта: линии, река, постройки, герои, крипы, руны, Рошан и рамка камеры.
## Клик/касание по миникарте переносит камеру.

signal clicked(world_pos: Vector3)

var hero: BaseHero
var rig: CameraRig


func _init() -> void:
	custom_minimum_size = Vector2(170.0, 170.0)
	mouse_filter = Control.MOUSE_FILTER_STOP


var _acc: float = 0.0


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.1:
		_acc = 0.0
		queue_redraw()


func _w2m(p: Vector3) -> Vector2:
	var h := Global.MAP_HALF
	return Vector2((p.x + h) / (2.0 * h) * size.x, (p.z + h) / (2.0 * h) * size.y)


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var hit := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pos = mb.position
			hit = true
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			pos = mm.position
			hit = true
	if hit:
		var h := Global.MAP_HALF
		clicked.emit(Vector3(pos.x / size.x * 2.0 * h - h, 0.0, pos.y / size.y * 2.0 * h - h))
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.25, 0.12, 0.94))
	draw_line(_w2m(Vector3(-Global.MAP_HALF, 0.0, -Global.MAP_HALF)), _w2m(Vector3(Global.MAP_HALF, 0.0, Global.MAP_HALF)), Color(0.2, 0.45, 0.85, 0.85), 6.0)
	for lane in 3:
		var pts: Array = Global.LANES[lane]
		for i in range(pts.size() - 1):
			draw_line(_w2m(pts[i]), _w2m(pts[i + 1]), Color(0.7, 0.65, 0.5), 4.0)
	var sc := size.x / (2.0 * Global.MAP_HALF)
	for hl in Global.hills():
		draw_circle(_w2m(Vector3(float(hl[0]), 0.0, float(hl[1]))), float(hl[2]) * sc, Color(0.55, 0.48, 0.35, 0.28))
	for n in get_tree().get_nodes_in_group("runes"):
		draw_circle(_w2m((n as Node3D).global_position), 3.0, Color(1.0, 1.0, 0.6))
	for n in Global.units():
		var u := n as Unit
		if u == null or not u.alive or not u.visible:
			continue
		var p := _w2m(u.global_position)
		if u is Building:
			var half: float = 5.0 if (u as Building).is_throne else 3.0
			draw_rect(Rect2(p - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), u.team_color())
		elif u is BaseHero:
			draw_circle(p, 5.0, u.team_color())
			draw_arc(p, 5.5, 0.0, TAU, 16, Color.WHITE, 1.5)
		elif u is Creep and (u as Creep).guardian:
			draw_circle(p, 5.0, Color(0.6, 0.3, 0.7))
		else:
			draw_circle(p, 1.8, u.team_color())
	for team in 2:
		if Global.siege_waves[team] > 0:
			draw_arc(_w2m(Global.throne_pos(team)), 9.0, 0, TAU, 20, Color(0.3, 0.95, 0.85), 3.0)
	if rig != null:
		var c := _w2m(rig.global_position)
		var k := rig.distance / 70.0
		draw_rect(Rect2(c - Vector2(14.0, 9.0) * k, Vector2(28.0, 18.0) * k), Color(1.0, 1.0, 1.0, 0.8), false, 1.5)
	for pg in Global.pings:
		var age: float = Global.elapsed - float(pg[1])
		if age < 3.0:
			var col: Color = pg[2]
			draw_arc(_w2m(pg[0]), 4.0 + age * 10.0, 0.0, TAU, 20, Color(col.r, col.g, col.b, 1.0 - age / 3.0), 2.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.6), false, 2.0)
