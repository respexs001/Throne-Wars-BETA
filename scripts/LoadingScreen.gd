extends Control
## LoadingScreen.gd — экран загрузки. Не использует class_name.
## Создаётся через load("res://scripts/LoadingScreen.gd").new() из MainMenu.gd.
## Перед add_child() нужно задать поля _target и _bg_paths.

const TIPS: Array[String] = [
	"Ластхит важнее агрессии: 10 крипов = 400 золота.",
	"Не стойте под вражеской башней без своих крипов.",
	"Руны в реке появляются каждые 2 минуты.",
	"Кария фармит в лёгкой линии, а не бегает за киллами.",
	"TP-свиток отменяется при получении урона.",
	"После 6 уровня следите за миникартой — начнутся ганки.",
	"BKB спасает от магии, но не от физического урона.",
	"Если у врага нет ульты — самое время давить.",
]

const GOLD := Color(0.9, 0.72, 0.3)
const MIN_SHOW_TIME: float = 0.6
const HOLD_100_MS: float = 0.3
const ERROR_HOLD_SEC: float = 2.5
const FALLBACK_SCENE: String = "res://scenes/MainMenu.tscn"
const CROSSFADE_SEC: float = 4.0
const CURTAIN_SEC: float = 0.35

var _target: String = ""
var _bg_paths: Array = []
var _loaded_scene: PackedScene = null
var _progress_val: float = 0.0
var _bar: ProgressBar
var _lbl_progress: Label
var _lbl_tip: Label
var _curtain: ColorRect
var _layers: Array = []
var _crossfade_tween: Tween
var _finished: bool = false
var _requested: bool = false
var _elapsed_show: float = 0.0
var _sparks: CPUParticles2D


func _ready() -> void:
	set_process(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background_layers()
	_build_vignette()
	_build_sparks()
	_build_title()
	_build_tip()
	_build_progress()
	_build_curtain()
	_animate_curtain_in()
	_boot()
	_start_crossfade()


func _boot() -> void:
	await get_tree().process_frame
	_elapsed_show = 0.0
	if _target == "":
		_fail("LoadingScreen: пустая цель загрузки")
		return
	var err := ResourceLoader.load_threaded_request(_target)
	if err != OK:
		_fail("LoadingScreen: load_threaded_request('%s') = %s" % [_target, err])
		return
	_requested = true


# Ошибка загрузки: показываем сообщение и возвращаемся в меню, а не зависаем на экране загрузки.
func _fail(message: String) -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	push_error(message)
	if _lbl_progress != null:
		_lbl_progress.text = "ОШИБКА ЗАГРУЗКИ"
	await get_tree().create_timer(ERROR_HOLD_SEC).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file(FALLBACK_SCENE)


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed_show += delta
	if not _requested:
		return
	var status := ResourceLoader.load_threaded_get_status(_target, [_progress_val])
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_bar.value = lerpf(_bar.value, _progress_val, 0.2)
			_lbl_progress.text = "%d%%" % int(_bar.value * 100.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			if _elapsed_show < MIN_SHOW_TIME:
				return
			_bar.value = 1.0
			_lbl_progress.text = "100%"
			set_process(false)
			_loaded_scene = ResourceLoader.load_threaded_get(_target)
			_finish()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail("LoadingScreen: не удалось загрузить %s" % _target)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	await get_tree().create_timer(HOLD_100_MS).timeout
	if _loaded_scene == null or not is_inside_tree():
		return
	await _animate_curtain_out()
	var tree := get_tree()
	var old := tree.current_scene
	var inst := _loaded_scene.instantiate()
	tree.root.add_child(inst)
	tree.current_scene = inst
	if old != null and is_instance_valid(old):
		old.hide()
		old.queue_free()


func _build_background_layers() -> void:
	var holder := Control.new()
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var count: int = maxi(_bg_paths.size(), 3)
	for i in count:
		var layer := TextureRect.new()
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.modulate.a = 1.0 if i == 0 else 0.0
		var tex: Texture2D = null
		if i < _bg_paths.size():
			var p: String = String(_bg_paths[i])
			if p != "" and ResourceLoader.exists(p):
				tex = load(p) as Texture2D
		if tex == null:
			tex = _make_gradient_tex(i)
		layer.texture = tex
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		holder.add_child(layer)
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.offset_left = -120
		layer.offset_top = -120
		layer.offset_right = 120
		layer.offset_bottom = 120
		layer.pivot_offset = Vector2(960, 540)
		_layers.append(layer)
		var tw := layer.create_tween().set_loops()
		tw.tween_property(layer, "scale", Vector2(1.10, 1.10), 9.0 + float(i)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(layer, "scale", Vector2(1.0, 1.0), 9.0 + float(i)).set_trans(Tween.TRANS_SINE)


func _make_gradient_tex(idx: int) -> Texture2D:
	var palettes: Array = [
		[Color(0.10, 0.05, 0.16), Color(0.01, 0.01, 0.02)],
		[Color(0.16, 0.08, 0.04), Color(0.02, 0.01, 0.01)],
		[Color(0.04, 0.06, 0.14), Color(0.01, 0.01, 0.03)],
	]
	var pal: Array = palettes[idx % palettes.size()]
	var g := Gradient.new()
	g.set_color(0, pal[0])
	g.set_color(1, pal[1])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.35)
	gt.fill_to = Vector2(1.1, 0.6)
	gt.width = 1024
	gt.height = 1024
	return gt


func _start_crossfade() -> void:
	if _layers.size() < 2:
		return
	_crossfade_tween = create_tween().set_loops()
	for i in _layers.size():
		var next: int = (i + 1) % _layers.size()
		var nxt: TextureRect = _layers[next]
		_crossfade_tween.tween_interval(CROSSFADE_SEC)
		_crossfade_tween.tween_property(nxt, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
		_crossfade_tween.tween_callback(func() -> void:
			for j in _layers.size():
				if j != next:
					(_layers[j] as TextureRect).modulate.a = 0.0
		)


func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 1024
	gt.height = 1024
	var vig := TextureRect.new()
	vig.texture = gt
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_sparks() -> void:
	_sparks = CPUParticles2D.new()
	_sparks.amount = 55
	_sparks.lifetime = 4.5
	_sparks.preprocess = 4.5
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparks.direction = Vector2(0.0, -1.0)
	_sparks.spread = 16.0
	_sparks.gravity = Vector2(0.0, -18.0)
	_sparks.initial_velocity_min = 35.0
	_sparks.initial_velocity_max = 95.0
	_sparks.scale_amount_min = 1.5
	_sparks.scale_amount_max = 4.0
	_sparks.color = Color(1.0, 0.85, 0.4, 0.7)
	add_child(_sparks)
	_reposition_sparks()
	get_viewport().size_changed.connect(_reposition_sparks)


func _reposition_sparks() -> void:
	if _sparks == null or not is_instance_valid(_sparks):
		return
	var sz := get_viewport_rect().size
	_sparks.position = Vector2(sz.x * 0.5, sz.y + 30.0)
	_sparks.emission_rect_extents = Vector2(sz.x * 0.55, 10.0)


func _build_title() -> void:
	var title := Label.new()
	title.text = "THRONE WARS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 10)
	add_child(title)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -500
	title.offset_right = 500
	title.offset_top = 100
	title.offset_bottom = 220
	var tw := create_tween().set_loops()
	tw.tween_property(title, "modulate", Color(1.15, 1.08, 0.85), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "modulate", Color.WHITE, 1.6).set_trans(Tween.TRANS_SINE)


func _build_tip() -> void:
	_lbl_tip = Label.new()
	_lbl_tip.text = TIPS.pick_random()
	_lbl_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_tip.add_theme_font_size_override("font_size", 20)
	_lbl_tip.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_lbl_tip.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl_tip.add_theme_constant_override("outline_size", 4)
	add_child(_lbl_tip)
	_lbl_tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lbl_tip.offset_left = -650
	_lbl_tip.offset_right = 650
	_lbl_tip.offset_top = -220
	_lbl_tip.offset_bottom = -140
	_lbl_tip.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_lbl_tip, "modulate:a", 1.0, 0.5)


func _build_progress() -> void:
	var spinner := Control.new()
	spinner.custom_minimum_size = Vector2(48, 48)
	spinner.set_script(_create_spinner_script())
	add_child(spinner)
	spinner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	spinner.offset_left = -24
	spinner.offset_right = 24
	spinner.offset_top = -175
	spinner.offset_bottom = -127

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.value = 0.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(5)
	_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.05, 0.05, 0.9)
	bg.border_color = GOLD
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("background", bg)
	add_child(_bar)
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.offset_left = -450
	_bar.offset_right = 450
	_bar.offset_top = -110
	_bar.offset_bottom = -70

	_lbl_progress = Label.new()
	_lbl_progress.text = "0%"
	_lbl_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_progress.add_theme_font_size_override("font_size", 18)
	_lbl_progress.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_lbl_progress.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl_progress.add_theme_constant_override("outline_size", 4)
	add_child(_lbl_progress)
	_lbl_progress.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lbl_progress.offset_left = -450
	_lbl_progress.offset_right = 450
	_lbl_progress.offset_top = -110
	_lbl_progress.offset_bottom = -70


func _build_curtain() -> void:
	_curtain = ColorRect.new()
	_curtain.color = Color(0.02, 0.01, 0.03, 1.0)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.z_index = 50
	add_child(_curtain)
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.modulate.a = 1.0


func _animate_curtain_in() -> void:
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(_curtain, "modulate:a", 0.0, CURTAIN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _animate_curtain_out() -> void:
	if _curtain == null or not is_instance_valid(_curtain):
		return
	var tw := create_tween()
	tw.tween_property(_curtain, "modulate:a", 1.0, CURTAIN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished


static func go_to(tree: SceneTree, target_path: String, bg_path: String = "") -> void:
	if tree == null:
		return
	var script = load("res://scripts/LoadingScreen.gd")
	if script == null:
		tree.change_scene_to_file(target_path)
		return
	var node = script.new()
	node._target = target_path
	if bg_path != "":
		node._bg_paths = [bg_path]
	var current = tree.current_scene
	tree.root.add_child(node)
	tree.current_scene = node
	if current != null and is_instance_valid(current):
		current.queue_free()


func _create_spinner_script() -> GDScript:
	var scr := GDScript.new()
	scr.source_code = """extends Control
var angle: float = 0.0
func _ready() -> void:
    custom_minimum_size = Vector2(48, 48)
    set_process(true)
func _process(delta: float) -> void:
    angle += delta * 5.0
    queue_redraw()
func _draw() -> void:
    var center := size * 0.5
    var gold := Color(0.9, 0.72, 0.3, 0.95)
    var cyan := Color(0.3, 0.75, 1.0, 0.7)
    draw_arc(center, 18.0, angle, angle + 4.5, 28, gold, 4.0, true)
    draw_arc(center, 11.0, -angle * 1.5, -angle * 1.5 + 3.2, 20, cyan, 2.5, true)
"""
	scr.reload()
	return scr
