class_name TouchJoystick
extends Control
## TouchJoystick.gd — виртуальный джойстик: ручка задаёт направление движения героя, отпустил - герой встаёт.

var vec: Vector2 = Vector2.ZERO
var active: bool = false


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index != MOUSE_BUTTON_LEFT:
            return
        if mb.pressed:
            active = true
            _set_from(mb.position)
        else:
            _release()
        accept_event()
    elif event is InputEventMouseMotion and active:
        _set_from((event as InputEventMouseMotion).position)
        accept_event()


func _set_from(p: Vector2) -> void:
    var c := size * 0.5
    var r := minf(size.x, size.y) * 0.5
    var d := (p - c) / r
    if d.length() > 1.0:
        d = d.normalized()
    vec = d
    queue_redraw()


func _release() -> void:
    active = false
    vec = Vector2.ZERO
    queue_redraw()


func _draw() -> void:
    var c := size * 0.5
    var r := minf(size.x, size.y) * 0.5
    draw_circle(c, r, Color(0.0, 0.0, 0.0, 0.35))
    draw_arc(c, r, 0.0, TAU, 48, Color(1.0, 0.85, 0.4, 0.7), 3.0)
    draw_circle(c + vec * (r * 0.6), r * 0.38, Color(1.0, 0.9, 0.5, 0.9 if active else 0.5))
