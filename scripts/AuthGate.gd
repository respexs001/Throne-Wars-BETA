extends Control
## AuthGate.gd — гостевой вход или локальный профиль перед главным меню.

const GOLD: Color = Color(0.8, 0.3, 0.24)
const MUTED: Color = Color(0.68, 0.72, 0.84)
const AUTH_SHADER_PATH: String = "res://Shaders/fog_menu.gdshader"
const MENU_SCENE_PATH: String = "res://scenes/MainMenu.tscn"

var _mode: String = "login"
var _username: LineEdit
var _password: LineEdit
var _password_repeat: LineEdit
var _error: Label
var _submit_button: Button
var _login_button: Button
var _register_button: Button
var _busy: bool = false


func _ready() -> void:
    get_tree().paused = false
    if OS.get_environment("THRONE_WARS_TEST") == "1" and ("--verify-runtime" in OS.get_cmdline_user_args() or "--benchmark-runtime" in OS.get_cmdline_user_args()):
        var data_dir := OS.get_user_data_dir().replace("\\", "/")
        if not data_dir.contains("/thronewars-runtime-"):
            printerr("Runtime verification requires tools/test_windows.py and isolated data.")
            get_tree().quit(2)
            return
        _build_screen()
        var verification: Node = preload("res://scripts/RuntimeBenchmark.gd").new() if "--benchmark-runtime" in OS.get_cmdline_user_args() else preload("res://scripts/RuntimeVerification.gd").new()
        get_tree().root.call_deferred("add_child", verification)
        return
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    if not ProfileService.auth_result.is_connected(_on_auth_result):
        ProfileService.auth_result.connect(_on_auth_result)
    if ProfileService.has_session():
        call_deferred("_open_menu")
        return
    _build_screen()


func _build_screen() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color.WHITE
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if ResourceLoader.exists(AUTH_SHADER_PATH):
        var shader := load(AUTH_SHADER_PATH) as Shader
        if shader != null:
            var material := ShaderMaterial.new()
            material.shader = shader
            material.set_shader_parameter("base_color", Color(0.018, 0.025, 0.045, 1.0))
            material.set_shader_parameter("fog_color", Color(0.075, 0.09, 0.15, 1.0))
            material.set_shader_parameter("aurora_intensity", 0.35)
            material.set_shader_parameter("spark_intensity", 0.45)
            background.material = material
    add_child(background)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.015, 0.02, 0.035, 0.3)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(center)

    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(maxf(280.0, minf(460.0, get_viewport_rect().size.x - 24.0)), 0.0)
    var card_style := StyleBoxFlat.new()
    card_style.bg_color = Color(0.035, 0.045, 0.07, 0.96)
    card_style.border_color = Color(0.3, 0.39, 0.43, 0.85)
    card_style.set_border_width_all(1)
    card_style.set_corner_radius_all(12)
    card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
    card_style.shadow_size = 22
    card_style.content_margin_left = 30.0
    card_style.content_margin_right = 30.0
    card_style.content_margin_top = 26.0
    card_style.content_margin_bottom = 26.0
    card.add_theme_stylebox_override("panel", card_style)
    center.add_child(card)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 12)
    card.add_child(content)

    var eyebrow := _label("THRONE WARS  •  ACCOUNT SYSTEM", 12, MUTED)
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(eyebrow)
    var title := _label("ВРАТА КОРОЛЕВСТВА", 29, GOLD)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(title)
    var subtitle := _label("Войдите или создайте аккаунт, чтобы продолжить.", 15, MUTED)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(subtitle)

    var divider := HSeparator.new()
    content.add_child(divider)
    var mode_row := HBoxContainer.new()
    mode_row.add_theme_constant_override("separation", 8)
    content.add_child(mode_row)
    var login_tab := _button("ВХОД", _set_login_mode, true)
    var register_tab := _button("РЕГИСТРАЦИЯ", _set_register_mode, false)
    login_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    register_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mode_row.add_child(login_tab)
    mode_row.add_child(register_tab)
    _login_button = login_tab
    _register_button = register_tab

    _username = _field("Логин", false)
    content.add_child(_username)
    _password = _field("Пароль", true)
    content.add_child(_password)
    _password_repeat = _field("Повторите пароль", true)
    content.add_child(_password_repeat)

    _error = _label("", 14, Color(1.0, 0.42, 0.38))
    _error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(_error)
    _submit_button = _button("ВОЙТИ В ИГРУ", _submit, true)
    _submit_button.custom_minimum_size.y = 54.0
    content.add_child(_submit_button)
    var guest := _button("ИГРАТЬ ГОСТЕМ", _guest, false)
    content.add_child(guest)

    var note := _label("Локальный профиль на этом устройстве.\nПосле перезапуска потребуется снова войти.", 12, MUTED)
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(note)

    _password.text_submitted.connect(func(_value: String) -> void: _submit())
    _password_repeat.text_submitted.connect(func(_value: String) -> void: _submit())
    _refresh_mode()


func _set_login_mode() -> void:
    if _busy:
        return
    _mode = "login"
    _error.text = ""
    _refresh_mode()


func _set_register_mode() -> void:
    if _busy:
        return
    _mode = "register"
    _error.text = ""
    _refresh_mode()


func _refresh_mode() -> void:
    var registering := _mode == "register"
    _password.placeholder_text = ("Пароль · от %d символов" % AuthBackend.PASSWORD_MIN) if registering else "Пароль"
    _password_repeat.visible = registering
    _password_repeat.editable = registering
    _submit_button.text = "СОЗДАТЬ АККАУНТ" if registering else "ВОЙТИ В ИГРУ"
    if _register_button != null:
        _style_mode_button(_register_button, registering)
    if _login_button != null:
        _style_mode_button(_login_button, not registering)


func _submit() -> void:
    if _busy or _username == null or _password == null:
        return
    var username := _username.text.strip_edges()
    var password := _password.text
    if username.is_empty() or password.is_empty():
        _error.text = "Заполните логин и пароль."
        return
    var result: Dictionary
    if _mode == "register":
        if password != _password_repeat.text:
            _error.text = "Пароли не совпадают."
            return
        _busy = true
        _submit_button.disabled = true
        _submit_button.text = "СОЗДАНИЕ АККАУНТА..."
        _password.clear()
        _password_repeat.clear()
        result = await ProfileService.authenticate_async("register", username, password)
        if not bool(result.get("ok", false)):
            _busy = false
            _submit_button.disabled = false
            _refresh_mode()
            _error.text = String(result.get("error", "Не удалось создать аккаунт."))
    else:
        _busy = true
        _submit_button.disabled = true
        _submit_button.text = "ВХОД..."
        _password.clear()
        _password_repeat.clear()
        result = await ProfileService.authenticate_async("login", username, password)
        if not bool(result.get("ok", false)):
            _busy = false
            _submit_button.disabled = false
            _refresh_mode()
            _error.text = String(result.get("error", "Не удалось войти."))


func _on_auth_result(action: String, result: Dictionary) -> void:
    if action not in ["register", "login"]:
        return
    if not bool(result.get("ok", false)):
        return
    _busy = false
    call_deferred("_open_menu")


func _open_menu() -> void:
    if not ProfileService.has_session():
        return
    get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _field(placeholder: String, secret: bool) -> LineEdit:
    var field := LineEdit.new()
    field.placeholder_text = placeholder
    field.secret = secret
    field.max_length = AuthBackend.PASSWORD_MAX if secret else AuthBackend.USERNAME_MAX
    field.custom_minimum_size = Vector2(0.0, 48.0)
    field.add_theme_font_size_override("font_size", 17)
    field.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.07, 0.085, 0.12, 1.0)
    normal.border_color = Color(0.22, 0.27, 0.36)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(5)
    normal.set_content_margin_all(10.0)
    field.add_theme_stylebox_override("normal", normal)
    field.add_theme_stylebox_override("focus", normal)
    return field


func _button(text: String, callback: Callable, primary: bool) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(0.0, 44.0)
    button.add_theme_font_size_override("font_size", 16)
    var color := GOLD if primary else Color(0.45, 0.51, 0.66)
    for state in ["normal", "hover", "pressed", "disabled"]:
        var style := StyleBoxFlat.new()
        style.bg_color = Color(color.r, color.g, color.b, 0.14 if state == "normal" else 0.28)
        style.border_color = color.darkened(0.1)
        style.set_border_width_all(1)
        style.set_corner_radius_all(5)
        style.set_content_margin_all(8.0)
        button.add_theme_stylebox_override(state, style)
    button.pressed.connect(callback)
    return button


func _label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label

func _style_mode_button(button: Button, active: bool) -> void:
    var color := GOLD if active else Color(0.3, 0.39, 0.43)
    for state in ["normal", "hover", "pressed", "disabled"]:
        var style := StyleBoxFlat.new()
        style.bg_color = Color(color.r, color.g, color.b, 0.2 if active else 0.07)
        style.border_color = color
        style.set_border_width_all(1)
        style.set_corner_radius_all(5)
        style.set_content_margin_all(8.0)
        button.add_theme_stylebox_override(state, style)

func _guest() -> void:
    if _busy: return
    ProfileService.start_guest()
    _open_menu()
