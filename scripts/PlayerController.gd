class_name PlayerController
extends Node
## PlayerController.gd — улучшенное MOBA-управление (PC & Touch с защитой от случайных кастов).

var hero: BaseHero
var cam: Camera3D
var rig: CameraRig

# --- Состояние прицеливания и режимов ---
var targeting: int = -1
var item_targeting: int = -1
var amove_mode: bool = false
var joy: TouchJoystick = null
var _joy_moving: bool = false

var _held_key: int = -1
var _held_item: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _aim_pos: Vector3 = Vector3.ZERO
var _aim_active: bool = false

# --- Защита от случайных тапов (Инспекция предметов и скиллов) ---
var _last_ab_tapped: int = -1
var _ab_tap_time: float = 0.0
var _last_item_tapped: int = -1
var _item_tap_time: float = 0.0

# --- Визуальные индикаторы прицеливания ---
var _ring: MeshInstance3D
var _aoe: MeshInstance3D
var _line: MeshInstance3D
var _click_fx: MeshInstance3D
var _click_tween: Tween


func _ready() -> void:
	_ring = _create_indicator_mesh(TorusMesh.new(), Color(0.2, 0.8, 1.0, 0.6))
	_aoe = _create_indicator_mesh(CylinderMesh.new(), Color(1.0, 0.3, 0.2, 0.25))
	_line = _create_indicator_mesh(BoxMesh.new(), Color(1.0, 0.85, 0.2, 0.35))
	_click_fx = _create_click_fx_mesh()


# ---------- Создание 3D Индикаторов ----------
func _indicator_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _create_indicator_mesh(mesh_type: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if mesh_type is TorusMesh:
		mesh_type.inner_radius = 0.98
		mesh_type.outer_radius = 1.0
		mesh_type.rings = 32
	elif mesh_type is CylinderMesh:
		mesh_type.top_radius = 1.0
		mesh_type.bottom_radius = 1.0
		mesh_type.height = 0.02
	elif mesh_type is BoxMesh:
		mesh_type.size = Vector3(1.0, 0.02, 1.0)
		
	mi.mesh = mesh_type
	mi.material_override = _indicator_mat(color)
	mi.visible = false
	add_child(mi)
	return mi


func _create_click_fx_mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 1.0
	mi.mesh = tm
	mi.material_override = _indicator_mat(Color(0.2, 1.0, 0.4, 0.8))
	mi.visible = false
	add_child(mi)
	return mi


func _spawn_click_marker(pos: Vector3, is_attack: bool = false) -> void:
	if _click_tween and _click_tween.is_running():
		_click_tween.kill()
		
	var mat = _click_fx.material_override as StandardMaterial3D
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.8) if is_attack else Color(0.2, 1.0, 0.4, 0.8)
	
	_click_fx.global_position = pos + Vector3(0.0, 0.08, 0.0)
	_click_fx.scale = Vector3(1.2, 1.2, 1.2)
	_click_fx.visible = true
	
	_click_tween = create_tween().set_parallel(true)
	_click_tween.tween_property(_click_fx, "scale", Vector3(0.2, 0.2, 0.2), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_click_tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	_click_tween.chain().tween_callback(func(): _click_fx.visible = false)


# ---------- Ввод (Мышь / Касания) ----------
func _unhandled_input(event: InputEvent) -> void:
	if Global.is_over or hero == null:
		return
		
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		var phrases: Array = ["Вперёд!", "Держим линию!", "Ха-ха!", "Нужна помощь!", "Отступаем!", "Хорошая игра!"]
		Global.float_text(hero.global_position + Vector3(0.0, hero.hp_bar_height + 3.0, 0.0), phrases[randi() % phrases.size()], Color(1.0, 1.0, 0.7), 1.5)
		return

	if not (event is InputEventMouseButton):
		return
		
	var mb := event as InputEventMouseButton
	if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return

	if Global.is_touch():
		if mb.pressed:
			_press_pos = mb.position
			_pressing = true
			Global.pinch_latch = false
		elif _pressing:
			_pressing = false
			if not Global.pinch_latch and mb.position.distance_to(_press_pos) < 24.0:
				_handle_tap(mb.position)
		return

	if not mb.pressed:
		return
		
	if mb.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_ALT):
		var gp := _ground_at(mb.position)
		Global.ping(gp, Color(1.0, 1.0, 1.0))
		Global.float_text(gp + Vector3(0.0, 4.0, 0.0), "!", Color(1.0, 1.0, 0.5), 2.0)
		Global.say("Пинг на карте")
		return

	if mb.button_index == MOUSE_BUTTON_RIGHT:
		if cancel_modes():
			return
		_command_at(mb.position, Input.is_key_pressed(KEY_SHIFT))
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		if _confirm(mb.position):
			return
		var hit := _ray(3, mb.position)
		if not hit.is_empty():
			var u := hit["collider"] as Unit
			Global.selected_unit = u if (u != null and u.alive and u.visible) else null


func _handle_tap(m: Vector2) -> void:
	if _confirm(m):
		return
	var hit := _ray(3, m)
	if not hit.is_empty():
		var u := hit["collider"] as Unit
		if u != null and u.alive and u.visible:
			Global.selected_unit = u
			if u == hero or _is_my_illusion(u):
				return
	_command_at(m, false)


func _command_at(m: Vector2, queued: bool) -> void:
	var hit := _ray(3, m)
	if not hit.is_empty():
		var u := hit["collider"] as Unit
		if u != null and u.alive and u.visible and u != hero:
			var deny := u.team == hero.team and u is Creep and u.hp < u.max_hp * 0.5
			if u.team != hero.team or deny:
				_spawn_click_marker(u.global_position, true)
				_o_attack(u)
				return
				
	var g := _ray(1, m)
	if not g.is_empty():
		var is_attack = amove_mode
		_spawn_click_marker(g["position"], is_attack)
		if amove_mode:
			_o_amove(g["position"])
			amove_mode = false
		else:
			_o_move(g["position"], queued)


func _confirm(m: Vector2) -> bool:
	var pos := _ground_at(m)
	if targeting >= 0:
		var i := targeting
		cancel_modes()
		hero.try_cast(i, pos)
		return true
	if item_targeting >= 0:
		var s := item_targeting
		cancel_modes()
		hero.use_item(s, pos)
		return true
	if amove_mode:
		amove_mode = false
		_spawn_click_marker(pos, true)
		_o_amove(pos)
		return true
	return false


func cancel_modes() -> bool:
	var was := targeting >= 0 or item_targeting >= 0 or amove_mode
	targeting = -1
	item_targeting = -1
	amove_mode = false
	_held_key = -1
	_held_item = -1
	_aim_active = false
	return was


# ---------- Процесс и клавиатура ----------
func _process(_delta: float) -> void:
	if hero == null:
		return
		
	_update_indicators()
	
	if Global.is_over or get_viewport().gui_get_focus_owner() is LineEdit:
		return

	if joy != null and joy.active and joy.vec.length() > 0.15:
		cancel_modes()
		var cam_f := -cam.global_transform.basis.z
		cam_f.y = 0.0
		cam_f = cam_f.normalized()
		var cam_r := cam.global_transform.basis.x
		cam_r.y = 0.0
		cam_r = cam_r.normalized()
		var dir := cam_r * joy.vec.x - cam_f * joy.vec.y
		for u in _squad():
			u.order_move(u.global_position + dir * 30.0)
		_joy_moving = true
	elif _joy_moving:
		_joy_moving = false
		_o_stop()

	for i in hero.abilities.size():
		var action := "cast_" + String(hero.ab_key[i])
		if Input.is_action_just_pressed(action):
			if Input.is_key_pressed(KEY_CTRL):
				hero.learn_ability(i)
			else:
				press_ability(i, true)
		if Input.is_action_just_released(action):
			_release_ability(i)

	for s in 6:
		var iact := "item_%d" % (s + 1)
		if Input.is_action_just_pressed(iact):
			press_item(s, true)
		if Input.is_action_just_released(iact):
			_release_item(s)

	if Input.is_action_just_pressed("attack_move"):
		start_amove()
	if Input.is_action_just_pressed("stop_order"):
		cancel_modes()
		_o_stop()
	if Input.is_action_just_pressed("hold_order"):
		cancel_modes()
		_o_hold()
	if Input.is_action_just_pressed("center_cam"):
		rig.center()
		Global.selected_unit = hero


# ---------- Управление иллюзиями ----------
# Левый клик / тап по своей иллюзии выбирает только её: приказы получает она одна.
# Выбран герой (клик по нему, Пробел) или что-то другое — приказы получают герой и все его иллюзии.
func _is_my_illusion(u: Unit) -> bool:
	var b := u as BaseHero
	return b != null and b.is_illusion and b.alive and b.illusion_owner == hero


func _squad() -> Array:
	var sel: Unit = Global.selected_unit
	if is_instance_valid(sel) and _is_my_illusion(sel):
		return [sel]
	var out: Array = [hero]
	for n in get_tree().get_nodes_in_group("illusions"):
		var b := n as BaseHero
		if b != null and b.alive and b.illusion_owner == hero:
			out.append(b)
	return out


func _o_move(pos: Vector3, queued: bool) -> void:
	var sq := _squad()
	for i in sq.size():
		var p := pos
		if i > 0:
			var a := TAU * float(i) / float(sq.size() - 1)
			p += Vector3(cos(a), 0.0, sin(a)) * 3.0
		sq[i].order_move(p, queued)


func _o_attack(t: Unit) -> void:
	for u in _squad():
		u.order_attack(t)


func _o_amove(pos: Vector3) -> void:
	for u in _squad():
		u.order_amove(pos)


func _o_stop() -> void:
	for u in _squad():
		u.order_stop()


func _o_hold() -> void:
	for u in _squad():
		u.order_hold()


func start_amove() -> void:
	cancel_modes()
	amove_mode = true


func press_ability(i: int, from_key: bool = false) -> void:
	if i >= hero.abilities.size() or hero.is_passive(i) or hero.ab_level[i] <= 0:
		return
	cancel_modes()
	var ab: Dictionary = hero.abilities[i]
	if ab["target"] == "none":
		hero.try_cast(i, hero.global_position)
		return
	if Global.cast_mode == 1 and from_key:
		hero.try_cast(i, mouse_ground())
		return
	targeting = i
	if Global.cast_mode == 2 and from_key:
		_held_key = i


func _release_ability(i: int) -> void:
	if Global.cast_mode == 2 and _held_key == i and targeting == i:
		targeting = -1
		_held_key = -1
		hero.try_cast(i, mouse_ground())


func press_item(s: int, from_key: bool = false) -> void:
	var id: String = hero.inventory[s]
	if id == "":
		return
	cancel_modes()
	if not hero.item_is_targeted(s):
		hero.use_item(s, hero.global_position)
	elif Global.cast_mode == 1 and from_key:
		hero.use_item(s, mouse_ground())
	else:
		item_targeting = s
		if Global.cast_mode == 2 and from_key:
			_held_item = s


func _release_item(s: int) -> void:
	if Global.cast_mode == 2 and _held_item == s and item_targeting == s:
		item_targeting = -1
		_held_item = -1
		hero.use_item(s, mouse_ground())


# ---------- Кнопка предмета на экране (Телефон) с защитой от случайного использования ----------
func press_item_button(s: int) -> void:
	var id: String = hero.inventory[s]
	if id == "":
		return
		
	var time := Time.get_ticks_msec() / 1000.0
	
	# Если предмет уже был выбран для просмотра (двойной тап в течение 0.5 сек) — используем его!
	if _last_item_tapped == s and (time - _item_tap_time) < 0.5:
		_last_item_tapped = -1
		cancel_modes()
		var pos := hero.smart_target_pos()
		var item: Dictionary = Global.ITEMS[id]
		if item.has("active"):
			var act: Dictionary = item["active"]
			if act["kind"] == "tp":
				pos = hero.global_position
			elif act["kind"] == "blink":
				pos = hero.move_target if hero.has_move_target else hero.global_position + Global.forward(hero.team) * 24.0
		hero.use_item(s, pos)
	else:
		# Первый тап — показываем описание (инспекция) вместо использования!
		_last_item_tapped = s
		_item_tap_time = time
		cancel_modes()
		var item: Dictionary = Global.ITEMS[id]
		var item_name = item.get("name", id)
		var item_desc = item.get("desc", "Нет описания")
		Global.float_text(hero.global_position + Vector3(0.0, hero.hp_bar_height + 3.0, 0.0), "%s: %s (Тапните еще раз для использования)" % [item_name, item_desc], Color(1.0, 0.9, 0.4), 2.5)


# ---------- Экранные кнопки прицеливания и инспекции способностей (Тач) ----------
func btn_begin(i: int) -> void:
	if i >= hero.abilities.size() or hero.is_passive(i) or hero.ab_level[i] <= 0:
		return
	targeting = i
	_aim_pos = hero.ability_aim_pos(i)
	_aim_active = false


func btn_move(i: int, vec: Vector2) -> void:
	if targeting != i:
		return
	if vec.length() < 18.0:
		_aim_active = false
		return
	_aim_active = true
	var rng := maxf(hero.ab_range(i), 10.0)
	var dist := minf(vec.length() / 130.0, 1.0) * rng
	_aim_pos = hero.global_position + Vector3(vec.x, 0.0, vec.y).normalized() * dist


func btn_end(i: int, vec: Vector2) -> void:
	var dragged := vec.length() >= 18.0
	var time := Time.get_ticks_msec() / 1000.0
	
	if i >= hero.abilities.size() or hero.is_passive(i) or hero.ab_level[i] <= 0:
		return
	var ab: Dictionary = hero.abilities[i]
	
	# Если не перетаскивали и это первый тап — показываем описание (инспекция) вместо каста!
	if not dragged and not (_last_ab_tapped == i and (time - _ab_tap_time) < 0.5):
		_last_ab_tapped = i
		_ab_tap_time = time
		targeting = i # Оставляем радиус видимым для удобства
		
		var ab_name = ab.get("name", "Скилл %d" % (i + 1))
		var ab_desc = ab.get("desc", "Нажмите еще раз или потяните для каста")
		Global.float_text(hero.global_position + Vector3(0.0, hero.hp_bar_height + 3.0, 0.0), "%s: %s" % [ab_name, ab_desc], Color(0.4, 0.9, 1.0), 2.5)
		return
		
	# Если был драг или повторный тап (двойной тап) — применяем способность!
	_last_ab_tapped = -1
	var aimed := _aim_active
	cancel_modes()
	
	if ab["target"] == "none" or not dragged:
		hero.try_cast(i, hero.global_position)
	elif dragged and aimed:
		hero.try_cast(i, _aim_pos)
	elif Global.is_touch():
		hero.try_cast(i, hero.ability_aim_pos(i))


# ---------- Отрисовка Индикаторов ----------
func _cursor_world() -> Vector3:
	if _aim_active:
		return _aim_pos
	return mouse_ground()


func _update_indicators() -> void:
	var rng := 0.0
	var rad := 0.0
	var is_line := false
	var show := false
	var width := 1.5
	
	if targeting >= 0 and targeting < hero.abilities.size():
		var ab: Dictionary = hero.abilities[targeting]
		var lvl: int = maxi(hero.ab_level[targeting], 1)
		rng = Abilities.v(ab, "range", lvl)
		rad = Abilities.v(ab, "radius", lvl)
		is_line = ab["kind"] == "proj_line"
		width = Abilities.v(ab, "width", lvl, 1.5)
		show = true
	elif item_targeting >= 0:
		var id: String = hero.inventory[item_targeting]
		if id != "":
			var item: Dictionary = Global.ITEMS[id]
			var act: Dictionary = item["active"]
			rng = float(act.get("range", 14.0)) * Global.RANGE_MULT
			show = true
	elif amove_mode:
		rad = 3.0
		show = true

	var cur := _cursor_world()
	_ring.visible = show and rng > 0.0
	_aoe.visible = show and rad > 0.0 and not is_line
	_line.visible = show and is_line

	if _ring.visible:
		_ring.global_position = hero.global_position + Vector3(0.0, 0.05, 0.0)
		_ring.scale = Vector3(rng, 1.0, rng)

	if _aoe.visible:
		var p := cur
		if rng > 0.0:
			var d := cur - hero.global_position
			d.y = 0.0
			if d.length() > rng:
				p = hero.global_position + d.normalized() * rng
		_aoe.global_position = Vector3(p.x, 0.06, p.z)
		_aoe.scale = Vector3(rad, 1.0, rad)

	if _line.visible:
		var dd := cur - hero.global_position
		dd.y = 0.0
		if dd.length() < 0.5:
			dd = Global.forward(hero.team)
		var dir := dd.normalized()
		_line.global_position = hero.global_position + dir * (rng * 0.5) + Vector3(0.0, 0.06, 0.0)
		_line.rotation.y = atan2(dir.x, dir.z)
		_line.scale = Vector3(width * 2.0, 1.0, rng)


# ---------- Рейкастинг и позиционирование ----------
func _ray(mask: int, m: Vector2) -> Dictionary:
	var from := cam.project_ray_origin(m)
	var to_pt := from + cam.project_ray_normal(m) * 900.0
	var q := PhysicsRayQueryParameters3D.create(from, to_pt, mask)
	return cam.get_world_3d().direct_space_state.intersect_ray(q)


func _ground_at(m: Vector2) -> Vector3:
	var g := _ray(1, m)
	if not g.is_empty():
		return g["position"]
	var from := cam.project_ray_origin(m)
	var dir := cam.project_ray_normal(m)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	if hit == null:
		return hero.global_position
	return hit


func mouse_ground() -> Vector3:
	return _ground_at(get_viewport().get_mouse_position())
