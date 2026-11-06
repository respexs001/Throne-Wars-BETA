class_name DayNightIcon
extends Control
## DayNightIcon.gd — маленький значок: солнце или луна.

var day: bool = true


func _init() -> void:
    custom_minimum_size = Vector2(28.0, 28.0)
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_day(v: bool) -> void:
    if v != day:
        day = v
        queue_redraw()


func _draw() -> void:
    var c := size * 0.5
    if day:
        draw_circle(c, 7.0, Color(1.0, 0.85, 0.3))
        for i in 8:
            var a := TAU / 8.0 * float(i)
            draw_line(c + Vector2(cos(a), sin(a)) * 9.5, c + Vector2(cos(a), sin(a)) * 13.0, Color(1.0, 0.9, 0.4), 2.0)
    else:
        draw_circle(c, 10.0, Color(0.9, 0.93, 1.0))
        draw_circle(c + Vector2(5.0, -3.0), 9.0, Color(0.1, 0.12, 0.22))
