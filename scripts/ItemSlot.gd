class_name ItemSlot
extends Control
## ItemSlot.gd — слот предмета: иконка, клавиша, перезарядка. Клик использует предмет, наведение показывает подсказку.

signal pressed(i: int)
signal hovered(i: int, on: bool)

var index: int = 0
var key_text: String = ""
var item_id: String = ""
var cd_left: float = 0.0
var cd_total: float = 1.0
var _hover: bool = false


func _ready() -> void:
    mouse_entered.connect(func() -> void:
        _hover = true
        hovered.emit(index, true))
    mouse_exited.connect(func() -> void:
        _hover = false
        hovered.emit(index, false))


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
            pressed.emit(index)
            accept_event()


func _draw() -> void:
    var font := ThemeDB.fallback_font
    var r := Rect2(Vector2.ZERO, size)
    draw_rect(r, Color(0.07, 0.08, 0.11, 0.95))
    if item_id != "":
        var item: Dictionary = Global.ITEMS[item_id]
        var ic: String = item["icon"]
        IconPainter.paint(self, r.grow(-2.0), ic, IconPainter.color_for(ic))
        if cd_left > 0.0:
            var k := clampf(cd_left / maxf(cd_total, 0.1), 0.0, 1.0)
            draw_rect(Rect2(Vector2(2.0, 2.0), Vector2(size.x - 4.0, (size.y - 4.0) * k)), Color(0.0, 0.0, 0.0, 0.65))
            draw_string(font, Vector2(0.0, size.y * 0.66), str(int(ceilf(cd_left))), HORIZONTAL_ALIGNMENT_CENTER, size.x, int(size.y * 0.42), Color.WHITE)
    draw_rect(Rect2(Vector2(2.0, 2.0), Vector2(size.x * 0.3, size.y * 0.28)), Color(0.0, 0.0, 0.0, 0.65))
    draw_string(font, Vector2(2.0, size.y * 0.25), key_text, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.3, int(size.y * 0.24), Color(0.95, 0.9, 0.55))
    draw_rect(r, Color(1.0, 1.0, 0.6) if _hover else Color(0.45, 0.47, 0.55), false, 2.0)
