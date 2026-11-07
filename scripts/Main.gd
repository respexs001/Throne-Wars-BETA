extends Node3D
## Main.gd — игровая сцена: небо и свет (смена дня и ночи), карта (MapBuilder), здания, крипы по трём линиям,
## нейтральные лагеря, Древний Страж, руны, герои, камера, управление, HUD.

const WAVE_INTERVAL: float = MatchBalance.WAVE_INTERVAL

var player: BaseHero
var bot: BaseHero
var next_wave_in: float = MatchBalance.FIRST_WAVE
var _wave: int = 0
var _wave_spawner := LaneWaveSpawner.new()
var _camps: Array = []
var _guardian: Creep = null
var _guardian_wait: float = MatchBalance.GUARDIAN_FIRST
var _power_cd: float = 30.0
var _bounty_cd: float = 25.0
var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _water: Material
var _flames: Array = []
var _t: float = 0.0
var _dn_acc: float = 99.0
var _pending_allies: Array = []
var _pending_foes: Array = []
var _biome: Dictionary = {}
var _weather_kind: String = "rain"
var _fireflies: CPUParticles3D
var _rain: CPUParticles3D


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Global.reset_stats()
	Global.clear_obstacles()
	Global.tools_used = false
	_biome = Biome.cfg(Global.biome)
	_weather_kind = String(_biome["weather"])
	Engine.max_fps = Global.fps_cap
	get_viewport().scaling_3d_scale = Global.res_scale
	_build_environment()
	var built := MapBuilder.build(self)
	if Global.test_mode:
		next_wave_in = 1.0e9
	_flames = built["flames"]
	_water = built["river"]
	if not Global.test_mode:
		_build_buildings()
	_build_camps()
	_spawn_heroes()
	_spawn_couriers()
	_build_shrines()
	add_child(FogManager.new())
	var rig := CameraRig.new()
	rig.target = player
	rig.position = player.position
	add_child(rig)
	_fireflies = _make_fireflies()
	rig.add_child(_fireflies)
	_rain = _make_weather(_weather_kind)
	rig.add_child(_rain)
	var pc := PlayerController.new()
	pc.hero = player
	pc.cam = rig.cam
	pc.rig = rig
	add_child(pc)
	var hud := GameHUD.new()
	add_child(hud)
	hud.setup(player, bot, self, pc, rig)
	if not Global.tutorial_seen and not Global.test_mode:
		var guide := FirstMatchGuide.new()
		add_child(guide)
		guide.setup(player)
	if Global.is_touch():
		Global.say("Джойстик слева внизу ведёт героя. Тап по врагу - атака.")
		Global.say("Кнопки способностей: нажать - применить, зажать и потянуть - прицел.")
	else:
		Global.say("ПКМ - идти и атаковать, ЛКМ - выбрать. Q W E D F R - способности.")
		Global.say("Нажмите + над способностью, чтобы изучить. F4 - магазин, G - таланты.")
	Global.say("Покупки вдали от базы привозит курьер. Esc - пауза.")
	if Global.test_mode or not Global.prematch_on:
		_start_match(1)
	else:
		_begin_prematch()


func _process(delta: float) -> void:
	_t += delta
	MapBuilder.update_canopy_focus(player.global_position)
	next_wave_in -= delta
	if next_wave_in <= 0.0:
		next_wave_in = WAVE_INTERVAL
		_spawn_wave()
	_update_camps(delta)
	_update_guardian(delta)
	_update_runes(delta)
	_dn_acc += delta
	if _dn_acc >= 1.5:
		_dn_acc = 0.0
		_update_daynight()
	for i in _flames.size():
		var f: MeshInstance3D = _flames[i]
		f.scale = Vector3.ONE * (0.85 + 0.3 * sin(_t * 11.0 + float(i) * 1.9) * sin(_t * 6.3 + float(i)))


# ---------- небо и свет ----------
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_sky = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env.ambient_light_energy = 0.8
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_density = 0.00018 * float(_biome["fog_mult"])
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
	_sun.shadow_enabled = Global.shadows_on and not Global.is_touch()
	_sun.directional_shadow_max_distance = 110.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(_sun)


func _update_daynight() -> void:
	var cyc := fmod(Global.elapsed, 600.0)
	var k := 0.5 + 0.5 * cos(cyc / 600.0 * TAU)      # 1 = день, 0 = ночь
	var day_now: bool = k > 0.5
	if day_now != Global.is_day:
		Global.is_day = day_now
		SignalBus.day_night_changed.emit(day_now)
	_sun.light_energy = lerpf(0.28, 0.82, k)
	_sun.light_color = Color(0.5, 0.6, 1.0).lerp(Color(0.95, 0.88, 0.75), k)
	_sun.rotation_degrees.y = -30.0 + cyc * 0.12
	_env.ambient_light_energy = lerpf(0.42, 0.62, k)
	_env.ambient_light_color = Color(0.35, 0.4, 0.6).lerp(Color(0.68, 0.72, 0.78), k)
	_sky.sky_top_color = Color(0.03, 0.05, 0.16).lerp(_biome["sky_top"] as Color, k)
	_sky.sky_horizon_color = Color(0.1, 0.12, 0.25).lerp(_biome["sky_horizon"] as Color, k)
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_sky.ground_bottom_color = Color(0.03, 0.04, 0.08).lerp(Color(0.3, 0.35, 0.3), k)
	_env.fog_light_color = Color(0.1, 0.12, 0.25).lerp(_biome["fog"] as Color, k)
	if _fireflies != null:
		_fireflies.emitting = not Global.is_day
	var wet: bool = Global.weather_on and ((_weather_kind == "rain" and fmod(Global.elapsed, 260.0) > 190.0) or _weather_kind in ["snow", "ash", "sand"])
	if _rain != null:
		_rain.emitting = wet
	var fd: float = 0.00018 * float(_biome["fog_mult"])
	if wet:
		_sun.light_energy *= 0.8
		fd *= 2.0
	_env.fog_density = fd


# ---------- здания ----------
func _build_buildings() -> void:
	for t in [0, 1]:
		var throne := Building.new()
		throne.team = t
		throne.is_throne = true
		throne.tier = 4
		throne.position = Global.throne_pos(t)
		add_child(throne)
		for lane in 3:
			for tier in 3:
				var tw := Building.new()
				tw.team = t
				tw.lane = lane
				tw.tier = tier
				tw.position = Global.tower_def_pos(t, lane, tier)
				add_child(tw)
		for d in Global.T4_DEFS:
			var t4 := Building.new()
			t4.team = t
			t4.tier = 3
			var p := Vector3(d[0], 0.0, d[1])
			t4.position = p if t == 0 else Global.mirror(p)
			add_child(t4)


# ---------- крипы линий ----------
func _spawn_wave() -> void:
	_wave += 1
	_wave_spawner.spawn(self, _wave)


# ---------- нейтралы и страж ----------
func _build_camps() -> void:
	var idx := 0
	for t in [0, 1]:
		for p in Global.CAMP_DEFS:
			var pos: Vector3 = p if t == 0 else Global.mirror(p)
			_camps.append({"pos": pos, "units": [], "cd": 45.0, "id": idx})
			idx += 1


func _update_camps(delta: float) -> void:
	for camp in _camps:
		var alive_units: Array = []
		for u in camp["units"]:
			if is_instance_valid(u) and u.alive:
				alive_units.append(u)
		camp["units"] = alive_units
		if alive_units.is_empty():
			camp["cd"] = float(camp["cd"]) + delta
			if float(camp["cd"]) >= 45.0:
				camp["cd"] = 0.0
				_spawn_camp(camp)


func _spawn_camp(camp: Dictionary) -> void:
	var offs: Array = [Vector3.ZERO, Vector3(10.0, 0.0, 0.0), Vector3(-6.0, 0.0, 10.0)]
	var base: Vector3 = camp["pos"]
	for i in 3:
		var c := Creep.new()
		c.neutral = true
		c.big = (i == 0)
		c.team = 2
		c.camp_id = int(camp["id"])
		c.wave = int(Global.elapsed / 300.0)
		c.home_pos = base + (offs[i] as Vector3)
		c.position = c.home_pos
		add_child(c)
		camp["units"].append(c)


func _spawn_guardian() -> void:
	_guardian = Creep.new()
	_guardian.neutral = true
	_guardian.guardian = true
	_guardian.team = 2
	_guardian.wave = int(Global.elapsed / 300.0)
	_guardian.home_pos = Global.GUARDIAN_POS
	_guardian.position = Global.GUARDIAN_POS
	add_child(_guardian)


func _update_guardian(delta: float) -> void:
	if is_instance_valid(_guardian) and _guardian.alive:
		return
	if _guardian_wait < 0.0:
		_guardian_wait = MatchBalance.GUARDIAN_RESPAWN
	_guardian_wait -= delta
	if _guardian_wait <= 0.0:
		_guardian_wait = -1.0
		_spawn_guardian()
		Global.shout("Древний Страж возродился", Color(0.9, 0.5, 0.3))


# ---------- руны: каждые 55 с в случайной точке реки или джунглей (до 3 одновременно) ----------
const RUNE_KINDS: Array = ["haste", "haste", "haste", "dd", "dd", "dd", "regen", "regen", "regen", "arcane", "arcane", "shield", "shield", "wisdom", "bounty"]


func _update_runes(delta: float) -> void:
	_power_cd -= delta
	if _power_cd > 0.0:
		return
	_power_cd = 55.0
	var active := get_tree().get_nodes_in_group("runes")
	if active.size() >= 3:
		return
	var spots: Array = []
	for p in Global.RUNE_SPOTS:
		spots.append(p)
	for p in Global.BOUNTY_SPOTS:
		spots.append(p)
		spots.append(Global.mirror(p))
	spots.shuffle()
	for sp in spots:
		var busy := false
		for r in active:
			if Global.flat_dist((r as Node3D).global_position, sp) < 25.0:
				busy = true
		if not busy:
			var kind: String = RUNE_KINDS[randi() % RUNE_KINDS.size()]
			_spawn_rune(kind, sp)
			Global.shout("Руна: %s" % Rune.NAMES[kind], Rune.colour_of(kind))
			Global.ping(sp, Rune.colour_of(kind))
			return


func _spawn_rune(kind: String, pos: Vector3) -> void:
	var r := Rune.new()
	r.kind = kind
	r.position = pos
	add_child(r)
	SignalBus.rune_spawned.emit(r)


# ---------- герои ----------
func _spawn_heroes() -> void:
	var n: int = Global.team_size
	var pool: Array = []
	for h in HeroDB.all():
		if h["id"] != Global.selected_hero and (Global.experimental or Global.team_size != 2 or h["id"] in MatchBalance.PRIMARY_HEROES):
			pool.append(h["id"])
	pool.shuffle()
	var lanes: Array = [1, 0, 2, 1, 0]      # распределение ботов по линиям
	player = _make_hero(Global.selected_hero, 0, true, 0, n)
	if Global.test_mode:
		bot = _make_hero(pool[0], 1, false, 0, 1)
		bot.auto_acquire = false
		return
	var pi := 0
	for i in range(1, n):
		var ally := _make_hero(pool[pi], 0, false, i, n)
		pi += 1
		_pending_allies.append(ally)
	for i in n:
		var foe := _make_hero(pool[pi], 1, false, i, n)
		pi += 1
		if i == 0:
			bot = foe
		_pending_foes.append(foe)


func _add_bot(h: BaseHero, lane_idx: int) -> void:
	h.income_mult = [0.8, 1.0, 1.25][Global.difficulty]
	var bc := StrategicBot.new()
	bc.hero = h
	bc.difficulty = Global.difficulty
	bc.lane = lane_idx
	add_child(bc)


func _make_hero(id: String, t: int, human: bool, idx: int, count: int) -> BaseHero:
	var h := BaseHero.new()
	h.hero_id = id
	h.team = t
	h.is_player = human
	var f := Global.forward(t)
	var side := Vector3(-f.z, 0.0, f.x)
	h.position = Global.throne_pos(t) + f * 46.0 + side * (float(idx) - float(count - 1) * 0.5) * 12.0
	add_child(h)
	return h


# Светлячки ночью: частицы следуют за камерой.
func _make_fireflies() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 45
	p.lifetime = 6.0
	p.position = Vector3(0.0, 8.0, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(70.0, 8.0, 70.0)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	p.gravity = Vector3.ZERO
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	sm.radial_segments = 6
	sm.rings = 3
	p.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.95, 0.5)
	p.material_override = m
	p.emitting = false
	return p


func _spawn_couriers() -> void:
	for t in [0, 1]:
		var c := Courier.new()
		c.team = t
		c.owner_hero = player if t == 0 else bot
		c.position = Global.fountain_pos(t) + Vector3(10.0, 0.0, 0.0)
		add_child(c)
		if t == 0:
			player.courier = c
		else:
			bot.courier = c


func _build_shrines() -> void:
	for p in [Vector3(-120.0, 0.0, 60.0), Vector3(60.0, 0.0, 120.0)]:
		for q in [p, Global.mirror(p)]:
			var sh := Shrine.new()
			sh.position = q
			add_child(sh)


# Дождь: частицы следуют за камерой, идут в часть матча.
func _make_rain() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 250 if Global.is_touch() else 500
	p.lifetime = 1.1
	p.position = Vector3(0.0, 70.0, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(90.0, 1.0, 90.0)
	p.direction = Vector3.DOWN
	p.spread = 3.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 85.0
	p.gravity = Vector3(0.0, -20.0, 0.0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 1.6, 0.06)
	p.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.7, 0.8, 1.0, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = m
	p.emitting = false
	return p


# Погода по ландшафту: дождь, снег, пепел, песчаный ветер (частицы следуют за камерой).
func _make_weather(kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh: Mesh
	var amount := 500
	p.position = Vector3(0.0, 70.0, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(90.0, 1.0, 90.0)
	p.direction = Vector3.DOWN
	p.spread = 3.0
	p.lifetime = 1.1
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 85.0
	p.gravity = Vector3(0.0, -20.0, 0.0)
	match kind:
		"snow":
			amount = 420
			p.lifetime = 5.0
			p.spread = 25.0
			p.initial_velocity_min = 7.0
			p.initial_velocity_max = 13.0
			p.gravity = Vector3(2.0, -2.0, 0.0)
			var sm := SphereMesh.new()
			sm.radius = 0.2
			sm.height = 0.4
			sm.radial_segments = 6
			sm.rings = 3
			mesh = sm
			m.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
		"ash":
			amount = 320
			p.lifetime = 5.0
			p.spread = 30.0
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 10.0
			p.gravity = Vector3(3.0, -1.0, 0.0)
			var am := SphereMesh.new()
			am.radius = 0.16
			am.height = 0.32
			am.radial_segments = 5
			am.rings = 3
			mesh = am
			m.albedo_color = Color(0.9, 0.4, 0.2, 0.8)
		"sand":
			amount = 320
			p.lifetime = 3.0
			p.position = Vector3(0.0, 12.0, 0.0)
			p.emission_box_extents = Vector3(110.0, 14.0, 110.0)
			p.direction = Vector3(1.0, -0.05, 0.3)
			p.spread = 12.0
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 60.0
			p.gravity = Vector3.ZERO
			var bm := BoxMesh.new()
			bm.size = Vector3(1.6, 0.06, 0.06)
			mesh = bm
			m.albedo_color = Color(0.85, 0.7, 0.45, 0.45)
		_:
			var rbm := BoxMesh.new()
			rbm.size = Vector3(0.06, 1.6, 0.06)
			mesh = rbm
			m.albedo_color = Color(0.7, 0.8, 1.0, 0.5)
	p.amount = int(float(amount) * (0.5 if Global.is_touch() else 1.0))
	p.mesh = mesh
	p.material_override = m
	p.emitting = false
	return p


# ---------- подготовка к матчу: линия и закупка ----------
func _begin_prematch() -> void:
	Global.in_prematch = true
	get_tree().paused = true
	var pm := PreMatchUI.new()
	add_child(pm)
	pm.setup(player)
	pm.finished.connect(_start_match)


func _start_match(lane: int) -> void:
	Global.in_prematch = false
	SignalBus.game_state_changed.emit("match_started")
	Global.player_lane = lane
	_assign_lanes(lane)
	get_tree().paused = false
	if not Global.test_mode and lane >= 0:
		player.order_move(Global.tower_def_pos(0, lane, 1))


# Союзные боты занимают свободные линии, враги зеркалят расстановку вашей команды (подстраиваются под игрока).
func _assign_lanes(player_lane: int) -> void:
	var counts: Array = [0, 0, 0]
	if player_lane >= 0:
		counts[player_lane] += 1
	var order: Array = [1, 0, 2]
	for h in _pending_allies:
		var best: int = order[0]
		for l in order:
			if int(counts[l]) < int(counts[best]):
				best = l
		counts[best] += 1
		_add_bot(h, player_lane if Global.team_size == 2 and not Global.experimental else best)
	var layout: Array = []
	for l in 3:
		for k in int(counts[l]):
			layout.append(l)
	for i in _pending_foes.size():
		var fl: int = player_lane if Global.team_size == 2 and not Global.experimental else (int(layout[i]) if i < layout.size() else 1)
		_add_bot(_pending_foes[i], fl)
	_pending_allies.clear()
	_pending_foes.clear()
