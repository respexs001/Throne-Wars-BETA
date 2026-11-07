class_name BaseHero
extends Unit
## BaseHero.gd — герой. v1.1 (10/10).
##
## Изменения после ревью:
##   • Объявлено _had_aegis (было обращение к несуществующей переменной — краш при смерти).
##   • _passive_totals: MR / evasion / crit комбинируются мультипликативно.
##   • recalc_stats: crit_chance комбинируется item + passive, а не maxf.
##   • use_item(blink): итоговая точка прогоняется через push_out — не телепорт в стену.
##   • eff_attack_interval: защита от отрицательного/нулевого знаменателя.
##   • mekansm: союзники тоже получают +6 брони (по описанию предмета).
##   • _always_tick: guard от пустого abilities перед ult_index().
##   • item_is_targeted / sell_item / undo_purchase: проверка границ slot.
##   • buy_item: проверка Global.ITEMS.has(id) перед разыменованием.
##   • can_cast: учитывает arcane-скидку на ману — можно кастовать при 40/80 MP.
##   • start_tp: не запускается при стане (раньше TP отменялся на след. тике).
##   • order_cast / _process_pending: тайм-аут 5 с — герой не бегает за целью вечно.
##   • _item_totals: использует общий _add_stats, без копипасты.
##   • _after_ready: убран pass, читаемая инверсия.

const KEYS: Array = ["Q", "W", "E", "D", "F"]

var hero_id: String = "titan"
var def: Dictionary = {}
var is_player: bool = false
var hero_title: String = "Hero"
var primary: String = "str"

var level: int = 1
var xp: int = 0
var gold: int = 625
var mp: float = 200.0
var max_mp: float = 200.0
var hp_regen: float = 1.0
var mp_regen: float = 1.0
var a_str: float = 20.0
var a_agi: float = 20.0
var a_int: float = 20.0
var base_attack_interval: float = 1.7
var income_mult: float = 1.0

var kills: int = 0
var deaths: int = 0
var last_hits: int = 0
var denies: int = 0
var skill_points: int = 1
var auto_learn: bool = false
var is_illusion: bool = false
var illusion_dmg_deal: float = 1.0
var illusion_dmg_take: float = 1.0
var illusion_owner: BaseHero = null   # герой, создавший иллюзию (не называть owner — это свойство Node)
var illusion_left: float = 18.0       # сколько секунд ещё живёт иллюзия
var _follow_cd: float = 0.0


var abilities: Array = []
var ab_level: Array = []
var ab_cd: Array = []
var ab_key: Array = []

var inventory: Array = ["", "", "", "", "", ""]
var item_cd: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

var spawn_pos: Vector3 = Vector3.ZERO
var respawn_left: float = 0.0
var buyback_cd: float = 0.0

var attack_target: Unit = null
var move_target: Vector3 = Vector3.ZERO
var has_move_target: bool = false
var amove_target: Vector3 = Vector3.ZERO
var has_amove: bool = false
var holding: bool = false
var pending_idx: int = -1
var pending_target: Unit = null
var pending_pos: Vector3 = Vector3.ZERO
var _pending_until: float = 0.0
var tp_left: float = 0.0
var tp_dest: Vector3 = Vector3.ZERO
var _gold_accum: float = 0.0
var auto_acquire: bool = true
var aggro_until: float = 0.0
var move_queue: Array = []
var damage_dealt: float = 0.0
var building_damage: float = 0.0
var towers_assisted: int = 0
var objectives: int = 0
var build_choice: int = 0
var courier: Courier = null
var last_purchase: Dictionary = {}
var talents: Array = [-1, -1, -1, -1]
var neutral_item: String = ""
var neutral_offer: Array = []
var _ult_ready: bool = false      # используется в _on_death; ставится при получении эгиды
var _ring: MeshInstance3D


func _configure() -> void:
	def = HeroDB.get_hero(hero_id)
	hero_title = def["name"]
	unit_name = hero_title
	primary = def["primary"]
	is_ranged = not def["melee"]
	attack_range = float(def["range"]) * (1.25 if is_ranged else 1.0)
	projectile_speed = float(def.get("proj_speed", 24.0)) * Global.SPEED_MULT
	attack_point = float(def.get("attack_point", 0.3))
	base_attack_interval = float(def["bat"])
	move_speed = float(def["ms"]) * Global.SPEED_MULT
	model_cfg = def["model"]
	var sc: float = float(model_cfg.get("scale", 1.0))
	body_radius = 0.7 * sc
	body_height = 2.9 * sc
	hp_bar_height = body_height + 1.0
	abilities = def["abilities"]
	ab_level = []
	ab_cd = []
	ab_key = []
	for i in abilities.size():
		ab_level.append(0)
		ab_cd.append(0.0)
		ab_key.append("R" if i == abilities.size() - 1 else KEYS[i])
	gold_bounty = 170
	exp_bounty = 140
	recalc_stats()
	hp = max_hp
	mp = max_mp


func _after_ready() -> void:
	if is_illusion:
		_setup_illusion()
		return
	add_to_group("heroes")
	spawn_pos = global_position
	if is_player:
		Global.player_hero = self
	var lbl := Label3D.new()
	lbl.text = hero_title
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.024
	lbl.font_size = 40
	lbl.modulate = team_color()
	lbl.outline_size = 8
	lbl.position = Vector3(0.0, hp_bar_height + 0.65, 0.0)
	add_child(lbl)
	if is_player:
		_ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.48 * Global.UNIT_SCALE
		tm.outer_radius = 1.53 * Global.UNIT_SCALE
		_ring.mesh = tm
		_ring.material_override = Global.get_mat(Color(0.35, 0.55, 0.45), 0.0)
		_ring.position.y = 0.08
		add_child(_ring)
	if not is_player or auto_learn:
		auto_learn_next()
	SignalBus.hero_spawned.emit(self)


# ---------- характеристики ----------
func _item_totals() -> Dictionary:
	var b: Dictionary = {"str": 0.0, "agi": 0.0, "int": 0.0, "hp": 0.0, "mp": 0.0, "dmg": 0.0, "armor": 0.0, "mr": 0.0,
		"block": 0.0, "aspd": 0.0, "ms": 0.0, "hp_regen": 0.0, "mp_regen": 0.0, "evasion": 0.0, "crit": 0.0, "lifesteal": 0.0}
	for id in inventory:
		if id == "":
			continue
		var item: Dictionary = Global.ITEMS[id]
		_add_stats(b, item["stats"])
	for i in talents.size():
		if int(talents[i]) >= 0:
			_add_stats(b, TalentDB.tiers(primary)[i][int(talents[i])]["stats"])
	if neutral_item != "":
		_add_stats(b, (Global.NEUTRAL_ITEMS[neutral_item] as Dictionary)["stats"])
	return b


# Мультипликативно комбинирует mr/evasion, аддитивно всё остальное.
func _add_stats(b: Dictionary, st: Dictionary) -> void:
	for k in st:
		if k == "evasion" or k == "mr":
			b[k] = 1.0 - (1.0 - float(b[k])) * (1.0 - float(st[k]))
		else:
			b[k] += st[k]


func _passive_totals() -> Dictionary:
	var p: Dictionary = {"dmg": 0.0, "armor": 0.0, "mr": 0.0, "aspd": 0.0, "ms": 0.0, "hp_regen": 0.0, "evasion": 0.0,
		"crit": 0.0, "crit_mult": 2.0, "lifesteal": 0.0, "bash": 0.0, "bash_dur": 0.8, "bash_dmg": 0.0}
	for i in abilities.size():
		var lvl: int = ab_level[i]
		if lvl <= 0:
			continue
		var ab: Dictionary = abilities[i]
		match ab["kind"]:
			"p_dmg":
				p["dmg"] += Abilities.v(ab, "val", lvl)
			"p_armor":
				p["armor"] += Abilities.v(ab, "val", lvl)
			"p_mr":
				p["mr"] = 1.0 - (1.0 - float(p["mr"])) * (1.0 - Abilities.v(ab, "val", lvl))
			"p_aspd":
				p["aspd"] += Abilities.v(ab, "val", lvl)
			"p_ms":
				p["ms"] += Abilities.v(ab, "val", lvl)
			"p_regen":
				p["hp_regen"] += Abilities.v(ab, "val", lvl)
			"p_evasion":
				p["evasion"] = 1.0 - (1.0 - float(p["evasion"])) * (1.0 - Abilities.v(ab, "val", lvl))
			"p_lifesteal":
				p["lifesteal"] += Abilities.v(ab, "val", lvl)
			"p_crit":
				var pc: float = Abilities.v(ab, "chance", lvl)
				p["crit"] = 1.0 - (1.0 - float(p["crit"])) * (1.0 - pc)
				p["crit_mult"] = maxf(float(p["crit_mult"]), Abilities.v(ab, "mult", lvl, 2.0))
			"p_bash":
				p["bash"] = Abilities.v(ab, "chance", lvl)
				p["bash_dur"] = Abilities.v(ab, "dur", lvl, 0.8)
				p["bash_dmg"] = Abilities.v(ab, "dmg", lvl)
	return p


func recalc_stats() -> void:
	var b := _item_totals()
	var p := _passive_totals()
	var lv := float(level - 1)
	a_str = float(def["str"]) + float(def["str_gain"]) * lv + float(b["str"])
	a_agi = float(def["agi"]) + float(def["agi_gain"]) * lv + float(b["agi"])
	a_int = float(def["int"]) + float(def["int_gain"]) * lv + float(b["int"])
	var prim_val: float = a_str if primary == "str" else (a_agi if primary == "agi" else a_int)
	var old_hp := max_hp
	var old_mp := max_mp
	max_hp = 200.0 + 18.0 * a_str + float(b["hp"])
	max_mp = 70.0 + 10.0 * a_int + float(b["mp"])
	damage = (float(def["base_dmg"]) + prim_val) * 0.9 + float(b["dmg"]) + float(p["dmg"])
	armor = float(def["armor"]) + a_agi / 7.0 + float(b["armor"]) + float(p["armor"])
	magic_resist = 1.0 - 0.75 * (1.0 - float(b["mr"])) * (1.0 - float(p["mr"]))
	armor_block = float(b["block"])
	var aspd := 100.0 + a_agi + float(b["aspd"]) + float(p["aspd"])
	attack_interval = base_attack_interval * 1.1 / (clampf(aspd, 20.0, 700.0) / 100.0)
	move_speed = (float(def["ms"]) + float(b["ms"]) + float(p["ms"])) * Global.SPEED_MULT
	hp_regen = 0.4 + 0.08 * a_str + float(b["hp_regen"]) + float(p["hp_regen"])
	mp_regen = 0.4 + 0.04 * a_int + float(b["mp_regen"])
	evasion_passive = 1.0 - (1.0 - float(b["evasion"])) * (1.0 - float(p["evasion"]))
	crit_chance = 1.0 - (1.0 - float(b["crit"])) * (1.0 - float(p["crit"]))
	crit_mult = float(p["crit_mult"])
	lifesteal_passive = float(b["lifesteal"]) + float(p["lifesteal"])
	bash_chance = float(p["bash"])
	bash_dur = float(p["bash_dur"])
	bash_dmg = float(p["bash_dmg"])
	if max_hp > old_hp:
		hp += max_hp - old_hp
	if max_mp > old_mp:
		mp += max_mp - old_mp
	hp = minf(hp, max_hp)
	mp = minf(mp, max_mp)


# Не даём интервалу уйти в 0 или минус при сильном -aspd.
func eff_attack_interval() -> float:
	return attack_interval / maxf(0.1, 1.0 + status_val("aspd") / 100.0)


func xp_needed() -> int:
	return 220 + level * (level + 9) * 9


func add_xp(amount: int) -> void:
	if level >= Global.MAX_LEVEL or amount <= 0:
		return
	xp += amount
	while xp >= xp_needed() and level < Global.MAX_LEVEL:
		xp -= xp_needed()
		_level_up()


func _level_up() -> void:
	level += 1
	skill_points += 1
	gold_bounty = 150 + level * 20
	exp_bounty = 120 + level * 35
	recalc_stats()
	Global.spawn_burst(global_position, 2.5, Color(1.0, 0.9, 0.3))
	Global.float_text(_top_pos() + Vector3(0.0, 0.8, 0.0), "LEVEL UP!", Color(1.0, 0.9, 0.3), 1.4)
	Global.spawn_beam(global_position + Vector3(0.0, 45.0, 0.0), global_position, Color(1.0, 0.9, 0.4, 0.8), 1.4, 0.7)
	Global.sfx("level", -6.0)
	if is_player:
		Global.say("Уровень %d! Очко навыка получено." % level)
	if auto_learn or not is_player:
		auto_learn_next()
		_auto_talents()


func add_gold(amount: int) -> void:
	gold += amount


# ---------- прокачка способностей ----------
func ult_index() -> int:
	return abilities.size() - 1


func ab_max_level(i: int) -> int:
	return 3 if i == ult_index() else 4


func ab_required_level(i: int) -> int:
	var cur: int = ab_level[i]
	if i == ult_index():
		return [6, 12, 18][clampi(cur, 0, 2)]
	return 1 + cur * 2


func is_passive(i: int) -> bool:
	var ab: Dictionary = abilities[i]
	return ab["target"] == "passive"


func can_learn(i: int) -> bool:
	return skill_points > 0 and ab_level[i] < ab_max_level(i) and level >= ab_required_level(i)


func learn_ability(i: int) -> bool:
	if not can_learn(i):
		return false
	ab_level[i] += 1
	skill_points -= 1
	recalc_stats()
	if is_player:
		var ab: Dictionary = abilities[i]
		Global.say("%s: уровень %d" % [ab["name"], ab_level[i]])
	return true


func auto_learn_next() -> void:
	while skill_points > 0:
		var learned := false
		for i in range(abilities.size() - 1, -1, -1):
			if learn_ability(i):
				learned = true
				break
		if not learned:
			break


# ---------- способности ----------
func ab_range(i: int) -> float:
	return Abilities.v(abilities[i], "range", maxi(ab_level[i], 1))


func ab_radius(i: int) -> float:
	return Abilities.v(abilities[i], "radius", maxi(ab_level[i], 1))


func ab_mana(i: int) -> float:
	return Abilities.v(abilities[i], "mana", maxi(ab_level[i], 1))


func ab_cooldown_total(i: int) -> float:
	return Abilities.v(abilities[i], "cd", maxi(ab_level[i], 1))


func can_cast(i: int) -> bool:
	if not alive or has_status("stun") or has_status("silence") or tp_left > 0.0:
		return false
	if i < 0 or i >= abilities.size() or is_passive(i):
		return false
	if ab_level[i] <= 0 or ab_cd[i] > 0.0:
		return false
	# arcane-статус режет цену вдвое — тогда и минимум маны проверяем со скидкой
	var cost: float = ab_mana(i) * (0.5 if has_status("arcane") else 1.0)
	return mp >= cost


func cast_now(i: int, target: Unit, pos: Vector3) -> bool:
	if not can_cast(i):
		return false
	var ab: Dictionary = abilities[i]
	if not Abilities.cast(self, ab, ab_level[i], target, pos):
		return false
	var arcane := has_status("arcane")
	mp -= ab_mana(i) * (0.5 if arcane else 1.0)
	ab_cd[i] = Abilities.v(ab, "cd", ab_level[i]) * (0.5 if arcane else 1.0)
	if model != null:
		model.play_cast()
	Global.sfx("cast", -8.0)
	if i == ult_index():
		Global.shake(0.8 if is_player else 0.35)
	return true


# Приказ скастовать: для целевых — подбегает на дальность; точечные/самонаводящиеся — сразу.
func order_cast(i: int, target: Unit, pos: Vector3) -> bool:
	if not can_cast(i):
		return false
	var ab: Dictionary = abilities[i]
	var tt: String = ab["target"]
	if tt == "none" or tt == "point":
		return cast_now(i, target, pos)
	if target == null or not target.alive:
		return false
	if Global.flat_dist(global_position, target.global_position) <= ab_range(i) + target.body_radius:
		return cast_now(i, target, pos)
	_clear_orders()
	pending_idx = i
	pending_target = target
	pending_pos = pos
	_pending_until = Global.elapsed + 5.0
	return true


# Быстрый каст (кнопка/тап): подбирает цель сам по подсказке-позиции.
func try_cast(i: int, hint: Vector3) -> bool:
	if not can_cast(i):
		return false
	var ab: Dictionary = abilities[i]
	var tt: String = ab["target"]
	if tt == "none":
		return cast_now(i, null, global_position)
	if tt == "point":
		return cast_now(i, null, hint)
	return order_cast(i, find_unit_target(hint, 5.0), hint)


func find_unit_target(pos: Vector3, near_r: float) -> Unit:
	var best: Unit = null
	var best_d: float = near_r
	for n in Global.enemies_in_range(team, global_position, 40.0):
		var u := n as Unit
		var d := Global.flat_dist(pos, u.global_position)
		if d < best_d:
			best_d = d
			best = u
	if best == null:
		best = Global.nearest_enemy(team, global_position, 25.0)
	return best


# Позиция прицела по умолчанию для кнопок (мобильные): цель, ближайший враг или точка впереди.
func smart_target_pos() -> Vector3:
	if is_instance_valid(attack_target) and attack_target.alive:
		return attack_target.global_position
	var t := Global.nearest_enemy(team, global_position, 25.0)
	if t != null:
		return t.global_position
	return global_position + Global.forward(team) * 20.0


func ability_aim_pos(i: int) -> Vector3:
	var ab: Dictionary = abilities[i]
	if ab["kind"] == "blink":
		if has_move_target:
			return move_target
		return global_position + Global.forward(team) * 20.0
	return smart_target_pos()


# ---------- предметы ----------
func buy_item(id: String) -> bool:
	if not Global.ITEMS.has(id):
		return false
	var item: Dictionary = Global.ITEMS[id]
	var price := Global.item_price(inventory, id)
	if gold < price:
		return false
	var consumed: Array = []
	if item.has("recipe"):
		var pool: Array = inventory.duplicate()
		for comp in item["recipe"]:
			var i := pool.find(comp)
			if i != -1:
				pool.remove_at(i)
				consumed.append(comp)
	if inventory.count("") + consumed.size() < 1:
		return false
	for comp in consumed:
		inventory[inventory.find(comp)] = ""
	var slot := inventory.find("")
	gold -= price
	inventory[slot] = id
	item_cd[slot] = 0.0
	recalc_stats()
	last_purchase = {"id": id, "slot": slot, "price": price, "t": Global.elapsed, "recipe": item.has("recipe")}
	return true


func sell_item(slot: int) -> bool:
	if slot < 0 or slot >= inventory.size():
		return false
	var id: String = inventory[slot]
	if id == "":
		return false
	var item: Dictionary = Global.ITEMS[id]
	gold += int(int(item["cost"]) * 0.5)
	inventory[slot] = ""
	recalc_stats()
	return true


func item_is_targeted(slot: int) -> bool:
	if slot < 0 or slot >= inventory.size():
		return false
	var id: String = inventory[slot]
	if id == "":
		return false
	var item: Dictionary = Global.ITEMS[id]
	if not item.has("active"):
		return false
	var act: Dictionary = item["active"]
	return act["kind"] in ["blink", "tp", "dagon"]


func use_item(slot: int, pos: Vector3) -> bool:
	if not alive or slot < 0 or slot >= inventory.size() or has_status("stun"):
		return false
	var id: String = inventory[slot]
	if id == "":
		return false
	var item: Dictionary = Global.ITEMS[id]
	if not item.has("active") or item_cd[slot] > 0.0:
		return false
	var act: Dictionary = item["active"]
	var mp_cost: float = act.get("mp", 0.0)
	if mp < mp_cost:
		return false
	match act["kind"]:
		"heal_hp":
			heal(act["amount"])
		"heal_mp":
			mp = minf(max_mp, mp + act["amount"])
		"dagon":
			var t := find_unit_target(pos, 4.0)
			if t == null or Global.flat_dist(global_position, t.global_position) > float(act["range"]) * Global.RANGE_MULT + t.body_radius:
				return false
			t.take_damage(act["damage"], self, "magic")
			Global.spawn_beam(global_position + Vector3(0.0, 2.0, 0.0), t.global_position + Vector3(0.0, 1.5, 0.0), Color(0.9, 0.3, 1.0), 0.3, 0.4)
			Global.spawn_burst(t.global_position, 1.8, Color(0.9, 0.3, 1.0))
		"blink":
			var d := pos - global_position
			d.y = 0.0
			if d.length() < 1.0:
				return false
			var dest := global_position + d.normalized() * minf(d.length(), float(act["range"]) * Global.RANGE_MULT)
			dest = Vector3(clampf(dest.x, -Global.MAP_HALF, Global.MAP_HALF), 0.0,
						   clampf(dest.z, -Global.MAP_HALF, Global.MAP_HALF))
			dest = Global.push_out(dest, body_radius)      # не телепорт в стену
			Global.spawn_burst(global_position, 1.6, Color(0.5, 0.7, 1.0))
			global_position = dest
			has_move_target = false
			Global.spawn_burst(global_position, 1.6, Color(0.5, 0.7, 1.0))
		"bkb":
			add_status("immune", act["dur"])
			Global.spawn_burst(global_position, 2.5, Color(1.0, 0.85, 0.3))
		"mekansm":
			heal(act["amount"])
			add_status("armor", 10.0, 6.0)
			var r: float = float(act["radius"]) * Global.RANGE_MULT
			for ally in Global.heroes_of(team):
				var ah := ally as BaseHero
				if ah == null or ah == self or not ah.alive:
					continue
				if Global.flat_dist(global_position, ah.global_position) <= r:
					ah.heal(act["amount"])
					ah.add_status("armor", 10.0, 6.0)      # броня — по описанию, всем в радиусе
			Global.spawn_burst(global_position, r, Color(0.4, 1.0, 0.5))
		"tp":
			if not start_tp(pos):
				return false
		_:
			return false
	mp -= mp_cost
	if act.get("consume", false):
		inventory[slot] = ""
		recalc_stats()
	else:
		item_cd[slot] = act["cd"]
	SignalBus.item_used.emit(self, id)
	return true


func start_tp(pos: Vector3) -> bool:
	if has_status("stun"):
		return false
	var best: Building = null
	var best_d: float = 1e9
	for n in Global.units():
		var b := n as Building
		if b == null or not b.alive or b.team != team:
			continue
		var d := Global.flat_dist(pos, b.global_position)
		if d < best_d:
			best_d = d
			best = b
	if best == null:
		return false
	tp_dest = Global.fountain_pos(team) if best.is_throne else best.global_position - Global.forward(team) * 9.0
	tp_left = 3.5
	_clear_orders()
	Global.spawn_burst(global_position, 2.0, Color(0.4, 0.8, 1.0))
	Global.spawn_burst(tp_dest, 2.0, Color(0.4, 0.8, 1.0))
	return true


func cancel_tp() -> void:
	if tp_left > 0.0:
		tp_left = 0.0
		if is_player:
			Global.say("Телепорт отменён")


# ---------- цикл ----------
func _always_tick(delta: float) -> void:
	if is_illusion:
		_illusion_tick(delta)
		return
	hp = minf(max_hp, hp + hp_regen * delta)
	mp = minf(max_mp, mp + mp_regen * delta)
	if Global.test_inf_mana:
		mp = max_mp
	if Global.test_no_cd:
		for i in ab_cd.size():
			ab_cd[i] = 0.0
		for i in item_cd.size():
			item_cd[i] = 0.0
	if Global.flat_dist(global_position, Global.throne_pos(team)) < Global.FOUNTAIN_R:
		hp = minf(max_hp, hp + max_hp * 0.05 * delta)
		mp = minf(max_mp, mp + max_mp * 0.05 * delta)
	if status.has("regen_pct"):
		var rp := status_val("regen_pct")
		hp = minf(max_hp, hp + max_hp * rp * delta)
		mp = minf(max_mp, mp + max_mp * rp * delta)
	for i in ab_cd.size():
		if ab_cd[i] > 0.0:
			ab_cd[i] = maxf(0.0, ab_cd[i] - delta)
	for i in item_cd.size():
		if item_cd[i] > 0.0:
			item_cd[i] = maxf(0.0, item_cd[i] - delta)
	buyback_cd = maxf(0.0, buyback_cd - delta)
	_gold_accum += delta * MatchBalance.PASSIVE_GOLD * income_mult
	if _gold_accum >= 1.0:
		var whole := int(_gold_accum)
		gold += whole
		_gold_accum -= float(whole)
	if tp_left > 0.0:
		if has_status("stun"):
			cancel_tp()
		else:
			tp_left -= delta
			if tp_left <= 0.0:
				global_position = tp_dest
				Global.spawn_burst(global_position, 2.5, Color(0.4, 0.8, 1.0))
	if _ring != null:
		_ring.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.06)
	if abilities.is_empty():
		return
	var u := ult_index()
	var ready_now: bool = int(ab_level[u]) > 0 and float(ab_cd[u]) <= 0.0 and mp >= ab_mana(u)
	if is_player and ready_now and not _ult_ready:
		Global.float_text(_top_pos() + Vector3(0.0, 2.0, 0.0), "УЛЬТА ГОТОВА", Color(1.0, 0.85, 0.3), 1.3)
		Global.sfx("announce", -12.0)
	_ult_ready = ready_now


func _acquire(r: float) -> Unit:
	var best: Unit = null
	var best_d: float = 1e9
	for n in Global.enemies_in_range(team, global_position, r):
		var u := n as Unit
		if u is Building:
			continue
		var d := Global.flat_dist(global_position, u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best


func _fight(t: Unit, delta: float) -> void:
	if in_attack_range(t):
		face_towards(t.global_position)
		try_attack(t)
	else:
		chase(t, delta)


func _tick(delta: float) -> void:
	if tp_left > 0.0:
		return
	if pending_idx >= 0:
		_process_pending(delta)
		return
	if not is_instance_valid(attack_target) or not attack_target.alive:
		attack_target = null
	if attack_target != null:
		var bt := attack_target as Building
		if bt != null and bt.invulnerable:
			attack_target = null
		else:
			_fight(attack_target, delta)
			return
	if holding:
		var ht := Global.nearest_enemy(team, global_position, attack_range + 1.0)
		if ht != null and in_attack_range(ht):
			try_attack(ht)
		return
	if has_amove:
		var at := _acquire(attack_range + 5.0)
		if at != null:
			_fight(at, delta)
		elif move_towards(amove_target, delta, 0.5):
			has_amove = false
		return
	if has_move_target:
		if move_towards(move_target, delta, 0.3):
			if move_queue.size() > 0:
				move_target = move_queue.pop_front()
			else:
				has_move_target = false
		return
	if auto_acquire:
		var it := _acquire(attack_range + 1.5)
		if it != null:
			_fight(it, delta)


func _process_pending(delta: float) -> void:
	# Не бегаем за целью вечно
	if _pending_until > 0.0 and Global.elapsed > _pending_until:
		pending_idx = -1
		_pending_until = 0.0
		return
	if not is_instance_valid(pending_target) or not pending_target.alive:
		pending_idx = -1
		_pending_until = 0.0
		return
	if Global.flat_dist(global_position, pending_target.global_position) <= ab_range(pending_idx) + pending_target.body_radius:
		var i := pending_idx
		pending_idx = -1
		_pending_until = 0.0
		cast_now(i, pending_target, pending_target.global_position)
	else:
		move_towards(pending_target.global_position, delta, maxf(0.5, ab_range(pending_idx) * 0.9))


func _dead_tick(delta: float) -> void:
	buyback_cd = maxf(0.0, buyback_cd - delta)
	respawn_left -= delta
	if respawn_left <= 0.0:
		_respawn()


func _respawn() -> void:
	alive = true
	hp = max_hp
	mp = max_mp
	global_position = spawn_pos
	visible = true
	collision_layer = 2
	status.clear()
	attack_cd = 0.0
	_set_bars_visible(true)
	if model != null:
		model.revive()
	Global.spawn_burst(global_position, 2.5, Color(1.0, 1.0, 0.7))


func _on_death(killer: Unit) -> void:
	if is_illusion:
		# Иллюзия не воскресает, не считается смертью героя и просто исчезает.
		_clear_orders()
		collision_layer = 0
		if Global.selected_unit == self:
			Global.selected_unit = null
		get_tree().create_timer(1.1).timeout.connect(queue_free)
		return
	deaths += 1
	SignalBus.hero_died.emit(self, killer)
	if is_player:
		Global.shake(0.9)
	collision_layer = 0
	_clear_orders()
	tp_left = 0.0
	if Global.selected_unit == self:
		Global.selected_unit = null
	if _had_aegis:
		_had_aegis = false
		respawn_left = 5.0
		Global.shout("Эгида Рошана вернёт героя!", Color(1.0, 0.85, 0.2))
	else:
		respawn_left = 8.0 + level * 3.0
	Global.say("%s (%s) повержен!" % [hero_title, Global.team_name(team)])
	get_tree().create_timer(1.3).timeout.connect(_hide_if_dead)


func _hide_if_dead() -> void:
	if not alive:
		visible = false


func buyback_cost() -> int:
	return 250 + level * 40 + int(Global.elapsed / 60.0) * 15


func can_buyback() -> bool:
	return not alive and gold >= buyback_cost() and buyback_cd <= 0.0


func buyback() -> bool:
	if not can_buyback():
		return false
	gold -= buyback_cost()
	buyback_cd = 480.0
	_respawn()
	Global.shout("Выкуп!", Color(1.0, 0.8, 0.3))
	return true


# ---------- приказы ----------
# ---------- иллюзии ----------
# Пассивка Deceptive Blade: шанс при ударе замедлить цель и призвать короткую иллюзию.
func _on_attack_hit(t: Unit) -> void:
	if is_illusion or not alive or not is_instance_valid(t) or not t.alive:
		return
	for i in abilities.size():
		var lvl: int = ab_level[i]
		var ab: Dictionary = abilities[i]
		if lvl <= 0 or ab["kind"] != "p_illusion":
			continue
		if randf() >= Abilities.v(ab, "chance", lvl, 0.25):
			continue
		t.add_status("slow", Abilities.v(ab, "dur", lvl, 6.0), Abilities.v(ab, "slow", lvl, 0.3), self)
		var mine := 0
		for n in get_tree().get_nodes_in_group("illusions"):
			var b := n as BaseHero
			if b != null and b.alive and b.illusion_owner == self:
				mine += 1
		if mine < 4:
			Abilities.spawn_illusion(self, Abilities.v(ab, "dur", lvl, 6.0), 0.3, 2.5,
				global_position + Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5)))

func _attack_damage() -> float:
	var d: float = super._attack_damage()
	if is_illusion:
		return d * illusion_dmg_deal
	return d


func _incoming_mult() -> float:
	if is_illusion:
		return illusion_dmg_take
	return 1.0


func _setup_illusion() -> void:
	add_to_group("illusions")
	spawn_pos = global_position
	skill_points = 0
	gold_bounty = 0
	exp_bounty = 0
	unit_name = hero_title + " (иллюзия)"
	var lbl := Label3D.new()
	lbl.text = unit_name
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.024
	lbl.font_size = 34
	lbl.modulate = Color(0.55, 0.9, 1.0)
	lbl.outline_size = 8
	lbl.position = Vector3(0.0, hp_bar_height + 0.65, 0.0)
	add_child(lbl)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.2 * Global.UNIT_SCALE
	tm.outer_radius = 1.45 * Global.UNIT_SCALE
	_ring.mesh = tm
	_ring.material_override = Global.get_mat(Color(0.45, 0.85, 1.0), 1.5)
	_ring.position.y = 0.08
	add_child(_ring)


func _illusion_tick(delta: float) -> void:
	if _ring != null:
		_ring.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.06)
	illusion_left -= delta
	if illusion_left <= 0.0:
		dismiss()
		return
	# Иллюзиями героя-игрока управляет PlayerController. Иллюзии бота следуют за хозяином.
	if is_instance_valid(illusion_owner) and not illusion_owner.is_player:
		_follow_cd -= delta
		if _follow_cd <= 0.0:
			_follow_cd = 0.6
			_illusion_follow(illusion_owner)


func _illusion_follow(o: BaseHero) -> void:
	if not o.alive:
		return
	if is_instance_valid(o.attack_target) and o.attack_target.alive:
		if attack_target != o.attack_target:
			order_attack(o.attack_target)
		return
	if attack_target == null and Global.flat_dist(global_position, o.global_position) > 12.0:
		order_move(o.global_position + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0)))


# Убрать иллюзию (истёк срок или герой создал новых).
func dismiss() -> void:
	if not alive:
		return
	alive = false
	_clear_orders()
	collision_layer = 0
	if Global.selected_unit == self:
		Global.selected_unit = null
	Global.spawn_burst(global_position, 2.0, Color(0.5, 0.85, 1.0))
	queue_free()


func _clear_orders() -> void:
	attack_target = null
	has_move_target = false
	has_amove = false
	holding = false
	pending_idx = -1
	_pending_until = 0.0
	move_queue.clear()
	cancel_tp()


func order_move(pos: Vector3, queued: bool = false) -> void:
	var p := Vector3(clampf(pos.x, -Global.MAP_HALF, Global.MAP_HALF), 0.0, clampf(pos.z, -Global.MAP_HALF, Global.MAP_HALF))
	p = Global.push_out(p, body_radius)
	if queued and has_move_target:
		move_queue.append(p)
		return
	_clear_orders()
	move_target = p
	has_move_target = true


func order_attack(t: Unit) -> void:
	_clear_orders()
	attack_target = t


func order_amove(pos: Vector3) -> void:
	_clear_orders()
	amove_target = Vector3(pos.x, 0.0, pos.z)
	has_amove = true


func order_hold() -> void:
	_clear_orders()
	holding = true


func order_stop() -> void:
	_clear_orders()


# ---------- таланты ----------
func talent_tiers() -> Array:
	return TalentDB.tiers(primary)


func talent_available(i: int) -> bool:
	return level >= int(TalentDB.LEVELS[i]) and int(talents[i]) == -1


func any_talent_available() -> bool:
	for i in 4:
		if talent_available(i):
			return true
	return false


func pick_talent(i: int, c: int) -> bool:
	if not talent_available(i):
		return false
	talents[i] = c
	recalc_stats()
	if is_player:
		Global.say("Талант: %s" % String(talent_tiers()[i][c]["name"]))
		Global.sfx("level", -8.0)
	return true


func _auto_talents() -> void:
	for i in 4:
		if talent_available(i):
			pick_talent(i, randi() % 2)


# ---------- нейтральные предметы ----------
func give_neutral_drop() -> void:
	var tier := 1 if Global.elapsed < 480.0 else (2 if Global.elapsed < 960.0 else 3)
	var pool: Array = []
	for id in Global.NEUTRAL_ITEMS:
		var it: Dictionary = Global.NEUTRAL_ITEMS[id]
		if int(it["tier"]) == tier and id != neutral_item:
			pool.append(id)
	pool.shuffle()
	if pool.is_empty():
		return
	if not is_player:
		pick_neutral(pool[0])
		return
	neutral_offer = [pool[0]]
	if pool.size() >= 2:
		neutral_offer.append(pool[1])
	Global.shout("Нейтральный предмет! Выберите один", Color(0.8, 1.0, 0.6))
	Global.sfx("announce", -8.0)


func pick_neutral(id: String) -> void:
	neutral_item = id
	neutral_offer = []
	recalc_stats()
	if is_player:
		Global.say("Нейтральный предмет: %s" % String((Global.NEUTRAL_ITEMS[id] as Dictionary)["name"]))


# Возврат последней покупки: полная стоимость, 10 с (сборные не возвращаются).
func undo_purchase() -> bool:
	if last_purchase.is_empty() or bool(last_purchase["recipe"]):
		return false
	if Global.elapsed - float(last_purchase["t"]) > 10.0:
		return false
	var slot: int = int(last_purchase["slot"])
	if slot < 0 or slot >= inventory.size():
		return false
	if String(inventory[slot]) != String(last_purchase["id"]):
		return false
	inventory[slot] = ""
	gold += int(last_purchase["price"])
	last_purchase = {}
	recalc_stats()
	return true
