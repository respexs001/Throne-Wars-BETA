extends Control
## MainMenu.gd — главное меню. Туман (шейдер) + загрузка через load().

const GOLD: Color = Color(0.78, 0.27, 0.22)
const MUTED: Color = Color(0.62, 0.69, 0.72)
const DIFF_NAMES: Array = ["Легко", "Нормально", "Сложно"]
const MODE_NAMES: Array = ["Авто", "Телефон", "ПК"]
const CAST_NAMES: Array = ["клик по цели", "мгновенно", "удержать и отпустить"]
const ATTR_NAMES: Dictionary = {"str": "Сила", "agi": "Ловкость", "int": "Интеллект"}
const ATTR_COL: Dictionary = {"str": Color(0.95, 0.4, 0.35), "agi": Color(0.4, 0.85, 0.45), "int": Color(0.4, 0.65, 1.0)}

const QUALITY_PRESETS: Array = [
	{"name": "Низкое",  "res_scale": 0.55, "shadows": false, "weather": false, "fps": 30},
	{"name": "Среднее", "res_scale": 0.70, "shadows": false, "weather": true,  "fps": 60},
	{"name": "Высокое", "res_scale": 0.85, "shadows": true,  "weather": true,  "fps": 60},
	{"name": "Ультра",  "res_scale": 1.00, "shadows": true,  "weather": true,  "fps": 120},
]

const SAVE_DEBOUNCE_SEC: float = 0.4
const SFX_PATH: String = "res://assets/ui_click.ogg"
const FOG_SHADER_PATH: String = "res://Shaders/fog_menu.gdshader"
const LOADING_SCENE_PATH: String = "res://scripts/LoadingScreen.gd"
const AUTH_GATE_SCENE_PATH: String = "res://scenes/AuthGate.tscn"

var _panels: Dictionary = {}
var _tabs: Dictionary = {}
var _hero_btns: Dictionary = {}
var _world_view: SubViewportContainer
var _pivot: Node3D
var _model: UnitModel
var _demo_step: int = 0
var _t: float = 0.0
var _title: Label
var _play_btn: Button
var _play_name: Label
var _play_role: Label
var _play_stats: Label
var _info_name: Label
var _icons: HBoxContainer
var _info: RichTextLabel
var _setting_btns: Dictionary = {}
var _diff_chips: Array = []
var _save_timer: Timer
var _save_pending: bool = false
var _sfx: AudioStreamPlayer
var _particles: CPUParticles2D
var _fog_rect: ColorRect


func _ready() -> void:
	get_tree().paused = false
	if not ProfileService.has_session():
		call_deferred("_return_to_auth")
		return
	if not ProfileService.session_changed.is_connected(_on_session_changed):
		ProfileService.session_changed.connect(_on_session_changed)
	get_tree().root.content_scale_factor = 1.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_base_background()
	_build_world()
	_build_fog_background()
	_build_vignette()
	_build_ui()
	_add_version_label()
	_setup_sfx()
	_setup_save_timer()
	_pick(Global.selected_hero)
	_show("play")
	get_viewport().size_changed.connect(_reposition_particles)

	var timer := Timer.new()
	timer.wait_time = 1.9
	timer.autostart = true
	timer.timeout.connect(_demo_tick)
	add_child(timer)

	var tw := create_tween().set_loops()
	tw.tween_property(_play_btn, "modulate", Color(1.06, 1.02, 1.02), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_play_btn, "modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween().set_loops()
	tw2.tween_property(_title, "modulate", Color(1.05, 1.05, 1.05), 1.6).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(_title, "modulate", Color.WHITE, 1.6).set_trans(Tween.TRANS_SINE)


# ---------- сервис ----------
func _setup_sfx() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "Master"
	if ResourceLoader.exists(SFX_PATH):
		_sfx.stream = load(SFX_PATH)
	add_child(_sfx)


func _play_click() -> void:
	if _sfx != null and _sfx.stream != null:
		_sfx.play()


func _setup_save_timer() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SEC
	_save_timer.timeout.connect(_flush_save)
	add_child(_save_timer)


func _schedule_save() -> void:
	_save_pending = true
	_save_timer.start(SAVE_DEBOUNCE_SEC)


# Сохраняет ожидающие настройки немедленно. Вызывается по таймеру и из _exit_tree():
# иначе нажатие «Играть»/«Выход» раньше SAVE_DEBOUNCE_SEC теряло изменения.
func _flush_save() -> void:
	if not _save_pending:
		return
	_save_pending = false
	Global.save_settings()


func _exit_tree() -> void:
	_flush_save()


# ---------- 3D фон ----------
func _build_world() -> void:
	var svc := SubViewportContainer.new()
	_world_view = svc
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.anchor_right = 0.49
	var sv := SubViewport.new()
	svc.add_child(sv)
	var root3 := Node3D.new()
	sv.add_child(root3)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.035, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.75)
	env.ambient_light_energy = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	root3.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30.0, -35.0, 0.0)
	key.light_color = Color(1.0, 0.92, 0.8)
	key.light_energy = 1.7
	root3.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-5.0, 4.0, -3.0)
	rim.light_color = Color(0.35, 0.58, 0.7)
	rim.light_energy = 2.5
	rim.omni_range = 18.0
	root3.add_child(rim)
	var warm := OmniLight3D.new()
	warm.position = Vector3(5.0, 2.5, 5.0)
	warm.light_color = GOLD
	warm.light_energy = 0.9
	warm.omni_range = 16.0
	root3.add_child(warm)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 4.7, 12.5)
	cam.look_at_from_position(Vector3(0.0, 4.7, 12.5), Vector3(0.0, 1.8, 0.0))
	cam.fov = 42.0
	root3.add_child(cam)
	cam.current = true
	var floor_m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.8
	cm.bottom_radius = 3.0
	cm.height = 0.25
	cm.radial_segments = 40
	floor_m.mesh = cm
	floor_m.material_override = Global.make_mat(Color(0.095, 0.12, 0.14))
	floor_m.position.y = -0.15
	root3.add_child(floor_m)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.55
	tm.outer_radius = 2.7
	tm.rings = 48
	ring.mesh = tm
	ring.material_override = Global.make_mat(GOLD, 0.5)
	ring.position.y = 0.0
	root3.add_child(ring)
	_pivot = Node3D.new()
	root3.add_child(_pivot)


# ---------- туман поверх 3D ----------
func _build_fog_background() -> void:
	if not ResourceLoader.exists(FOG_SHADER_PATH):
		return
	_fog_rect = ColorRect.new()
	_fog_rect.color = Color(0, 0, 0, 0)
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(FOG_SHADER_PATH)
	_fog_rect.material = mat
	_fog_rect.modulate.a = 0.32
	add_child(_fog_rect)
	_fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(_fog_rect, 1)


func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.0, 0.0, 0.03, 0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.25, 0.45)
	gt.fill_to = Vector2(1.0, 0.5)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_particles = CPUParticles2D.new()
	_particles.amount = 40
	_particles.lifetime = 8.0
	_particles.preprocess = 8.0
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.direction = Vector2(0.0, -1.0)
	_particles.spread = 14.0
	_particles.gravity = Vector2.ZERO
	_particles.initial_velocity_min = 30.0
	_particles.initial_velocity_max = 80.0
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 4.0
	_particles.color = Color(1.0, 0.85, 0.5, 0.25)
	add_child(_particles)
	_reposition_particles()


func _reposition_particles() -> void:
	if _particles == null:
		return
	var sz: Vector2 = get_viewport_rect().size
	_particles.position = Vector2(sz.x * 0.5, sz.y + 30.0)
	_particles.emission_rect_extents = Vector2(sz.x * 0.55, 10.0)


# ---------- оформление ----------
func _sb(bg: Color, border: Color, radius: int = 8, bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10.0)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	s.shadow_size = 3
	return s


func _panel_style() -> StyleBoxFlat:
	return _sb(Color(0.055, 0.075, 0.09, 0.97), GOLD.darkened(0.45), 4, 1)


func _wire_button(b: Button, cb: Callable) -> void:
	b.pressed.connect(func() -> void:
		_play_click()
		cb.call()
	)


func _button(text: String, w: float, h: float, cb: Callable, border: Color = GOLD) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", _sb(Color(0.085, 0.11, 0.13, 0.98), border.darkened(0.5), 3, 1))
	b.add_theme_stylebox_override("hover", _sb(Color(0.14, 0.19, 0.21), border, 3, 1))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.15, 0.08, 0.08), border, 3, 1))
	b.add_theme_stylebox_override("hover_pressed", _sb(Color(0.2, 0.1, 0.09), border, 3, 1))
	_wire_button(b, cb)
	return b


func _gold_button(text: String, w: float, h: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
	b.add_theme_color_override("font_hover_color", Color(0.96, 0.95, 0.92))
	b.add_theme_color_override("font_pressed_color", Color(0.96, 0.95, 0.92))
	b.add_theme_stylebox_override("normal", _sb(Color(0.56, 0.16, 0.13), Color(0.8, 0.32, 0.26), 3, 1))
	b.add_theme_stylebox_override("hover", _sb(Color(0.7, 0.22, 0.17), Color(0.92, 0.45, 0.34), 3, 1))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.43, 0.11, 0.09), Color(0.8, 0.32, 0.26), 3, 1))
	_wire_button(b, cb)
	return b


func _tab_button(text: String, key: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(94.0, 46.0)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(0.75, 0.78, 0.9))
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_hover_pressed_color", GOLD)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	flat.set_content_margin_all(8.0)
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(1.0, 1.0, 1.0, 0.07)
	hov.set_content_margin_all(8.0)
	var act := StyleBoxFlat.new()
	act.bg_color = Color(0.75, 0.23, 0.18, 0.13)
	act.border_color = GOLD
	act.border_width_bottom = 3
	act.set_content_margin_all(8.0)
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", act)
	b.add_theme_stylebox_override("hover_pressed", act)
	_wire_button(b, _show.bind(key))
	_tabs[key] = b
	return b


func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l


# ---------- каркас ----------
func _build_ui() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var bar := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.035, 0.05, 0.06, 0.97)
	bs.border_color = GOLD.darkened(0.3)
	bs.border_width_bottom = 2
	bs.set_content_margin_all(6.0)
	bar.add_theme_stylebox_override("panel", bs)
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	bar.add_child(hb)
	_title = _label("THRONE WARS", 24, GOLD)
	hb.add_child(_title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var group := ButtonGroup.new()
	hb.add_child(_tab_button("Играть", "play", group))
	hb.add_child(_tab_button("Герои", "heroes", group))
	hb.add_child(_tab_button("Профиль", "profile", group))
	hb.add_child(_tab_button("Настройки", "settings", group))
	hb.add_child(_tab_button("Обновления", "changelog", group))
	hb.add_child(_button("Выход", 90.0, 40.0, _confirm_quit, Color(0.9, 0.4, 0.35)))

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	_panels["play"] = _build_play()
	_panels["heroes"] = _build_heroes()
	_panels["profile"] = ProfilePanel.new()
	_panels["settings"] = _build_settings()
	_panels["changelog"] = _build_changelog()
	for k in _panels:
		var p: Control = _panels[k]
		content.add_child(p)
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _show(key: String) -> void:
	if not _panels.has(key):
		return
	for panel_key in _panels:
		(_panels[panel_key] as Control).visible = panel_key == key
	for tab_key in _tabs:
		(_tabs[tab_key] as Button).button_pressed = tab_key == key
	_world_view.visible = key in ["play", "heroes", "profile"]
	_pivot.position = Vector3.ZERO


func _build_play() -> Control:
	var page := Control.new()
	var card := PanelContainer.new()
	page.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.anchor_left = 0.51
	card.anchor_right = 0.98
	card.anchor_top = 0.09
	card.anchor_bottom = 0.94
	card.add_theme_stylebox_override("panel", _panel_style())
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	column.add_child(_label("ВЫБРАННЫЙ ГЕРОЙ", 12, MUTED))
	_play_name = _label("", 42, Color(0.94, 0.94, 0.91))
	column.add_child(_play_name)
	_play_role = _label("", 16, MUTED)
	_play_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_play_role)
	_play_stats = _label("", 14, MUTED)
	_play_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_play_stats)
	column.add_child(_button("ВЫБРАТЬ ГЕРОЯ  →", 260, 40, _show.bind("heroes")))
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(space)
	column.add_child(_label("СЛОЖНОСТЬ СОПЕРНИКА", 12, MUTED))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	column.add_child(chips)
	var group := ButtonGroup.new()
	for i in 3:
		var button := _button(DIFF_NAMES[i], 90, 42, _set_diff.bind(i))
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chips.add_child(button)
		_diff_chips.append(button)
	_play_btn = _gold_button("НАЧАТЬ СРАЖЕНИЕ", 300, 60, _on_play)
	column.add_child(_play_btn)
	var caption := _label("Локальный матч с ботами · настройки во вкладке «Настройки»", 12, MUTED)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caption)
	return page


func _return_to_auth() -> void:
	get_tree().change_scene_to_file(AUTH_GATE_SCENE_PATH)


func _on_session_changed(new_profile: Dictionary) -> void:
	if new_profile.is_empty():
		call_deferred("_return_to_auth")


# ---------- ГЕРОИ ----------
func _build_heroes() -> Control:
	var page := Control.new()
	var row := HBoxContainer.new()
	page.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.anchor_left = 0.46
	row.add_theme_constant_override("separation", 14)
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", _panel_style())
	lp.custom_minimum_size = Vector2(238.0, 0.0)
	row.add_child(lp)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lp.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)
	var group := ButtonGroup.new()
	for attr in ["str", "agi", "int"]:
		v.add_child(_label("— %s —" % ATTR_NAMES[attr], 15, ATTR_COL[attr]))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 5)
		grid.add_theme_constant_override("v_separation", 5)
		v.add_child(grid)
		for h in HeroDB.all():
			if h["primary"] != attr:
				continue
			var b := Button.new()
			b.text = str(h["name"])
			b.disabled = not Global.experimental and h["id"] not in MatchBalance.PRIMARY_HEROES
			b.tooltip_text = str(h["name"]) + (" · Экспериментальный: включите в настройках" if h["id"] not in MatchBalance.PRIMARY_HEROES else " · Основной герой альфы")
			b.toggle_mode = true
			b.button_group = group
			b.custom_minimum_size = Vector2(104.0, 50.0)
			b.clip_text = true
			b.add_theme_font_size_override("font_size", 11)
			var col: Color = ATTR_COL[attr]
			b.add_theme_stylebox_override("normal", _sb(Color(0.07, 0.09, 0.11, 0.98), col.darkened(0.55), 6, 1))
			b.add_theme_stylebox_override("hover", _sb(Color(0.13, 0.18, 0.2), col, 6, 2))
			b.add_theme_stylebox_override("pressed", _sb(col.darkened(0.6), col, 6, 3))
			b.add_theme_stylebox_override("hover_pressed", _sb(col.darkened(0.5), col, 6, 3))
			_wire_button(b, _pick.bind(h["id"]))
			grid.add_child(b)
			_hero_btns[h["id"]] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.queue_free()
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", _panel_style())
	rp.custom_minimum_size = Vector2(300.0, 0.0)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rp)
	var rscroll := ScrollContainer.new()
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rp.add_child(rscroll)
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_theme_constant_override("separation", 8)
	rscroll.add_child(rv)
	_info_name = _label("", 20, Color(0.93, 0.94, 0.92))
	_info_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(_info_name)
	_icons = HBoxContainer.new()
	_icons.add_theme_constant_override("separation", 5)
	rv.add_child(_icons)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.add_theme_font_size_override("normal_font_size", 14)
	rv.add_child(_info)
	return page


func _pick(id: String) -> void:
	Global.selected_hero = id
	var h := HeroDB.get_hero(id)
	if _model != null:
		_model.queue_free()
	_model = UnitModel.new()
	_pivot.add_child(_model)
	var model_col: Color = ATTR_COL.get(h.get("primary", ""), Color(0.3, 0.6, 1.0))
	var menu_model: Dictionary = h["model"].duplicate()
	menu_model["scale"] = float(menu_model.get("scale", 1.0)) * 1.45
	_model.build(menu_model, model_col)
	_demo_step = 0
	if _hero_btns.has(id):
		(_hero_btns[id] as Button).button_pressed = true
	var lore := HeroLore.get_info(id)
	var abs_arr: Array = h["abilities"] if h["abilities"] is Array else []
	var keys: Array = ["Q", "W", "E", "D", "F"]
	_info_name.text = "%s  —  %s" % [h["name"], h["role"]]
	for c in _icons.get_children():
		c.queue_free()
	for i in abs_arr.size():
		var ab: Dictionary = abs_arr[i]
		var box := IconBox.new()
		box.icon = ab.get("icon", "orb")
		box.color = ab.get("color", Color(0.6, 0.6, 0.8))
		box.is_ult = i == abs_arr.size() - 1
		box.key_text = "R" if box.is_ult else String(keys[i])
		box.tooltip_text = "%s\n%s" % [ab["name"], ab.get("desc", "")]
		_icons.add_child(box)
	var lines: Array = []
	lines.append("[color=#9fb4ff]Основной атрибут: %s[/color]   %s, дальность %.1f" % [ATTR_NAMES[h["primary"]], "ближний бой" if h["melee"] else "дальний бой", float(h["range"])])
	lines.append("Сила %d (+%.1f)   Ловкость %d (+%.1f)   Интеллект %d (+%.1f)" % [
		int(h["str"]), float(h["str_gain"]), int(h["agi"]), float(h["agi_gain"]), int(h["int"]), float(h["int_gain"])])
	lines.append("")
	lines.append("[color=#ddd]%s[/color]" % lore["story"])
	lines.append("")
	lines.append("[b][color=#ffd978]Способности[/color][/b]")
	for i in abs_arr.size():
		var ab2: Dictionary = abs_arr[i]
		var key := "R" if i == abs_arr.size() - 1 else String(keys[i])
		lines.append("[b]%s — %s[/b]: %s" % [key, ab2["name"], ab2.get("desc", "")])
	lines.append("")
	lines.append("[b][color=#ffd978]Совет[/color][/b]\n%s" % lore["tips"])
	_info.text = "\n".join(lines)
	_refresh()


func _demo_tick() -> void:
	if _model == null:
		return
	_demo_step += 1
	var h := HeroDB.get_hero(Global.selected_hero)
	var ranged: bool = not h["melee"]
	match _demo_step % 4:
		0, 1:
			_model.set_moving(false)
			_model.play_attack(ranged)
		2:
			_model.set_moving(false)
			_model.play_cast()
		3:
			_model.set_moving(true)


func _process(delta: float) -> void:
	_t += delta
	if _pivot != null:
		_pivot.rotation.y = sin(_t * 0.5) * 0.55


# ---------- НАСТРОЙКИ ----------
func _row(parent: Control, caption: String, key: String, cb: Callable) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var l := _label(caption, 16)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var b := _button("", 220.0, 42.0, cb)
	hb.add_child(b)
	parent.add_child(hb)
	_setting_btns[key] = b


func _build_settings() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var wrap := VBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(wrap)
	var hwrap := HBoxContainer.new()
	hwrap.alignment = BoxContainer.ALIGNMENT_CENTER
	hwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(hwrap)
	var pn := PanelContainer.new()
	pn.add_theme_stylebox_override("panel", _panel_style())
	hwrap.add_child(pn)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 34)
	pn.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(500.0, 0.0)
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	left.add_child(_label("Игра", 22, GOLD))
	_row(left, "Сложность бота", "diff", _cycle_diff)
	_row(left, "Режим матча", "teams", _cycle_teams)
	_row(left, "Экспериментальные режимы и герои", "experimental", _toggle_experimental)
	_row(left, "Подготовка к матчу", "prematch", _toggle_prematch)
	_row(left, "Туман войны", "fog", _toggle_fog)
	_row(left, "Каст способностей", "cast", _cycle_cast)
	_row(left, "Управление", "mode", _cycle_mode)
	_row(left, "Прокрутка камеры у края", "edge", _toggle_edge)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(500.0, 0.0)
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	right.add_child(_label("Графика и ландшафт", 22, GOLD))
	_row(right, "Ландшафт", "biome", _cycle_biome)
	_row(right, "Пресет качества", "quality", _cycle_quality)
	_row(right, "Разрешение 3D", "res", _cycle_res)
	_row(right, "Лимит FPS", "fps", _cycle_fps)
	_row(right, "Погода", "weather", _toggle_weather)
	_row(right, "Тени", "shadow", _toggle_shadow)
	_row(right, "Громкость", "volume", _cycle_volume)
	right.add_child(_button("Сбросить все настройки", 440.0, 42.0, _reset_settings, Color(0.9, 0.4, 0.35)))
	return scroll


# ---------- обновление и действия ----------
func _refresh() -> void:
	_schedule_save()
	var h := HeroDB.get_hero(Global.selected_hero)
	_play_name.text = str(h["name"])
	_play_name.add_theme_color_override("font_color", ProfileService.mastery_color(Global.selected_hero).lightened(0.4))
	_play_role.text = "%s   |   %s   |   Матч %d на %d" % [h["role"], "ближний бой" if h["melee"] else "дальний бой", Global.team_size, Global.team_size]
	var abil_count: int = (h["abilities"] as Array).size() if h["abilities"] is Array else 0
	_play_stats.text = "Сила %d   Ловкость %d   Интеллект %d   |   Способностей: %d" % [int(h["str"]), int(h["agi"]), int(h["int"]), abil_count]
	_play_stats.text += "\nМастерство: %s · %d опыта%s" % [ProfileService.mastery_title(Global.selected_hero), ProfileService.mastery_xp(Global.selected_hero), " · гостевой сеанс" if ProfileService.is_guest else ""]
	for i in _diff_chips.size():
		(_diff_chips[i] as Button).button_pressed = (i == Global.difficulty)
	(_setting_btns["diff"] as Button).text = DIFF_NAMES[Global.difficulty]
	(_setting_btns["experimental"] as Button).text = "вкл · экспериментальное" if Global.experimental else "выкл · основная альфа"
	(_setting_btns["teams"] as Button).text = "%d на %d" % [Global.team_size, Global.team_size]
	(_setting_btns["fog"] as Button).text = "вкл" if Global.fog_on else "выкл"
	(_setting_btns["prematch"] as Button).text = "вкл" if Global.prematch_on else "выкл"
	(_setting_btns["cast"] as Button).text = CAST_NAMES[Global.cast_mode]
	(_setting_btns["mode"] as Button).text = MODE_NAMES[Global.control_mode]
	(_setting_btns["edge"] as Button).text = "вкл" if Global.edge_scroll else "выкл"
	(_setting_btns["shadow"] as Button).text = "вкл" if Global.shadows_on else "выкл"
	(_setting_btns["quality"] as Button).text = String(QUALITY_PRESETS[Global.quality]["name"])
	(_setting_btns["biome"] as Button).text = String(Biome.cfg(Global.biome)["name"])
	(_setting_btns["res"] as Button).text = "%d%%" % int(Global.res_scale * 100.0)
	(_setting_btns["fps"] as Button).text = "без лимита" if Global.fps_cap == 0 else str(Global.fps_cap)
	(_setting_btns["weather"] as Button).text = "вкл" if Global.weather_on else "выкл"
	(_setting_btns["volume"] as Button).text = "выкл" if Global.volume <= 0.001 else "%d%%" % int(Global.volume * 100.0)


func _set_diff(i: int) -> void:
	Global.difficulty = i
	_refresh()


func _cycle_diff() -> void:
	Global.difficulty = (Global.difficulty + 1) % 3
	_refresh()


func _cycle_mode() -> void:
	Global.control_mode = (Global.control_mode + 1) % 3
	_refresh()


func _cycle_cast() -> void:
	Global.cast_mode = (Global.cast_mode + 1) % 3
	_refresh()


func _toggle_shadow() -> void:
	Global.shadows_on = not Global.shadows_on
	_refresh()


func _cycle_quality() -> void:
	Global.quality = (Global.quality + 1) % QUALITY_PRESETS.size()
	_apply_quality_preset(Global.quality)
	_refresh()


func _apply_quality_preset(q: int) -> void:
	var p: Dictionary = QUALITY_PRESETS[q]
	Global.res_scale = float(p["res_scale"])
	Global.shadows_on = bool(p["shadows"])
	Global.weather_on = bool(p["weather"])
	Global.fps_cap = int(p["fps"])
	Engine.max_fps = Global.fps_cap


func _toggle_edge() -> void:
	Global.edge_scroll = not Global.edge_scroll
	_refresh()


func _on_play() -> void:
	Global.test_mode = false
	Global.test_inf_mana = false
	Global.test_no_cd = false
	_go_to_scene("res://scenes/Main.tscn", "res://assets/ui/loading_match.png")


# Универсальный переход: если LoadingScreen.gd есть — грузим через него, иначе прямой переход.
func _go_to_scene(path: String, bg_path: String = "") -> void:
	if ResourceLoader.exists(LOADING_SCENE_PATH):
		var ls_script = load(LOADING_SCENE_PATH)
		if ls_script != null and ls_script.has_method("go_to"):
			ls_script.go_to(get_tree(), path, bg_path)
			return
	get_tree().change_scene_to_file(path)


func _cycle_teams() -> void:
	if not Global.experimental:
		Global.team_size = 2
		_refresh()
		return
	Global.team_size = {1: 2, 2: 5, 5: 1}.get(Global.team_size, 1)
	_refresh()


func _toggle_fog() -> void:
	Global.fog_on = not Global.fog_on
	_refresh()


func _cycle_biome() -> void:
	var i := Biome.ORDER.find(Global.biome)
	Global.biome = String(Biome.ORDER[(i + 1) % Biome.ORDER.size()])
	_refresh()


func _cycle_res() -> void:
	var opts: Array = [1.0, 0.85, 0.7, 0.55]
	var i := opts.find(Global.res_scale)
	Global.res_scale = float(opts[(i + 1) % opts.size()])
	_refresh()


func _cycle_fps() -> void:
	var opts: Array = [30, 60, 120, 0]
	var i := opts.find(Global.fps_cap)
	Global.fps_cap = int(opts[(i + 1) % opts.size()])
	Engine.max_fps = Global.fps_cap
	_refresh()


func _toggle_weather() -> void:
	Global.weather_on = not Global.weather_on
	_refresh()


func _cycle_volume() -> void:
	var opts: Array = [0.0, 0.3, 0.6, 1.0]
	var idx := 0
	for k in opts.size():
		if absf(float(opts[k]) - Global.volume) < 0.05:
			idx = k
	Global.volume = float(opts[(idx + 1) % opts.size()])
	Global.apply_volume()
	_refresh()


func _add_version_label() -> void:
	var l := Label.new()
	l.text = "Throne Wars  v%s" % Global.VERSION
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(1.0, 1.0, 1.0, 0.55)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 100
	add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)


func _reset_settings() -> void:
	Global.reset_settings()
	_pick(Global.selected_hero)
	_refresh()


func _toggle_prematch() -> void:
	Global.prematch_on = not Global.prematch_on
	_refresh()


# ---------- клавиатура и выход ----------
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			_play_click(); _show("play")
		KEY_2:
			_play_click(); _show("heroes")
		KEY_3:
			_play_click(); _show("settings")
		KEY_ESCAPE:
			if _any_dialog_visible():
				return
			if _panels["play"].visible:
				_confirm_quit()
			else:
				_play_click(); _show("play")


func _any_dialog_visible() -> bool:
	for c in get_children():
		if c is AcceptDialog and (c as AcceptDialog).visible:
			return true
	return false


func _confirm_quit() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Выход"
	dlg.dialog_text = "Выйти из игры?"
	dlg.ok_button_text = "Выйти"
	dlg.cancel_button_text = "Остаться"
	dlg.confirmed.connect(func() -> void: get_tree().quit())
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _build_changelog() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	var heading := HBoxContainer.new()
	page.add_child(heading)
	var title := _label("ПУТЬ РАЗРАБОТКИ", 28, Color(0.94, 0.94, 0.91))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(270, 42)
	select.add_item("Все этапы")
	var history = preload("res://scripts/DevelopmentHistory.gd")
	for stage in history.STAGES:
		select.add_item(stage["short"])
	heading.add_child(select)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	var cards: Array[Control] = []
	for stage in history.STAGES:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _panel_style())
		list.add_child(card)
		cards.append(card)
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 14)
		card.add_child(margin)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 8)
		margin.add_child(content)
		content.add_child(_label(stage["meta"], 12, GOLD))
		var name_label := _label(stage["title"], 22)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(name_label)
		for item in stage["items"]:
			var line := _label("•  " + item, 15, MUTED)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(line)
	select.item_selected.connect(func(index: int) -> void:
		for i in cards.size():
			cards[i].visible = index == 0 or i == index - 1
		scroll.scroll_vertical = 0
	)
	return page

func _build_base_background() -> void:
	var background := ColorRect.new()
	background.color = Color(0.025, 0.035, 0.045)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _toggle_experimental() -> void:
	Global.experimental = not Global.experimental
	if not Global.experimental:
		Global.team_size = 2
		if Global.selected_hero not in MatchBalance.PRIMARY_HEROES:
			_pick("titan")
	for id in _hero_btns:
		(_hero_btns[id] as Button).disabled = not Global.experimental and id not in MatchBalance.PRIMARY_HEROES
	_refresh()
