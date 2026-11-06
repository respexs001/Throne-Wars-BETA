class_name Zone
extends Node3D
## Zone.gd — зона на земле: сначала предупреждающее кольцо (delay), затем урон/замедление/оглушение (разово или тиками).

var source: Unit = null
var team: int = 0
var radius: float = 5.0
var delay: float = 0.0
var duration: float = 0.0
var tick: float = 1.0
var dmg: float = 0.0
var dtype: String = "magic"
var slow: float = 0.0
var stun: float = 0.0
var color: Color = Color(1.0, 0.5, 0.2)

var _t: float = 0.0
var _next_tick: float = 0.0
var _first: bool = true
var _ring: MeshInstance3D
var _mat: StandardMaterial3D


static func launch(parent: Node, pos: Vector3, src: Unit, rad: float, dly: float, dur: float, tk: float, dmg_tick: float, dt: String, slow_pct: float, stun_dur: float, col: Color) -> Zone:
    var z := Zone.new()
    z.source = src
    z.team = src.team
    z.radius = rad
    z.delay = dly
    z.duration = dur
    z.tick = maxf(tk, 0.1)
    z.dmg = dmg_tick
    z.dtype = dt
    z.slow = slow_pct
    z.stun = stun_dur
    z.color = col
    parent.add_child(z)
    z.global_position = Vector3(pos.x, 0.05, pos.z)
    return z


func _ready() -> void:
    _ring = MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = radius
    cm.bottom_radius = radius
    cm.height = 0.06
    _ring.mesh = cm
    _mat = StandardMaterial3D.new()
    _mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mat.albedo_color = Color(color.r, color.g, color.b, 0.25)
    _ring.material_override = _mat
    add_child(_ring)
    _ring.scale = Vector3(0.1, 1.0, 0.1)
    var tw := create_tween()
    tw.tween_property(_ring, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
    _t += delta
    var pulse := 0.25 + 0.15 * sin(_t * 8.0)
    _mat.albedo_color = Color(color.r, color.g, color.b, pulse if _t < delay else 0.3)
    if _t < delay:
        return
    if duration <= 0.0:
        _apply()
        queue_free()
        return
    _next_tick -= delta
    if _next_tick <= 0.0:
        _next_tick = tick
        _apply()
    if _t >= delay + duration:
        queue_free()


func _apply() -> void:
    var src: Unit = source if is_instance_valid(source) else null
    for n in Global.enemies_in_range(team, global_position, radius):
        var u := n as Unit
        if dmg > 0.0:
            u.take_damage(dmg, src, dtype)
        if u.alive:
            if slow > 0.0:
                u.add_status("slow", 1.0, slow, src)
            if stun > 0.0 and _first:
                u.add_status("stun", stun, 0.0, src)
    _first = false
    # эффект: удары с неба по случайным точкам внутри зоны
    var a := randf() * TAU
    var r := sqrt(randf()) * radius
    var p := global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
    Global.spawn_beam(p + Vector3(0.0, 14.0, 0.0), p, color, 0.35, 0.3)
    Global.spawn_burst(p, 1.5, color)
