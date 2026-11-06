class_name IconBox
extends Control
## IconBox.gd — иконка способности для меню (рисуется IconPainter), подсказка - стандартная.

var icon: String = "orb"
var color: Color = Color(0.6, 0.6, 0.8)
var is_ult: bool = false
var key_text: String = ""


func _init() -> void:
    custom_minimum_size = Vector2(54.0, 54.0)
    mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
    var r := Rect2(Vector2.ZERO, size)
    IconPainter.paint(self, r, icon, color)
    draw_rect(r, Color(1.0, 0.82, 0.3) if is_ult else Color(0.7, 0.72, 0.8), false, 2.0)
    draw_rect(Rect2(Vector2(2.0, 2.0), Vector2(16.0, 15.0)), Color(0.0, 0.0, 0.0, 0.7))
    draw_string(ThemeDB.fallback_font, Vector2(3.0, 14.0), key_text, HORIZONTAL_ALIGNMENT_CENTER, 14.0, 13, Color(1.0, 0.92, 0.5))
