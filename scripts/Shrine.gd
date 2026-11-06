class_name Shrine
extends Node3D
## Shrine.gd — святилище в лесу: герой рядом восстанавливает 35% здоровья и маны, затем кристалл гаснет на 90 секунд.

var _cd: float = 0.0
var _t: float = 0.0
var _crystal: MeshInstance3D
var _active: bool = true


func is_ready() -> bool:
    return _cd <= 0.0


func _ready() -> void:
    add_to_group("shrines")
    var base := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 4.0
    cm.bottom_radius = 5.0
    cm.height = 1.2
    cm.radial_segments = 10
    base.mesh = cm
    base.material_override = Global.get_mat(Color(0.5, 0.52, 0.56))
    base.position.y = 0.6
    add_child(base)
    var ring := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = 5.6
    tm.outer_radius = 6.0
    ring.mesh = tm
    ring.material_override = Global.get_mat(Color(0.4, 1.0, 0.6), 1.0)
    ring.position.y = 0.3
    add_child(ring)
    _crystal = MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(2.2, 3.4, 2.2)
    _crystal.mesh = bm
    _crystal.material_override = Global.get_mat(Color(0.4, 1.0, 0.6), 2.2)
    _crystal.position.y = 4.0
    add_child(_crystal)


func _physics_process(delta: float) -> void:
    _t += delta
    _cd = maxf(0.0, _cd - delta)
    _crystal.rotation.y = _t * 1.4
    _crystal.rotation.z = 0.5
    _crystal.position.y = 4.0 + sin(_t * 2.0) * 0.4
    var ready := _cd <= 0.0
    if ready != _active:
        _active = ready
        _crystal.material_override = Global.get_mat(Color(0.4, 1.0, 0.6), 2.2) if ready else Global.get_mat(Color(0.25, 0.3, 0.28))
    if not ready:
        return
    for n in get_tree().get_nodes_in_group("heroes"):
        var h := n as BaseHero
        if h != null and h.alive and Global.flat_dist(h.global_position, global_position) < 9.0:
            h.hp = minf(h.max_hp, h.hp + h.max_hp * 0.35)
            h.mp = minf(h.max_mp, h.mp + h.max_mp * 0.35)
            Global.spawn_burst(global_position, 7.0, Color(0.4, 1.0, 0.6))
            Global.float_text(h.global_position + Vector3(0.0, 12.0, 0.0), "Святилище", Color(0.5, 1.0, 0.7), 1.2)
            _cd = 90.0
            return
