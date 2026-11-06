class_name Creep
extends Unit
## Creep.gd — умные крипы.
## Крип линии: идёт по точкам пути, выбирает цель по приоритету (враждебные крипы > герой, ударивший союзного героя > здания),
## осадный крип бьёт здания в 2.2 раза сильнее. Нейтралы: зовут на помощь весь лагерь, возвращаются и лечатся. Древний Страж - босс.

const AGGRO: float = 16.0

var lane: int = 1
var path: Array = []
var path_idx: int = 0
var goal_pos: Vector3 = Vector3.ZERO
var wave: int = 0
var ranged_creep: bool = false
var siege: bool = false
var guardian_empowered: bool = false
var neutral: bool = false
var big: bool = false
var guardian: bool = false
var camp_id: int = -1
var home_pos: Vector3 = Vector3.ZERO

var _aggro: float = AGGRO
var _target: Unit = null
var _retarget_cd: float = 0.0
var _returning: bool = false


func _configure() -> void:
    _retarget_cd = randf() * 0.3
    if guardian:
        unit_name = "Древний Страж"
        max_hp = MatchBalance.GUARDIAN_HP + wave * 250.0
        damage = MatchBalance.GUARDIAN_DAMAGE + wave * 5.0
        armor = 10.0
        move_speed = 4.0 * Global.SPEED_MULT
        attack_interval = 1.5
        attack_range = 4.0
        body_radius = 3.5
        body_height = 9.0
        hp_bar_height = 11.0
        gold_bounty = 400
        exp_bounty = 800
        _aggro = 20.0
        model_cfg = {"scale": 1.6, "build": "bulky", "body": Color(0.45, 0.4, 0.5), "accent": Color(0.8, 0.3, 0.2), "skin": Color(0.55, 0.5, 0.6), "weapon": "fists", "hat": "horns", "eyes": Color(1.0, 0.2, 0.1)}
        return
    if neutral:
        unit_name = "Лесной великан" if big else "Лесной зверь"
        max_hp = 1300.0 if big else 700.0
        damage = 52.0 if big else 30.0
        armor = 3.5 if big else 2.0
        move_speed = 4.2 * Global.SPEED_MULT
        attack_interval = 1.4
        attack_range = 2.2
        body_radius = 1.3 if big else 0.8
        body_height = 3.6 if big else 2.2
        hp_bar_height = body_height + 1.0
        gold_bounty = 110 if big else 60
        exp_bounty = 120 if big else 70
        _aggro = 15.0
        model_cfg = {"scale": 1.45 if big else 0.95, "build": "bulky", "body": Color(0.35, 0.5, 0.25) if big else Color(0.5, 0.4, 0.25),
            "accent": Color(0.8, 0.6, 0.2), "skin": Color(0.5, 0.65, 0.3), "weapon": "club", "hat": "horns", "eyes": Color(1.0, 0.7, 0.2)}
        return
    unit_name = "Осадный крип" if siege else "Крип"
    max_hp = 420.0 + wave * 22.0
    damage = 20.0 + wave * 0.8
    armor = 1.0 + wave * 0.06
    move_speed = 4.5 * Global.SPEED_MULT
    attack_interval = 1.25
    attack_range = 2.0
    body_radius = 0.7
    body_height = 2.0
    hp_bar_height = 3.0
    gold_bounty = 34 + int(wave * 0.35)
    exp_bounty = 52
    damage *= MatchBalance.creep_pressure(Global.elapsed)
    var col := team_color()
    model_cfg = {"scale": 0.85, "build": "mid", "body": col.darkened(0.2), "accent": col.lightened(0.3), "skin": Color(0.85, 0.7, 0.55), "weapon": "sword", "hat": "helmet"}
    if ranged_creep:
        is_ranged = true
        attack_range = 9.0
        max_hp *= 0.7
        damage *= 1.15
        projectile_speed = 30.0
        attack_point = 0.35
        model_cfg["weapon"] = "bow"
        model_cfg["hat"] = "hood"
    if siege:
        is_ranged = true
        attack_range = 11.0
        max_hp = 650.0 + wave * 30.0
        damage = 55.0 * MatchBalance.creep_pressure(Global.elapsed)
        building_dmg_mult = 2.2
        move_speed = 3.6 * Global.SPEED_MULT
        projectile_speed = 28.0
        attack_point = 0.5
        body_radius = 1.0
        body_height = 2.6
        hp_bar_height = 3.8
        gold_bounty = 62
        exp_bounty = 80
        model_cfg = {"scale": 1.15, "build": "bulky", "body": col.darkened(0.45), "accent": Color(0.9, 0.7, 0.3), "skin": Color(0.7, 0.6, 0.5), "weapon": "hammer", "hat": "helmet"}
        if guardian_empowered:
            unit_name = "Осадный крип Стража"
            model_cfg["accent"] = Color(0.2, 0.9, 0.8)


# ---------- выбор цели ----------
func _score(u: Unit) -> float:
    var d := Global.flat_dist(global_position, u.global_position)
    var s := -d
    if u is BaseHero:
        s += 6.0
        if (u as BaseHero).aggro_until > Global.elapsed:
            s += 45.0                     # герой ударил союзного героя - крипы переключаются на него
    elif u is Creep:
        s += 14.0
    elif u is Building:
        s += 28.0 if siege else -12.0
    s += (1.0 - u.hp / u.max_hp) * 6.0
    if u == _target:
        s += 4.0                           # небольшая инерция, чтобы не метаться
    return s


func _pick_target() -> Unit:
    var best: Unit = null
    var best_s: float = -1e9
    for n in Global.enemies_in_range(team, global_position, _aggro):
        var u := n as Unit
        var sc := _score(u)
        if sc > best_s:
            best_s = sc
            best = u
    return best


func _tick(delta: float) -> void:
    _retarget_cd -= delta
    if _retarget_cd <= 0.0:
        _retarget_cd = 0.3
        _target = _pick_target()
        if neutral and _target != null:
            _call_camp(_target)
    if not is_instance_valid(_target) or not _target.alive:
        _target = null
    if neutral:
        _neutral_tick(delta)
        return
    if _target != null:
        if in_attack_range(_target):
            face_towards(_target.global_position)
            try_attack(_target)
        else:
            chase(_target, delta)
    elif path_idx < path.size():
        var wp: Vector3 = path[path_idx]
        if move_towards(wp, delta, 6.0):
            path_idx += 1
    else:
        move_towards(goal_pos, delta, 4.0)


# ---------- нейтралы ----------
func _call_camp(t: Unit) -> void:
    if camp_id < 0:
        return
    for n in Global.units():
        var c := n as Creep
        if c != null and c != self and c.alive and c.neutral and c.camp_id == camp_id:
            c._target = t


func _neutral_tick(delta: float) -> void:
    var away := Global.flat_dist(global_position, home_pos)
    if away > (60.0 if guardian else 38.0):
        _returning = true
    if _returning:
        _target = null
        if move_towards(home_pos, delta, 1.0):
            _returning = false
        hp = minf(max_hp, hp + max_hp * 0.2 * delta)
        return
    if _target != null:
        if in_attack_range(_target):
            face_towards(_target.global_position)
            try_attack(_target)
        else:
            chase(_target, delta)
    else:
        if away > 1.0:
            move_towards(home_pos, delta, 0.5)
        hp = minf(max_hp, hp + max_hp * (0.03 if guardian else 0.15) * delta)


func _on_death(killer: Unit) -> void:
    if guardian:
        var kh := killer as BaseHero
        if kh != null:
            if kh.is_illusion and is_instance_valid(kh.illusion_owner): kh = kh.illusion_owner
            kh.add_status("aegis", 300.0)
            Global.siege_waves[kh.team] = 2
            Global.shout("%s: две усиленные осадные волны!" % Global.team_name(kh.team), Color(0.3, 0.85, 0.85))
            Global.shout("%s убили Древнего Стража! Амулет возрождения получен!" % Global.team_name(kh.team), Color(1.0, 0.85, 0.2))
            for h in Global.heroes_of(kh.team):
                (h as BaseHero).add_gold(200)
                (h as BaseHero).objectives += 1
        else:
            Global.shout("Древний Страж повержен!", Color(1.0, 0.85, 0.2))
    super._on_death(killer)

