class_name PreMatchUI
extends CanvasLayer
## PreMatchUI.gd — подготовка перед матчем. Совместимо с ThroneWars 1.0.2.
##
## Изменения после ревью:
##   • _reset_purchases возвращает к стартовому золоту и очищает инвентарь —
##     эксплойт с «дорогим рецептом из чужих компонентов» закрыт.
##   • PRIMARY_LANE — единая мапа, .get() от неизвестного атрибута.
##   • _process guard от null _lbl_time (если setup не вызван).
##   • Кнопка «Пропустить» (Esc) — не ждать 75 секунд.
##   • Таймер предупреждает в последние 10 секунд.
##   • _buy_kit различает полную / частичную / нулевую покупку.
##   • Hover у кнопок линий заметен (lightened).
##   • _lbl_time выровнен по центру.
##   • Кеш StyleBoxFlat — меньше мусора при повторных открытиях.
##   • set_process(false) в _finish для чистоты.

signal finished(lane: int)

const LANES: Array = [
	["Верхняя линия", 0],
	["Центральная линия (мид)", 1],
	["Нижняя линия", 2],
	["Свободно: лес и роуминг", -1]
]
const LANE_NAMES: Dictionary = {0: "верхняя линия", 1: "центральная линия", 2: "нижняя линия", -1: "свободная игра"}
const PRIMARY_LANE: Dictionary = {"int": 1, "agi": 2, "str": 0}
const KITS: Array = [
	["Универсальный", ["tp_scroll", "health_potion", "iron_branch", "iron_branch"]],
	["Маг", ["tp_scroll", "mana_potion", "mana_potion", "health_potion", "iron_branch"]],
	["Боец", ["ring_health", "health_potion"]],
	["Скорость", ["boots"]],
]
const TIME_LIMIT: float = 75.0
const TIME_WARN: float = 10.0

var hero: BaseHero
var _lane: int = 1
var _left: float = TIME_LIMIT
var _lbl_time: Label
var _lbl_hint: Label
var _status: Label
var _done: bool = false
var _start_gold: int = 0
var _style_cache: Dictionary = {}


func _sb(bg: Color, border: Color, radius: float = 12.0, margin: float = 12.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(int(radius))
	s.set_content_margin_all(margin)
	return s


func _btn_style(bg: Color, border: Color, radius: float = 8.0) -> StyleBoxFlat:
	var key := "%s_%s_%s" % [bg.to_html(), border.to_html(), radius]
	if _style_cache.has(key):
		return _style_cache[key]
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(int(radius))
	s.set_content_margin_all(8.0)
	_style_cache[key] = s
	return s


func _button(text: String, w: float, h: float, cb: Callable, is_accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	var bg_normal = Color(0.14, 0.16, 0.22, 0.9) if not is_accent else Color(0.85, 0.65, 0.15, 0.9)
	var border_normal = Color(0.3, 0.35, 0.45) if not is_accent else Color(1.0, 0.85, 0.4)
	var text_color = Color(0.9, 0.92, 0.95) if not is_accent else Color(0.08, 0.08, 0.1)
	b.add_theme_stylebox_override("normal", _btn_style(bg_normal, border_normal))
	b.add_theme_stylebox_override("hover", _btn_style(bg_normal.lightened(0.15), border_normal.lightened(0.2)))
	b.add_theme_stylebox_override("pressed", _btn_style(bg_normal.darkened(0.15), border_normal))
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_hover_color", text_color)
	b.pressed.connect(cb)
	return b


func setup(h: BaseHero) -> void:
	hero = h
	_start_gold = hero.gold
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lane = int(PRIMARY_LANE.get(hero.primary, 1))

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.95)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# --- ШАПКА ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)

	var title_box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Подготовка к матчу"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Распределите роли, закупитесь и разработайте тактику"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	title_box.add_child(subtitle)
	top.add_child(title_box)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)

	var time_container := PanelContainer.new()
	time_container.add_theme_stylebox_override("panel", _sb(Color(0.1, 0.12, 0.18), Color(0.3, 0.35, 0.45), 8, 6))
	_lbl_time = Label.new()
	_lbl_time.add_theme_font_size_override("font_size", 18)
	_lbl_time.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	_lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_time.custom_minimum_size = Vector2(160, 0)
	time_container.add_child(_lbl_time)
	top.add_child(time_container)

	var skip := _button("Пропустить (Esc)", 160.0, 48.0, _finish, false)
	top.add_child(skip)

	var ready := _button("ГОТОВ К БОЮ ▶", 200.0, 48.0, _finish, true)
	ready.add_theme_font_size_override("font_size", 16)
	top.add_child(ready)

	# --- КОНТЕНТ ---
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# Левая панель
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.09, 0.13, 0.95), Color(0.7, 0.55, 0.2, 0.6)))
	left.custom_minimum_size = Vector2(340.0, 0.0)
	body.add_child(left)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	left.add_child(lv)

	lv.add_child(_head("1. Выберите линию"))

	var group := ButtonGroup.new()
	for item in LANES:
		var b := Button.new()
		b.text = item[0]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(310.0, 38.0)
		b.button_pressed = int(item[1]) == _lane

		var s_off := _btn_style(Color(0.12, 0.14, 0.2), Color(0.25, 0.3, 0.4))
		var s_hover := _btn_style(Color(0.18, 0.21, 0.28), Color(0.45, 0.52, 0.65))
		var s_on := _btn_style(Color(0.3, 0.25, 0.1), Color(1.0, 0.8, 0.3))
		b.add_theme_stylebox_override("normal", s_off)
		b.add_theme_stylebox_override("hover", s_hover)
		b.add_theme_stylebox_override("pressed", s_on)
		b.add_theme_stylebox_override("on", s_on)
		b.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		b.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.5))
		b.pressed.connect(_pick_lane.bind(int(item[1])))
		lv.add_child(b)

	var hint_panel := PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.06, 0.09), Color(0.2, 0.25, 0.35), 6, 8))
	_lbl_hint = Label.new()
	_lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_hint.custom_minimum_size = Vector2(294.0, 75.0)
	_lbl_hint.add_theme_font_size_override("font_size", 11)
	_lbl_hint.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	hint_panel.add_child(_lbl_hint)
	lv.add_child(hint_panel)

	lv.add_child(_head("2. Стартовое золото"))

	for kit in KITS:
		var ids: Array = kit[1]
		var cost := 0
		for id in ids:
			cost += int((Global.ITEMS[id] as Dictionary)["cost"])
		lv.add_child(_button("%s  —  %d зол." % [kit[0], cost], 310.0, 34.0, _buy_kit.bind(ids)))

	lv.add_child(_button("Вернуть все покупки", 310.0, 34.0, _reset_purchases))

	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.06, 0.09), Color(0.25, 0.3, 0.4), 6, 6))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(294.0, 35.0)
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	status_panel.add_child(_status)
	lv.add_child(status_panel)

	# Правая панель
	var shop := ShopUI.new()
	shop.embedded = true
	shop.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.09, 0.13, 0.95), Color(0.7, 0.55, 0.2, 0.6)))
	body.add_child(shop)
	shop.setup(hero)

	_update_hint()


func _head(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	return l


func _pick_lane(lane: int) -> void:
	if lane not in [0, 1, 2, -1]:
		return
	_lane = lane
	_update_hint()


func _update_hint() -> void:
	var rec: int = int(PRIMARY_LANE.get(hero.primary, 1))
	_lbl_hint.text = "Выбрано: %s.\nРекомендация (%s): %s. Враги зеркалят линии, будьте готовы к ганкам после 6 уровня!" % [LANE_NAMES[_lane], hero.hero_title, LANE_NAMES[rec]]


func _buy_kit(ids: Array) -> void:
	var bought := 0
	for id in ids:
		if hero.buy_item(id):
			bought += 1
		else:
			break
	if bought == ids.size():
		_status.text = "Набор куплен полностью | Золото: %d" % hero.gold
	elif bought > 0:
		_status.text = "Куплено частично: %d/%d | Золото: %d" % [bought, ids.size(), hero.gold]
	else:
		_status.text = "Не хватает золота"


func _reset_purchases() -> void:
	for i in 6:
		hero.inventory[i] = ""
	hero.gold = _start_gold
	hero.recalc_stats()
	hero.last_purchase = {}
	_status.text = "Покупки отменены. Золото: %d" % hero.gold


func _process(delta: float) -> void:
	if _done or _lbl_time == null:
		return
	_left -= delta
	var t: int = int(ceilf(maxf(_left, 0.0)))
	if _left <= TIME_WARN:
		_lbl_time.text = "Старт через %d с" % t
		_lbl_time.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	else:
		_lbl_time.text = "⏱ Старт через %d с" % t
	if _left <= 0.0:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	finished.emit(_lane)
	queue_free()
