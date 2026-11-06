class_name FirstMatchGuide
extends CanvasLayer
var hero: BaseHero
var step: int = 0
var _start: Vector3
var _label: Label
var _elapsed: float = 0.0
var _baseline_damage: float = 0.0
var _last_inventory: Array = []
const STEPS: Array[String] = [
    "1/5 · Передвижение: ПКМ по земле. Пройдите несколько шагов.",
    "2/5 · Атака: ПКМ по вражескому крипу. Дождитесь попадания.",
    "3/5 · Способность: изучите Q кнопкой «+», затем примените её.",
    "4/5 · Предмет: F4 — магазин. Купите зелье и используйте его клавишей слота (Z–N).",
    "5/5 · Цель: сопровождайте крипов к вражеской башне и нанесите ей урон.",
]
func setup(unit: BaseHero) -> void:
    hero = unit
    _start = hero.global_position
    _baseline_damage = hero.damage_dealt
    _last_inventory = hero.inventory.duplicate()
    var panel := PanelContainer.new()
    panel.position = Vector2(16, 100)
    panel.custom_minimum_size = Vector2(350, 0)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.055, 0.07, 0.94)
    style.border_color = Color(0.75, 0.25, 0.2)
    style.set_border_width_all(1)
    style.set_content_margin_all(12)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    var column := VBoxContainer.new()
    panel.add_child(column)
    _label = Label.new()
    _label.custom_minimum_size.x = 325
    _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label.add_theme_font_size_override("font_size", 15)
    column.add_child(_label)
    var skip := Button.new()
    skip.text = "Закрыть подсказки"
    skip.pressed.connect(_finish)
    column.add_child(skip)
func _process(delta: float) -> void:
    if not is_instance_valid(hero) or Global.is_over:
        queue_free()
        return
    _elapsed += delta
    var done: bool = false
    match step:
        0: done = Global.flat_dist(hero.global_position, _start) > 8.0
        1: done = hero.damage_dealt > _baseline_damage
        2:
            for cd in hero.ab_cd:
                if float(cd) > 0.0: done = true
        3:
            for cd in hero.item_cd:
                if float(cd) > 0.0: done = true
            if hero.inventory.count("health_potion") < _last_inventory.count("health_potion"): done = true
            _last_inventory = hero.inventory.duplicate()
        4: done = hero.building_damage > 0.0
    if done:
        step += 1
    if step >= STEPS.size():
        _finish()
        return
    _label.text = STEPS[step]
    if _elapsed > 120.0:
        _label.text += "\nПродолжайте в своём темпе — подсказки можно закрыть."
func _finish() -> void:
    Global.tutorial_seen = true
    Global.save_settings()
    queue_free()
