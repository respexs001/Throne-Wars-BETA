extends Node
## Global.gd — Autoload. v1.0.2 (фиксы после ревью).
##
## Что изменено:
##   • elapsed тикает только когда есть player_hero — меню больше не «съедает» время матча.
##   • reset_stats() полностью сбрасывает состояние партии: multi, last_kill_t, pings,
##     pinch_latch, in_prematch, кэш героев.
##   • add_obstacle() регистрирует препятствие во ВСЕ клетки, которые оно перекрывает —
##     push_out() больше не пропускает большие здания.
##   • team_name() возвращает «Нейтралы» для team == 2.
##   • heroes_of() кэшируется по физическому кадру (как units()).
##   • _build_sfx() — 12 плееров вместо 6 (запас под одновременные эффекты в толпе).
##   • Комментарий quality: 0–3 (соответствует 4 пресетам из MainMenu).
##   • Стилистика: not in вместо not X in Y.
##   • fountain_pos() — комментарий о положении (проверить на геймплее).

signal message(text: String)
signal announce(text: String, color: Color)
signal game_over(winner_team: int)
signal request_pause

const VERSION: String = "1.0.3-alpha.1"
const SAVE_PATH: String = "user://settings.cfg"

# ---------- МАСШТАБ И БАЛАНС ----------
const MAP_SCALE: float = 3.0
const MAP_HALF: float = 300.0
const BASE_POS: float = 216.0
const SHOP_RADIUS: float = 60.0
const FOUNTAIN_R: float = 55.0
const LANE_WIDTH: float = 26.0
const MAX_LEVEL: int = 25
const UNIT_SCALE: float = 3.0
const SPEED_MULT: float = 1.8
const RANGE_MULT: float = 1.4
const DMG_MULT: float = 0.78
const CD_MULT: float = 1.2
const MANA_MULT: float = 1.15

# Исходные координаты (до масштабирования). Линии идут от базы Света к базе Тьмы.
const _LANES0: Array = [
	[Vector3(-78.0, 0.0, 55.0), Vector3(-78.0, 0.0, 0.0), Vector3(-78.0, 0.0, -62.0),
	 Vector3(-62.0, 0.0, -78.0), Vector3(0.0, 0.0, -78.0), Vector3(60.0, 0.0, -78.0)],
	[Vector3(-60.0, 0.0, 60.0), Vector3(-30.0, 0.0, 30.0), Vector3(0.0, 0.0, 0.0),
	 Vector3(30.0, 0.0, -30.0), Vector3(60.0, 0.0, -60.0)],
	[Vector3(-55.0, 0.0, 78.0), Vector3(0.0, 0.0, 78.0), Vector3(62.0, 0.0, 78.0),
	 Vector3(78.0, 0.0, 62.0), Vector3(78.0, 0.0, 0.0), Vector3(78.0, 0.0, -55.0)],
]
const _TOWERS0: Array = [
	[0, 0, -78.0, -25.0], [0, 1, -78.0, 10.0], [0, 2, -78.0, 40.0],
	[1, 0, -22.0, 22.0], [1, 1, -40.0, 40.0], [1, 2, -54.0, 54.0],
	[2, 0, 25.0, 78.0], [2, 1, -5.0, 78.0], [2, 2, -38.0, 78.0],
]
const _T40: Array = [[-63.0, 68.0], [-68.0, 63.0]]
const _CAMPS0: Array = [Vector3(-20.0, 0.0, 55.0), Vector3(12.0, 0.0, 52.0),
	Vector3(-55.0, 0.0, 20.0), Vector3(-50.0, 0.0, -12.0)]
const _RUNES0: Array = [Vector3(-22.0, 0.0, -22.0), Vector3(22.0, 0.0, 22.0)]
const _BOUNTY0: Array = [Vector3(-10.0, 0.0, 40.0), Vector3(-62.0, 0.0, 5.0)]

var LANES: Array = []
var TOWER_DEFS: Array = []
var T4_DEFS: Array = []          # только для team == 0; Map.gd зеркалит для team 1
var CAMP_DEFS: Array = []
var RUNE_SPOTS: Array = []
var BOUNTY_SPOTS: Array = []
var GUARDIAN_POS: Vector3 = Vector3(135.0, 0.0, 135.0)

# ---------- ПРЕДМЕТЫ ----------
const ITEMS: Dictionary = {
	"health_potion": {"name": "Health Potion", "icon": "potion_hp", "cost": 120, "desc": "Актив: мгновенно +150 HP.", "stats": {},
		"active": {"kind": "heal_hp", "amount": 150.0, "cd": 5.0, "consume": true}},
	"mana_potion": {"name": "Mana Potion", "icon": "potion_mp", "cost": 90, "desc": "Актив: мгновенно +100 MP.", "stats": {},
		"active": {"kind": "heal_mp", "amount": 100.0, "cd": 5.0, "consume": true}},
	"tp_scroll": {"name": "Recall Scroll", "icon": "scroll", "cost": 110, "desc": "Актив: телепорт к ближайшему союзному зданию за 3.5 с. Движение отменяет.", "stats": {},
		"active": {"kind": "tp", "cd": 40.0, "consume": true}},
	"boots": {"name": "Boots of Speed", "icon": "boots", "cost": 540, "desc": "+2.5 к скорости бега.", "stats": {"ms": 2.5}},
	"ring_health": {"name": "Ring of Health", "icon": "ring", "cost": 420, "desc": "+4 к регенерации HP.", "stats": {"hp_regen": 4.0}},
	"iron_branch": {"name": "Iron Branch", "icon": "star", "cost": 180, "desc": "+2 ко всем характеристикам.", "stats": {"str": 2.0, "agi": 2.0, "int": 2.0}},
	"blade_attack": {"name": "Blade of Attack", "icon": "sword", "cost": 540, "desc": "+16 к урону.", "stats": {"dmg": 16.0}},
	"vitality": {"name": "Vitality Booster", "icon": "heart", "cost": 1300, "desc": "+300 к максимуму HP.", "stats": {"hp": 300.0}},
	"energy": {"name": "Energy Booster", "icon": "orb", "cost": 1080, "desc": "+250 к максимуму MP.", "stats": {"mp": 250.0}},
	"gloves": {"name": "Gloves of Haste", "icon": "fang", "cost": 720, "desc": "+30 к скорости атаки.", "stats": {"aspd": 30.0}},
	"chainmail": {"name": "Chainmail", "icon": "shield", "cost": 780, "desc": "+5 к броне.", "stats": {"armor": 5.0}},
	"cloak": {"name": "Cloak", "icon": "wind", "cost": 660, "desc": "+20% сопротивления магии.", "stats": {"mr": 0.2}},
	"ogre_axe": {"name": "Giant's Axe", "icon": "axe", "cost": 1200, "desc": "+10 к силе.", "stats": {"str": 10.0}},
	"blade_alacrity": {"name": "Blade of Agility", "icon": "arrow", "cost": 1200, "desc": "+10 к ловкости.", "stats": {"agi": 10.0}},
	"staff_wizardry": {"name": "Wizard Staff", "icon": "orb", "cost": 1200, "desc": "+10 к интеллекту.", "stats": {"int": 10.0}},
	"vanguard": {"name": "Vanguard", "icon": "shield", "cost": 2150, "desc": "+300 HP, +5 реген HP, блок 20 урона от каждой атаки.", "stats": {"hp": 300.0, "hp_regen": 5.0, "block": 20.0}},
	"crystalys": {"name": "Crystal Blade", "icon": "gem", "cost": 2500, "desc": "+28 к урону, 20% шанс критического удара x2.", "stats": {"dmg": 28.0, "crit": 0.2}},
	"mekansm": {"name": "Sanctum Idol", "icon": "heart", "cost": 2650, "desc": "+4 броня, +5 ко всем статам. Актив: лечит 250 HP союзникам рядом и даёт +6 брони на 10 с.", "stats": {"armor": 4.0, "str": 5.0, "agi": 5.0, "int": 5.0},
		"active": {"kind": "mekansm", "amount": 250.0, "radius": 12.0, "cd": 45.0, "mp": 40.0}},
	"blink_dagger": {"name": "Shift Dagger", "icon": "dash", "cost": 2700, "desc": "Актив: мгновенный рывок в точку (до 14 x 1.4).", "stats": {},
		"active": {"kind": "blink", "range": 14.0, "cd": 14.0}},
	"dagon": {"name": "Dagon", "icon": "bolt", "cost": 3350, "desc": "+8/8/12 к статам. Актив: 400 магического урона цели (дальность 14 x 1.4).", "stats": {"str": 8.0, "agi": 8.0, "int": 12.0},
		"active": {"kind": "dagon", "damage": 400.0, "range": 14.0, "cd": 28.0, "mp": 90.0}},
	"butterfly": {"name": "Zephyr Cloak", "icon": "wind", "cost": 5400, "desc": "+30 ловкость, +28 урон, 35% уклонения.", "stats": {"agi": 30.0, "dmg": 28.0, "evasion": 0.35}},
	"bkb": {"name": "Warding Crown", "icon": "crown", "cost": 4650, "desc": "+10 сила, +22 урон. Актив: иммунитет к магии 6 с.", "stats": {"str": 10.0, "dmg": 22.0},
		"active": {"kind": "bkb", "dur": 6.0, "cd": 75.0}},
	"heart": {"name": "Titan Heart", "icon": "heart", "cost": 6000, "desc": "+35 к силе, +6 к регенерации HP.", "stats": {"str": 35.0, "hp_regen": 6.0}},
	"battle_boots": {"name": "Battle Boots", "icon": "boots", "cost": 1560, "recipe": ["boots", "gloves"], "desc": "Сборка: Boots of Speed + Gloves of Haste. +3.5 скорость, +40 скорость атаки, +10 урон.", "stats": {"ms": 3.5, "aspd": 40.0, "dmg": 10.0}},
	"bulwark": {"name": "Bulwark", "icon": "shield", "cost": 1600, "recipe": ["chainmail", "ring_health"], "desc": "Сборка: Chainmail + Ring of Health. +8 броня, +6 реген HP, блок 15 урона.", "stats": {"armor": 8.0, "hp_regen": 6.0, "block": 15.0}},
	"arcane_orb": {"name": "Arcane Orb", "icon": "orb", "cost": 2630, "recipe": ["staff_wizardry", "energy"], "desc": "Сборка: Wizard Staff + Energy Booster. +18 интеллект, +400 мана, +2 реген маны.", "stats": {"int": 18.0, "mp": 400.0, "mp_regen": 2.0}},
	"warlord_blade": {"name": "Warlord Blade", "icon": "sword", "cost": 2190, "recipe": ["blade_attack", "ogre_axe"], "desc": "Сборка: Blade of Attack + Giant's Axe. +34 урон, +12 сила, 12% вампиризма.", "stats": {"dmg": 34.0, "str": 12.0, "lifesteal": 0.12}},
	"mage_cloak": {"name": "Mage Cloak", "icon": "wind", "cost": 2160, "recipe": ["cloak", "staff_wizardry"], "desc": "Сборка: Cloak + Wizard Staff. +30% сопротивления магии, +14 интеллект, +3 реген HP.", "stats": {"mr": 0.3, "int": 14.0, "hp_regen": 3.0}},
	"titan_plate": {"name": "Titan Plate", "icon": "heart", "cost": 2580, "recipe": ["vitality", "chainmail"], "desc": "Сборка: Vitality Booster + Chainmail. +500 здоровье, +6 броня.", "stats": {"hp": 500.0, "armor": 6.0}},
}
const ITEM_ORDER: Array = ["health_potion", "mana_potion", "tp_scroll", "boots", "ring_health", "iron_branch",
	"blade_attack", "gloves", "chainmail", "cloak", "ogre_axe", "blade_alacrity", "staff_wizardry",
	"vitality", "energy", "vanguard", "crystalys", "mekansm", "blink_dagger", "dagon", "butterfly", "bkb", "heart",
	"battle_boots", "bulwark", "arcane_orb", "warlord_blade", "mage_cloak", "titan_plate"]

# ---------- настройки и состояние ----------
var selected_hero: String = "titan"
var difficulty: int = 1
var control_mode: int = 0
var cast_mode: int = 2
var edge_scroll: bool = false
var shadows_on: bool = false
var player_team: int = 0
var selected_unit: Unit = null
var pinch_latch: bool = false
var is_over: bool = false
var is_day: bool = true
var elapsed: float = 0.0
var match_id: String = ""
var siege_waves: Array[int] = [0, 0]
var experimental: bool = false
var tutorial_seen: bool = false
var stats: Dictionary = {}
var first_blood_done: bool = false
var streak: Array = [0, 0]
var _mats: Dictionary = {}
var test_mode: bool = false
var tools_used: bool = false   # в матче использовались отладочные инструменты: статистика не пишется
var test_inf_mana: bool = false
var test_no_cd: bool = false
var _obs: Dictionary = {}
var _unit_cache: Array = []
var _grid: Dictionary = {}
const GRID_CELL: float = 30.0
var player_hero: BaseHero = null
var quality: int = 1                  # 0 низкое / 1 среднее / 2 высокое / 3 ультра (см. MainMenu)
var pings: Array = []
var team_size: int = 2
var fog_on: bool = true
var biome: String = "forest"
var res_scale: float = 1.0
var fps_cap: int = 60
var weather_on: bool = true
var volume: float = 1.0
var prematch_on: bool = true
var in_prematch: bool = false
var player_lane: int = 1
var terrain_amp: float = 2.5
var _hmap: PackedFloat32Array = PackedFloat32Array()
var _hnoise: FastNoiseLite = null
var _hills: Array = []
var last_kill_t: Array = [-99.0, -99.0]
var multi: Array = [0, 0]
var _sfx: Dictionary = {}
var _sfx_t: Dictionary = {}
var _players: Array = []
var _unit_frame: int = -1
var _unit_pframe: int = -1
var _heroes_frame: int = -1
var _heroes_by_team: Dictionary = {}


# A frame can contain tree removals between physics, timers and idle processing.
# Frame counters alone cannot define cache validity.
func invalidate_unit_cache() -> void:
	_unit_frame = -1
	_unit_pframe = -1
	_heroes_frame = -1


# Кэш всех юнитов на физический кадр.
func units() -> Array:
	var f := Engine.get_physics_frames()
	var pf := Engine.get_process_frames()
	# Кэш живёт не дольше одного физического И одного кадра отрисовки: узлы, освобождённые
	# через queue_free() между физ. шагами, не должны оставаться в кэше для _process-кода.
	if f != _unit_frame or pf != _unit_pframe:
		_unit_frame = f
		_unit_pframe = pf
		_unit_cache = get_tree().get_nodes_in_group("units")
		_grid.clear()
		for n in _unit_cache:
			if not is_instance_valid(n) or not n.is_inside_tree():
				continue
			var u := n as Unit
			if u == null or not u.alive:
				continue
			# Covers units that already existed when a running script was reloaded.
			if not u.tree_exited.is_connected(invalidate_unit_cache):
				u.tree_exited.connect(invalidate_unit_cache)
			var key := Vector2i(floori(u.global_position.x / GRID_CELL), floori(u.global_position.z / GRID_CELL))
			if not _grid.has(key):
				_grid[key] = []
			(_grid[key] as Array).append(u)
	return _unit_cache


# Юниты в окрестности точки (по сетке).
func units_near(pos: Vector3, r: float) -> Array:
	units()
	if r > 70.0:
		return _unit_cache
	var out: Array = []
	var x0 := floori((pos.x - r) / GRID_CELL)
	var x1 := floori((pos.x + r) / GRID_CELL)
	var z0 := floori((pos.z - r) / GRID_CELL)
	var z1 := floori((pos.z + r) / GRID_CELL)
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var k := Vector2i(cx, cz)
			if _grid.has(k):
				out.append_array(_grid[k])
	return out

const OBS_CELL: float = 12.0


func clear_obstacles() -> void:
	_obs.clear()


# Статическое препятствие: регистрируется во ВСЕ клетки, которые перекрывает.
# push_out() проверяет только 3x3 клетки вокруг юнита, поэтому препятствие
# должно быть «видно» из любой клетки, которую оно задевает.
func add_obstacle(p: Vector3, r: float) -> void:
	var x0 := floori((p.x - r) / OBS_CELL)
	var x1 := floori((p.x + r) / OBS_CELL)
	var z0 := floori((p.z - r) / OBS_CELL)
	var z1 := floori((p.z + r) / OBS_CELL)
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var key := Vector2i(cx, cz)
			if not _obs.has(key):
				_obs[key] = []
			(_obs[key] as Array).append([Vector2(p.x, p.z), r])


# Выталкивает юнита радиуса radius из препятствий.
func push_out(p: Vector3, radius: float) -> Vector3:
	var c := Vector2i(floori(p.x / OBS_CELL), floori(p.z / OBS_CELL))
	var q := Vector2(p.x, p.z)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k := Vector2i(c.x + dx, c.y + dz)
			if not _obs.has(k):
				continue
			for o in (_obs[k] as Array):
				var op: Vector2 = o[0]
				var min_d: float = float(o[1]) + radius
				var d := q - op
				var l := d.length()
				if l < 0.0001:
					q = op + Vector2(min_d, 0.0)
				elif l < min_d:
					q = op + d / l * min_d
	return Vector3(q.x, p.y, q.y)


func _init() -> void:
	for lane in _LANES0:
		var pts: Array = []
		for p in lane:
			pts.append((p as Vector3) * MAP_SCALE)
		LANES.append(pts)
	for d in _TOWERS0:
		TOWER_DEFS.append([d[0], d[1], float(d[2]) * MAP_SCALE, float(d[3]) * MAP_SCALE])
	for d in _T40:
		T4_DEFS.append([float(d[0]) * MAP_SCALE, float(d[1]) * MAP_SCALE])
	for p in _CAMPS0:
		CAMP_DEFS.append((p as Vector3) * MAP_SCALE)
	for p in _RUNES0:
		RUNE_SPOTS.append((p as Vector3) * MAP_SCALE)
	for p in _BOUNTY0:
		BOUNTY_SPOTS.append((p as Vector3) * MAP_SCALE)


func _ready() -> void:
	if not SignalBus.unit_died.is_connected(_on_unit_died):
		SignalBus.unit_died.connect(_on_unit_died)
	reset_stats()
	_ensure_input_actions()
	_build_sfx()
	load_settings()


# elapsed тикает только пока в матче есть герой игрока.
# Раньше счётчик шёл уже в главном меню — сдвигая все тайминги партии.
func _process(delta: float) -> void:
	if not is_over and player_hero != null:
		elapsed += delta


func reset_stats() -> void:
	is_over = false
	selected_unit = null
	elapsed = 0.0
	match_id = Crypto.new().generate_random_bytes(12).hex_encode()
	siege_waves = [0, 0]
	first_blood_done = false
	player_hero = null
	streak = [0, 0]
	multi = [0, 0]
	last_kill_t = [-99.0, -99.0]
	pings.clear()
	pinch_latch = false
	in_prematch = false
	_heroes_frame = -1
	_heroes_by_team.clear()
	_unit_frame = -1
	_unit_pframe = -1
	_unit_cache.clear()
	_grid.clear()
	stats = {"kills": [0, 0], "creeps": [0, 0], "towers": [0, 0]}


# Подписчик шины: награды и статистика больше не вызываются из Unit напрямую.
func _on_unit_died(dead: Node, killer: Node) -> void:
	award_bounty(dead as Unit, killer as Unit)


func is_touch() -> bool:
	if control_mode == 1:
		return true
	if control_mode == 2:
		return false
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _ensure_input_actions() -> void:
	var keys: Dictionary = {
		"cast_Q": KEY_Q, "cast_W": KEY_W, "cast_E": KEY_E, "cast_D": KEY_D, "cast_F": KEY_F, "cast_R": KEY_R,
		"item_1": KEY_Z, "item_2": KEY_X, "item_3": KEY_C, "item_4": KEY_V, "item_5": KEY_B, "item_6": KEY_N,
		"attack_move": KEY_A, "stop_order": KEY_S, "hold_order": KEY_H, "center_cam": KEY_SPACE,
		"shop_toggle": KEY_F4, "pause_menu": KEY_ESCAPE, "camera_lock": KEY_Y, "talents": KEY_G,
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)


# ---------- геометрия ----------
func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var pa := Vector2(p.x - a.x, p.z - a.z)
	var ba := Vector2(b.x - a.x, b.z - a.z)
	var h := clampf(pa.dot(ba) / maxf(ba.length_squared(), 0.0001), 0.0, 1.0)
	return (pa - ba * h).length()


func mirror(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, -p.z)


func throne_pos(team: int) -> Vector3:
	return Vector3(-BASE_POS, 0.0, BASE_POS) if team == 0 else Vector3(BASE_POS, 0.0, -BASE_POS)


func forward(team: int) -> Vector3:
	var d := Vector3(1.0, 0.0, -1.0).normalized()
	return d if team == 0 else -d


# Фонтан стоит перед троном (в сторону карты). Если на геймплее бот в _retreat
# кажется «в опасности», поменяй знак: throne_pos(team) - forward(team) * 32.0
func fountain_pos(team: int) -> Vector3:
	return throne_pos(team) + forward(team) * 32.0


func lane_path(team: int, lane: int) -> Array:
	var p: Array = (LANES[lane] as Array).duplicate()
	if team == 1:
		p.reverse()
	return p


func tower_def_pos(team: int, lane: int, tier: int) -> Vector3:
	var l: int = lane if team == 0 else 2 - lane
	for d in TOWER_DEFS:
		if d[0] == l and d[1] == tier:
			var p := Vector3(d[2], 0.0, d[3])
			return p if team == 0 else mirror(p)
	return throne_pos(team)


func team_name(team: int) -> String:
	match team:
		0: return "Свет"
		1: return "Тьма"
		_: return "Нейтралы"


# ---------- поиск юнитов ----------
func enemies_in_range(team: int, pos: Vector3, radius: float) -> Array:
	var out: Array = []
	for n in units_near(pos, radius + 8.0):
		if not is_instance_valid(n):
			continue
		var u := n as Unit
		if u == null or not u.alive or u.team == team or u is Courier:
			continue
		var b := u as Building
		if b != null and b.invulnerable:
			continue
		if flat_dist(pos, u.global_position) <= radius + u.body_radius:
			out.append(u)
	return out


func nearest_enemy(team: int, pos: Vector3, radius: float) -> Unit:
	var best: Unit = null
	var best_d: float = 1e9
	for n in enemies_in_range(team, pos, radius):
		var u := n as Unit
		var d := flat_dist(pos, u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best


# Кэшируется по физическому кадру — боты зовут её в каждом think.
func heroes_of(team: int) -> Array:
	var f := Engine.get_physics_frames()
	if f != _heroes_frame:
		_heroes_frame = f
		_heroes_by_team = {0: [], 1: [], 2: []}
		for n in get_tree().get_nodes_in_group("heroes"):
			if not is_instance_valid(n):
				continue
			var h := n as BaseHero
			if h == null:
				continue
			var arr: Array = _heroes_by_team.get(h.team, [])
			arr.append(h)
			_heroes_by_team[h.team] = arr
	return _heroes_by_team.get(team, [])


# ---------- события ----------
func say(text: String) -> void:
	message.emit(text)


func shout(text: String, color: Color = Color(1.0, 0.9, 0.4)) -> void:
	announce.emit(text, color)


func award_bounty(dead: Unit, killer: Unit) -> void:
	# Иллюзии не дают награды и не считаются убийствами героев;
	# убийство, совершённое иллюзией, засчитывается её хозяину.
	var dead_hero := dead as BaseHero
	if dead_hero != null and dead_hero.is_illusion:
		return
	var killer_ill := killer as BaseHero
	if killer_ill != null and killer_ill.is_illusion:
		killer = killer_ill.illusion_owner if is_instance_valid(killer_ill.illusion_owner) else null
	var killer_team: int = (1 - dead.team) if killer == null else killer.team
	var killer_hero := killer as BaseHero
	if killer_team == dead.team and dead.team != 2:
		if killer_hero != null:
			killer_hero.denies += 1
		float_text(dead.global_position + Vector3(0.0, 2.0, 0.0), "DENY", Color(1.0, 0.6, 0.2))
		return
	var bonus := 0
	if dead is BaseHero:
		bonus = 45 * mini(int(streak[dead.team]), 5)
	if killer_team == 0 or killer_team == 1:
		if dead is BaseHero:
			stats["kills"][killer_team] += 1
			streak[dead.team] = 0
			streak[killer_team] += 1
			if killer_hero != null:
				killer_hero.kills += 1
			if not first_blood_done:
				first_blood_done = true
				shout("ПЕРВАЯ КРОВЬ!", Color(1.0, 0.3, 0.3))
				if killer_hero != null:
					killer_hero.add_gold(150)
			elif streak[killer_team] == 3:
				shout("%s: СЕРИЯ УБИЙСТВ!" % team_name(killer_team), Color(1.0, 0.6, 0.2))
			elif streak[killer_team] == 5:
				shout("%s: ДОМИНИРОВАНИЕ!" % team_name(killer_team), Color(1.0, 0.4, 0.8))
			elif streak[killer_team] >= 7:
				shout("%s: НЕУДЕРЖИМЫ!" % team_name(killer_team), Color(0.9, 0.3, 1.0))
		elif dead is Creep:
			stats["creeps"][killer_team] += 1
			if killer_hero != null and not (dead as Creep).neutral:
				killer_hero.last_hits += 1
			if killer_hero != null and (dead as Creep).neutral and (dead as Creep).big and not (dead as Creep).guardian and randf() < 0.22:
				killer_hero.give_neutral_drop()
		elif dead is Building and not (dead as Building).is_throne:
			stats["towers"][killer_team] += 1
			for id in (dead as Building).damage_contributors:
				var contributor = instance_from_id(id)
				if is_instance_valid(contributor) and contributor is BaseHero and contributor.team != dead.team:
					contributor.towers_assisted += 1
			shout("%s: БАШНЯ РАЗРУШЕНА" % team_name(dead.team), Color(1.0, 0.7, 0.3))
	var gold: int = dead.gold_bounty + bonus
	var xp: int = dead.exp_bounty
	if killer_hero != null and killer_hero.is_player:
		float_text(dead.global_position + Vector3(0.0, 4.0, 0.0), "+%d" % gold, Color(1.0, 0.85, 0.2), 1.1)
		sfx("gold", -10.0)
	if dead is BaseHero and (killer_team == 0 or killer_team == 1):
		ping(dead.global_position, Color(1.0, 0.3, 0.3))
		if elapsed - float(last_kill_t[killer_team]) < 18.0:
			multi[killer_team] += 1
		else:
			multi[killer_team] = 1
		last_kill_t[killer_team] = elapsed
		if multi[killer_team] == 2:
			shout("ДВОЙНОЕ УБИЙСТВО!", Color(1.0, 0.5, 0.2))
		elif multi[killer_team] == 3:
			shout("ТРОЙНОЕ УБИЙСТВО!", Color(1.0, 0.3, 0.6))
		elif multi[killer_team] >= 4:
			shout("МЕГА-УБИЙСТВО!", Color(0.9, 0.3, 1.0))
	if killer_hero != null:
		killer_hero.add_gold(gold)
		killer_hero.add_xp(xp)
	for h in heroes_of(killer_team):
		var hero := h as BaseHero
		if hero == killer_hero or not hero.alive:
			continue
		if flat_dist(hero.global_position, dead.global_position) <= 60.0:
			hero.add_xp(int(xp * 0.5))


func end_game(winner: int) -> void:
	if is_over:
		return
	is_over = true
	game_over.emit(winner)
	SignalBus.game_state_changed.emit("game_over")
	get_tree().paused = true


func apply_rune(hero: BaseHero, kind: String) -> void:
	match kind:
		"haste":
			hero.add_status("haste", 20.0, 0.5)
			shout("Руна скорости!", Color(0.4, 0.8, 1.0))
		"dd":
			hero.add_status("rage", 20.0, 1.0)
			shout("Руна двойного урона!", Color(0.6, 0.4, 1.0))
		"regen":
			hero.add_status("regen_pct", 12.0, 0.06)
			shout("Руна регенерации!", Color(0.4, 1.0, 0.5))
		"arcane":
			hero.add_status("arcane", 25.0, 0.5)
			shout("Арканная руна: мана и перезарядки вдвое дешевле!", Color(1.0, 0.5, 0.85))
		"shield":
			hero.add_status("shield", 25.0, 350.0 + elapsed / 60.0 * 12.0)
			shout("Руна щита!", Color(1.0, 0.7, 0.3))
		"wisdom":
			hero.add_xp(220 + int(elapsed / 60.0) * 25)
			shout("Руна мудрости!", Color(0.75, 0.9, 1.0))
		"bounty":
			hero.add_gold(140 + int(elapsed / 60.0) * 7)
			hero.add_xp(90)
			shout("Руна богатства!", Color(1.0, 0.85, 0.2))


# ---------- визуальные помощники ----------
func get_mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), glow]
	if _mats.has(key):
		return _mats[key]
	var m := make_mat(color, glow)
	_mats[key] = m
	return m


func make_mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m


func float_text(pos: Vector3, text: String, color: Color, size: float = 1.0) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.026 * size
	l.font_size = 48
	l.outline_size = 10
	l.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	scene.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.4, 0.4), 0.0, 0.0)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 2.4, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func spawn_burst(pos: Vector3, radius: float, color: Color) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var fx := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 16
	s.rings = 8
	fx.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.55)
	fx.material_override = m
	scene.add_child(fx)
	fx.global_position = pos + Vector3(0.0, 0.5, 0.0)
	fx.scale = Vector3.ONE * 0.2
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(fx.queue_free)


func spawn_puff(pos: Vector3, color: Color, size: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var fx := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	s.radial_segments = 8
	s.rings = 4
	fx.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.7)
	fx.material_override = m
	scene.add_child(fx)
	fx.global_position = pos
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector3.ONE * 0.1, 0.35)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(fx.queue_free)


func spawn_beam(from: Vector3, to: Vector3, color: Color, width: float = 0.18, dur: float = 0.25) -> void:
	var scene := get_tree().current_scene
	if scene == null or from.distance_to(to) < 0.1:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, from.distance_to(to))
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	mi.material_override = m
	scene.add_child(mi)
	var up := Vector3.UP
	if absf((to - from).normalized().y) > 0.95:
		up = Vector3.RIGHT
	mi.look_at_from_position((from + to) * 0.5, to, up)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.tween_callback(mi.queue_free)


# ---------- пинги на миникарте, тряска камеры ----------
func ping(pos: Vector3, color: Color) -> void:
	pings.append([pos, elapsed, color])
	while pings.size() > 8:
		pings.pop_front()


func shake(amount: float) -> void:
	for n in get_tree().get_nodes_in_group("camera_rig"):
		n.shake(amount)


# ---------- звуки (синтез без внешних файлов) ----------
const RATE: int = 22050


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


func _tone(freq: float, dur: float, vol: float, sweep_to: float = -1.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := freq if sweep_to < 0.0 else lerpf(freq, sweep_to, t)
		ph += TAU * f / float(RATE)
		out[i] = sin(ph) * vol * (1.0 - t)
	return out


func _noise(dur: float, vol: float, low: bool) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var acc := 0.0
	for i in n:
		var t := float(i) / float(n)
		var r := randf_range(-1.0, 1.0)
		if low:
			acc = acc * 0.96 + r * 0.04
			r = acc * 7.0
		out[i] = r * vol * (1.0 - t) * (1.0 - t)
	return out


func _arp(freqs: Array, note: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		out.append_array(_tone(float(f), note, vol))
	return out


func _build_sfx() -> void:
	_sfx["hit"] = _wav(_noise(0.07, 0.4, false))
	_sfx["cast"] = _wav(_tone(320.0, 0.2, 0.35, 780.0))
	_sfx["level"] = _wav(_arp([523.0, 659.0, 784.0, 1046.0], 0.09, 0.35))
	_sfx["gold"] = _wav(_arp([1318.0, 1760.0], 0.05, 0.3))
	_sfx["tower"] = _wav(_noise(0.7, 0.8, true))
	_sfx["announce"] = _wav(_arp([392.0, 523.0, 659.0], 0.12, 0.35))
	# 12 плееров — запас под одновременные эффекты в толпе (было 6 = впритык)
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func sfx(sound: String, vol_db: float = -8.0) -> void:
	if not _sfx.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_sfx_t.get(sound, 0)) < 70:
		return
	_sfx_t[sound] = now
	for p in _players:
		var ap := p as AudioStreamPlayer
		if not ap.playing:
			ap.stream = _sfx[sound]
			ap.volume_db = vol_db
			ap.play()
			return


# ---------- рельеф ----------
const HILLS: Array = [Vector3(-70.0, 22.0, 20.0), Vector3(90.0, 22.0, 185.0), Vector3(70.0, 22.0, -20.0), Vector3(-90.0, 22.0, -185.0)]

const HM_CELL: float = 8.0
const HM_N: int = 91
const HM_ORG: float = -360.0


func bake_terrain() -> void:
	_gen_hills()
	_hnoise = FastNoiseLite.new()
	_hnoise.seed = 7
	_hnoise.frequency = 0.012
	_hnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hmap = PackedFloat32Array()
	_hmap.resize(HM_N * HM_N)
	for iz in HM_N:
		for ix in HM_N:
			_hmap[iz * HM_N + ix] = _height_raw(HM_ORG + float(ix) * HM_CELL, HM_ORG + float(iz) * HM_CELL)


func height_at(x: float, z: float) -> float:
	if _hmap.is_empty():
		return _height_raw(x, z)
	var fx := clampf((x - HM_ORG) / HM_CELL, 0.0, float(HM_N - 1) - 0.001)
	var fz := clampf((z - HM_ORG) / HM_CELL, 0.0, float(HM_N - 1) - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - float(ix)
	var tz := fz - float(iz)
	var h00 := _hmap[iz * HM_N + ix]
	var h10 := _hmap[iz * HM_N + ix + 1]
	var h01 := _hmap[(iz + 1) * HM_N + ix]
	var h11 := _hmap[(iz + 1) * HM_N + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _flat_mask(x: float, z: float) -> float:
	var p := Vector3(x, 0.0, z)
	var m := 1.0
	var dl := 1e9
	for lane in LANES:
		var pts: Array = lane
		for i in range(pts.size() - 1):
			dl = minf(dl, dist_to_segment(p, pts[i], pts[i + 1]))
	m = minf(m, smoothstep(LANE_WIDTH * 0.5 + 6.0, LANE_WIDTH * 0.5 + 40.0, dl))
	m = minf(m, smoothstep(100.0, 150.0, minf(flat_dist(p, throne_pos(0)), flat_dist(p, throne_pos(1)))))
	for c in CAMP_DEFS:
		m = minf(m, smoothstep(18.0, 45.0, minf(flat_dist(p, c), flat_dist(p, mirror(c)))))
	for c in RUNE_SPOTS:
		m = minf(m, smoothstep(14.0, 36.0, flat_dist(p, c)))
	for c in BOUNTY_SPOTS:
		m = minf(m, smoothstep(14.0, 36.0, minf(flat_dist(p, c), flat_dist(p, mirror(c)))))
	for c in [Vector3(-120.0, 0.0, 60.0), Vector3(60.0, 0.0, 120.0)]:
		m = minf(m, smoothstep(14.0, 36.0, minf(flat_dist(p, c), flat_dist(p, mirror(c)))))
	m = minf(m, smoothstep(40.0, 80.0, flat_dist(p, GUARDIAN_POS)))
	m = minf(m, smoothstep(26.0, 60.0, absf(z - x) / 1.4142))
	return m


func _height_raw(x: float, z: float) -> float:
	var h := 0.0
	for hl in _hills:
		var d := Vector2(x - float(hl[0]), z - float(hl[1])).length()
		h += float(hl[3]) * (1.0 - smoothstep(float(hl[2]) * 0.5, float(hl[2]), d))
	h = minf(h, 18.0)
	var edge := MAP_HALF - maxf(absf(x), absf(z))
	if edge < 22.0:
		h += 10.0 * (1.0 - smoothstep(0.0, 22.0, edge))
	if _hnoise != null:
		var n := _hnoise.get_noise_2d(x, z) * 0.5 + 0.5
		h += terrain_amp * n * _flat_mask(x, z)
	return h


# ---------- нейтральные предметы ----------
const NEUTRAL_ITEMS: Dictionary = {
	"troll_charm": {"name": "Troll Charm", "tier": 1, "desc": "+15 скорость атаки, +2 реген HP", "stats": {"aspd": 15.0, "hp_regen": 2.0}},
	"ember_ring": {"name": "Ember Ring", "tier": 1, "desc": "+8 урон, +0.5 скорость", "stats": {"dmg": 8.0, "ms": 0.5}},
	"mystic_flask": {"name": "Mystic Flask", "tier": 1, "desc": "+2 реген маны, +100 здоровье", "stats": {"mp_regen": 2.0, "hp": 100.0}},
	"ogre_belt": {"name": "Ogre Belt", "tier": 2, "desc": "+300 здоровье, +3 броня", "stats": {"hp": 300.0, "armor": 3.0}},
	"arcane_ring": {"name": "Arcane Ring", "tier": 2, "desc": "+12 интеллект, +200 мана", "stats": {"int": 12.0, "mp": 200.0}},
	"wolf_fang": {"name": "Wolf Fang", "tier": 2, "desc": "+20 урон, +20 скорость атаки", "stats": {"dmg": 20.0, "aspd": 20.0}},
	"giant_core": {"name": "Giant Core", "tier": 3, "desc": "+15 сила, +400 здоровье", "stats": {"str": 15.0, "hp": 400.0}},
	"phoenix_ash": {"name": "Phoenix Ash", "tier": 3, "desc": "+30 урон, 10% вампиризма", "stats": {"dmg": 30.0, "lifesteal": 0.1}},
	"void_mantle": {"name": "Void Mantle", "tier": 3, "desc": "+25% сопротивления магии, +5 броня", "stats": {"mr": 0.25, "armor": 5.0}},
}


func item_price(inv: Array, id: String) -> int:
	var item: Dictionary = ITEMS[id]
	var price: int = item["cost"]
	if item.has("recipe"):
		var pool: Array = inv.duplicate()
		for comp in item["recipe"]:
			var i := pool.find(comp)
			if i != -1:
				pool.remove_at(i)
				price -= int((ITEMS[comp] as Dictionary)["cost"])
	return price


# ---------- холмы ----------
func hills() -> Array:
	return _hills


func _hill_ok(x: float, z: float, r: float) -> bool:
	if _flat_mask(x, z) < 0.98:
		return false
	for k in 8:
		var a := TAU / 8.0 * float(k)
		if _flat_mask(x + cos(a) * r * 0.9, z + sin(a) * r * 0.9) < 0.5:
			return false
	return true


func _gen_hills() -> void:
	_hills.clear()
	for hl in HILLS:
		_hills.append([hl.x, hl.z, hl.y, 9.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var want: int = [4, 8, 12, 18][clampi(quality, 0, 3)]
	var placed := 0
	var tries := 0
	while placed < want and tries < 900:
		tries += 1
		var x := rng.randf_range(-MAP_HALF + 40.0, MAP_HALF - 40.0)
		var z := rng.randf_range(-MAP_HALF + 40.0, MAP_HALF - 40.0)
		if z <= x:
			continue
		var r := rng.randf_range(16.0, 32.0)
		var hh := rng.randf_range(5.0, 14.0)
		var clear := true
		for o in _hills:
			if Vector2(x - float(o[0]), z - float(o[1])).length() < (r + float(o[2])) * 0.75:
				clear = false
				break
		if not clear or not _hill_ok(x, z, r):
			continue
		_hills.append([x, z, r, hh])
		_hills.append([-x, -z, r, hh])
		placed += 1
		if rng.randf() < 0.4:
			var ang := rng.randf() * TAU
			var x2 := x + cos(ang) * r * 1.1
			var z2 := z + sin(ang) * r * 1.1
			if z2 > x2 and _hill_ok(x2, z2, r * 0.8):
				_hills.append([x2, z2, r * 0.8, hh * 0.8])
				_hills.append([-x2, -z2, r * 0.8, hh * 0.8])


# ---------- сохранение настроек ----------
func apply_volume() -> void:
	var db := -80.0 if volume <= 0.001 else linear_to_db(volume)
	AudioServer.set_bus_volume_db(0, db)


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "hero", selected_hero)
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("game", "team_size", team_size)
	cf.set_value("game", "experimental", experimental)
	cf.set_value("game", "tutorial_seen", tutorial_seen)
	cf.set_value("game", "fog_on", fog_on)
	cf.set_value("game", "prematch_on", prematch_on)
	cf.set_value("game", "cast_mode", cast_mode)
	cf.set_value("game", "control_mode", control_mode)
	cf.set_value("game", "edge_scroll", edge_scroll)
	cf.set_value("gfx", "biome", biome)
	cf.set_value("gfx", "quality", quality)
	cf.set_value("gfx", "res_scale", res_scale)
	cf.set_value("gfx", "fps_cap", fps_cap)
	cf.set_value("gfx", "weather_on", weather_on)
	cf.set_value("gfx", "shadows_on", shadows_on)
	cf.set_value("audio", "volume", volume)
	cf.save(SAVE_PATH)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		_phone_defaults()
		Engine.max_fps = fps_cap
		apply_volume()
		return
	selected_hero = String(cf.get_value("game", "hero", selected_hero))
	if String(HeroDB.get_hero(selected_hero)["id"]) != selected_hero:
		selected_hero = "titan"
	difficulty = clampi(int(cf.get_value("game", "difficulty", difficulty)), 0, 2)
	team_size = int(cf.get_value("game", "team_size", team_size))
	if team_size not in [1, 2, 5]:
		team_size = 2
	experimental = bool(cf.get_value("game", "experimental", false))
	tutorial_seen = bool(cf.get_value("game", "tutorial_seen", false))
	if not experimental:
		team_size = 2
		if selected_hero not in MatchBalance.PRIMARY_HEROES: selected_hero = "titan"
	fog_on = bool(cf.get_value("game", "fog_on", fog_on))
	prematch_on = bool(cf.get_value("game", "prematch_on", prematch_on))
	cast_mode = clampi(int(cf.get_value("game", "cast_mode", cast_mode)), 0, 2)
	control_mode = clampi(int(cf.get_value("game", "control_mode", control_mode)), 0, 2)
	edge_scroll = bool(cf.get_value("game", "edge_scroll", edge_scroll))
	biome = String(cf.get_value("gfx", "biome", biome))
	if biome not in Biome.ORDER:
		biome = "forest"
	quality = clampi(int(cf.get_value("gfx", "quality", quality)), 0, 3)
	res_scale = clampf(float(cf.get_value("gfx", "res_scale", res_scale)), 0.5, 1.0)
	fps_cap = int(cf.get_value("gfx", "fps_cap", fps_cap))
	if fps_cap not in [0, 30, 60, 120]:
		fps_cap = 60
	weather_on = bool(cf.get_value("gfx", "weather_on", weather_on))
	shadows_on = bool(cf.get_value("gfx", "shadows_on", shadows_on))
	volume = clampf(float(cf.get_value("audio", "volume", volume)), 0.0, 1.0)
	Engine.max_fps = fps_cap
	apply_volume()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		request_pause.emit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var sc := get_tree().current_scene
		if sc != null and sc.name == "MainMenu":
			get_tree().quit()
		else:
			request_pause.emit()


func _phone_defaults() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		quality = 0
		res_scale = 0.7
		fps_cap = 30
		shadows_on = false
		weather_on = false


func reset_settings() -> void:
	experimental = false
	selected_hero = "titan"
	difficulty = 1
	team_size = 2
	fog_on = true
	prematch_on = true
	cast_mode = 2
	control_mode = 0
	edge_scroll = false
	biome = "forest"
	quality = 1
	res_scale = 1.0
	fps_cap = 60
	weather_on = true
	shadows_on = false
	volume = 1.0
	_phone_defaults()
	Engine.max_fps = fps_cap
	apply_volume()
	save_settings()
