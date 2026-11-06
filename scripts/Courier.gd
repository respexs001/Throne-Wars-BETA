class_name Courier
extends Unit
## Courier.gd — летающий курьер. Покупки вдали от базы попадают в его сумку; кнопка "Курьер" посылает его к герою,
## он кладёт предметы в инвентарь и возвращается. Враги могут его убить (возрождение 60 с, сумка теряется).

const RESPAWN: float = 60.0

var stash: Array = []
var owner_hero: BaseHero
var state: int = 0          # 0 дома, 1 летит к герою, 2 возвращается
var _respawn_t: float = 0.0
var _wings: Array = []
var _bag: MeshInstance3D
var _t: float = 0.0


func _configure() -> void:
    unit_name = "Курьер"
    max_hp = 220.0
    armor = 0.0
    move_speed = 18.0
    body_radius = 0.6
    body_height = 1.2
    hp_bar_height = 1.6
    gold_bounty = 100


func _sph(root: Node3D, r: float, pos: Vector3, col: Color, glow: float = 0.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    s.radial_segments = 10
    s.rings = 6
    mi.mesh = s
    mi.material_override = Global.get_mat(col, glow)
    mi.position = pos
    root.add_child(mi)
    return mi


func _make_body(root: Node3D) -> void:
    var col := team_color()
    var body := _sph(root, 1.6, Vector3(0.0, 4.2, 0.0), col)
    body.scale = Vector3(1.0, 0.85, 1.4)
    _sph(root, 0.9, Vector3(0.0, 5.1, 2.0), col.lightened(0.3))
    var beak := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.0
    cm.bottom_radius = 0.35
    cm.height = 1.1
    cm.radial_segments = 6
    beak.mesh = cm
    beak.material_override = Global.get_mat(Color(1.0, 0.75, 0.2))
    beak.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    beak.position = Vector3(0.0, 5.0, 3.0)
    root.add_child(beak)
    for side in [-1.0, 1.0]:
        var pv := Node3D.new()
        pv.position = Vector3(float(side) * 1.3, 4.7, 0.0)
        var w := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(3.0, 0.15, 1.8)
        w.mesh = bm
        w.material_override = Global.get_mat(Color(0.95, 0.95, 1.0))
        w.position = Vector3(float(side) * 1.5, 0.0, 0.0)
        pv.add_child(w)
        root.add_child(pv)
        _wings.append(pv)
    _bag = MeshInstance3D.new()
    var bb := BoxMesh.new()
    bb.size = Vector3(1.4, 1.0, 1.4)
    _bag.mesh = bb
    _bag.material_override = Global.get_mat(Color(1.0, 0.8, 0.25), 1.2)
    _bag.position = Vector3(0.0, 6.0, -0.6)
    _bag.visible = false
    root.add_child(_bag)


func _separate_units(_delta: float) -> void:
    pass


func _home() -> Vector3:
    return Global.fountain_pos(team) + Vector3(10.0, 0.0, 0.0)


func deliver_to(h: BaseHero) -> bool:
    if not alive or stash.is_empty():
        return false
    owner_hero = h
    state = 1
    return true


func call_home() -> void:
    if alive:
        state = 2


func _fly_to(pos: Vector3, delta: float, stop: float) -> bool:
    var d := pos - global_position
    d.y = 0.0
    var l := d.length()
    if l <= stop:
        return true
    face_towards(pos)
    global_position += d / l * minf(move_speed * delta, l - stop)
    return false


func _always_tick(delta: float) -> void:
    _t += delta
    for i in _wings.size():
        var pv: Node3D = _wings[i]
        pv.rotation.z = (1.0 if i == 1 else -1.0) * sin(_t * 14.0) * 0.6
    if _bag != null:
        _bag.visible = not stash.is_empty()


func _tick(delta: float) -> void:
    match state:
        0:
            if Global.flat_dist(global_position, _home()) > 3.0:
                _fly_to(_home(), delta, 1.0)
        1:
            if is_instance_valid(owner_hero) and owner_hero.alive:
                if _fly_to(owner_hero.global_position, delta, 8.0):
                    _drop()
                    state = 2
            else:
                state = 2
        2:
            if _fly_to(_home(), delta, 1.0):
                state = 0


func _drop() -> void:
    var n := 0
    for id in stash.duplicate():
        var slot := owner_hero.inventory.find("")
        if slot == -1:
            break
        owner_hero.inventory[slot] = id
        owner_hero.item_cd[slot] = 0.0
        stash.erase(id)
        n += 1
    owner_hero.recalc_stats()
    if n > 0:
        Global.float_text(owner_hero.global_position + Vector3(0.0, 12.0, 0.0), "Курьер: +%d предм." % n, Color(1.0, 0.9, 0.4), 1.2)
        Global.sfx("gold", -8.0)
    if not stash.is_empty():
        Global.say("Инвентарь полон: часть предметов осталась у курьера")


func _on_death(_killer: Unit) -> void:
    stash.clear()
    Global.say("Курьер (%s) уничтожен" % Global.team_name(team))
    visible = false
    collision_layer = 0
    _respawn_t = RESPAWN


func _dead_tick(delta: float) -> void:
    _respawn_t -= delta
    if _respawn_t <= 0.0:
        alive = true
        hp = max_hp
        global_position = _home()
        visible = true
        collision_layer = 2
        state = 0
        _set_bars_visible(true)
