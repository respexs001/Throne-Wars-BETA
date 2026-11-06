extends Node
signal auth_result(action: String, result: Dictionary)
signal session_changed(profile: Dictionary)
signal profile_updated(profile: Dictionary)
const AVATAR_COUNT: int = 8
var backend: AuthBackend
var profile: Dictionary = {}
var is_guest: bool = false
var _guest_profile: Dictionary = {}
var _auth_thread: Thread
var _auth_busy: bool = false
var _recorded_match_id: String = ""

func _ready() -> void:
    backend = LocalAuthBackend.new()
    Global.game_over.connect(_on_game_over)

func has_session() -> bool:
    return not profile.is_empty()
func is_logged_in() -> bool:
    return has_session() and not is_guest
func display_name() -> String:
    return String(profile.get("display_name", "Гость"))
func start_guest() -> void:
    if _auth_busy: return
    backend.logout()
    if _guest_profile.is_empty():
        _guest_profile = {"v": 3, "username": "guest", "display_name": "Гость", "avatar": 0, "mastery": {}, "stats": {"matches": 0, "wins": 0, "losses": 0, "kills": 0, "deaths": 0, "play_time_sec": 0.0, "heroes": {}}}
    is_guest = true
    profile = _guest_profile.duplicate(true)
    session_changed.emit(profile)
func register(username: String, password: String) -> Dictionary:
    if _auth_busy: return AuthBackend.fail("Дождитесь завершения входа.")
    return _finish("register", backend.register(username.strip_edges(), password))
func login(username: String, password: String) -> Dictionary:
    if _auth_busy: return AuthBackend.fail("Дождитесь завершения входа.")
    return _finish("login", backend.login(username.strip_edges(), password))
func logout() -> void:
    if _auth_busy: return
    if is_guest: _guest_profile = profile.duplicate(true)
    backend.logout()
    profile = {}
    is_guest = false
    session_changed.emit(profile)
func update_profile(new_display_name: String, avatar: int) -> Dictionary:
    if _auth_busy or not is_logged_in(): return AuthBackend.fail("Для сохранения нужен локальный профиль.")
    var p := profile.duplicate(true)
    p["display_name"] = new_display_name.strip_edges()
    p["avatar"] = clampi(avatar, 0, AVATAR_COUNT - 1)
    var r := backend.save_profile(p)
    if r["ok"]:
        profile = r["profile"]
        profile_updated.emit(profile)
    auth_result.emit("save", r)
    return r
func mastery_xp(id: String) -> int:
    var data: Dictionary = profile.get("mastery", {})
    return maxi(0, int(data.get(id, 0)))
func mastery_level(id: String) -> int:
    var level: int = 0
    for threshold in MatchBalance.MASTERY_THRESHOLDS:
        if mastery_xp(id) >= threshold: level += 1
    return level
func mastery_color(id: String) -> Color:
    return [Color(0.28, 0.37, 0.41), Color(0.65, 0.4, 0.2), Color(0.65, 0.76, 0.85), Color(0.72, 0.42, 0.9)][mastery_level(id)]
func mastery_title(id: String) -> String:
    return ["Новичок", "Бронза", "Серебро", "Мастер"][mastery_level(id)]
func record_match(won: bool, kills: int, deaths: int, seconds: float, hero_id: String) -> void:
    if not has_session() or Global.test_mode or Global.tools_used or _recorded_match_id == Global.match_id: return
    var p := profile.duplicate(true)
    var stats: Dictionary = p["stats"]
    stats["matches"] = int(stats["matches"]) + 1
    var key: String = "wins" if won else "losses"
    stats[key] = int(stats[key]) + 1
    stats["kills"] = int(stats["kills"]) + kills
    stats["deaths"] = int(stats["deaths"]) + deaths
    stats["play_time_sec"] = float(stats["play_time_sec"]) + seconds
    var heroes: Dictionary = stats["heroes"]
    heroes[hero_id] = int(heroes.get(hero_id, 0)) + 1
    if not p.has("mastery"): p["mastery"] = {}
    if hero_id in MatchBalance.PRIMARY_HEROES:
        p["mastery"][hero_id] = int(p["mastery"].get(hero_id, 0)) + 100 + (50 if won else 0)
    if is_guest:
        _guest_profile = p.duplicate(true)
    else:
        var result := backend.save_profile(p)
        if not result["ok"]:
            push_warning("Не удалось сохранить результат матча: " + str(result["error"]))
            return
        p = result["profile"]
    _recorded_match_id = Global.match_id
    profile = p
    profile_updated.emit(profile)
func _finish(action: String, result: Dictionary) -> Dictionary:
    if result["ok"]:
        if is_guest: _guest_profile = profile.duplicate(true)
        is_guest = false
        profile = result["profile"]
        session_changed.emit(profile)
    auth_result.emit(action, result)
    return result
func _on_game_over(winner_team: int) -> void:
    if not has_session() or Global.test_mode or Global.tools_used: return
    for node in get_tree().get_nodes_in_group("heroes"):
        if is_instance_valid(node) and node is BaseHero and node.is_player:
            record_match(node.team == winner_team, node.kills, node.deaths, Global.elapsed, node.hero_id)
            return
func authenticate_async(action: String, username: String, password: String) -> Dictionary:
    if _auth_busy or action not in ["register", "login"]: return AuthBackend.fail("Дождитесь завершения входа.")
    _auth_busy = true
    _auth_thread = Thread.new()
    var error := _auth_thread.start(Callable(backend, action).bind(username.strip_edges(), password))
    if error != OK:
        _auth_busy = false
        return AuthBackend.fail("Не удалось начать вход.")
    while _auth_thread.is_alive(): await get_tree().process_frame
    var result: Dictionary = _auth_thread.wait_to_finish()
    _auth_thread = null
    _auth_busy = false
    return _finish(action, result)
func _exit_tree() -> void:
    if _auth_thread != null and _auth_thread.is_started(): _auth_thread.wait_to_finish()
