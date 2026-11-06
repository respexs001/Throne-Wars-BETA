class_name Building
extends Unit
## Building.gd — башня и трон.
## - башня неуязвима, пока жива башня яруса ниже на её линии; T4 (у трона) - пока живы все три T3; трон - пока жива хоть одна T4;
## - защита от бэкдора: пока рядом нет вражеских крипов, здание получает на 75% меньше урона и быстро лечится.

var damage_contributors: Dictionary = {}
var is_throne: bool = false
var tier: int = 0          # 0..2 = T1..T3 на линии, 3 = T4 у трона, 4 = трон
var lane: int = -1
var invulnerable: bool = false
var discovered: bool = false
var backdoor_protected: bool = false

var _prot_cd: float = 0.0
var _orb: MeshInstance3D
var _ring: MeshInstance3D
var _flames: Array = []
var _range_ring: MeshInstance3D
var _alert_t: float = -100.0
var _t: float = 0.0
var _kick: float = 0.0


func _configure() -> void:
    if is_throne:
        unit_name = "Трон"
        max_hp = MatchBalance.THRONE_HP
        armor = 18.0
        damage = 0.0
        body_radius = 5.0
        body_height = 8.0
        hp_bar_height = 12.0
    else:
        unit_name = "Башня T%d" % (tier + 1)
        max_hp = MatchBalance.TOWER_HP + tier * MatchBalance.TOWER_HP_PER_TIER
        armor = MatchBalance.TOWER_ARMOR + tier
        damage = MatchBalance.TOWER_DAMAGE + tier * 8.0
        attack_range = 17.0
        attack_interval = 1.1
        attack_point = 0.2
        is_ranged = true
        projectile_speed = 48.0
        body_radius = 2.4
        body_height = 11.0
        hp_bar_height = 13.5
        gold_bounty = 180 + tier * 70
        exp_bounty = 160 + tier * 40
    magic_resist = 0.25


func take_damage(amount: float, attacker: Unit = null, dtype: String = "phys", is_attack: bool = false) -> void:
    if invulnerable:
        return
    if team == Global.player_team and Global.elapsed - _alert_t > 20.0 and attacker != null:
        _alert_t = Global.elapsed
        Global.shout("%s атакуют!" % unit_name, Color(1.0, 0.55, 0.3))
        Global.ping(global_position, Color(1.0, 0.5, 0.2))
    if backdoor_protected:
        amount *= 0.25
    super.take_damage(amount, attacker, dtype, is_attack)


func _always_tick(delta: float) -> void:
    _prot_cd -= delta
    if _prot_cd <= 0.0:
        _prot_cd = 0.5
        invulnerable = _compute_protected()
        backdoor_protected = not _enemy_creep_near()
    if backdoor_protected:
        hp = minf(max_hp, hp + MatchBalance.BACKDOOR_REGEN * delta)
    if _range_ring != null:
        var ph := Global.player_hero
        _range_ring.visible = is_instance_valid(ph) and ph.alive and team != Global.player_team and Global.flat_dist(ph.global_position, global_position) < attack_range + 30.0
    _t += delta
    _kick = maxf(0.0, _kick - delta * 4.0)
    if _orb != null:
        _orb.scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.08 + _kick * 0.5)
    if _ring != null:
        _ring.rotation.y += delta * (1.2 if not invulnerable else 0.4)
    for i in _flames.size():
        var f: MeshInstance3D = _flames[i]
        f.scale = Vector3.ONE * (0.85 + 0.25 * sin(_t * 11.0 + float(i) * 1.7) * sin(_t * 7.3 + float(i)))


func _enemy_creep_near() -> bool:
    for n in Global.units():
        var c := n as Creep
        if c != null and c.alive and not c.neutral and c.team != team and Global.flat_dist(global_position, c.global_position) < 45.0:
            return true
    return false


func _compute_protected() -> bool:
    var t3_alive := 0
    for n in Global.units():
        var b := n as Building
        if b == null or b == self or not b.alive or b.team != team:
            continue
        if is_throne:
            if b.tier == 3:
                return true
        elif tier == 3:
            if b.tier == 2:
                t3_alive += 1
        elif tier > 0 and b.lane == lane and b.tier == tier - 1:
            return true
    if tier == 3 and not is_throne:
        return t3_alive >= 3
    return false


func _tick(_delta: float) -> void:
    if is_throne:
        return
    var target: Unit = null
    var best: float = 1e9
    for n in Global.enemies_in_range(team, global_position, attack_range):
        var u := n as Unit
        if u is Building:
            continue
        var d := Global.flat_dist(global_position, u.global_position)
        if u is BaseHero:
            d += 8.0
            if (u as BaseHero).aggro_until > Global.elapsed:
                d -= 40.0       # герой бьёт союзного героя под башней - башня переключается на него
        if d < best:
            best = d
            target = u
    if target != null and try_attack(target):
        _kick = 1.0


# ---------- внешний вид ----------
func _mesh_cyl(root: Node3D, top: float, bottom: float, h: float, y: float, color: Color, glow: float = 0.0, segs: int = 12) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var c := CylinderMesh.new()
    c.top_radius = top
    c.bottom_radius = bottom
    c.height = h
    c.radial_segments = segs
    mi.mesh = c
    mi.material_override = Global.get_mat(color, glow)
    mi.position.y = y
    root.add_child(mi)
    return mi


func _flame(root: Node3D, pos: Vector3, size: float) -> void:
    var mi := MeshInstance3D.new()
    var s := SphereMesh.new()
    s.radius = size
    s.height = size * 2.0
    s.radial_segments = 8
    s.rings = 4
    mi.mesh = s
    mi.material_override = Global.get_mat(Color(1.0, 0.6, 0.15), 3.0)
    mi.position = pos
    root.add_child(mi)
    _flames.append(mi)


func _make_body(root: Node3D) -> void:
    var col := team_color()
    var stone := Color(0.55, 0.55, 0.6)
    var dark := col.darkened(0.45)
    if is_throne:
        _mesh_cyl(root, 7.5, 8.0, 0.8, 0.4, stone.darkened(0.2), 0.0, 20)
        _mesh_cyl(root, 6.0, 6.8, 0.8, 1.2, stone, 0.0, 20)
        _mesh_cyl(root, 4.4, 5.2, 0.8, 2.0, stone.lightened(0.1), 0.0, 20)
        _mesh_cyl(root, 3.0, 3.6, 5.0, 4.9, dark, 0.0, 12)
        for i in 4:
            var a := TAU / 4.0 * float(i) + PI / 4.0
            var px := cos(a) * 5.6
            var pz := sin(a) * 5.6
            var p := _mesh_cyl(root, 0.5, 0.7, 5.0, 3.5, stone.lightened(0.15), 0.0, 8)
            p.position = Vector3(px, 3.5, pz)
            var cap := MeshInstance3D.new()
            var sm := SphereMesh.new()
            sm.radius = 0.7
            sm.height = 1.4
            cap.mesh = sm
            cap.material_override = Global.get_mat(col, 1.8)
            cap.position = Vector3(px, 6.3, pz)
            root.add_child(cap)
            _flame(root, Vector3(px, 7.0, pz), 0.4)
        _orb = MeshInstance3D.new()
        var s := SphereMesh.new()
        s.radius = 2.0
        s.height = 4.0
        _orb.mesh = s
        _orb.material_override = Global.get_mat(col, 2.2)
        _orb.position.y = 9.0
        root.add_child(_orb)
        _ring = MeshInstance3D.new()
        var tm := TorusMesh.new()
        tm.inner_radius = 3.1
        tm.outer_radius = 3.5
        _ring.mesh = tm
        _ring.material_override = Global.get_mat(Color(1.0, 0.9, 0.6), 1.4)
        _ring.position.y = 9.0
        _ring.rotation.x = 1.2
        root.add_child(_ring)
    else:
        _mesh_cyl(root, 3.4, 3.8, 0.9, 0.45, stone.darkened(0.2), 0.0, 10)
        _mesh_cyl(root, 2.0, 2.8, 6.0, 3.9, stone, 0.0, 8)
        _mesh_cyl(root, 2.5, 2.1, 0.7, 7.2, dark, 0.0, 8)
        _mesh_cyl(root, 2.3, 2.3, 1.6, 8.3, stone.lightened(0.1), 0.0, 8)
        var roof := _mesh_cyl(root, 0.0, 3.0, 2.4, 10.2, dark.darkened(0.1), 0.0, 8)
        roof.position.y = 10.4
        _orb = MeshInstance3D.new()
        var s2 := SphereMesh.new()
        s2.radius = 0.8
        s2.height = 1.6
        _orb.mesh = s2
        _orb.material_override = Global.get_mat(col, 2.4)
        _orb.position.y = 8.4
        root.add_child(_orb)
        _ring = MeshInstance3D.new()
        var tm2 := TorusMesh.new()
        tm2.inner_radius = 1.3
        tm2.outer_radius = 1.5
        _ring.mesh = tm2
        _ring.material_override = Global.get_mat(Color(1.0, 0.9, 0.6), 1.2)
        _ring.position.y = 8.4
        _ring.rotation.x = 1.2
        root.add_child(_ring)
        for sx in [-1.0, 1.0]:
            _flame(root, Vector3(sx * 3.0, 1.9, 0.0), 0.35)
        var banner := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.1, 2.4, 1.2)
        banner.mesh = bm
        banner.material_override = Global.get_mat(col, 0.5)
        banner.position = Vector3(2.4, 6.0, 0.0)
        root.add_child(banner)


func _rubble() -> void:
    var parent := get_parent()
    if parent == null:
        return
    var mat := Global.get_mat(Color(0.28, 0.26, 0.26))
    var n := 12 if is_throne else 7
    for i in n:
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        var s := randf_range(1.0, 3.2) * (1.6 if is_throne else 1.0)
        bm.size = Vector3(s, s * randf_range(0.4, 0.9), s)
        mi.mesh = bm
        mi.material_override = mat
        parent.add_child(mi)
        mi.global_position = global_position + Vector3(randf_range(-1.0, 1.0), 0.3, randf_range(-1.0, 1.0)) * body_radius * 1.2
        mi.rotation = Vector3(randf() * 0.6, randf() * TAU, randf() * 0.6)


func _on_death(_killer: Unit) -> void:
    _rubble()
    Global.spawn_burst(global_position, body_radius * 2.5, Color(1.0, 0.6, 0.2))
    Global.sfx("tower", -4.0)
    Global.shake(1.2)
    Global.ping(global_position, Color(1.0, 0.8, 0.3))
    Global.spawn_burst(global_position + Vector3(0.0, 5.0, 0.0), body_radius * 1.8, Color(1.0, 0.85, 0.4))
    if Global.selected_unit == self:
        Global.selected_unit = null
    if is_throne:
        Global.say("Трон (%s) разрушен!" % Global.team_name(team))
        # замедленная съёмка перед итогами
        var loser := team
        Engine.time_scale = 0.3
        Global.shake(2.2)
        var t := get_tree().create_timer(0.6, true, false, true)
        t.timeout.connect(func() -> void:
            Engine.time_scale = 1.0
            Global.end_game(1 - loser))
    else:
        Global.say("%s (%s) разрушена!" % [unit_name, Global.team_name(team)])
    queue_free()
