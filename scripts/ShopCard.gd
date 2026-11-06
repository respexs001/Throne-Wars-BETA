class_name ShopCard
extends Control
## ShopCard.gd — карточка предмета в магазине: иконка, название, цена. Клик выбирает, повторный клик покупает.

signal pressed(id: String)
signal hovered(id: String)

var item_id: String = ""
var affordable: bool = true
var recommended: bool = false
var price: int = -1
var parts_have: int = 0
var parts_total: int = 0
var _hover: bool = false


func _init() -> void:
    custom_minimum_size = Vector2(128.0, 84.0)
    mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
    mouse_entered.connect(func() -> void:
        _hover = true
        hovered.emit(item_id))
    mouse_exited.connect(func() -> void:
        _hover = false
        hovered.emit(""))


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
            pressed.emit(item_id)
            accept_event()


func _draw() -> void:
    var item: Dictionary = Global.ITEMS[item_id]
    var font := ThemeDB.fallback_font
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.08, 0.06, 0.96))
    var ic: String = item["icon"]
    IconPainter.paint(self, Rect2(Vector2(6.0, 6.0), Vector2(44.0, 44.0)), ic, IconPainter.color_for(ic))
    draw_string(font, Vector2(54.0, 20.0), str(item["name"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 58.0, 12, Color(1.0, 0.95, 0.8))
    var col := Color(1.0, 0.85, 0.3) if affordable else Color(0.9, 0.35, 0.3)
    draw_circle(Vector2(60.0, 40.0), 5.0, col)
    draw_string(font, Vector2(70.0, 45.0), str(price if price >= 0 else int(item["cost"])), HORIZONTAL_ALIGNMENT_LEFT, 60.0, 14, col)
    if recommended:
        draw_colored_polygon(IconPainter._star(Vector2(size.x - 12.0, 12.0), 7.0, 5, 0.45), Color(1.0, 0.85, 0.3))
    if parts_total > 0:
        var pc := Color(0.6, 1.0, 0.6) if parts_have == parts_total else Color(0.95, 0.8, 0.4)
        draw_string(font, Vector2(size.x - 44.0, size.y - 8.0), "%d/%d" % [parts_have, parts_total], HORIZONTAL_ALIGNMENT_LEFT, 40.0, 12, pc)
    if not affordable:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.35))
    draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.85, 0.4) if _hover else Color(0.5, 0.4, 0.28), false, 2.0)
