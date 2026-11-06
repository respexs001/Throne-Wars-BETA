class_name StrategicBot
extends BotController
## Utility planner: lane pressure, local force, objective protection and commitment.
var strategy: String = "Удержание линии"
var _plan_at: float = 0.0
var _rotate_at: float = 0.0
var task_kind: String = "lane"
var task_position: Vector3 = Vector3.ZERO
var task_until: float = 0.0
var _objective: Unit
var _last_objective: float = -100.0

func _ready() -> void:
    difficulty = clampi(difficulty, 0, 2)
    super._ready()
    add_to_group("strategic_bots")

func _lane() -> void:
    if _b_survive():
        strategy = "Восстановление"
        return
    if difficulty > 0 and _now() >= _plan_at:
        _plan_at = _now() + 2.0
        _plan_objective()
        if mode != Mode.LANE:
            return
    if difficulty > 0 and _local_balance() < 0.65 and _fd < 65.0:
        strategy = "Отход к подкреплению"
        var anchor := Global.tower_def_pos(hero.team, lane, 0)
        hero.order_move(anchor)
        Abilities.ai_escape(hero, anchor)
        return
    if _execute_objective():
        return
    super._lane()

func _local_balance() -> float:
    var friendly: float = hero.hp * (hero.damage + 20.0) / 100.0
    var hostile: float = 1.0
    for n in Global.units_near(hero.global_position, 70.0):
        var u := n as Unit
        if u == null or u == hero or not u.alive or u.team > 1:
            continue
        if Global.flat_dist(hero.global_position, u.global_position) > 70.0:
            continue
        var weight: float = 1.0 if u is BaseHero else 0.22
        if u is Building:
            weight = 0.4
        var power: float = u.hp * (u.damage + 20.0) / 100.0 * weight
        if u.team == hero.team:
            friendly += power
        else:
            hostile += power
    return friendly / hostile

func _plan_objective() -> void:
    var best: Building = null
    var best_score: float = 0.0
    # Allies provide information around threatened buildings, even across the map.
    for n in Global.units():
        var b := n as Building
        if b == null or not b.alive or b.team != hero.team:
            continue
        var pressure: float = 0.0
        for e in Global.enemies_in_range(hero.team, b.global_position, 65.0):
            if e is Building or (e is Creep and (e as Creep).neutral):
                continue
            pressure += 3.0 if e is BaseHero else 0.55
        if pressure <= 0.0:
            continue
        var defenders: int = 0
        for a in Global.heroes_of(hero.team):
            if a != hero and a.alive and Global.flat_dist(a.global_position, b.global_position) < 90.0:
                defenders += 1
        defenders = maxi(defenders, TeamStrategy.committed(get_tree(), hero.team, b.global_position, self))
        var distance := Global.flat_dist(hero.global_position, b.global_position)
        var score: float = pressure * 12.0 + (1.0 - b.hp / b.max_hp) * 25.0
        score += 95.0 if b.is_throne else float(b.tier) * 9.0
        score -= float(defenders) * 22.0 + distance * 0.06
        if score > best_score:
            best_score = score
            best = b
    if best != null and best_score > 18.0 and _ratio > 0.45:
        _def_pos = best.global_position
        task_kind = "defend"
        task_position = _def_pos
        task_until = _now() + 18.0
        mode = Mode.DEFEND
        strategy = "Защита трона" if best.is_throne else "Защита линии"
        if best.lane >= 0:
            lane = best.lane
        if Global.flat_dist(hero.global_position, _def_pos) > 220.0 and _fd > 85.0:
            _use_item_id("tp_scroll", _def_pos)
        return
    if _try_guardian():
        return
    if task_kind == "guardian" and is_instance_valid(_objective) and _objective.alive:
        return
    task_kind = "push"
    if _now() < _rotate_at or _fd < 85.0 or _now() < 90.0:
        return
    var scores: Array[float] = [0.0, 0.0, 0.0]
    for l in 3:
        var point := Global.tower_def_pos(hero.team, l, 0)
        scores[l] = 20.0 - Global.flat_dist(hero.global_position, point) * 0.035
        for a in Global.heroes_of(hero.team):
            if a != hero and a.alive and _lane_of(a.global_position) == l:
                scores[l] -= 16.0
        for n in Global.units():
            var c := n as Creep
            if c == null or not c.alive or c.neutral or c.lane != l:
                continue
            if Global.flat_dist(c.global_position, point) < 100.0:
                scores[l] += 2.0 if c.team != hero.team else 0.5
    var choice: int = lane
    for l in 3:
        if scores[l] > scores[choice] + 8.0:
            choice = l
    if choice != lane:
        lane = choice
        _pos_smooth_ok = false
        strategy = "Перераспределение по линиям"
    else:
        strategy = "Давление с волной крипов"
    _rotate_at = _now() + 18.0

func _defend() -> void:
    if _b_survive():
        return
    var threat := Global.nearest_enemy(hero.team, _def_pos, 65.0)
    if threat == null or threat is Building or _now() > task_until:
        mode = Mode.LANE
        task_kind = "lane"
        task_until = 0.0
        return
    if Global.flat_dist(hero.global_position, _def_pos) > 65.0:
        _route_to(_def_pos)
        return
    if _local_balance() < 0.55 and _ratio < 0.65:
        hero.order_move(_def_pos - Global.forward(hero.team) * 15.0)
        return
    if Global.flat_dist(hero.global_position, threat.global_position) <= hero.attack_range + 14.0:
        Abilities.ai_use(hero, threat)
    hero.order_attack(threat)

func _gank() -> void:
    if _b_survive():
        return
    if _gank_target != null and is_instance_valid(_gank_target):
        if _danger(_gank_target.global_position) or _local_balance() < 0.7:
            _gank_target = null
            mode = Mode.LANE
            return
    super._gank()

# Upgrade permanent equipment instead of repeatedly rebuying consumed potions.
func _next_item() -> String:
    for id in BuildGuide.items(hero.hero_id, hero.build_choice):
        if id == "boots" and hero.inventory.has("battle_boots"):
            continue
        if not hero.inventory.has(id):
            return id
    return ""

func _b_shop() -> bool:
    if _fd < 100.0 or _enemy_near > 0 or _now() - _last_shop < 35.0:
        return false
    var id := _next_item()
    if id == "" or hero.gold < Global.item_price(hero.inventory, id) + 80:
        return false
    mode = Mode.SHOP
    strategy = "Улучшение экипировки"
    return true

func _buy_items() -> void:
    for i in 6:
        var id := _next_item()
        if id == "" or hero.gold < Global.item_price(hero.inventory, id):
            break
        if not hero.inventory.has(""):
            var slot: int = hero.inventory.find("iron_branch")
            if slot < 0:
                slot = hero.inventory.find("health_potion")
            if slot < 0:
                slot = hero.inventory.find("tp_scroll")
            if slot >= 0:
                hero.sell_item(slot)
        if not hero.buy_item(id):
            break

func _shop() -> void:
    var home := Global.fountain_pos(hero.team)
    if Global.flat_dist(hero.global_position, home) > 200.0:
        _use_item_id("tp_scroll", Global.throne_pos(hero.team))
        if hero.tp_left > 0.0:
            return
    _route_to(home)
    if Global.flat_dist(hero.global_position, home) < 18.0:
        _buy_items()
        _last_shop = _now()
        if _ratio < 0.4:
            mode = Mode.RETREAT
        else:
            _return_to_lane()

func _b_push() -> bool:
    if _foe != null and _fd < 55.0:
        return false
    for n in Global.enemies_in_range(hero.team, hero.global_position, hero.attack_range + 30.0):
        var b := n as Building
        if b == null or b.invulnerable or b.backdoor_protected:
            continue
        if _creeps_near(b.global_position, 28.0, false) >= 2:
            strategy = "Осада с союзной волной"
            hero.order_attack(b)
            return true
    return false

const Navigation = preload("res://scripts/BotNavigation.gd")
var _route_path: Array[Vector3] = []
var _route_goal: Vector3 = Vector3.INF
var _route_expires: float = 0.0
var _pickup_after: float = 0.0
var _pickup_deadline: float = 0.0

func _route_to(goal: Vector3) -> bool:
    if hero.tp_left > 0.0:
        return true
    if Global.flat_dist(hero.global_position, goal) < 5.0:
        hero.order_move(goal)
        return true
    if _route_path.is_empty() or Global.flat_dist(goal, _route_goal) > 3.0 or _now() >= _route_expires:
        _route_path = Navigation.route(hero.global_position, goal, hero.body_radius, hero.get_parent())
        _route_goal = goal
        _route_expires = _now() + 4.0
    while not _route_path.is_empty() and Global.flat_dist(hero.global_position, _route_path[0]) < 1.5:
        _route_path.pop_front()
    if _route_path.is_empty():
        return false
    hero.order_move(_route_path[0])
    return true

func _b_pickup() -> bool:
    if _now() < _pickup_after:
        return false
    if not super._b_pickup():
        return false
    _route_path.clear()
    _pickup_deadline = _now() + maxf(18.0, Global.flat_dist(hero.global_position, _rune_pos) / maxf(hero.eff_move_speed(), 1.0) * 2.0 + 6.0)
    return true

func _rune() -> void:
    if _now() >= _pickup_deadline:
        mode = Mode.LANE
        _pickup_after = _now() + 35.0
        _route_path.clear()
        return
    super._rune()
    if mode == Mode.RUNE and not _route_to(_rune_pos):
        mode = Mode.LANE
        _pickup_after = _now() + 35.0

func _retreat() -> void:
    super._retreat()
    if mode == Mode.RETREAT and hero.tp_left <= 0.0:
        _route_to(Global.fountain_pos(hero.team))

func _b_defend() -> bool:
    # Strategic reservations supersede the uncoordinated legacy fallback.
    return false

func _reset_combat_state() -> void:
    super._reset_combat_state()
    task_kind = "lane"
    task_until = 0.0
    _objective = null

func _try_guardian() -> bool:
    if difficulty < 1 or hero.level < 4 or _ratio < 0.75 or hero.mp < hero.max_mp * 0.25 or _fd < 80.0 or _now() - _last_objective < 40.0:
        return false
    var allies: int = 0
    for ally in Global.heroes_of(hero.team):
        if ally != hero and ally.alive and ally.hp > ally.max_hp * 0.6 and Global.flat_dist(ally.global_position, hero.global_position) < 110.0:
            allies += 1
    if allies == 0: return false
    for node in Global.units():
        var guardian := node as Creep
        if guardian == null or not guardian.guardian or not guardian.alive: continue
        if TeamStrategy.committed(get_tree(), hero.team, guardian.global_position, self) >= 2: return false
        _objective = guardian
        task_kind = "guardian"
        task_position = guardian.global_position
        task_until = _now() + 45.0
        _last_objective = _now()
        strategy = "Командная цель: Древний Страж"
        return true
    return false

func _execute_objective() -> bool:
    if task_kind == "guardian":
        if not is_instance_valid(_objective) or not _objective.alive or _now() > task_until or _ratio < 0.4 or _fd < 55.0:
            task_kind = "push"
            _objective = null
            task_until = 0.0
            return false
        var distance := Global.flat_dist(hero.global_position, _objective.global_position)
        if distance > hero.attack_range + hero.body_radius + _objective.body_radius:
            _route_to(_objective.global_position)
        else:
            Abilities.ai_use(hero, _objective)
            hero.order_attack(_objective)
        return true
    if task_kind != "push" or _now() < 45.0 or _ratio < 0.5:
        return false
    # Farm and escort the active wave rather than waiting far behind melee creeps.
    if _foe != null and _fd < 40.0:
        if _b_kill() or _b_harass(): return true
    if _b_lasthit(): return true
    var target: Building = null
    var best_distance: float = INF
    for node in Global.units():
        var building := node as Building
        if building == null or not building.alive or building.team == hero.team or building.invulnerable: continue
        if building.lane >= 0 and building.lane != lane: continue
        var d := Global.flat_dist(hero.global_position, building.global_position)
        if d < best_distance:
            best_distance = d
            target = building
    if target == null: return false
    if _creeps_near(target.global_position, 45.0, false) >= 2 and (_foe == null or _fd > 35.0 or _local_balance() > 1.2):
        strategy = "Осада с союзной волной"
        if best_distance < hero.attack_range + hero.body_radius + target.body_radius + 1.0:
            hero.order_attack(target)
        else:
            hero.order_amove(target.global_position)
        return true
    if _front != null:
        strategy = "Сопровождение волны"
        var wp: Vector3 = _front.path[_front.path_idx] if _front.path_idx < _front.path.size() else _front.goal_pos
        var direction: Vector3 = (wp - _front.global_position).normalized()
        var follow := _front.global_position - direction * (3.0 if not hero.is_ranged else maxf(hero.attack_range * 0.6, 8.0))
        hero.order_amove(follow)
        return true
    return false
