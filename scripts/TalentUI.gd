class_name TalentUI
extends PanelContainer
## TalentUI.gd — окно талантов (клавиша G): 4 яруса по 2 варианта, выбор один раз за ярус.

var hero: BaseHero
var _btns: Array = []
var _acc: float = 0.0


func setup(h: BaseHero) -> void:
    hero = h
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 8)
    add_child(v)
    var title := Label.new()
    title.text = "ТАЛАНТЫ (G)"
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
    v.add_child(title)
    for i in 4:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        var lbl := Label.new()
        lbl.text = "Ур. %d" % int(TalentDB.LEVELS[i])
        lbl.custom_minimum_size = Vector2(64.0, 0.0)
        row.add_child(lbl)
        var pair: Array = []
        for c in 2:
            var b := Button.new()
            b.focus_mode = Control.FOCUS_NONE
            b.custom_minimum_size = Vector2(230.0, 44.0)
            b.pressed.connect(_pick.bind(i, c))
            row.add_child(b)
            pair.append(b)
        _btns.append(pair)
        v.add_child(row)
    var close := Button.new()
    close.text = "Закрыть"
    close.focus_mode = Control.FOCUS_NONE
    close.pressed.connect(toggle)
    v.add_child(close)
    _refresh()


func toggle() -> void:
    visible = not visible
    _refresh()


func _pick(i: int, c: int) -> void:
    hero.pick_talent(i, c)
    _refresh()


func _refresh() -> void:
    var tiers := hero.talent_tiers()
    for i in 4:
        for c in 2:
            var b: Button = _btns[i][c]
            b.text = String(tiers[i][c]["name"])
            var chosen: bool = hero.talents[i] == c
            b.disabled = hero.talents[i] != -1 or not hero.talent_available(i)
            b.modulate = Color(1.3, 1.15, 0.7) if chosen else Color.WHITE


func _process(delta: float) -> void:
    if visible:
        _acc += delta
        if _acc > 0.3:
            _acc = 0.0
            _refresh()
