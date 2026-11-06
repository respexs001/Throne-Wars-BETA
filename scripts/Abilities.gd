class_name Abilities
extends RefCounted
## Abilities.gd — движок способностей. Все способности героев описаны данными в HeroDB.gd,
## а здесь реализованы их "виды" (kind): stun_point, nova, buff, proj_aoe, proj_line, blink, dash, leap,
## debuff, chain, zone, execute, cone, silence_point и пассивные p_*. Также простой ИИ применения для бота.


static func _mult(key: String) -> float:
    match key:
        "dmg":
            return Global.DMG_MULT
        "cd":
            return Global.CD_MULT
        "mana":
            return Global.MANA_MULT
        "range":
            return Global.RANGE_MULT
        "speed":
            return Global.SPEED_MULT
        "radius", "width":
            return 1.8
    return 1.0


static func v(ab: Dictionary, key: String, lvl: int, default: float = 0.0) -> float:
    if not ab.has(key):
        return default
    var x = ab[key]
    if x is Array:
        var arr: Array = x
        if arr.is_empty():
            return default
        return float(arr[clampi(lvl - 1, 0, arr.size() - 1)]) * _mult(key)
    return float(x) * _mult(key)


static func _pick(raw, lvl: int) -> float:
    if raw is Array:
        var arr: Array = raw
        return float(arr[clampi(lvl - 1, 0, arr.size() - 1)])
    return float(raw)


static func _clamp_pos(h: BaseHero, pos: Vector3, rng: float) -> Vector3:
    var d := pos - h.global_position
    d.y = 0.0
    if rng > 0.0 and d.length() > rng:
        return h.global_position + d.normalized() * rng
    return Vector3(pos.x, 0.0, pos.z)


static func _hurt(h: BaseHero, u: Unit, ab: Dictionary, lvl: int) -> float:
    var amount := v(ab, "dmg", lvl)
    if amount <= 0.0:
        return 0.0
    var before := u.hp
    u.take_damage(amount, h, ab.get("dtype", "magic"))
    return maxf(0.0, before - u.hp)


static func _col(ab: Dictionary) -> Color:
    return ab.get("color", Color(1.0, 0.6, 0.2))


static func cast(h: BaseHero, ab: Dictionary, lvl: int, target: Unit, pos: Vector3) -> bool:
    var kind: String = ab["kind"]
    match kind:
        "illusions":
            return _illusions(h, ab, lvl)
        "stun_point":
            return _stun_point(h, ab, lvl, pos)
        "nova":
            return _nova(h, ab, lvl)
        "buff":
            return _buff(h, ab, lvl)
        "proj_aoe":
            return _proj_aoe(h, ab, lvl, pos)
        "proj_line":
            return _proj_line(h, ab, lvl, pos)
        "blink":
            return _blink(h, ab, lvl, pos)
        "dash":
            return _dash(h, ab, lvl, target)
        "leap":
            return _leap(h, ab, lvl, pos)
        "debuff":
            return _debuff(h, ab, lvl, target)
        "chain":
            return _chain(h, ab, lvl, target)
        "zone":
            return _zone(h, ab, lvl, pos)
        "execute":
            return _execute(h, ab, lvl, target)
        "cone":
            return _cone(h, ab, lvl, pos)
        "silence_point":
            return _silence(h, ab, lvl, pos)
    return false


static func _stun_point(h: BaseHero, ab: Dictionary, lvl: int, pos: Vector3) -> bool:
    var p := _clamp_pos(h, pos, v(ab, "range", lvl))
    h.face_towards(p)
    var r := v(ab, "radius", lvl)
    for e in Global.enemies_in_range(h.team, p, r):
        var u := e as Unit
        _hurt(h, u, ab, lvl)
        if u.alive:
            u.add_status("stun", v(ab, "stun", lvl), 0.0, h)
    Global.spawn_burst(p, r, _col(ab))
    Global.spawn_beam(p + Vector3(0.0, 12.0, 0.0), p, _col(ab), 0.5, 0.3)
    return true


static func _nova(h: BaseHero, ab: Dictionary, lvl: int) -> bool:
    var r := v(ab, "radius", lvl)
    var total := 0.0
    for e in Global.enemies_in_range(h.team, h.global_position, r):
        var u := e as Unit
        total += _hurt(h, u, ab, lvl)
        if u.alive:
            var st := v(ab, "stun", lvl)
            if st > 0.0:
                u.add_status("stun", st, 0.0, h)
            var sl := v(ab, "slow", lvl)
            if sl > 0.0:
                u.add_status("slow", v(ab, "slow_dur", lvl, 2.5), sl, h)
    var pct := v(ab, "heal_pct", lvl)
    if pct > 0.0 and total > 0.0:
        h.heal(total * pct)
    Global.spawn_burst(h.global_position, r, _col(ab))
    return true


static func _buff(h: BaseHero, ab: Dictionary, lvl: int) -> bool:
    var dur := v(ab, "dur", lvl, 6.0)
    var buffs: Dictionary = ab.get("buffs", {})
    for k in buffs:
        h.add_status(k, dur, _pick(buffs[k], lvl), h)
    var g := v(ab, "grow", lvl)
    if g > 0.0 and h.model != null:
        h.model.grow(g, dur)
    Global.spawn_burst(h.global_position, 2.2, _col(ab))
    return true


static func _proj_aoe(h: BaseHero, ab: Dictionary, lvl: int, pos: Vector3) -> bool:
    var p := _clamp_pos(h, pos, v(ab, "range", lvl))
    h.face_towards(p)
    Projectile.launch_aoe(h.get_parent(), h.global_position + Vector3(0.0, 1.8, 0.0), p, v(ab, "dmg", lvl),
        h, v(ab, "speed", lvl, 24.0), v(ab, "radius", lvl), _col(ab), ab.get("dtype", "magic"), v(ab, "stun", lvl))
    return true


static func _proj_line(h: BaseHero, ab: Dictionary, lvl: int, pos: Vector3) -> bool:
    var d := pos - h.global_position
    d.y = 0.0
    if d.length() < 0.5:
        d = Global.forward(h.team)
    h.face_towards(h.global_position + d)
    Projectile.launch_line(h.get_parent(), h.global_position + Vector3(0.0, 1.5, 0.0), d, v(ab, "range", lvl),
        v(ab, "width", lvl, 1.5), v(ab, "dmg", lvl), h, v(ab, "speed", lvl, 30.0), _col(ab), ab.get("dtype", "magic"),
        v(ab, "stun", lvl), v(ab, "slow", lvl), v(ab, "slow_dur", lvl, 2.0))
    return true


static func _blink(h: BaseHero, ab: Dictionary, lvl: int, pos: Vector3) -> bool:
    var d := pos - h.global_position
    d.y = 0.0
    if d.length() < 1.0:
        return false
    var dest := _clamp_pos(h, pos, v(ab, "range", lvl))
    Global.spawn_burst(h.global_position, 1.6, _col(ab))
    h.global_position = Vector3(clampf(dest.x, -Global.MAP_HALF, Global.MAP_HALF), 0.0, clampf(dest.z, -Global.MAP_HALF, Global.MAP_HALF))
    h.has_move_target = false
    h.has_amove = false
    Global.spawn_burst(h.global_position, 1.6, _col(ab))
    return true


static func _dash(h: BaseHero, ab: Dictionary, lvl: int, target: Unit) -> bool:
    if target == null or not target.alive:
        return false
    var d := target.global_position - h.global_position
    d.y = 0.0
    var dir := d.normalized()
    Global.spawn_beam(h.global_position + Vector3(0.0, 1.0, 0.0), target.global_position + Vector3(0.0, 1.0, 0.0), _col(ab), 0.3, 0.3)
    h.global_position = target.global_position - dir * (h.body_radius + target.body_radius + 0.4)
    h.face_towards(target.global_position)
    _hurt(h, target, ab, lvl)
    if target.alive:
        var st := v(ab, "stun", lvl)
        if st > 0.0:
            target.add_status("stun", st, 0.0, h)
        h.attack_target = target
    return true


static func _leap(h: BaseHero, ab: Dictionary, lvl: int, pos: Vector3) -> bool:
    var dest := _clamp_pos(h, pos, v(ab, "range", lvl))
    h.face_towards(dest)
    h.add_status("root", 0.32, 0.0)
    var tw := h.create_tween()
    tw.tween_property(h, "global_position", dest, 0.3)
    tw.tween_callback(func() -> void: _leap_land(h, ab, lvl, dest))
    if h.model != null:
        var arc := h.model.create_tween()
        arc.tween_property(h.model, "position:y", 2.2, 0.15).set_ease(Tween.EASE_OUT)
        arc.tween_property(h.model, "position:y", 0.0, 0.15).set_ease(Tween.EASE_IN)
    return true


static func _leap_land(h: BaseHero, ab: Dictionary, lvl: int, dest: Vector3) -> void:
    if not is_instance_valid(h) or not h.alive:
        return
    var r := v(ab, "radius", lvl)
    for e in Global.enemies_in_range(h.team, dest, r):
        var u := e as Unit
        _hurt(h, u, ab, lvl)
        if u.alive and v(ab, "stun", lvl) > 0.0:
            u.add_status("stun", v(ab, "stun", lvl), 0.0, h)
    Global.spawn_burst(dest, r, _col(ab))


static func _debuff(h: BaseHero, ab: Dictionary, lvl: int, target: Unit) -> bool:
    if target == null or not target.alive:
        return false
    h.face_towards(target.global_position)
    _hurt(h, target, ab, lvl)
    if target.alive:
        var dur := v(ab, "dur", lvl, 3.0)
        var fx: Dictionary = ab.get("fx", {})
        for k in fx:
            target.add_status(k, dur, _pick(fx[k], lvl), h)
    Global.spawn_beam(h.global_position + Vector3(0.0, 2.0, 0.0), target.global_position + Vector3(0.0, 1.5, 0.0), _col(ab), 0.16, 0.25)
    Global.spawn_burst(target.global_position, 1.3, _col(ab))
    return true


static func _chain(h: BaseHero, ab: Dictionary, lvl: int, target: Unit) -> bool:
    if target == null or not target.alive:
        return false
    var hit: Array = []
    var cur: Unit = target
    var amount := v(ab, "dmg", lvl)
    var from := h.global_position + Vector3(0.0, 2.0, 0.0)
    var bounces := int(v(ab, "bounces", lvl, 3.0))
    for i in bounces + 1:
        if cur == null:
            break
        hit.append(cur)
        var top := cur.global_position + Vector3(0.0, 1.4, 0.0)
        Global.spawn_beam(from, top, _col(ab), 0.22, 0.3)
        from = top
        cur.take_damage(amount, h, ab.get("dtype", "magic"))
        amount *= v(ab, "falloff", lvl, 0.85)
        var nxt: Unit = null
        var best: float = 9.0
        for e in Global.enemies_in_range(h.team, cur.global_position, 9.0):
            var u := e as Unit
            if hit.has(u):
                continue
            var d := Global.flat_dist(cur.global_position, u.global_position)
            if d < best:
                best = d
                nxt = u
        cur = nxt
    return true


static func _zone(h: BaseHero, ab: Dictionary, lvl: int, pos: Vector3) -> bool:
    var p := _clamp_pos(h, pos, v(ab, "range", lvl))
    h.face_towards(p)
    Zone.launch(h.get_parent(), p, h, v(ab, "radius", lvl), v(ab, "delay", lvl), v(ab, "zdur", lvl), v(ab, "tick", lvl, 1.0),
        v(ab, "dmg", lvl), ab.get("dtype", "magic"), v(ab, "slow", lvl), v(ab, "stun", lvl), _col(ab))
    return true


static func _execute(h: BaseHero, ab: Dictionary, lvl: int, target: Unit) -> bool:
    if target == null or not target.alive:
        return false
    var amount := v(ab, "dmg", lvl) + v(ab, "pct", lvl) * (target.max_hp - target.hp)
    h.face_towards(target.global_position)
    Global.spawn_beam(h.global_position + Vector3(0.0, 1.5, 0.0), target.global_position + Vector3(0.0, 1.5, 0.0), _col(ab), 0.4, 0.4)
    Global.spawn_burst(target.global_position, 2.0, _col(ab))
    target.take_damage(amount, h, "pure")
    return true


static func _cone(h: BaseHero, ab: Dictionary, lvl: int, pos: Vector3) -> bool:
    var dir := pos - h.global_position
    dir.y = 0.0
    if dir.length() < 0.5:
        dir = Global.forward(h.team)
    dir = dir.normalized()
    var rng := v(ab, "range", lvl)
    var half := deg_to_rad(v(ab, "angle", lvl, 60.0)) * 0.5
    h.face_towards(h.global_position + dir)
    for e in Global.enemies_in_range(h.team, h.global_position, rng):
        var u := e as Unit
        var to := u.global_position - h.global_position
        to.y = 0.0
        if to.length() > 0.1 and dir.angle_to(to.normalized()) > half:
            continue
        _hurt(h, u, ab, lvl)
        if u.alive and v(ab, "slow", lvl) > 0.0:
            u.add_status("slow", v(ab, "slow_dur", lvl, 2.0), v(ab, "slow", lvl), h)
    for i in 7:
        var a := -half + (half * 2.0) * float(i) / 6.0
        Global.spawn_burst(h.global_position + dir.rotated(Vector3.UP, a) * rng * 0.65, 1.5, _col(ab))
    return true


static func _silence(h: BaseHero, ab: Dictionary, lvl: int, pos: Vector3) -> bool:
    var p := _clamp_pos(h, pos, v(ab, "range", lvl))
    h.face_towards(p)
    var r := v(ab, "radius", lvl)
    for e in Global.enemies_in_range(h.team, p, r):
        var u := e as Unit
        _hurt(h, u, ab, lvl)
        if u.alive:
            u.add_status("silence", v(ab, "dur", lvl, 3.0), 0.0, h)
    Global.spawn_burst(p, r, _col(ab))
    return true


# ---------------- ИИ бота ----------------
static func ai_use(h: BaseHero, target: Unit) -> bool:
    for i in range(h.abilities.size() - 1, -1, -1):
        if h.can_cast(i) and _ai_try(h, i, target):
            return true
    return false


static func _pick_enemy(h: BaseHero, rng: float, hero_only: bool, farm_ok: bool, preferred: Unit = null, execute_only: bool = false) -> Unit:
    var best: Unit = null
    var best_score: float = INF
    var creeps := 0
    var cluster: Unit = null
    for e in Global.enemies_in_range(h.team, h.global_position, rng):
        var u := e as Unit
        if u == null or u is Building:
            continue
        if u is BaseHero:
            # Execute ищет именно уязвимого героя, а не просто ближайшего.
            if execute_only and u.hp > u.max_hp * 0.6:
                continue
            # Если выбранная ботом цель жива и в радиусе, не подменяем её случайной.
            if is_instance_valid(preferred) and u == preferred:
                return u
            var score := Global.flat_dist(h.global_position, u.global_position)
            if execute_only:
                score -= (1.0 - u.hp / maxf(u.max_hp, 1.0)) * 10.0
            if score < best_score:
                best_score = score
                best = u
        elif not hero_only:
            creeps += 1
            if cluster == null:
                cluster = u
    if best != null:
        return best
    if farm_ok and creeps >= 3:
        return cluster
    return null

static func _ai_try(h: BaseHero, i: int, _target: Unit) -> bool:
    var ab: Dictionary = h.abilities[i]
    var lvl: int = h.ab_level[i]
    var kind: String = ab["kind"]
    var rng := v(ab, "range", lvl)
    var rad := v(ab, "radius", lvl)
    var is_ult := i == h.abilities.size() - 1
    var farm_ok := h.mp > h.max_mp * 0.6 and not is_ult
    match kind:
        "stun_point", "proj_aoe", "proj_line", "zone", "silence_point", "cone":
            var c := _pick_enemy(h, rng + rad * 0.5, is_ult, farm_ok, _target)
            if c == null:
                return false
            return h.cast_now(i, c, c.global_position)
        "debuff", "dash", "chain", "execute":
            var c2 := _pick_enemy(h, rng, is_ult or kind == "execute", farm_ok and kind == "chain", _target, kind == "execute")
            if c2 == null:
                return false
            if kind == "dash" and h.hp < h.max_hp * 0.35:
                return false
            return h.cast_now(i, c2, c2.global_position)
        "nova":
            var n := 0
            var heroes := 0
            for e in Global.enemies_in_range(h.team, h.global_position, rad):
                n += 1
                if e is BaseHero:
                    heroes += 1
            if heroes >= 1 or (n >= 3 and not is_ult):
                return h.cast_now(i, null, h.global_position)
        "leap":
            var c3 := _pick_enemy(h, rng, true, false, _target)
            if c3 != null and h.hp > h.max_hp * 0.4:
                return h.cast_now(i, null, c3.global_position)
        "buff":
            var buffs: Dictionary = ab.get("buffs", {})
            if buffs.is_empty() or h.has_status(String(buffs.keys()[0])):
                return false
            var near := Global.enemies_in_range(h.team, h.global_position, 14.0)
            var hero_near := false
            for e in near:
                if e is BaseHero:
                    hero_near = true
            var shield_ok: bool = buffs.has("shield") and h.hp < h.max_hp * 0.65 and near.size() > 0
            if hero_near or near.size() >= 4 or shield_ok:
                return h.cast_now(i, null, h.global_position)
    return false


static func ai_escape(h: BaseHero, home: Vector3) -> void:
    var threat := Global.nearest_enemy(h.team, h.global_position, 14.0)
    if threat == null:
        return
    for i in h.abilities.size():
        if not h.can_cast(i):
            continue
        var ab: Dictionary = h.abilities[i]
        var lvl: int = h.ab_level[i]
        var kind: String = ab["kind"]
        if kind == "blink":
            h.cast_now(i, null, home)
            return
        if kind == "buff" and ab.get("buffs", {}).has("haste"):
            h.cast_now(i, null, h.global_position)
            return
        if kind == "nova" and Global.flat_dist(h.global_position, threat.global_position) < v(ab, "radius", lvl):
            h.cast_now(i, null, h.global_position)
            return


# ---------------- оценка урона (для ИИ) ----------------
static func damage_potential(h: BaseHero, target: Unit) -> float:
    var total := 0.0
    for i in h.abilities.size():
        if not h.can_cast(i):
            continue
        var ab: Dictionary = h.abilities[i]
        var lvl: int = h.ab_level[i]
        var d := v(ab, "dmg", lvl)
        match ab["kind"]:
            "zone":
                d = d * maxf(1.0, v(ab, "zdur", lvl) / maxf(v(ab, "tick", lvl, 1.0), 0.1)) * 0.6
            "execute":
                d += v(ab, "pct", lvl) * (target.max_hp - target.hp)
            "buff", "blink":
                d = 0.0
        if d <= 0.0:
            continue
        var dt: String = ab.get("dtype", "magic")
        if dt == "magic":
            d *= 1.0 - target.magic_resist
        elif dt == "phys":
            var ar := target.eff_armor()
            d *= 1.0 - (0.06 * ar) / (1.0 + 0.06 * absf(ar))
        total += d
    for id in h.inventory:
        if id == "dagon":
            total += 400.0 * (1.0 - target.magic_resist)
    return total


# ---------------- описание для подсказки (BBCode) ----------------
const _LABELS: Dictionary = {
    "dmg": ["Урон", 1.0, 0], "stun": ["Оглушение, с", 1.0, 1], "dur": ["Длительность, с", 1.0, 1], "zdur": ["Время действия, с", 1.0, 1],
    "slow": ["Замедление, %", 100.0, 0], "slow_dur": ["Длит. замедления, с", 1.0, 1], "radius": ["Радиус", 1.0, 0], "range": ["Дальность", 1.0, 0],
    "bounces": ["Прыжков", 1.0, 0], "pct": ["% недостающего HP", 100.0, 0], "heal_pct": ["Лечение от урона, %", 100.0, 0],
    "val": ["Бонус", 1.0, 0], "chance": ["Шанс, %", 100.0, 0], "angle": ["Угол, град.", 1.0, 0],
}
const _BUFF_LABELS: Dictionary = {
    "rage": ["Бонус урона, %", 100.0], "haste": ["Скорость, %", 100.0], "shield": ["Щит", 1.0], "armor": ["Броня", 1.0],
    "evasion": ["Уклонение, %", 100.0], "lifesteal": ["Вампиризм, %", 100.0], "aspd": ["Скорость атаки", 1.0],
    "regen_pct": ["Реген HP/MP, %/с", 100.0], "poison": ["Яд, урон/с", 1.0], "burn": ["Поджог, урон/с", 1.0], "slow": ["Замедление, %", 100.0],
}


static func _vals(raw, cur: int, scale: float, decimals: int) -> String:
    var arr: Array = raw if raw is Array else [raw]
    var parts: Array = []
    for i in arr.size():
        var s: String = ("%." + str(decimals) + "f") % (float(arr[i]) * scale)
        if i + 1 == cur and arr.size() > 1:
            s = "[color=#ffd54a][b]%s[/b][/color]" % s
        parts.append(s)
    return " / ".join(parts)


static func describe(ab: Dictionary, cur: int, max_level: int, key_text: String, is_ult: bool) -> String:
    var targets: Dictionary = {"none": "без цели", "point": "точка на земле", "unit": "выбранная цель", "passive": "пассивная"}
    var kind_txt := "Ультимативная способность" if is_ult else ("Пассивная способность" if ab["target"] == "passive" else "Активная способность")
    var out: Array = []
    out.append("[font_size=19][b][color=#ffe08a]%s[/color][/b][/font_size]  [color=#aab](%s)[/color]" % [ab["name"], key_text])
    out.append("[color=#9fb4ff]%s[/color]  -  цель: %s" % [kind_txt, targets.get(ab["target"], "")])
    out.append("[color=#ddd]%s[/color]" % ab.get("desc", ""))
    out.append("")
    out.append("Уровень: [color=#ffd54a]%d[/color] / %d" % [cur, max_level])
    for key in ["dmg", "stun", "dur", "zdur", "slow", "slow_dur", "radius", "range", "bounces", "pct", "heal_pct", "val", "chance", "angle"]:
        if not ab.has(key):
            continue
        if key == "dur" and (ab.has("buffs") or ab.has("fx")):
            pass
        var info: Array = _LABELS[key]
        out.append("%s: %s" % [info[0], _vals(ab[key], cur, float(info[1]) * _mult(key), int(info[2]))])
    for grp in ["buffs", "fx"]:
        if ab.has(grp):
            var d: Dictionary = ab[grp]
            for k in d:
                if _BUFF_LABELS.has(k):
                    var bi: Array = _BUFF_LABELS[k]
                    out.append("%s: %s" % [bi[0], _vals(d[k], cur, float(bi[1]), 0)])
                elif k == "stun" or k == "root" or k == "silence":
                    out.append("Эффект: %s" % {"stun": "оглушение", "root": "обездвиживание", "silence": "безмолвие"}[k])
    if ab.has("mana"):
        out.append("[color=#6fa8ff]Мана: %s[/color]" % _vals(ab["mana"], cur, _mult("mana"), 0))
    if ab.has("cd"):
        out.append("[color=#c9c9c9]Перезарядка, с: %s[/color]" % _vals(ab["cd"], cur, _mult("cd"), 1))
    return "\n".join(out)


static func _illusions(h: BaseHero, ab: Dictionary, lvl: int) -> bool:
    var count := int(v(ab, "count", lvl, 2.0))
    var dur := v(ab, "dur", lvl, 18.0)
    var dmg_deal := v(ab, "dmg_deal", lvl, 0.3)
    var dmg_take := v(ab, "dmg_take", lvl, 2.5)
    var parent := h.get_parent()
    if parent == null:
        return false
    # Повторный каст заменяет старые иллюзии этого героя.
    for n in h.get_tree().get_nodes_in_group("illusions"):
        var old := n as BaseHero
        if old != null and old.illusion_owner == h:
            old.dismiss()
    for i in range(count):
        var a := TAU * float(i) / float(maxi(count, 1)) + randf() * 0.5
        spawn_illusion(h, dur, dmg_deal, dmg_take, h.position + Vector3(cos(a), 0.0, sin(a)) * 3.5)
    return true


static func spawn_illusion(h: BaseHero, dur: float, dmg_deal: float, dmg_take: float, pos: Vector3) -> BaseHero:
    var parent := h.get_parent()
    if parent == null:
        return null
    var ill := BaseHero.new()
    ill.hero_id = h.hero_id
    ill.team = h.team
    ill.is_player = false
    ill.level = h.level
    ill.inventory = h.inventory.duplicate()
    ill.is_illusion = true
    ill.illusion_owner = h
    ill.illusion_left = dur
    ill.illusion_dmg_deal = dmg_deal
    ill.illusion_dmg_take = dmg_take
    ill.position = pos
    parent.add_child(ill)
    Global.spawn_burst(ill.global_position, 2.0, Color(0.5, 0.85, 1.0))
    return ill
