class_name AbilityButton
extends Control
## AbilityButton.gd — кнопка способности с векторной иконкой, клавишей, уровнем, перезарядкой (сектор + секунды), кнопкой "+".
## Зажать и потянуть (телефон) - прицел: сигналы begin / moved / ended. Наведение показывает подсказку (hovered).

signal begin(i: int)
signal moved(i: int, vec: Vector2)
signal ended(i: int, vec: Vector2)
signal learn(i: int)
signal hovered(i: int, on: bool)

var index: int = 0
var icon: String = "orb"
var key_text: String = ""
var icon_color: Color = Color(0.6, 0.6, 0.8)
var level: int = 0
var max_level: int = 4
var cd_left: float = 0.0
var cd_total: float = 1.0
var mana_ok: bool = true
var passive: bool = false
var learnable: bool = false
var is_ult: bool = false

var _down: bool = false
var _hover: bool = false
var _origin: Vector2 = Vector2.ZERO
var _learn_btn: Button
var _pulse: Tween


func _ready() -> void:
    _learn_btn = Button.new()
    _learn_btn.text = "+"
    _learn_btn.focus_mode = Control.FOCUS_NONE
    _learn_btn.custom_minimum_size = Vector2(30.0, 24.0)
    _learn_btn.visible = false
    _learn_btn.pressed.connect(func() -> void: learn.emit(index))
    add_child(_learn_btn)
    _pulse = create_tween().set_loops()
    _pulse.tween_property(_learn_btn, "modulate", Color(1.0, 1.0, 0.3), 0.45)
    _pulse.tween_property(_learn_btn, "modulate", Color.WHITE, 0.45)
    mouse_entered.connect(func() -> void:
        _hover = true
        hovered.emit(index, true))
    mouse_exited.connect(func() -> void:
        _hover = false
        hovered.emit(index, false))


func set_learnable(v: bool) -> void:
    learnable = v
    if _learn_btn != null:
        _learn_btn.visible = v
        _learn_btn.position = Vector2(size.x * 0.5 - 15.0, -28.0)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index != MOUSE_BUTTON_LEFT:
            return
        if mb.pressed:
            _down = true
            _origin = mb.position
            begin.emit(index)
            accept_event()
        elif _down:
            _down = false
            ended.emit(index, mb.position - _origin)
            accept_event()
    elif event is InputEventMouseMotion and _down:
        moved.emit(index, (event as InputEventMouseMotion).position - _origin)
        accept_event()


func _draw() -> void:
    var font := ThemeDB.fallback_font
    var s := size.x
    var ir := Rect2(Vector2.ZERO, Vector2(s, s))
    IconPainter.paint(self, ir, icon, icon_color if level > 0 else Color(0.35, 0.35, 0.4))
    if level <= 0:
        draw_rect(ir, Color(0.0, 0.0, 0.0, 0.45))
    if level > 0 and not mana_ok and not passive:
        draw_rect(ir, Color(0.05, 0.1, 0.6, 0.5))
    if cd_left > 0.0:
        var frac := clampf(cd_left / maxf(cd_total, 0.1), 0.0, 1.0)
        var pts := PackedVector2Array()
        var cen := ir.get_center()
        pts.append(cen)
        var steps := 24
        for i in steps + 1:
            var a := -PI / 2.0 + TAU * frac * float(i) / float(steps)
            pts.append(cen + Vector2(cos(a), sin(a)) * s * 0.75)
        var clipped := PackedVector2Array()
        for p in pts:
            clipped.append(Vector2(clampf(p.x, 0.0, s), clampf(p.y, 0.0, s)))
        draw_colored_polygon(clipped, Color(0.0, 0.0, 0.0, 0.62))
        draw_string(font, Vector2(0.0, s * 0.64), str(int(ceilf(cd_left))), HORIZONTAL_ALIGNMENT_CENTER, s, int(s * 0.42), Color.WHITE)
    # рамка
    var border := Color(1.0, 0.82, 0.3) if is_ult else Color(0.7, 0.72, 0.8)
    if _hover or _down:
        border = Color(1.0, 1.0, 0.6)
    draw_rect(ir, border, false, 3.0 if (_hover or _down) else 2.0)
    # значок клавиши
    draw_rect(Rect2(Vector2(2.0, 2.0), Vector2(s * 0.34, s * 0.3)), Color(0.0, 0.0, 0.0, 0.7))
    draw_string(font, Vector2(2.0, s * 0.26), key_text, HORIZONTAL_ALIGNMENT_CENTER, s * 0.34, int(s * 0.24), Color(1.0, 0.92, 0.5))
    if passive:
        draw_string(font, Vector2(0.0, s - 4.0), "пасс.", HORIZONTAL_ALIGNMENT_CENTER, s, 10, Color(0.85, 0.85, 0.95))
    # точки уровня
    var pw := (s - 4.0) / float(max_level)
    for p in max_level:
        var pc := Color(1.0, 0.85, 0.2) if p < level else Color(0.25, 0.25, 0.3)
        draw_rect(Rect2(Vector2(2.0 + pw * float(p), s + 4.0), Vector2(pw - 2.0, 6.0)), pc)
