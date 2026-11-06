class_name Unit
extends CharacterBody3D
## Unit.gd — общий предок героев, крипов и построек: характеристики, броня, статусы, бой, HP-бар, модель.

signal died(unit: Unit)

const DEBUFFS: Array = ["stun", "slow", "silence", "root", "poison", "burn", "amp"]
const DOTS: Array = ["poison", "burn"]
static var SHADOW_MAT: StandardMaterial3D = _make_shadow_mat()


static func _make_shadow_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.0, 0.0, 0.0, 0.35)
	return m

var team: int = 0                 # 0 Свет, 1 Тьма, 2 нейтралы
var unit_name: String = "Unit"
var max_hp: float = 100.0
var hp: float = 100.0
var damage: float = 10.0
var armor: float = 0.0
var magic_resist: float = 0.25
var armor_block: float = 0.0
var attack_range: float = 2.0
var attack_interval: float = 1.0
var attack_point: float = 0.3
var move_speed: float = 4.0
var is_ranged: bool = false
var projectile_speed: float = 24.0
var gold_bounty: int = 0
var exp_bounty: int = 0
var body_radius: float = 0.6
var body_height: float = 2.0
var hp_bar_height: float = 2.6
var alive: bool = true
var attack_cd: float = 0.0
var crit_chance: float = 0.0
var crit_mult: float = 2.0
var bash_chance: float = 0.0
var bash_dur: float = 0.8
var bash_dmg: float = 0.0
var building_dmg_mult: float = 1.0
var evasion_passive: float = 0.0
var lifesteal_passive: float = 0.0
var status: Dictionary = {}       # имя -> {left, val, src}
var model_cfg: Dictionary = {}
var model: UnitModel = null

var _visual_root: Node3D
var _bar_fg: MeshInstance3D
var _bar_bg: MeshInstance3D
var _moved: bool = false
var _had_aegis: bool = false
var _stuck: float = 0.0
var _sep_cd: float = 0.0
var _shown_hp_ratio: float = -1.0


func _ready() -> void:
	add_to_group("units")
	collision_layer = 2
	collision_mask = 0
	_configure()
	if not (self is Building):
		# герои и крипы в UNIT_SCALE раз крупнее: размер тела, полоска HP и модель
		var sc := Global.UNIT_SCALE
		body_radius *= sc
		body_height *= sc
		hp_bar_height *= sc
		model_cfg = model_cfg.duplicate()
		model_cfg["scale"] = float(model_cfg.get("scale", 1.0)) * sc
	hp = max_hp
	_setup_collision()
	_build_visual()
	_build_hp_bar()
	_after_ready()
	# Invalidate on both creation and actual tree exit (including illusion expiry).
	tree_exited.connect(Global.invalidate_unit_cache)
	Global.invalidate_unit_cache()


# ---------- виртуальные методы ----------
func _configure() -> void: pass
func _after_ready() -> void: pass
func _always_tick(_delta: float) -> void: pass
func _tick(_delta: float) -> void: pass
func _dead_tick(_delta: float) -> void: pass

func _on_death(_killer: Unit) -> void:
	if Global.selected_unit == self:
		Global.selected_unit = null
	collision_layer = 0
	get_tree().create_timer(1.1).timeout.connect(queue_free)

func _attack_damage() -> float:
	return damage * (1.0 + status_val("rage")) * randf_range(0.95, 1.05)

# Множитель входящего урона (у иллюзий переопределяется в BaseHero).
func _incoming_mult() -> float:
	return 1.0

func eff_attack_interval() -> float:
	return attack_interval


# ---------- цикл ----------
func _physics_process(delta: float) -> void:
	if not alive:
		_dead_tick(delta)
		return
	_moved = false
	if attack_cd > 0.0:
		attack_cd -= delta
	_tick_status(delta)
	if not alive:
		return
	_separate_units(delta)
	_snap_to_ground()
	_always_tick(delta)
	_update_bar()
	if status.has("stun"):
		_sync_model()
		return
	_tick(delta)
	_sync_model()


func _sync_model() -> void:
	if model != null:
		model.set_moving(_moved)
		model.set_stunned(status.has("stun"))


# ---------- статусы ----------
func add_status(sname: String, dur: float, val: float = 0.0, src: Unit = null) -> void:
	if dur <= 0.0 or not alive:
		return
	if sname in DEBUFFS and status.has("immune"):
		return
	if status.has(sname):
		var s: Dictionary = status[sname]
		s["left"] = maxf(float(s["left"]), dur)
		s["val"] = maxf(float(s["val"]), val)
		if src != null:
			s["src"] = src
	else:
		status[sname] = {"left": dur, "val": val, "src": src}
	if sname == "immune":
		for d in DEBUFFS:
			status.erase(d)


func apply_stun(seconds: float) -> void:
	add_status("stun", seconds)


func has_status(sname: String) -> bool:
	return status.has(sname)


func status_val(sname: String) -> float:
	if status.has(sname):
		var s: Dictionary = status[sname]
		return float(s["val"])
	return 0.0


func _tick_status(delta: float) -> void:
	if status.is_empty():
		return
	var expired: Array = []
	for k in status:
		var s: Dictionary = status[k]
		s["left"] = float(s["left"]) - delta
		if k in DOTS:
			var src: Unit = null
			if is_instance_valid(s["src"]):
				src = s["src"]
			take_damage(float(s["val"]) * delta, src, "dot")
			if not alive:
				return
		if float(s["left"]) <= 0.0:
			expired.append(k)
	for k in expired:
		status.erase(k)


func eff_armor() -> float:
	return armor + status_val("armor")


func eff_move_speed() -> float:
	var s := move_speed
	if status.has("slow"):
		s *= 1.0 - minf(0.9, status_val("slow"))
	if status.has("haste"):
		s *= 1.0 + status_val("haste")
	return maxf(s, 3.0)


# ---------- здоровье и урон ----------
func take_damage(amount: float, attacker: Unit = null, dtype: String = "phys", is_attack: bool = false) -> void:
	if not alive or amount <= 0.0 or status.has("invuln"):
		return
	var silent := dtype == "dot"
	if attacker != null and attacker is BaseHero and self is BaseHero and not silent:
		(attacker as BaseHero).aggro_until = Global.elapsed + 2.5
	var col := Color.WHITE
	if is_attack:
		var ev: float = maxf(status_val("evasion"), evasion_passive)
		if ev > 0.0 and randf() < ev:
			Global.float_text(_top_pos(), "MISS", Color(0.8, 0.8, 0.8), 0.8)
			return
		amount = maxf(amount - armor_block, amount * 0.2)
	match dtype:
		"phys":
			var a := eff_armor()
			amount *= 1.0 - (0.06 * a) / (1.0 + 0.06 * absf(a))
		"magic", "dot":
			if status.has("immune"):
				return
			amount *= 1.0 - magic_resist
			col = Color(0.5, 0.7, 1.0)
		"pure":
			col = Color(0.85, 0.5, 1.0)
	if status.has("amp"):
		amount *= 1.0 + status_val("amp")
	amount *= _incoming_mult()
	if status.has("shield"):
		var sh: Dictionary = status["shield"]
		var absorbed: float = minf(float(sh["val"]), amount)
		sh["val"] = float(sh["val"]) - absorbed
		amount -= absorbed
		if float(sh["val"]) <= 0.0:
			status.erase("shield")
	if amount <= 0.0:
		return
	var actual_damage := minf(amount, maxf(hp, 0.0))
	hp -= amount
	if attacker is BaseHero:
		var hero := attacker as BaseHero
		if hero.is_illusion and is_instance_valid(hero.illusion_owner):
			hero = hero.illusion_owner
		hero.damage_dealt += actual_damage
		if self is Building:
			hero.building_damage += actual_damage
			(self as Building).damage_contributors[hero.get_instance_id()] = true
	if not silent:
		SignalBus.unit_damaged.emit(self, attacker, amount)
		if model != null:
			model.flash()
		if self is BaseHero or attacker is BaseHero:
			Global.sfx("hit", -14.0)
		if self is BaseHero or attacker is BaseHero:
			Global.float_text(_top_pos(), str(int(amount)), col)
	_update_bar()
	if hp <= 0.0:
		_die(attacker)


func heal(amount: float) -> void:
	if not alive:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	if hp - before >= 1.0 and self is BaseHero:
		Global.float_text(_top_pos(), "+%d" % int(hp - before), Color(0.4, 1.0, 0.5), 0.9)


func _die(killer: Unit) -> void:
	alive = false
	hp = 0.0
	_had_aegis = status.has("aegis")
	status.clear()
	_update_bar()
	_set_bars_visible(false)
	died.emit(self)
	SignalBus.unit_died.emit(self, killer)
	if model != null:
		model.play_death()
	_on_death(killer)


# ---------- бой и движение ----------
func in_attack_range(t: Unit) -> bool:
	return Global.flat_dist(global_position, t.global_position) <= attack_range + body_radius + t.body_radius


func try_attack(t: Unit) -> bool:
	if attack_cd > 0.0 or not in_attack_range(t) or status.has("disarm"):
		return false
	attack_cd = eff_attack_interval()
	face_towards(t.global_position)
	if model != null:
		model.play_attack(is_ranged)
	get_tree().create_timer(attack_point).timeout.connect(_land_attack.bind(t))
	return true


func _land_attack(t) -> void:
	if not alive or not is_instance_valid(t) or not t.alive or status.has("stun"):
		return
	if is_ranged:
		var parent := get_parent()
		if parent != null:
			Projectile.launch_homing(parent, global_position + Vector3(0.0, body_height * 0.75, 0.0), t, self, projectile_speed)
	else:
		deliver_attack(t)


# Применяет удар: крит, оглушающий удар, вампиризм.
func deliver_attack(t: Unit) -> void:
	if not alive or not is_instance_valid(t) or not t.alive:
		return
	if t.global_position.y - global_position.y > 3.0 and randf() < 0.25:
		Global.float_text(t.global_position + Vector3(0.0, t.body_height, 0.0), "MISS (высота)", Color(0.8, 0.8, 0.8), 0.8)
		return
	var dmg := _attack_damage()
	if t is Building:
		dmg *= building_dmg_mult
	var crit := false
	if crit_chance > 0.0 and randf() < crit_chance:
		dmg *= crit_mult
		crit = true
	var bonus := 0.0
	if bash_chance > 0.0 and randf() < bash_chance:
		t.add_status("stun", bash_dur, 0.0, self)
		bonus = bash_dmg
	var before := t.hp
	t.take_damage(dmg + bonus, self, "phys", true)
	var dealt := maxf(0.0, before - t.hp)
	var ls := lifesteal_passive + status_val("lifesteal")
	if ls > 0.0 and dealt > 0.0:
		heal(dealt * ls)
	if crit:
		Global.float_text(t.global_position + Vector3(0.0, t.body_height + 1.2, 0.0), "CRIT!", Color(1.0, 0.3, 0.2), 1.3)
	_on_attack_hit(t)


# Вызывается после каждого успешного удара автоатаки (переопределяется в BaseHero).
func _on_attack_hit(_t: Unit) -> void:
	pass


func chase(t: Unit, delta: float) -> void:
	var stop := maxf(0.2, attack_range * 0.85 + body_radius + t.body_radius)
	move_towards(t.global_position, delta, stop)


func move_towards(pos: Vector3, delta: float, stop_dist: float = 0.1) -> bool:
	var dir := pos - global_position
	dir.y = 0.0
	var d := dir.length()
	if d <= stop_dist:
		return true
	face_towards(pos)
	if status.has("root"):
		return false
	var before := global_position
	var step := minf(eff_move_speed() * delta, d - stop_dist)
	global_position += dir / d * step
	global_position.x = clampf(global_position.x, -Global.MAP_HALF, Global.MAP_HALF)
	global_position.z = clampf(global_position.z, -Global.MAP_HALF, Global.MAP_HALF)
	global_position = Global.push_out(global_position, body_radius)
	var moved := before.distance_to(global_position)
	if moved < step * 0.3:
		# упёрся в препятствие: через 0.4 с считаем точку достигнутой, анимация бега останавливается
		_stuck += delta
		if _stuck > 0.4:
			_stuck = 0.0
			return true
	else:
		_stuck = maxf(0.0, _stuck - delta)
	_moved = moved > 0.02
	return false


func face_towards(p: Vector3) -> void:
	if _visual_root == null:
		return
	var dir := p - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(dir.x, dir.z), 0.4)


# ---------- визуал ----------
func team_color() -> Color:
	if team == 0:
		return Color(0.3, 0.6, 1.0)
	if team == 1:
		return Color(0.95, 0.3, 0.3)
	return Color(0.95, 0.7, 0.2)


func _bar_color() -> Color:
	if team == 2:
		return Color(0.95, 0.8, 0.2)
	return Color(0.25, 0.85, 0.3) if team == Global.player_team else Color(0.9, 0.25, 0.25)


func _top_pos() -> Vector3:
	return global_position + Vector3(0.0, hp_bar_height + 0.4, 0.0)


func _setup_collision() -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = body_radius
	shape.height = body_height
	cs.shape = shape
	cs.position.y = body_height * 0.5
	add_child(cs)


func _build_visual() -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)
	_make_body(_visual_root)
	if not (self is Building):
		var sh := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = body_radius * 1.15
		cm.bottom_radius = body_radius * 1.15
		cm.height = 0.03
		cm.radial_segments = 14
		sh.mesh = cm
		sh.material_override = SHADOW_MAT
		sh.position.y = 0.12
		add_child(sh)


func _make_body(root: Node3D) -> void:
	model = UnitModel.new()
	root.add_child(model)
	model.build(model_cfg, team_color())


func _build_hp_bar() -> void:
	var w: float = maxf(1.6, body_radius * 2.4)
	_bar_bg = _make_quad(Vector2(w + 0.1, 0.24), Color(0.05, 0.05, 0.05, 0.9), 1, 0.0)
	_bar_bg.position = Vector3(0.0, hp_bar_height, 0.0)
	add_child(_bar_bg)
	_bar_fg = _make_quad(Vector2(w, 0.16), _bar_color(), 2, w * 0.5)
	_bar_fg.position = Vector3(-w * 0.5, hp_bar_height, 0.0)
	add_child(_bar_fg)


func _make_quad(quad_size: Vector2, color: Color, prio: int, offset_x: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = quad_size
	q.center_offset = Vector3(offset_x, 0.0, 0.0)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.render_priority = prio
	mi.material_override = m
	return mi


func _set_bars_visible(v: bool) -> void:
	if _bar_fg != null:
		_bar_fg.visible = v
		_bar_bg.visible = v


func _update_bar() -> void:
	if _bar_fg != null:
		var ratio := clampf(hp / max_hp, 0.001, 1.0)
		if ratio != _shown_hp_ratio:
			_shown_hp_ratio = ratio
			_bar_fg.scale.x = ratio


# Мягкая коллизия юнит-юнит: юниты не слипаются (раз в 0.1 с, поиск по сетке).
func _separate_units(delta: float) -> void:
	if self is Building:
		return
	_sep_cd -= delta
	if _sep_cd > 0.0:
		return
	_sep_cd = 0.1
	for n in Global.units_near(global_position, body_radius + 14.0):
		var o := n as Unit
		if o == null or o == self or not o.alive or o is Building:
			continue
		var min_d := (body_radius + o.body_radius) * 0.8
		var d := Vector2(global_position.x - o.global_position.x, global_position.z - o.global_position.z)
		var l := d.length()
		if l < min_d:
			var push := Vector2.RIGHT * 0.3 if l < 0.001 else d / l * (min_d - l) * 0.5
			global_position += Vector3(push.x, 0.0, push.y)


# Юнит стоит на поверхности рельефа (холмы).
func _snap_to_ground() -> void:
	if self is Building:
		return
	var grounded := global_position
	grounded.y = Global.height_at(grounded.x, grounded.z)
	if grounded != global_position:
		global_position = grounded
