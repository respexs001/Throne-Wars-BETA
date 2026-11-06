class_name GameHUD
extends CanvasLayer
## HUD.gd — интерфейс: миникарта, портрет героя (3D) с уровнем, полоски HP/MP/опыта, характеристики, способности-иконки
## с подсказками при наведении (описание, значения по уровням, мана, перезарядка), предметы, счёт, день/ночь,
## объявления, пауза с настройками, выкуп, итоги матча.

const GOLD: Color = Color(0.82, 0.32, 0.26)
const PANEL: Color = Color(0.035, 0.055, 0.07, 0.96)
const EDGE: Color = Color(0.27, 0.36, 0.4)
const CAST_MODES: Array = ["клик по цели", "мгновенно", "удержать и отпустить"]

var hero: BaseHero
var bot: BaseHero
var main_node: Node
var pc: PlayerController
var rig: CameraRig
var shop: ShopUI
var touch: bool = false

var _lbl_score_l: Label
var _lbl_score_r: Label
var _lbl_time: Label
var _lbl_wave: Label
var _day_icon: DayNightIcon
var _lbl_name: Label
var _lbl_gold: Label
var _lbl_stats: Label
var _lbl_level: Label
var _bar_hp: ProgressBar
var _bar_mp: ProgressBar
var _bar_xp: ProgressBar
var _ab_btns: Array = []
var _slots: Array = []
var _lbl_msgs: Label
var _msgs: Array = []
var _lbl_target: Label
var _bar_target: ProgressBar
var _lbl_bot: Label
var _banner: Label
var _banner_tw: Tween
var _dead_panel: PanelContainer
var _lbl_dead: Label
var _btn_buyback: Button
var _pause_panel: Control
var _over_panel: Control
var _lbl_over: Label
var _hurt: ColorRect
var _tip: PanelContainer
var _tip_label: RichTextLabel
var _tip_target: Control = null
var _hp_shown: float = 1.0
var _mp_shown: float = 1.0
var _t: float = 0.0
var _pmodel: UnitModel
var _ppivot: Node3D
var _last_hp: float = 0.0
var _was_alive: bool = true
var _cast_btn: Button
var _ui_acc: float = 0.0
var _psv_acc: float = 0.0
var _psv: SubViewport
var _lbl_fps: Label
var _talent_ui: TalentUI
var _btn_talent: Button
var _neutral_panel: PanelContainer
var _neutral_btns: Array = []
var _score_root: Control
var _score_label: RichTextLabel
var _score_pinned: bool = false
var _score_acc: float = 0.0


func setup(h: BaseHero, b: BaseHero, m: Node, controller: PlayerController, camera_rig: CameraRig) -> void:
	hero = h
	bot = b
	main_node = m
	pc = controller
	rig = camera_rig
	touch = Global.is_touch()
	_last_hp = hero.hp
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.content_scale_factor = 1.15 if touch else 1.0
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt = ColorRect.new()
	_hurt.color = Color(0.8, 0.0, 0.0, 0.0)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hurt)
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_minimap(root)
	if touch:
		var j := TouchJoystick.new()
		j.anchor_left = 0.0
		j.anchor_right = 0.0
		j.anchor_top = 1.0
		j.anchor_bottom = 1.0
		j.offset_left = 8.0
		j.offset_right = 178.0
		j.offset_top = -178.0
		j.offset_bottom = -8.0
		root.add_child(j)
		pc.joy = j
	_build_bottom(root)
	_build_top(root)
	_build_right(root)
	_build_messages(root)
	_build_banner(root)
	_build_dead(root)
	_build_shop(root)
	_build_pause(root)
	_build_scoreboard(root)
	_build_over(root)
	_build_tip(root)
	Global.message.connect(_on_message)
	Global.announce.connect(_on_announce)
	Global.game_over.connect(_on_game_over)
	Global.request_pause.connect(_on_request_pause)


# ---------- стили ----------
func _sb(bg: Color, border: Color, radius: int = 6, bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(6.0)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	s.shadow_size = 3
	return s


func _panel(bg: Color = PANEL, border: Color = EDGE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(bg, border, 3, 1))
	return p


func _style_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _sb(Color(0.09, 0.1, 0.13), EDGE.darkened(0.3), 2, 1))
	b.add_theme_stylebox_override("hover", _sb(Color(0.15, 0.16, 0.21), GOLD, 2, 1))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.06, 0.07, 0.09), GOLD, 2, 1))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.07, 0.07, 0.08), Color(0.25, 0.25, 0.25), 2, 1))
	b.focus_mode = Control.FOCUS_NONE


func _small_button(text: String, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 32.0)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	_style_button(b)
	return b


func _make_bar(color: Color, width: float, height: float = 20.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, height)
	bar.add_theme_stylebox_override("background", _sb(Color(0.03, 0.03, 0.05), Color(0.0, 0.0, 0.0, 0.9), 4, 1))
	bar.add_theme_stylebox_override("fill", _sb(color, color.darkened(0.45), 4, 1))
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	bar.add_child(lbl)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bar


func _set_bar(bar: ProgressBar, value: float, max_v: float, text: String) -> void:
	bar.max_value = maxf(max_v, 1.0)
	bar.value = value
	(bar.get_child(0) as Label).text = text


# ---------- построение ----------
func _build_minimap(root: Control) -> void:
	var s: float = 150.0 if touch else 184.0
	var frame := _panel(Color(0.04, 0.05, 0.08, 0.96))
	frame.anchor_left = 0.0
	frame.anchor_right = 0.0
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = 6.0
	frame.offset_right = 6.0 + s + 12.0
	frame.offset_top = -(s + 20.0)
	frame.offset_bottom = -6.0
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if touch:
		frame.anchor_top = 0.0
		frame.anchor_bottom = 0.0
		frame.offset_top = 6.0
		frame.offset_bottom = 6.0 + s + 20.0
		frame.grow_vertical = Control.GROW_DIRECTION_END
	root.add_child(frame)
	var mm := Minimap.new()
	mm.hero = hero
	mm.rig = rig
	mm.custom_minimum_size = Vector2(s, s)
	mm.clicked.connect(func(p: Vector3) -> void: rig.look_at_world(p))
	frame.add_child(mm)


func _build_bottom(root: Control) -> void:
	var mm_s: float = 150.0 if touch else 184.0
	var pw: float = 96.0 if touch else 112.0
	var bar_w: float = 176.0 if touch else 214.0
	var ab_sz: float = 54.0 if touch else 60.0
	var it_w: float = 48.0 if touch else 54.0
	var bp := _panel()
	bp.anchor_left = 0.0
	bp.anchor_right = 1.0
	bp.anchor_top = 1.0
	bp.anchor_bottom = 1.0
	bp.offset_left = mm_s + 28.0
	bp.offset_right = -6.0
	bp.offset_top = -148.0
	bp.offset_bottom = -6.0
	bp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bp)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	bp.add_child(hb)

	# портрет героя с моделью и уровнем
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(pw, pw)
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(wrap)
	var mastery_color := ProfileService.mastery_color(hero.hero_id)
	var frame := _panel(Color(0.04, 0.055, 0.065), mastery_color)
	wrap.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	frame.add_child(svc)
	var sv := SubViewport.new()
	sv.size = Vector2i(int(pw * 1.4), int(pw * 1.4))
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	svc.add_child(sv)
	_psv = sv
	_build_portrait(sv)
	var mastery_badge := Label.new()
	mastery_badge.text = ["", "I", "II", "III"][ProfileService.mastery_level(hero.hero_id)]
	mastery_badge.tooltip_text = "Мастерство: " + ProfileService.mastery_title(hero.hero_id)
	mastery_badge.add_theme_color_override("font_color", mastery_color.lightened(0.3))
	mastery_badge.position = Vector2(pw - 24.0, 2.0)
	wrap.add_child(mastery_badge)
	_lbl_level = Label.new()
	_lbl_level.add_theme_font_size_override("font_size", 16)
	_lbl_level.add_theme_stylebox_override("normal", _sb(Color(0.1, 0.1, 0.16), GOLD, 14, 2))
	_lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_level.custom_minimum_size = Vector2(30.0, 28.0)
	_lbl_level.position = Vector2(-4.0, pw - 26.0)
	wrap.add_child(_lbl_level)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 3)
	stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(stats)
	_lbl_name = Label.new()
	_lbl_name.add_theme_font_size_override("font_size", 15)
	_lbl_name.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	stats.add_child(_lbl_name)
	_lbl_gold = Label.new()
	_lbl_gold.add_theme_font_size_override("font_size", 14)
	_lbl_gold.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	stats.add_child(_lbl_gold)
	_bar_hp = _make_bar(Color(0.2, 0.72, 0.28), bar_w)
	stats.add_child(_bar_hp)
	_bar_mp = _make_bar(Color(0.25, 0.45, 0.95), bar_w)
	stats.add_child(_bar_mp)
	_bar_xp = _make_bar(Color(0.7, 0.5, 0.9), bar_w, 14.0)
	stats.add_child(_bar_xp)
	_lbl_stats = Label.new()
	_lbl_stats.add_theme_font_size_override("font_size", 11)
	_lbl_stats.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	stats.add_child(_lbl_stats)

	var abox := HBoxContainer.new()
	abox.add_theme_constant_override("separation", 5)
	abox.size_flags_vertical = Control.SIZE_SHRINK_END
	hb.add_child(abox)
	for i in hero.abilities.size():
		var ab: Dictionary = hero.abilities[i]
		var btn := AbilityButton.new()
		btn.index = i
		btn.icon = ab.get("icon", "orb")
		btn.key_text = String(hero.ab_key[i])
		btn.icon_color = ab.get("color", Color(0.6, 0.6, 0.8))
		btn.max_level = hero.ab_max_level(i)
		btn.passive = ab["target"] == "passive"
		btn.is_ult = i == hero.ult_index()
		btn.custom_minimum_size = Vector2(ab_sz, ab_sz + 12.0)
		btn.begin.connect(pc.btn_begin)
		btn.moved.connect(pc.btn_move)
		btn.ended.connect(pc.btn_end)
		btn.begin.connect(func(idx: int) -> void:
			if touch:
				_on_ab_hover(idx, true))
		btn.ended.connect(func(_idx: int, _v: Vector2) -> void:
			if touch:
				_hide_tip())
		btn.hovered.connect(_on_ab_hover)
		btn.learn.connect(func(idx: int) -> void: hero.learn_ability(idx))
		abox.add_child(btn)
		_ab_btns.append(btn)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(grid)
	var keys: Array = ["Z", "X", "C", "V", "B", "N"]
	for i in 6:
		var sl := ItemSlot.new()
		sl.index = i
		sl.key_text = keys[i]
		sl.custom_minimum_size = Vector2(it_w, it_w * 0.82)
		sl.pressed.connect(_on_item)
		sl.hovered.connect(_on_item_hover)
		grid.add_child(sl)
		_slots.append(sl)

	var side := GridContainer.new()
	side.columns = 2
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.add_theme_constant_override("h_separation", 3)
	side.add_theme_constant_override("v_separation", 3)
	hb.add_child(side)
	side.add_child(_small_button("Магазин", 66.0, func() -> void: shop.toggle()))
	side.add_child(_small_button("Камера", 66.0, func() -> void: rig.center()))
	side.add_child(_small_button("Атака", 66.0, func() -> void: pc.start_amove()))
	side.add_child(_small_button("Стоп", 66.0, func() -> void: hero.order_stop()))
	side.add_child(_small_button("Держать", 66.0, func() -> void: hero.order_hold()))
	side.add_child(_small_button("Курьер", 66.0, _call_courier))
	_btn_talent = _small_button("Таланты", 66.0, func() -> void: _talent_ui.toggle())
	side.add_child(_btn_talent)
	var auto := CheckBox.new()
	auto.text = "Авто+"
	auto.focus_mode = Control.FOCUS_NONE
	auto.tooltip_text = "Авто-прокачка навыков"
	auto.add_theme_font_size_override("font_size", 11)
	auto.toggled.connect(func(on: bool) -> void:
		hero.auto_learn = on
		if on:
			hero.auto_learn_next())
	side.add_child(auto)


func _build_portrait(sv: SubViewport) -> void:
	var root3 := Node3D.new()
	sv.add_child(root3)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.95)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	root3.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30.0, 40.0, 0.0)
	sun.light_energy = 1.1
	root3.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 2.5, 6.3)
	cam.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	cam.fov = 34.0
	root3.add_child(cam)
	cam.current = true
	_ppivot = Node3D.new()
	root3.add_child(_ppivot)
	_pmodel = UnitModel.new()
	_ppivot.add_child(_pmodel)
	_pmodel.build(HeroDB.get_hero(hero.hero_id)["model"], hero.team_color())


func _build_top(root: Control) -> void:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pl := _panel(Color(0.08, 0.16, 0.34, 0.94), Color(0.3, 0.6, 1.0))
	_lbl_score_l = Label.new()
	_lbl_score_l.add_theme_font_size_override("font_size", 20)
	_lbl_score_l.custom_minimum_size = Vector2(110.0, 0.0)
	_lbl_score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.add_child(_lbl_score_l)
	wrap.add_child(pl)
	var pc2 := _panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	pc2.add_child(v)
	pc2.tooltip_text = "Таблица игроков (Tab)"
	pc2.gui_input.connect(_on_time_panel_input)
	_lbl_time = Label.new()
	_lbl_time.add_theme_font_size_override("font_size", 20)
	_lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_time.custom_minimum_size = Vector2(150.0, 0.0)
	v.add_child(_lbl_time)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_day_icon = DayNightIcon.new()
	row.add_child(_day_icon)
	_lbl_wave = Label.new()
	_lbl_wave.add_theme_font_size_override("font_size", 12)
	row.add_child(_lbl_wave)
	v.add_child(row)
	wrap.add_child(pc2)
	var pr := _panel(Color(0.34, 0.08, 0.08, 0.94), Color(1.0, 0.4, 0.35))
	_lbl_score_r = Label.new()
	_lbl_score_r.add_theme_font_size_override("font_size", 20)
	_lbl_score_r.custom_minimum_size = Vector2(110.0, 0.0)
	_lbl_score_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pr.add_child(_lbl_score_r)
	wrap.add_child(pr)
	root.add_child(wrap)
	wrap.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 6)
	wrap.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _build_right(root: Control) -> void:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(250.0, 0.0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(v)
	var pause := Button.new()
	pause.text = "Меню / Пауза (Esc)"
	pause.pressed.connect(_toggle_pause)
	_style_button(pause)
	v.add_child(pause)
	var tp := _panel()
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tv := VBoxContainer.new()
	tp.add_child(tv)
	_lbl_bot = Label.new()
	_lbl_bot.add_theme_font_size_override("font_size", 12)
	_lbl_bot.add_theme_color_override("font_color", Color(1.0, 0.7, 0.65))
	tv.add_child(_lbl_bot)
	_lbl_target = Label.new()
	_lbl_target.add_theme_font_size_override("font_size", 12)
	tv.add_child(_lbl_target)
	_bar_target = _make_bar(Color(0.85, 0.25, 0.25), 230.0)
	tv.add_child(_bar_target)
	v.add_child(tp)
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	v.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _build_messages(root: Control) -> void:
	_lbl_msgs = Label.new()
	_lbl_msgs.position = Vector2(12.0, 12.0)
	_lbl_msgs.custom_minimum_size = Vector2(370.0, 0.0)
	_lbl_msgs.size.x = 370.0
	_lbl_msgs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_msgs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_msgs.add_theme_font_size_override("font_size", 13)
	_lbl_msgs.add_theme_color_override("font_shadow_color", Color.BLACK)
	_lbl_msgs.add_theme_constant_override("shadow_offset_x", 1)
	_lbl_msgs.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(_lbl_msgs)
	_lbl_fps = Label.new()
	_lbl_fps.position = Vector2(12.0, 150.0)
	_lbl_fps.add_theme_font_size_override("font_size", 11)
	_lbl_fps.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_lbl_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_lbl_fps)


func _build_banner(root: Control) -> void:
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 9)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	root.add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 90)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _build_dead(root: Control) -> void:
	_dead_panel = _panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_dead_panel.add_child(v)
	_lbl_dead = Label.new()
	_lbl_dead.add_theme_font_size_override("font_size", 22)
	_lbl_dead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_lbl_dead)
	_btn_buyback = Button.new()
	_btn_buyback.custom_minimum_size = Vector2(0.0, 40.0)
	_btn_buyback.pressed.connect(func() -> void: hero.buyback())
	_style_button(_btn_buyback)
	v.add_child(_btn_buyback)
	root.add_child(_dead_panel)
	_dead_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_dead_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dead_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dead_panel.visible = false


func _build_shop(root: Control) -> void:
	shop = ShopUI.new()
	shop.add_theme_stylebox_override("panel", _sb(PANEL, GOLD, 10, 2))
	root.add_child(shop)
	shop.setup(hero)
	shop.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	shop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shop.grow_vertical = Control.GROW_DIRECTION_BOTH
	shop.visible = false
	_build_talents(root)
	_build_neutral(root)


func _overlay(root: Control) -> Control:
	var over := ColorRect.new()
	over.color = Color(0.0, 0.0, 0.0, 0.7)
	root.add_child(over)
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.visible = false
	return over


func _centered_box(over: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	over.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := _panel()
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	return v


func _big_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300.0, 46.0)
	b.pressed.connect(cb)
	_style_button(b)
	return b


func _build_pause(root: Control) -> void:
	_pause_panel = _overlay(root)
	var v := _centered_box(_pause_panel)
	var t := Label.new()
	t.text = "ПАУЗА"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	v.add_child(t)
	v.add_child(_big_button("Продолжить", _toggle_pause))
	_cast_btn = _big_button("", _cycle_cast)
	v.add_child(_cast_btn)
	_refresh_cast_btn()
	var edge := _big_button("", func() -> void: pass)
	edge.pressed.connect(func() -> void:
		Global.edge_scroll = not Global.edge_scroll
		edge.text = "Прокрутка по краям экрана: %s" % ("вкл" if Global.edge_scroll else "выкл"))
	edge.text = "Прокрутка по краям экрана: %s" % ("вкл" if Global.edge_scroll else "выкл")
	v.add_child(edge)
	if Global.test_mode:
		_add_test_buttons(v)
	v.add_child(_big_button("Сдаться", func() -> void:
		_pause_panel.visible = false
		Global.end_game(1 - hero.team)))
	v.add_child(_big_button("В главное меню", _on_menu))


func _add_test_buttons(v: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = "Тест-режим" if Global.test_mode else "Отладка"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl)
	_tool_button(v, "Бесконечная мана: вкл/выкл", func() -> void:
		Global.test_inf_mana = not Global.test_inf_mana)
	_tool_button(v, "Без перезарядок: вкл/выкл", func() -> void:
		Global.test_no_cd = not Global.test_no_cd)
	_tool_button(v, "+1 уровень", func() -> void:
		hero.add_xp(hero.xp_needed()))
	_tool_button(v, "+1000 золота", func() -> void:
		hero.gold += 1000)
	_tool_button(v, "Полное HP и MP", func() -> void:
		hero.hp = hero.max_hp
		hero.mp = hero.max_mp)
	_tool_button(v, "Сбросить перезарядки", func() -> void:
		for i in hero.ab_cd.size():
			hero.ab_cd[i] = 0.0)
	_tool_button(v, "+10 очков навыков", func() -> void:
		hero.skill_points += 10
		hero.auto_learn_next())


# Любое использование инструмента помечает матч как нерейтинговый.
func _tool_button(v: VBoxContainer, text: String, cb: Callable) -> void:
	v.add_child(_big_button(text, func() -> void:
		Global.tools_used = true
		cb.call()))


func _cycle_cast() -> void:
	Global.cast_mode = (Global.cast_mode + 1) % 3
	_refresh_cast_btn()


func _refresh_cast_btn() -> void:
	_cast_btn.text = "Режим каста: %s" % CAST_MODES[Global.cast_mode]


func _build_over(root: Control) -> void:
	_over_panel = _overlay(root)
	var v := _centered_box(_over_panel)
	_lbl_over = Label.new()
	_lbl_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_over.add_theme_font_size_override("font_size", 26)
	v.add_child(_lbl_over)
	v.add_child(_big_button("Играть снова", _on_restart))
	v.add_child(_big_button("В главное меню", _on_menu))


func _build_tip(root: Control) -> void:
	_tip = _panel(Color(0.04, 0.05, 0.09, 0.97), Color(0.95, 0.8, 0.35))
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_label = RichTextLabel.new()
	_tip_label.bbcode_enabled = true
	_tip_label.fit_content = true
	_tip_label.scroll_active = false
	_tip_label.custom_minimum_size = Vector2(340.0, 0.0)
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_label.add_theme_font_size_override("normal_font_size", 14)
	_tip.add_child(_tip_label)
	_tip.visible = false
	root.add_child(_tip)


# ---------- подсказки ----------
func _on_ab_hover(i: int, on: bool) -> void:
	if not on:
		_hide_tip()
		return
	var ab: Dictionary = hero.abilities[i]
	var txt := Abilities.describe(ab, maxi(hero.ab_level[i], 1), hero.ab_max_level(i), String(hero.ab_key[i]), i == hero.ult_index())
	if hero.can_learn(i):
		txt += "\n[color=#7dff7d]Можно улучшить: кнопка + или Ctrl+%s[/color]" % String(hero.ab_key[i])
	elif hero.ab_level[i] == 0:
		txt += "\n[color=#ff9d7d]Не изучена. Нужен уровень героя: %d[/color]" % hero.ab_required_level(i)
	_show_tip(txt, _ab_btns[i])


func _on_item_hover(i: int, on: bool) -> void:
	var id: String = hero.inventory[i]
	if not on or id == "":
		_hide_tip()
		return
	var item: Dictionary = Global.ITEMS[id]
	var lines: Array = []
	lines.append("[font_size=19][b][color=#ffe08a]%s[/color][/b][/font_size]" % item["name"])
	lines.append("[color=#ffd54a]Стоимость: %d[/color]   (продажа: %d)" % [item["cost"], int(item["cost"]) / 2])
	lines.append("[color=#ddd]%s[/color]" % item["desc"])
	if item.has("active"):
		var act: Dictionary = item["active"]
		lines.append("")
		lines.append("[color=#9fb4ff]Активный предмет[/color]  перезарядка: %d с" % int(act["cd"]))
		if act.has("mp"):
			lines.append("[color=#6fa8ff]Мана: %d[/color]" % int(act["mp"]))
	_show_tip("\n".join(lines), _slots[i])


func _show_tip(text: String, target: Control) -> void:
	_tip_label.text = text
	_tip.visible = true
	_tip.reset_size()
	_tip_target = target


func _hide_tip() -> void:
	_tip.visible = false
	_tip_target = null


func _place_tip() -> void:
	if not _tip.visible or not is_instance_valid(_tip_target):
		return
	var gr := _tip_target.get_global_rect()
	var sz := _tip.size
	var vp := get_viewport().get_visible_rect().size
	var x := clampf(gr.position.x + gr.size.x * 0.5 - sz.x * 0.5, 4.0, maxf(4.0, vp.x - sz.x - 4.0))
	var y := gr.position.y - sz.y - 12.0
	_tip.position = Vector2(x, maxf(4.0, y))


# ---------- обновление ----------
func _process(delta: float) -> void:
	if hero == null:
		return
	_t += delta
	_score_tick(delta)
	if Input.is_action_just_pressed("shop_toggle"):
		shop.toggle()
	if Input.is_action_just_pressed("talents"):
		_talent_ui.toggle()
	if Input.is_action_just_pressed("pause_menu") and not Global.is_over and not Global.in_prematch:
		if not pc.cancel_modes():
			_toggle_pause()

	_ui_acc += delta
	if _ui_acc < 0.05:
		_place_tip()
		return
	delta = _ui_acc
	_ui_acc = 0.0
	_psv_acc += delta
	if _psv_acc >= 0.12:
		_psv_acc = 0.0
		_psv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var k: Array = Global.stats["kills"]
	var secs := int(Global.elapsed)
	_lbl_score_l.text = "СВЕТ  %d" % k[0]
	_lbl_score_r.text = "%d  ТЬМА" % k[1]
	_lbl_time.text = "%02d:%02d" % [secs / 60, secs % 60]
	_lbl_fps.text = "FPS %d" % Engine.get_frames_per_second()
	var day_txt := "День" if Global.is_day else "Ночь"
	var lead := _networth(hero) - _networth(bot)
	day_txt += "   Золото: %s%d" % ["+" if lead >= 0 else "", lead]
	if Global.test_mode:
		_lbl_wave.text = " %s   Тест-режим" % day_txt
	else:
		_lbl_wave.text = " %s   Волна: %d с" % [day_txt, int(ceilf(float(main_node.get("next_wave_in"))))]
	_day_icon.set_day(Global.is_day)

	_hp_shown = lerpf(_hp_shown, hero.hp, clampf(delta * 10.0, 0.0, 1.0))
	_mp_shown = lerpf(_mp_shown, hero.mp, clampf(delta * 10.0, 0.0, 1.0))
	var nt := ""
	if hero.neutral_item != "":
		nt = "   [Нейтр.: %s]" % String((Global.NEUTRAL_ITEMS[hero.neutral_item] as Dictionary)["name"])
	_lbl_name.text = "%s   Очки навыков: %d%s" % [hero.hero_title, hero.skill_points, nt]
	_lbl_gold.text = "Золото: %d%s" % [hero.gold, _buff_text()]
	_lbl_level.text = str(hero.level)
	_set_bar(_bar_hp, _hp_shown, hero.max_hp, "%d / %d   +%.1f" % [int(hero.hp), int(hero.max_hp), hero.hp_regen])
	_set_bar(_bar_mp, _mp_shown, hero.max_mp, "%d / %d   +%.1f" % [int(hero.mp), int(hero.max_mp), hero.mp_regen])
	_set_bar(_bar_xp, float(hero.xp), float(hero.xp_needed()), "Опыт %d / %d" % [hero.xp, hero.xp_needed()])
	_lbl_stats.text = "СИЛ %d  ЛОВ %d  ИНТ %d  |  Урон %d  Броня %.1f  Скор. %.0f" % [
		int(hero.a_str), int(hero.a_agi), int(hero.a_int), int(hero.damage), hero.armor, hero.move_speed]

	for i in _ab_btns.size():
		var b: AbilityButton = _ab_btns[i]
		b.level = hero.ab_level[i]
		b.cd_left = hero.ab_cd[i]
		b.cd_total = maxf(hero.ab_cooldown_total(i), 0.1)
		b.mana_ok = hero.mp >= hero.ab_mana(i)
		b.set_learnable(hero.can_learn(i))
		b.queue_redraw()
	for i in 6:
		var sl: ItemSlot = _slots[i]
		var id: String = hero.inventory[i]
		sl.item_id = id
		sl.cd_left = hero.item_cd[i]
		if id != "":
			var item: Dictionary = Global.ITEMS[id]
			if item.has("active"):
				var act: Dictionary = item["active"]
				sl.cd_total = float(act["cd"])
		sl.queue_redraw()

	var tl := hero.any_talent_available()
	_btn_talent.text = "Таланты!" if tl else "Таланты"
	_btn_talent.modulate = Color(1.4, 1.2, 0.6) if (tl and int(_t * 3.0) % 2 == 0) else Color.WHITE
	var offer: Array = hero.neutral_offer
	_neutral_panel.visible = not offer.is_empty()
	if not offer.is_empty():
		for i in 2:
			var nit: Dictionary = Global.NEUTRAL_ITEMS[offer[i]]
			(_neutral_btns[i] as Button).text = "%s\n%s" % [nit["name"], nit["desc"]]
	var foes: Array = []
	for eh in Global.heroes_of(1 - hero.team):
		var fe := eh as BaseHero
		foes.append("%s ур.%d  %d/%d%s" % [fe.hero_title, fe.level, int(fe.hp), int(fe.max_hp), "" if fe.alive else " (мёртв)"])
	_lbl_bot.text = "Враги:\n" + "\n".join(foes)
	var sel: Unit = Global.selected_unit
	if is_instance_valid(sel) and sel.alive:
		var extra := ""
		if sel is Building and (sel as Building).invulnerable:
			extra = "  (неуязвима)"
		_lbl_target.text = "Цель: %s%s" % [sel.unit_name, extra]
		_set_bar(_bar_target, sel.hp, sel.max_hp, "%d / %d" % [int(sel.hp), int(sel.max_hp)])
		_lbl_target.visible = true
		_bar_target.visible = true
	else:
		_lbl_target.visible = false
		_bar_target.visible = false

	_dead_panel.visible = not hero.alive and not Global.is_over
	if not hero.alive:
		_lbl_dead.text = "Вы погибли! Возрождение через %d с" % int(ceilf(hero.respawn_left))
		_btn_buyback.text = "Выкуп (%d золота)" % hero.buyback_cost()
		_btn_buyback.disabled = not hero.can_buyback()

	var low := hero.alive and hero.hp < hero.max_hp * 0.25
	_hurt.color.a = (0.08 + 0.08 * sin(_t * 6.0)) if low else 0.0
	_portrait_tick(delta)
	_place_tip()

	for m in _msgs:
		m[1] -= delta
	while _msgs.size() > 0 and _msgs[0][1] <= 0.0:
		_msgs.pop_front()
	var lines: Array = []
	for m in _msgs:
		lines.append(m[0])
	_lbl_msgs.text = "\n".join(lines)


func _portrait_tick(delta: float) -> void:
	_ppivot.rotation.y = sin(_t * 0.6) * 0.5
	if hero.hp < _last_hp - 1.0 and hero.alive:
		_pmodel.flash()
	_last_hp = hero.hp
	if hero.alive and not _was_alive:
		_pmodel.revive()
	if not hero.alive and _was_alive:
		_pmodel.play_death()
	_was_alive = hero.alive
	_pmodel.set_stunned(hero.has_status("stun"))
	if hero.attack_cd > hero.eff_attack_interval() - delta * 1.5 and hero.alive:
		_pmodel.play_attack(hero.is_ranged)


# ---------- события ----------
func _toggle_pause() -> void:
	if Global.is_over:
		return
	_pause_panel.visible = not _pause_panel.visible
	get_tree().paused = _pause_panel.visible
	if _pause_panel.visible:
		_refresh_cast_btn()


func _on_message(text: String) -> void:
	_msgs.append([text, 7.0])
	if _msgs.size() > 6:
		_msgs.pop_front()


func _on_announce(text: String, color: Color) -> void:
	Global.sfx("announce", -8.0)
	if _banner_tw != null:
		_banner_tw.kill()
	_banner.text = text
	_banner.modulate = color
	_banner.visible = true
	_banner.reset_size()
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.5, 0.5)
	_banner_tw = create_tween()
	_banner_tw.tween_property(_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.tween_interval(1.8)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tw.tween_callback(func() -> void: _banner.visible = false)


func _on_item(i: int) -> void:
	if touch:
		pc.press_item_button(i)
	else:
		pc.press_item(i, false)


func _on_game_over(winner: int) -> void:
	var won := winner == hero.team
	var k: Array = Global.stats["kills"]
	var c: Array = Global.stats["creeps"]
	var tw: Array = Global.stats["towers"]
	var secs := int(Global.elapsed)
	var head := "Победа" if won else "Поражение"
	_lbl_over.text = "%s\n\nВремя матча: %02d:%02d\nТвой герой: %s, ур.%d\nУбийств / смертей: %d / %d\nДобито крипов: %d, отказов: %d\nНанесено урона: %d\nУбийства героев (команды): %d / %d\nКрипы: %d / %d   Башни: %d / %d" % [
		head, secs / 60, secs % 60, hero.hero_title, hero.level, hero.kills, hero.deaths, hero.last_hits, hero.denies, int(hero.damage_dealt),
		k[hero.team], k[1 - hero.team], c[hero.team], c[1 - hero.team], tw[hero.team], tw[1 - hero.team]]
	_lbl_over.text += "\nУрон строениям: %d · Участие в башнях: %d · Стражи: %d\nМастерство: %s · %d опыта" % [int(hero.building_damage), hero.towers_assisted, hero.objectives, ProfileService.mastery_title(hero.hero_id), ProfileService.mastery_xp(hero.hero_id)]
	_over_panel.visible = true
	_pause_panel.visible = false
	_over_panel.modulate.a = 0.0
	create_tween().tween_property(_over_panel, "modulate:a", 1.0, 0.5)


func _on_restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	var ls = load("res://scripts/LoadingScreen.gd")
	if ls != null and ls.has_method("go_to"):
		ls.go_to(get_tree(), "res://scenes/MainMenu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _call_courier() -> void:
	var c := hero.courier
	if c == null or not c.alive:
		Global.say("Курьер недоступен")
	elif c.deliver_to(hero):
		Global.say("Курьер летит к вам")
	else:
		Global.say("Сумка курьера пуста. Купите предметы в магазине (F4)")


# ---------- таблица игроков (удерживать Tab или нажать на панель времени) ----------
func _build_scoreboard(root: Control) -> void:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.visible = false
	_score_root = center
	var p := _panel(Color(0.03, 0.04, 0.06, 0.97), EDGE)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(p)
	_score_label = RichTextLabel.new()
	_score_label.bbcode_enabled = true
	_score_label.fit_content = true
	_score_label.scroll_active = false
	_score_label.custom_minimum_size = Vector2(640.0, 0.0)
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_score_label)


func _on_time_panel_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_score_pinned = not _score_pinned


func _score_tick(delta: float) -> void:
	if _score_root == null:
		return
	var want := (Input.is_key_pressed(KEY_TAB) or _score_pinned) and not Global.is_over
	if _score_root.visible != want:
		_score_root.visible = want
		_score_acc = 1.0
	if not want:
		return
	_score_acc += delta
	if _score_acc < 0.4:
		return
	_score_acc = 0.0
	var secs := int(Global.elapsed)
	var t := "[b]Таблица игроков[/b]   %02d:%02d\n\n" % [secs / 60, secs % 60]
	t += "[table=7]"
	for head in ["Герой", "Ур.", "У / С", "Крипы / отказы", "Урон", "Ценность", ""]:
		t += "[cell][color=#9a9a9a]%s[/color]   [/cell]" % head
	for team in [hero.team, 1 - hero.team]:
		for h in Global.heroes_of(team):
			var b := h as BaseHero
			var col := "#7fb4ff" if team == hero.team else "#ff8a80"
			var name_txt := b.hero_title + (" (ты)" if b == hero else "")
			var state := "" if b.alive else "мёртв"
			var cells := [name_txt, str(b.level), "%d / %d" % [b.kills, b.deaths], "%d / %d" % [b.last_hits, b.denies],
				str(int(b.damage_dealt)), str(_networth(b)), state]
			for c in cells:
				t += "[cell][color=%s]%s[/color]   [/cell]" % [col, c]
	t += "[/table]"
	_score_label.text = t


func _networth(h: BaseHero) -> int:
	var n: int = h.gold
	for id in h.inventory:
		if id != "":
			var item: Dictionary = Global.ITEMS[id]
			n += int(item["cost"])
	return n


func _buff_text() -> String:
	var names: Dictionary = {"haste": "скорость", "rage": "урон", "regen_pct": "реген", "arcane": "аркан", "shield": "щит", "immune": "иммунитет"}
	var out: Array = []
	for k in names:
		if hero.has_status(k):
			out.append(names[k])
	var ill := 0
	var left := 0.0
	for n in hero.get_tree().get_nodes_in_group("illusions"):
		var b := n as BaseHero
		if b != null and b.alive and b.illusion_owner == hero:
			ill += 1
			left = maxf(left, b.illusion_left)
	if ill > 0:
		out.append("иллюзии: %d (%d с)" % [ill, int(ceil(left))])
	return "" if out.is_empty() else "   [" + ", ".join(out) + "]"


func _build_talents(root: Control) -> void:
	_talent_ui = TalentUI.new()
	_talent_ui.add_theme_stylebox_override("panel", _sb(PANEL, GOLD, 10, 2))
	root.add_child(_talent_ui)
	_talent_ui.setup(hero)
	_talent_ui.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_talent_ui.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_talent_ui.grow_vertical = Control.GROW_DIRECTION_BOTH
	_talent_ui.visible = false


func _build_neutral(root: Control) -> void:
	_neutral_panel = _panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_neutral_panel.add_child(v)
	var l := Label.new()
	l.text = "Нейтральный предмет! Выберите:"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.8, 1.0, 0.6))
	v.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for i in 2:
		var b := Button.new()
		b.custom_minimum_size = Vector2(230.0, 70.0)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick_neutral.bind(i))
		_style_button(b)
		row.add_child(b)
		_neutral_btns.append(b)
	root.add_child(_neutral_panel)
	_neutral_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 150)
	_neutral_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_neutral_panel.visible = false


func _pick_neutral(i: int) -> void:
	if i < hero.neutral_offer.size():
		hero.pick_neutral(String(hero.neutral_offer[i]))


func _on_request_pause() -> void:
	if not _pause_panel.visible and not Global.is_over and not Global.in_prematch:
		_toggle_pause()
