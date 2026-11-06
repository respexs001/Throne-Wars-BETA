class_name ProfilePanel
extends Control
## ProfilePanel.gd — вкладка «ПРОФИЛЬ» главного меню: вход, регистрация, профиль и статистика.
## Только интерфейс: вся логика аккаунтов находится в ProfileService / AuthBackend.

const GOLD: Color = Color(0.8, 0.3, 0.24)
const MUTED: Color = Color(0.72, 0.76, 0.92)
const AVATAR_COLORS: Array[Color] = [
    Color(0.90, 0.72, 0.30), Color(0.35, 0.65, 1.00), Color(0.85, 0.35, 0.35), Color(0.45, 0.80, 0.50),
    Color(0.70, 0.45, 0.90), Color(0.95, 0.55, 0.25), Color(0.30, 0.80, 0.80), Color(0.85, 0.85, 0.90),
]

var _mode: String = "login"    # login | register
var _content: VBoxContainer = null
var _user: LineEdit = null
var _pass: LineEdit = null
var _pass2: LineEdit = null
var _name_edit: LineEdit = null
var _error: Label = null
var _status: Label = null
var _status_text: String = ""
var _status_ok: bool = true
var _auth_busy: bool = false


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    scroll.anchor_left = 0.5
    scroll.anchor_right = 1.0
    scroll.anchor_bottom = 1.0
    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 12)
    scroll.add_child(margin)
    _content = VBoxContainer.new()
    _content.custom_minimum_size = Vector2(380.0, 0.0)
    _content.add_theme_constant_override("separation", 10)
    margin.add_child(_content)
    ProfileService.session_changed.connect(_on_session_changed)
    ProfileService.profile_updated.connect(_on_profile_updated)
    ProfileService.auth_result.connect(_on_auth_result)
    visibility_changed.connect(_on_visibility)
    _rebuild()


# ---------- построение ----------
func _rebuild() -> void:
    if _content == null:
        return
    _user = null
    _pass = null
    _pass2 = null
    _name_edit = null
    _error = null
    _status = null
    for c in _content.get_children():
        _content.remove_child(c)
        c.queue_free()
    if ProfileService.is_logged_in():
        _build_profile()
    else:
        _build_auth()


func _build_auth() -> void:
    if ProfileService.is_guest:
        _content.add_child(_label("ГОСТЕВОЙ СЕАНС", 26, GOLD))
        _content.add_child(_label("Прогресс доступен до выхода из игры. Создайте профиль для будущих матчей.", 15, MUTED, true))
    var reg: bool = _mode == "register"
    _content.add_child(_label("РЕГИСТРАЦИЯ" if reg else "ВХОД", 34, GOLD))
    _content.add_child(_label("Создайте локальный аккаунт или войдите в существующий профиль.", 15, MUTED, true))
    _user = _field("Логин (латиница, цифры, _)", false, AuthBackend.USERNAME_MAX)
    _pass = _field("Пароль", true, AuthBackend.PASSWORD_MAX)
    _content.add_child(_user)
    _content.add_child(_pass)
    var last: LineEdit = _pass
    if reg:
        _pass2 = _field("Повторите пароль", true, AuthBackend.PASSWORD_MAX)
        _content.add_child(_pass2)
        last = _pass2
    last.text_submitted.connect(func(_t: String) -> void: _submit())
    _error = _label("", 15, Color(1.0, 0.45, 0.4), true)
    _content.add_child(_error)
    _content.add_child(_btn("Зарегистрироваться" if reg else "Войти", _submit, true))
    _content.add_child(_btn("Уже есть аккаунт? Войти" if reg else "Нет аккаунта? Создать", _toggle_mode))


func _build_profile() -> void:
    var p: Dictionary = ProfileService.profile
    var stats: Dictionary = p["stats"]
    var shown: String = String(p["display_name"])
    var avatar_idx: int = int(p["avatar"])

    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 14)
    head.add_child(_avatar(avatar_idx, shown, 72.0))
    var names := VBoxContainer.new()
    names.add_child(_label(shown, 32, GOLD))
    names.add_child(_label("@" + String(p["username"]), 15, MUTED))
    head.add_child(names)
    _content.add_child(head)
    for id in MatchBalance.PRIMARY_HEROES:
        var mastery := _label("%s · %s · %d опыта" % [HeroDB.get_hero(id)["name"], ProfileService.mastery_title(id), ProfileService.mastery_xp(id)], 15, ProfileService.mastery_color(id).lightened(0.35), true)
        _content.add_child(mastery)


    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    _name_edit = _field("Ник", false, AuthBackend.DISPLAY_MAX)
    _name_edit.text = shown
    _name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _name_edit.text_submitted.connect(func(_t: String) -> void: _save_name())
    row.add_child(_name_edit)
    var save := _btn("Сохранить", _save_name, true)
    save.custom_minimum_size.x = 130.0
    row.add_child(save)
    _content.add_child(row)

    _content.add_child(_label("Аватар", 16, MUTED))
    var av := HBoxContainer.new()
    av.add_theme_constant_override("separation", 6)
    for i in AVATAR_COLORS.size():
        av.add_child(_avatar_button(i, i == avatar_idx))
    _content.add_child(av)

    _content.add_child(_label("Статистика", 22, GOLD))
    var matches: int = int(stats["matches"])
    var wins: int = int(stats["wins"])
    var kills: int = int(stats["kills"])
    var deaths: int = int(stats["deaths"])
    var winrate: String = "—"
    if matches > 0:
        winrate = "%d%%" % roundi(wins * 100.0 / matches)
    var rows: Array = [
        ["Матчи", str(matches)],
        ["Победы / поражения", "%d / %d" % [wins, int(stats["losses"])]],
        ["Винрейт", winrate],
        ["Убийства / смерти", "%d / %d" % [kills, deaths]],
        ["K/D", "%.2f" % (float(kills) / float(maxi(deaths, 1)))],
        ["Время в игре", _fmt_time(float(stats["play_time_sec"]))],
        ["Любимый герой", _fav_hero(stats)],
        ["Аккаунт создан", Time.get_date_string_from_unix_time(int(p["created_unix"]))],
        ["ID игрока", String(p["player_id"])],
    ]
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 24)
    grid.add_theme_constant_override("v_separation", 6)
    for r in rows:
        grid.add_child(_label(String(r[0]), 17, MUTED))
        grid.add_child(_label(String(r[1]), 17))
    _content.add_child(grid)

    var ok_col := Color(0.5, 0.9, 0.55) if _status_ok else Color(1.0, 0.45, 0.4)
    _status = _label(_status_text, 15, ok_col, true)
    _content.add_child(_status)
    _content.add_child(_btn("Выйти из аккаунта", _logout))


# ---------- действия ----------
func _toggle_mode() -> void:
    _mode = "register" if _mode == "login" else "login"
    _rebuild()


func _submit() -> void:
    if _auth_busy or _user == null or _pass == null:
        return
    var username: String = _user.text.strip_edges()
    var password: String = _pass.text
    var result: Dictionary
    if _mode == "register":
        if password != _pass2.text:
            _error.text = "Пароли не совпадают."
            return
        _auth_busy = true
        _pass.clear()
        _pass2.clear()
        result = await ProfileService.authenticate_async("register", username, password)
    else:
        _auth_busy = true
        _pass.clear()
        result = await ProfileService.authenticate_async("login", username, password)
    _auth_busy = false
    if not bool(result["ok"]) and _error != null:
        _error.text = String(result["error"])


func _save_name() -> void:
    if _name_edit == null:
        return
    ProfileService.update_profile(_name_edit.text, int(ProfileService.profile["avatar"]))


func _pick_avatar(index: int) -> void:
    ProfileService.update_profile(ProfileService.display_name(), index)


func _logout() -> void:
    ProfileService.logout()


# ---------- сигналы сервиса ----------
func _on_session_changed(_p: Dictionary) -> void:
    _status_text = ""
    _rebuild.call_deferred()


func _on_profile_updated(_p: Dictionary) -> void:
    _rebuild.call_deferred()


func _on_auth_result(action: String, result: Dictionary) -> void:
    if action != "save":
        return
    _status_ok = bool(result["ok"])
    _status_text = "Сохранено." if _status_ok else String(result["error"])
    if _status != null and is_instance_valid(_status):
        _status.text = _status_text
        _status.add_theme_color_override("font_color", Color(0.5, 0.9, 0.55) if _status_ok else Color(1.0, 0.45, 0.4))


func _on_visibility() -> void:
    if visible:
        _rebuild()


# ---------- форматирование ----------
func _fmt_time(seconds: float) -> String:
    var total: int = int(seconds)
    return "%d ч %02d мин" % [int(total / 3600.0), int((total % 3600) / 60.0)]


func _fav_hero(stats: Dictionary) -> String:
    var heroes: Dictionary = stats["heroes"]
    var best_id: String = ""
    var best: int = 0
    for id in heroes.keys():
        var n: int = int(heroes[id])
        if n > best:
            best = n
            best_id = String(id)
    if best_id == "":
        return "—"
    return "%s (%d)" % [String(HeroDB.get_hero(best_id)["name"]), best]


# ---------- виджеты ----------
func _label(text: String, font_px: int, color: Color = Color.WHITE, wrap: bool = false) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", font_px)
    l.add_theme_color_override("font_color", color)
    if wrap:
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return l


func _field(placeholder: String, secret: bool, max_len: int) -> LineEdit:
    var f := LineEdit.new()
    f.placeholder_text = placeholder
    f.secret = secret
    f.max_length = max_len
    f.custom_minimum_size = Vector2(0.0, 46.0)
    f.add_theme_font_size_override("font_size", 18)
    return f


func _btn(text: String, cb: Callable, primary: bool = false) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0.0, 48.0)
    b.add_theme_font_size_override("font_size", 18)
    var col: Color = GOLD if primary else Color(0.5, 0.55, 0.7)
    for state in ["normal", "hover", "pressed"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(col.r, col.g, col.b, 0.12 if state == "normal" else 0.28)
        sb.border_color = col
        sb.set_border_width_all(2)
        sb.set_corner_radius_all(6)
        sb.set_content_margin_all(8.0)
        b.add_theme_stylebox_override(state, sb)
    b.pressed.connect(cb)
    return b


func _avatar(index: int, text: String, diameter: float) -> PanelContainer:
    var panel := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = AVATAR_COLORS[clampi(index, 0, AVATAR_COLORS.size() - 1)]
    sb.set_corner_radius_all(int(diameter * 0.5))
    panel.add_theme_stylebox_override("panel", sb)
    panel.custom_minimum_size = Vector2(diameter, diameter)
    var l := _label(text.substr(0, 1).to_upper(), int(diameter * 0.5), Color(0.08, 0.07, 0.06))
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    panel.add_child(l)
    return panel


func _avatar_button(index: int, selected: bool) -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(36.0, 36.0)
    var sb := StyleBoxFlat.new()
    sb.bg_color = AVATAR_COLORS[index]
    sb.set_corner_radius_all(18)
    if selected:
        sb.border_color = Color.WHITE
        sb.set_border_width_all(3)
    for state in ["normal", "hover", "pressed", "focus"]:
        b.add_theme_stylebox_override(state, sb)
    b.pressed.connect(_pick_avatar.bind(index))
    return b
