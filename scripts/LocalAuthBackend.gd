class_name LocalAuthBackend
extends AuthBackend
## Device-local accounts only. Local files cannot establish trusted online identity.
const PATH: String = "user://accounts.cfg"
const TMP_PATH: String = "user://accounts.tmp"
const SCHEMA: int = 3
const Kdf = preload("res://scripts/PasswordKdf.gd")
const MAX_FAILS: int = 5
var _cfg := ConfigFile.new()
var _authenticated: String = ""
var _storage_error: bool = false

func _init() -> void:
    var load_error := _cfg.load(PATH)
    if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
        _storage_error = true
        return
    var changed: bool = false
    for section in _cfg.get_sections():
        if not section.begins_with("acct:"):
            continue
        # Retire the old built-in service credential; preserve its profile data.
        if String(_cfg.get_value(section, "role", "")) == "admin" and String(_cfg.get_value(section, "salt", "")) == "dde32da404d8a534b6d6bbc498cb805e":
            _cfg.set_value(section, "disabled", true)
            changed = true
        for key in ["role", "privileges"]:
            if _cfg.has_section_key(section, key):
                _cfg.erase_section_key(section, key)
                changed = true
        var p: Dictionary = _cfg.get_value(section, "profile", {})
        if p.has("role") or p.has("privileges"):
            p.erase("role")
            p.erase("privileges")
            _cfg.set_value(section, "profile", p)
            changed = true
    for section in ["session", "system"]:
        if _cfg.has_section(section):
            _cfg.erase_section(section)
            changed = true
    if changed:
        _flush()

func register(username: String, password: String) -> Dictionary:
    if _storage_error:
        return fail("Файл аккаунтов недоступен. Данные не перезаписаны.")
    var locked := _check_lock()
    if locked != "":
        return fail(locked)
    var error := validate_username(username)
    if error == "":
        error = validate_password(password)
    if error != "":
        return fail(error)
    var section := _section(username)
    if _cfg.has_section(section):
        _record_failure()
        return fail("Не удалось создать аккаунт с этим логином. Выберите другой.")
    var salt := Crypto.new().generate_random_bytes(32)
    if salt.size() != 32:
        return fail("Не удалось создать аккаунт. Попробуйте ещё раз.")
    var profile := _new_profile(username)
    _cfg.set_value(section, "username", username)
    _store_hash(section, salt, Kdf.derive(password, salt))
    _cfg.set_value(section, "profile", profile)
    if not _flush():
        _cfg.erase_section(section)
        return fail("Не удалось сохранить аккаунт.")
    _authenticated = section
    _clear_failures()
    return success(profile)

func login(username: String, password: String) -> Dictionary:
    if _storage_error:
        return fail("Файл аккаунтов недоступен. Данные не перезаписаны.")
    var locked := _check_lock()
    if locked != "":
        return fail(locked)
    if validate_username(username) != "" or password.is_empty() or password.length() > PASSWORD_MAX:
        _record_failure()
        return fail("Неверный логин или пароль.")
    var section := _section(username)
    var exists := _cfg.has_section(section) and not bool(_cfg.get_value(section, "disabled", false))
    var scheme: String = _cfg.get_value(section, "scheme", "") if exists else "pbkdf2-sha256"
    var stored: String = _cfg.get_value(section, "hash", "") if exists else "00".repeat(32)
    var salt_text: String = _cfg.get_value(section, "salt", "") if exists else "00".repeat(32)
    var rounds: int = int(_cfg.get_value(section, "iterations", Kdf.ITERATIONS)) if exists else Kdf.ITERATIONS
    var legacy: bool = exists and scheme == ""
    var valid_hash: bool = stored.length() == 64 and stored.is_valid_hex_number(false)
    var valid_record := valid_hash and (legacy or (scheme == "pbkdf2-sha256" and salt_text.length() == 64 and salt_text.is_valid_hex_number(false) and rounds >= Kdf.ITERATIONS and rounds <= 1000000))
    var salt := Crypto.new().generate_random_bytes(32) if legacy or not valid_record else salt_text.hex_decode()
    var candidate := Kdf.derive(password, salt, rounds if valid_record and not legacy else Kdf.ITERATIONS)
    var verified := _equal(_legacy_hash(password, salt_text), stored) if legacy else Crypto.new().constant_time_compare(stored.hex_decode() if valid_hash else PackedByteArray(), candidate)
    if not exists or not valid_record or not verified:
        _record_failure()
        return fail("Неверный логин или пароль.")
    if legacy:
        var old_record: Dictionary = {}
        for key in ["salt", "hash", "scheme", "iterations"]:
            if _cfg.has_section_key(section, key):
                old_record[key] = _cfg.get_value(section, key)
        _store_hash(section, salt, candidate)
        if not _flush():
            for key in ["salt", "hash", "scheme", "iterations"]:
                if old_record.has(key):
                    _cfg.set_value(section, key, old_record[key])
                else:
                    _cfg.erase_section_key(section, key)
            return fail("Не удалось обновить защиту аккаунта. Повторите вход.")
    _authenticated = section
    _clear_failures()
    return success(_read_profile(section))

func restore_session() -> Dictionary:
    # A stored account name is not proof of authentication.
    return fail("")

func logout() -> void:
    _authenticated = ""

func save_profile(profile: Dictionary) -> Dictionary:
    var section := _section(String(profile.get("username", "")))
    if _authenticated == "" or section != _authenticated:
        return fail("Сначала войдите в этот аккаунт.")
    var error := validate_display_name(String(profile.get("display_name", "")))
    if error != "":
        return fail(error)
    var clean := profile.duplicate(true)
    clean.erase("role")
    clean.erase("privileges")
    clean["display_name"] = String(clean["display_name"]).strip_edges()
    var previous: Dictionary = _cfg.get_value(section, "profile", {})
    _cfg.set_value(section, "profile", clean)
    if not _flush():
        _cfg.set_value(section, "profile", previous)
        return fail("Не удалось сохранить профиль.")
    return success(clean)

func _section(username: String) -> String:
    return "acct:" + username.strip_edges().to_lower()

func _store_hash(section: String, salt: PackedByteArray, digest: PackedByteArray) -> void:
    _cfg.set_value(section, "salt", salt.hex_encode())
    _cfg.set_value(section, "hash", digest.hex_encode())
    _cfg.set_value(section, "scheme", "pbkdf2-sha256")
    _cfg.set_value(section, "iterations", Kdf.ITERATIONS)

func _check_lock() -> String:
    var remaining := int(_cfg.get_value("security", "locked_until", 0)) - int(Time.get_unix_time_from_system())
    return "Слишком много попыток. Подождите %d с." % remaining if remaining > 0 else ""

func _record_failure() -> void:
    var failures := int(_cfg.get_value("security", "failures", 0)) + 1
    if failures >= MAX_FAILS:
        var level := mini(4, int(_cfg.get_value("security", "lock_level", 0)) + 1)
        _cfg.set_value("security", "locked_until", int(Time.get_unix_time_from_system()) + 30 * (1 << (level - 1)))
        _cfg.set_value("security", "lock_level", level)
        failures = 0
    _cfg.set_value("security", "failures", failures)
    _flush()

func _clear_failures() -> void:
    _cfg.set_value("security", "failures", 0)
    _cfg.set_value("security", "lock_level", 0)
    _cfg.set_value("security", "locked_until", 0)
    _flush()

func _legacy_hash(password: String, salt: String) -> String:
    var pw := password.to_utf8_buffer()
    var digest := (salt + ":").to_utf8_buffer()
    var ctx := HashingContext.new()
    for i in 5000:
        ctx.start(HashingContext.HASH_SHA256)
        ctx.update(digest + pw)
        digest = ctx.finish()
    return digest.hex_encode()

func _equal(a: String, b: String) -> bool:
    return Crypto.new().constant_time_compare(a.to_utf8_buffer(), b.to_utf8_buffer())

func _empty_stats() -> Dictionary:
    return {"matches": 0, "wins": 0, "losses": 0, "kills": 0, "deaths": 0, "play_time_sec": 0.0, "heroes": {}}

func _new_profile(username: String) -> Dictionary:
    return {"v": SCHEMA, "player_id": Crypto.new().generate_random_bytes(16).hex_encode(), "username": username, "display_name": username, "avatar": 0, "mastery": {}, "created_unix": int(Time.get_unix_time_from_system()), "stats": _empty_stats()}

func _read_profile(section: String) -> Dictionary:
    var username: String = _cfg.get_value(section, "username", "")
    var stored: Dictionary = _cfg.get_value(section, "profile", {})
    var p := _new_profile(username)
    for key in ["player_id", "display_name", "avatar", "created_unix"]:
        if stored.has(key):
            p[key] = stored[key]
    var old_mastery = stored.get("mastery", {})
    if old_mastery is Dictionary:
        for hero_id in MatchBalance.PRIMARY_HEROES:
            p["mastery"][hero_id] = maxi(0, int(old_mastery.get(hero_id, 0)))
    var old_stats: Dictionary = stored.get("stats", {})
    for key in p["stats"]:
        if old_stats.has(key):
            p["stats"][key] = old_stats[key]
    return p

func _flush() -> bool:
    if _cfg.save(TMP_PATH) != OK:
        return false
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP_PATH), ProjectSettings.globalize_path(PATH)) == OK
