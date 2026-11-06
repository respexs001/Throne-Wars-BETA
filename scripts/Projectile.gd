class_name Projectile
extends Node3D
## Projectile.gd — снаряды: самонаводящийся (атаки), в точку со взрывом (AoE) и линейный (пробивает всех на пути).

enum Mode { HOMING, POINT, LINE }

var mode: Mode = Mode.HOMING
var target: Unit = null
var target_pos: Vector3 = Vector3.ZERO
var dir: Vector3 = Vector3.FORWARD
var speed: float = 22.0
var damage: float = 10.0
var dtype: String = "magic"
var source: Unit = null
var team: int = 0
var aoe_radius: float = 0.0
var width: float = 1.5
var travel: float = 0.0
var max_range: float = 20.0
var stun_time: float = 0.0
var slow_pct: float = 0.0
var slow_time: float = 0.0
var color: Color = Color(1.0, 0.85, 0.3)
var _hit_list: Array = []
var _trail_cd: float = 0.0


static func launch_homing(parent: Node, from: Vector3, tgt: Unit, src: Unit, spd: float) -> Projectile:
    var p := Projectile.new()
    p.mode = Mode.HOMING
    p.target = tgt
    p.source = src
    p.damage = src._attack_damage()
    p.team = src.team
    p.speed = spd
    p.color = Color(0.6, 0.85, 1.0) if src.team == 0 else Color(1.0, 0.55, 0.4)
    parent.add_child(p)
    p.global_position = from
    return p


static func launch_aoe(parent: Node, from: Vector3, to_pos: Vector3, dmg: float, src: Unit, spd: float, radius: float, col: Color, dt: String = "magic", stun: float = 0.0) -> Projectile:
    var p := Projectile.new()
    p.mode = Mode.POINT
    p.target_pos = Vector3(to_pos.x, 1.0, to_pos.z)
    p.damage = dmg
    p.source = src
    p.team = src.team
    p.speed = spd
    p.aoe_radius = radius
    p.color = col
    p.dtype = dt
    p.stun_time = stun
    parent.add_child(p)
    p.global_position = from
    return p


static func launch_line(parent: Node, from: Vector3, direction: Vector3, rng: float, wd: float, dmg: float, src: Unit, spd: float, col: Color, dt: String, stun: float, slow: float, slow_t: float) -> Projectile:
    var p := Projectile.new()
    p.mode = Mode.LINE
    p.dir = Vector3(direction.x, 0.0, direction.z).normalized()
    p.max_range = rng
    p.width = wd
    p.damage = dmg
    p.source = src
    p.team = src.team
    p.speed = spd
    p.color = col
    p.dtype = dt
    p.stun_time = stun
    p.slow_pct = slow
    p.slow_time = slow_t
    parent.add_child(p)
    p.global_position = from
    return p


func _ready() -> void:
    var mi := MeshInstance3D.new()
    var s := SphereMesh.new()
    var r: float = 0.25
    if mode == Mode.POINT:
        r = 0.6
    elif mode == Mode.LINE:
        r = 0.45
    s.radius = r
    s.height = r * 2.0
    mi.mesh = s
    mi.material_override = Global.get_mat(color, 3.0)
    mi.scale = Vector3.ONE * 2.0
    add_child(mi)


func _physics_process(delta: float) -> void:
    if mode != Mode.HOMING and not Global.is_touch():
        _trail_cd -= delta
        if _trail_cd <= 0.0:
            _trail_cd = 0.12
            Global.spawn_puff(global_position, color, 0.5)
    match mode:
        Mode.HOMING:
            _step_homing(delta)
        Mode.POINT:
            _step_point(delta)
        Mode.LINE:
            _step_line(delta)


func _step_homing(delta: float) -> void:
    if not is_instance_valid(target) or not target.alive:
        queue_free()
        return
    var aim := target.global_position + Vector3(0.0, target.body_height * 0.6, 0.0)
    var to_aim := aim - global_position
    var step := speed * delta
    if to_aim.length() <= step + 0.1:
        if is_instance_valid(source) and source.alive:
            source.deliver_attack(target)
        else:
            target.take_damage(damage, null, "phys", true)
        queue_free()
        return
    global_position += to_aim.normalized() * step


func _step_point(delta: float) -> void:
    var to_aim := target_pos - global_position
    var step := speed * delta
    if to_aim.length() <= step + 0.1:
        var src: Unit = source if is_instance_valid(source) else null
        for n in Global.enemies_in_range(team, global_position, aoe_radius):
            var u := n as Unit
            u.take_damage(damage, src, dtype)
            if stun_time > 0.0 and u.alive:
                u.add_status("stun", stun_time, 0.0, src)
        Global.spawn_burst(global_position, aoe_radius, color)
        queue_free()
        return
    global_position += to_aim.normalized() * step


func _step_line(delta: float) -> void:
    var step := speed * delta
    global_position += dir * step
    travel += step
    var src: Unit = source if is_instance_valid(source) else null
    for n in Global.enemies_in_range(team, global_position, width):
        var u := n as Unit
        if _hit_list.has(u) or u is Building:
            continue
        _hit_list.append(u)
        u.take_damage(damage, src, dtype)
        if u.alive:
            if stun_time > 0.0:
                u.add_status("stun", stun_time, 0.0, src)
            if slow_pct > 0.0:
                u.add_status("slow", slow_time, slow_pct, src)
        Global.spawn_burst(u.global_position, 1.4, color)
    if travel >= max_range:
        queue_free()
