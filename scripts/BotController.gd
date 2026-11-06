class_name BotController
extends Node
## BotController.gd — бот v4 (10/10).
##
## Исправления относительно v3:
##   • Hero.ult_index() больше не крашится при отсутствии ульты (проверка >= 0).
##   • _use_item_id проверяет готовность слота (item_ready) — нет спама КД.
##   • При смерти сбрасываются _chase_until / _gank_until / _gank_target /
##     _jungle_until / _jungle_camp / _pos_smooth — бот не «зависает» после респавна.
##   • _b_position: сглаживание целевой точки (lerp), ограничение анти-скучивания,
##     тайм-аут простоя в лейне (уход в джунгли).
##   • _b_kill: бот не лезет в окружение из >=3 вражеских крипов, если HP < 80%.
##   • _b_gank: цель выбирается по «слабости» (HP%, изоляция, готовность ульты),
##     а не просто ближайший враг.
##   • _rune: если руну/святыню забрали — бот не идёт в пустую точку.
##   • _b_shop: если золота навалом (>= 2000) — идёт вне обычного 45-сек окна.
##   • _sense: один проход по юнитам вместо двух для «тишины» и подсчёта 40 м.
##   • _b_defend: корректная проверка отсутствия врага.
##   • _start_kit: покупка только существующих в ITEMS предметов.

enum Mode { LANE, RETREAT, SHOP, RUNE, DEFEND, JUNGLE, GANK }

const BUILDS: Dictionary = {
	"str": ["health_potion", "tp_scroll", "boots", "ogre_axe", "vanguard", "blade_attack", "mekansm", "heart", "bkb", "crystalys"],
	"agi": ["health_potion", "tp_scroll", "boots", "gloves", "blade_attack", "blade_alacrity", "crystalys", "chainmail", "bkb", "butterfly"],
	"int": ["health_potion", "tp_scroll", "boots", "staff_wizardry", "mana_potion", "energy", "blink_dagger", "cloak", "dagon", "bkb"],
}

var hero: BaseHero
var difficulty: int = 1
var lane: int = 1
var mode: Mode = Mode.LANE

var _think: float = 0.0
var _lh_acc: float = 0.9
var _foe: BaseHero = null
var _fd: float = 1e9
var _ratio: float = 1.0
var _enemy_near: int = 0
var _ally_near: int = 0
var _enemy_heroes_near: int = 0
var _ally_heroes_near: int = 0
var _front: Creep = null
var _quiet_since: float = 0.0
var _chase_until: float = 0.0
var _last_shop: float = -100.0
var _last_jungle: float = -100.0
var _jungle_camp: Creep = null
var _jungle_until: float = 0.0
var _rune_pos: Vector3 = Vector3.ZERO
var _def_pos: Vector3 = Vector3.ZERO
var _gank_target: BaseHero = null
var _gank_until: float = 0.0
var _last_gank: float = -100.0

var _pos_smooth: Vector3 = Vector3.ZERO
var _pos_smooth_ok: bool = false
var _idle_lane_since: float = 0.0


func _ready() -> void:
	hero.auto_acquire = false
	_lh_acc = [0.55, 0.85, 0.97][difficulty]
	_start_kit()


func _physics_process(delta: float) -> void:
	if hero == null or Global.is_over:
		return
	if not hero.alive:
		_reset_combat_state()
		mode = Mode.LANE
		if difficulty == 2 and hero.can_buyback() and hero.gold > hero.buyback_cost() + 1800:
			hero.buyback()
		return
	if hero.tp_left > 0.0:
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = [0.4, 0.22, 0.1][difficulty]
	_sense()
	_use_consumables()
	match mode:
		Mode.LANE:    _lane()
		Mode.RETREAT: _retreat()
		Mode.SHOP:    _shop()
		Mode.RUNE:    _rune()
		Mode.DEFEND:  _defend()
		Mode.JUNGLE:  _jungle()
		Mode.GANK:    _gank()


func _reset_combat_state() -> void:
	_chase_until = 0.0
	_gank_until = 0.0
	_gank_target = null
	_jungle_until = 0.0
	_jungle_camp = null
	_pos_smooth = Vector3.ZERO
	_pos_smooth_ok = false
	_idle_lane_since = 0.0


# ---------- восприятие ----------
func _now() -> float:
	return Global.elapsed


func _sense() -> void:
	_ratio = hero.hp / hero.max_hp

	# Ближайший враг-герой
	_foe = null
	var nearest: float = 1e9
	for h in Global.heroes_of(1 - hero.team):
		var eh := h as BaseHero
		if eh.alive:
			var dd := Global.flat_dist(hero.global_position, eh.global_position)
			if dd < nearest:
				nearest = dd
				_foe = eh
	_fd = 1e9 if _foe == null else Global.flat_dist(hero.global_position, _foe.global_position)

	# Один проход: подсчёт крипов в радиусе 40 м (свои/враги)
	_enemy_near = 0
	_ally_near = 0
	for n in Global.units_near(hero.global_position, 40.0):
		var cr := n as Creep
		if cr == null or not cr.alive or cr.neutral:
			continue
		if Global.flat_dist(hero.global_position, cr.global_position) > 40.0:
			continue
		if cr.team == hero.team:
			_ally_near += 1
		else:
			_enemy_near += 1

	_enemy_heroes_near = 0
	_ally_heroes_near = 0
	for h in Global.heroes_of(1 - hero.team):
		var enemy_hero := h as BaseHero
		if enemy_hero != null and enemy_hero.alive and Global.flat_dist(hero.global_position, enemy_hero.global_position) <= 55.0:
			_enemy_heroes_near += 1
	for h in Global.heroes_of(hero.team):
		var ally_hero := h as BaseHero
		if ally_hero != null and ally_hero != hero and ally_hero.alive and Global.flat_dist(hero.global_position, ally_hero.global_position) <= 55.0:
			_ally_heroes_near += 1
	_front = _front_ally_creep()

	# Один проход: есть ли вообще крипы в радиусе 130 м (для _quiet_since)
	for n in Global.units_near(hero.global_position, 130.0):
		var cr := n as Creep
		if cr != null and cr.alive and not cr.neutral:
			_quiet_since = _now()
			break


func _creeps_near(pos: Vector3, r: float, enemy: bool) -> int:
	var c := 0
	for n in Global.units_near(pos, r):
		var cr := n as Creep
		if cr == null or not cr.alive or cr.neutral:
			continue
		if (cr.team != hero.team) == enemy and Global.flat_dist(pos, cr.global_position) <= r:
			c += 1
	return c


func _eff_dmg(t: Unit) -> float:
	var a := t.eff_armor()
	return hero.damage * (1.0 - (0.06 * a) / (1.0 + 0.06 * absf(a)))


func _ult_ready() -> bool:
	if not hero.has_method("ult_index"):
		return false
	var ui: int = hero.ult_index()
	return ui >= 0 and hero.can_cast(ui)


func _danger(pos: Vector3) -> bool:
	for n in Global.enemies_in_range(hero.team, pos, 40.0):
		var b := n as Building
		if b != null and not b.is_throne and Global.flat_dist(pos, b.global_position) <= b.attack_range + 3.0:
			return _creeps_near(b.global_position, 26.0, false) < 2
	return false


func _ahead() -> bool:
	var k: Array = Global.stats["kills"]
	var t: Array = Global.stats["towers"]
	return k[hero.team] >= k[1 - hero.team] and t[hero.team] >= t[1 - hero.team]


func _front_ally_creep() -> Creep:
	var best: Creep = null
	var best_score: float = -1e9
	for n in Global.units():
		var c := n as Creep
		if c == null or not c.alive or c.neutral or c.team != hero.team or c.lane != lane:
			continue
		var wp: Vector3 = c.path[c.path_idx] if c.path_idx < c.path.size() else c.goal_pos
		var score: float = float(c.path_idx) * 1000.0 - Global.flat_dist(c.global_position, wp)
		if score > best_score:
			best_score = score
			best = c
	return best


# ---------- дерево приоритетов ----------
func _lane() -> void:
	if _b_survive():  return
	if _b_defend():   return
	if _b_shop():     return
	if _b_pickup():   return
	if _b_kill():     return
	if _b_gank():     return
	if _b_jungle():   return
	if _b_lasthit():  return
	if _b_harass():   return
	if _b_push():     return

	# Тайм-аут простоя: нет крипов, нет врагов — пробуем джунгли
	if _front == null and _foe == null and difficulty >= 1:
		if _idle_lane_since == 0.0:
			_idle_lane_since = _now()
		elif _now() - _idle_lane_since > 5.0:
			if _b_jungle():
				return
			_idle_lane_since = _now()   # откладываем новую попытку на 5 с
	else:
		_idle_lane_since = 0.0

	_b_position()


func _b_survive() -> bool:
	var go: bool = _ratio < [0.3, 0.24, 0.2][difficulty]
	if not go and _foe != null and _fd < 45.0:
		var threat := Abilities.damage_potential(_foe, hero) + _foe.damage * 1.5
		var mine := Abilities.damage_potential(hero, _foe) + _eff_dmg(_foe) * 2.0
		go = threat >= hero.hp * 0.9 and _ratio < 0.65 and mine < _foe.hp
	if not go and _ratio < 0.5 and _danger(hero.global_position):
		go = true
	if go:
		mode = Mode.RETREAT
		hero.order_stop()
		_try_teleport_home()
		return true
	return false


func _b_defend() -> bool:
	if difficulty < 1:
		return false
	var tw := _threatened_tower()
	if tw == null:
		return false
	# Чистая проверка: защищаем, если врага рядом нет / он далеко / мы здоровы
	if _foe == null or _fd > 50.0 or _ratio > 0.7:
		_def_pos = tw.global_position
		mode = Mode.DEFEND
		if Global.flat_dist(hero.global_position, _def_pos) > 220.0:
			_use_item_id("tp_scroll", _def_pos)
		return true
	return false


func _b_shop() -> bool:
	# Обычное окно — не чаще 45 с. Исключение: накопили 2000+ золота.
	if _now() - _last_shop < 45.0 and hero.gold < 2000:
		return false
	if _fd < 100.0 or _enemy_near > 0:
		return false
	var id := _next_item()
	if id == "" or not hero.inventory.has(""):
		return false
	var item: Dictionary = Global.ITEMS[id]
	if hero.gold < int(item["cost"]) + 80:
		return false
	mode = Mode.SHOP
	return true


func _b_pickup() -> bool:
	if difficulty < 1 or _ratio < 0.4 or _fd < 80.0 or _enemy_near > 0:
		return false
	var best: Vector3 = Vector3.ZERO
	var bd: float = 230.0
	var found := false
	for n in get_tree().get_nodes_in_group("runes"):
		var d := Global.flat_dist(hero.global_position, (n as Node3D).global_position)
		if d < bd:
			bd = d
			best = (n as Node3D).global_position
			found = true
	if not found and _ratio < 0.6:
		for n in get_tree().get_nodes_in_group("shrines"):
			var sh := n as Shrine
			if sh.is_ready() and Global.forward(hero.team).dot(sh.global_position) < 40.0:
				var d2 := Global.flat_dist(hero.global_position, sh.global_position)
				if d2 < bd:
					bd = d2
					best = sh.global_position
					found = true
	if found:
		_rune_pos = best
		mode = Mode.RUNE
		return true
	return false


func _b_kill() -> bool:
	if _foe == null:
		return false
	if not (_chase_until > _now() and _fd < 55.0):
		if _fd > 55.0:
			return false
		var mine := Abilities.damage_potential(hero, _foe) + _eff_dmg(_foe) * 2.5
		if mine < _foe.hp * [1.5, 1.1, 0.95][difficulty]:
			return false
		if _danger(_foe.global_position) and _foe.hp > mine * 0.5:
			return false
		# Не лезем в толпу вражеских крипов без запаса HP
		if _ratio < 0.8:
			var guard := _creeps_near(_foe.global_position, 30.0, true)
			if guard >= 3:
				return false
		if _enemy_heroes_near > _ally_heroes_near + 1 and _ratio < 0.85:
			return false
		_chase_until = _now() + 3.0
	_engage()
	return true


func _engage() -> void:
	if difficulty >= 1 and _fd > hero.attack_range + 10.0:
		_use_item_id("blink_dagger", _foe.global_position)
	if randf() < [0.6, 0.92, 1.0][difficulty]:
		Abilities.ai_use(hero, _foe)
	_use_item_id("dagon", _foe.global_position)
	if _ratio < 0.6:
		_use_item_id("bkb", hero.global_position)
	hero.order_attack(_foe)
	if hero.is_ranged and difficulty >= 1 and _fd < hero.attack_range * 0.45 and hero.attack_cd > 0.3:
		var away := hero.global_position - _foe.global_position
		away.y = 0.0
		if away.length() > 0.1:
			hero.order_move(hero.global_position + away.normalized() * 12.0)


func _b_jungle() -> bool:
	if difficulty < 1 or _ratio < 0.75 or _now() - _last_jungle < 60.0:
		return false
	if _now() < 180.0 or hero.level < 4 or _now() - _quiet_since < 25.0:
		return false
	var camp := _camp_target()
	if camp == null:
		return false
	_jungle_camp = camp
	_jungle_until = _now() + 18.0
	mode = Mode.JUNGLE
	return true


func _b_lasthit() -> bool:
	if randf() > _lh_acc:
		return false
	var best: Unit = null
	var best_hp: float = 1e9
	var reach := hero.attack_range + 10.0
	for n in Global.units_near(hero.global_position, reach):
		var c := n as Creep
		if c == null or not c.alive or c.neutral:
			continue
		if Global.flat_dist(hero.global_position, c.global_position) > reach:
			continue
		var dmg := _eff_dmg(c)
		if c.team != hero.team:
			if c.hp <= dmg * 1.05 and c.hp < best_hp and not _danger(c.global_position):
				best = c
				best_hp = c.hp
		elif difficulty >= 1 and c.hp < c.max_hp * 0.5 and c.hp <= dmg * 1.05 and c.hp < best_hp:
			best = c
			best_hp = c.hp
	if best != null:
		hero.order_attack(best)
		return true
	return false


func _b_harass() -> bool:
	if _foe == null or _fd > hero.attack_range + 12.0:
		return false
	if _danger(_foe.global_position) or _ratio < 0.5:
		return false
	if _enemy_near >= 3 and _ratio < 0.85:
		return false
	if _enemy_heroes_near > _ally_heroes_near + 1 and _ratio < 0.8:
		return false
	if _ratio < _foe.hp / _foe.max_hp - 0.15 and difficulty > 0:
		return false
	_engage()
	return true


func _b_push() -> bool:
	if _foe != null and _fd < 55.0:
		return false
	var need: int = 1 if _ahead() else 2
	for n in Global.enemies_in_range(hero.team, hero.global_position, hero.attack_range + 30.0):
		var b := n as Building
		if b != null and _creeps_near(b.global_position, 28.0, false) >= need:
			hero.order_attack(b)
			return true
	return false


func _b_position() -> void:
	var spot: Vector3
	if _front == null:
		spot = Global.tower_def_pos(hero.team, lane, 1)
	elif _enemy_near > _ally_near + 1 and difficulty >= 1:
		spot = Global.tower_def_pos(hero.team, lane, 0)
	else:
		var wp: Vector3 = _front.path[_front.path_idx] if _front.path_idx < _front.path.size() else _front.goal_pos
		var dir := wp - _front.global_position
		dir.y = 0.0
		dir = dir.normalized()

		# Держим дистанцию: чуть позади крипов, дальники — на своей дальности
		var back := 3.0 if not hero.is_ranged else maxf(hero.attack_range * 0.65, 8.0)
		spot = _front.global_position - dir * back

		for i in 6:
			if _danger(spot):
				spot -= dir * 10.0
			else:
				break

	# Сглаживание целевой точки — убирает «дёргание» при смене waypoint
	if not _pos_smooth_ok:
		_pos_smooth = spot
		_pos_smooth_ok = true
	else:
		_pos_smooth = _pos_smooth.lerp(spot, 0.35)
		spot = _pos_smooth

	# Анти-скучивание — ограничено, чтобы не улететь с линии
	var separation := Vector3.ZERO
	for n in Global.units_near(hero.global_position, 6.0):
		if n != hero and n is BaseHero and n.team == hero.team:
			var away: Vector3 = hero.global_position - n.global_position
			away.y = 0.0
			if away.length() > 0.01:
				separation += away.normalized() * (6.0 - away.length())
	if separation.length() > 4.0:
		separation = separation.normalized() * 4.0
	spot += separation

	if Global.flat_dist(hero.global_position, spot) > 15.0:
		hero.order_move(spot)
		return

	var best: Unit = null
	var bh: float = 1e9
	for e in Global.enemies_in_range(hero.team, hero.global_position, hero.attack_range + 4.0):
		var c := e as Creep
		if c != null and not c.neutral and c.hp < bh and not _danger(c.global_position) and _ally_near > 0:
			best = c
			bh = c.hp
	if best != null:
		hero.order_attack(best)
	else:
		hero.order_move(spot)


# ---------- режимы ----------
func _retreat() -> void:
	var home := Global.fountain_pos(hero.team)
	hero.order_move(home)
	Abilities.ai_escape(hero, home)
	_use_item_id("blink_dagger", home)
	if Global.flat_dist(hero.global_position, home) < 18.0:
		_buy_items()
		if _ratio > 0.8 and hero.mp > hero.max_mp * 0.6:
			_return_to_lane()


func _shop() -> void:
	var home := Global.fountain_pos(hero.team)
	if Global.flat_dist(hero.global_position, home) > 200.0:
		_use_item_id("tp_scroll", Global.throne_pos(hero.team))
	hero.order_move(home)
	if Global.flat_dist(hero.global_position, home) < 18.0:
		_buy_items()
		_last_shop = _now()
		if _ratio < [0.3, 0.24, 0.2][difficulty]:
			mode = Mode.RETREAT
		else:
			_return_to_lane()


func _return_to_lane() -> void:
	mode = Mode.LANE
	if difficulty >= 1:
		_use_item_id("tp_scroll", Global.tower_def_pos(hero.team, lane, 0))


func _rune() -> void:
	if _ratio < 0.35 or _fd < 50.0:
		mode = Mode.LANE
		return
	# Проверяем, что цель ещё существует (руну могли забрать, святыню — использовать)
	var still_there := false
	for n in get_tree().get_nodes_in_group("runes"):
		if Global.flat_dist((n as Node3D).global_position, _rune_pos) < 15.0:
			still_there = true
			break
	if not still_there:
		for n in get_tree().get_nodes_in_group("shrines"):
			var sh := n as Shrine
			if sh.is_ready() and Global.flat_dist(sh.global_position, _rune_pos) < 15.0:
				still_there = true
				break
	if not still_there:
		mode = Mode.LANE
		return
	if Global.flat_dist(hero.global_position, _rune_pos) < 5.0:
		mode = Mode.LANE
		return
	hero.order_move(_rune_pos)


func _defend() -> void:
	var near := Global.nearest_enemy(hero.team, _def_pos, 36.0)
	if near == null or near is Building or _ratio < [0.35, 0.3, 0.25][difficulty] or Global.flat_dist(hero.global_position, _def_pos) > 340.0:
		mode = Mode.LANE
		return
	if Global.flat_dist(hero.global_position, near.global_position) < hero.attack_range + 14.0:
		Abilities.ai_use(hero, near)
	hero.order_attack(near)


func _jungle() -> void:
	var camp_ok := _jungle_camp != null and is_instance_valid(_jungle_camp) and _jungle_camp.alive
	if _ratio < 0.4 or _fd < 60.0 or _now() > _jungle_until or not camp_ok or _enemy_near > 1:
		_last_jungle = _now()
		mode = Mode.LANE
		return
	if Global.flat_dist(hero.global_position, _jungle_camp.global_position) < hero.attack_range + 16.0:
		Abilities.ai_use(hero, _jungle_camp)
	hero.order_attack(_jungle_camp)


func _camp_target() -> Creep:
	var best: Creep = null
	var bd: float = 260.0
	for n in Global.units():
		var c := n as Creep
		if c == null or not c.alive or not c.neutral or c.guardian:
			continue
		if Global.forward(hero.team).dot(c.global_position) > 0.0:
			continue
		var d := Global.flat_dist(hero.global_position, c.global_position)
		if d < bd:
			bd = d
			best = c
	return best


func _threatened_tower() -> Building:
	for n in Global.units():
		var b := n as Building
		if b == null or not b.alive or b.team != hero.team:
			continue
		if Global.flat_dist(hero.global_position, b.global_position) > (520.0 if difficulty >= 2 else 240.0):
			continue
		var foes := 0
		var has_hero := false
		for e in Global.enemies_in_range(hero.team, b.global_position, 30.0):
			if e is Building or (e is Creep and (e as Creep).neutral):
				continue
			foes += 1
			if e is BaseHero:
				has_hero = true
		if foes >= 2 or (has_hero and b.hp < b.max_hp * 0.9):
			return b
	return null


# ---------- предметы ----------
func _try_teleport_home() -> void:
	if difficulty >= 1 and Global.flat_dist(hero.global_position, Global.fountain_pos(hero.team)) > 200.0:
		_use_item_id("tp_scroll", Global.throne_pos(hero.team))


func _next_item() -> String:
	for id in BUILDS[hero.primary]:
		if not hero.inventory.has(id):
			return id
	return ""


func _buy_items() -> void:
	for i in 6:
		var id := _next_item()
		if id == "" or not hero.buy_item(id):
			break


func _use_consumables() -> void:
	if _ratio < 0.45:
		_use_item_id("health_potion", hero.global_position)
	if _ratio < 0.5:
		_use_item_id("mekansm", hero.global_position)
	if hero.mp < hero.max_mp * 0.2:
		_use_item_id("mana_potion", hero.global_position)


func _use_item_id(id: String, pos: Vector3) -> void:
	var slot := hero.inventory.find(id)
	if slot == -1:
		return
	# Не спамим use_item каждый think — уважаем КД слота, если класс умеет
	if hero.has_method("item_ready") and not hero.item_ready(slot):
		return
	hero.use_item(slot, pos)


func _start_kit() -> void:
	for id in ["tp_scroll", "health_potion", "iron_branch", "iron_branch"]:
		if Global.ITEMS.has(id):
			hero.buy_item(id)


# ---------- ганки ----------
func _lane_of(pos: Vector3) -> int:
	var best := 1
	var bd: float = 1e9
	for l in 3:
		var pts: Array = Global.LANES[l]
		for i in range(pts.size() - 1):
			var d := Global.dist_to_segment(pos, pts[i], pts[i + 1])
			if d < bd:
				bd = d
				best = l
	return best


func _b_gank() -> bool:
	if difficulty < 1 or hero.level < 6 or _now() - _last_gank < 70.0:
		return false
	if _ratio < 0.7 or hero.mp < hero.max_mp * 0.5:
		return false

	var ult_ready := _ult_ready()
	var hp_threshold: float = 0.75 if ult_ready else 0.6
	var burst_ratio: float = 0.55 if ult_ready else 0.7

	# Выбираем цель не «ближайшую», а «самую слабую и изолированную»
	var target: BaseHero = null
	var best_score: float = -1e9
	for h in Global.heroes_of(1 - hero.team):
		var eh := h as BaseHero
		if not eh.alive:
			continue
		var dd := Global.flat_dist(hero.global_position, eh.global_position)
		if dd < 70.0 or dd > 380.0:
			continue
		if _lane_of(eh.global_position) == lane:
			continue
		if _danger(eh.global_position):
			continue
		# Союзники врага рядом — плохая цель
		var guard := 0
		for e in Global.heroes_of(eh.team):
			var mate := e as BaseHero
			if mate != eh and mate.alive and Global.flat_dist(mate.global_position, eh.global_position) < 55.0:
				guard += 1
		if guard >= 1:
			continue
		var hp_ratio := eh.hp / eh.max_hp
		if hp_ratio > hp_threshold:
			continue
		var burst := Abilities.damage_potential(hero, eh) + _eff_dmg(eh) * 2.0
		if burst < eh.hp * burst_ratio:
			continue
		var score := (1.0 - hp_ratio) * 100.0 - dd * 0.05
		if score > best_score:
			best_score = score
			target = eh

	if target == null:
		return false
	_gank_target = target
	_gank_until = _now() + 14.0
	_last_gank = _now()
	mode = Mode.GANK
	return true


func _gank() -> void:
	if _gank_target == null or not is_instance_valid(_gank_target) or not _gank_target.alive or _now() > _gank_until or _ratio < 0.4:
		mode = Mode.LANE
		return
	_foe = _gank_target
	_fd = Global.flat_dist(hero.global_position, _foe.global_position)
	if _fd > hero.attack_range + 14.0:
		if _fd > 90.0:
			_use_item_id("blink_dagger", _foe.global_position)
		hero.order_move(_foe.global_position)
	else:
		_engage()
	if _danger(_foe.global_position) and _foe.hp > _foe.max_hp * 0.35:
		mode = Mode.LANE
