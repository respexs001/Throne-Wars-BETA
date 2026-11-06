extends SceneTree
const Kdf = preload("res://scripts/PasswordKdf.gd")
var ticks: int = 0
func _initialize() -> void:
    if OS.get_environment("THRONE_WARS_TEST") != "1":
        printerr("Use tools/test.py to isolate data.")
        quit(2)
        return
    call_deferred("run")
func _process(_delta: float) -> bool:
    ticks += 1
    return false
func check(ok: bool, message: String) -> void:
    if not ok:
        push_error(message)
        quit(1)
        assert(ok, message)
func run() -> void:
    var backend := LocalAuthBackend.new()
    # PBKDF2-HMAC-SHA256 reference vector (2 iterations, 32 bytes).
    check(Kdf.derive("password", "salt".to_utf8_buffer(), 2).hex_encode() == "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43", "PBKDF2 reference vector mismatch")
    check(AuthBackend.validate_password("short") != "", "Short password accepted")
    check(AuthBackend.validate_password("aaaaaaaaaaaaaaaaaaa") != "", "Repeated password accepted")
    check(AuthBackend.validate_password("Синие горы и тихая река 47") == "", "Unicode passphrase rejected")
    check(AuthBackend.validate_display_name("[url=evil]name") != "", "Markup name accepted")
    var fixture := ConfigFile.new()
    fixture.set_value("acct:legacy_user", "username", "Legacy_User")
    fixture.set_value("acct:legacy_user", "salt", "old-salt")
    fixture.set_value("acct:legacy_user", "hash", backend._legacy_hash("oldpass", "old-salt"))
    fixture.set_value("acct:legacy_user", "profile", {"display_name": "Legacy", "stats": {"wins": 7}})
    fixture.set_value("acct:service", "role", "admin")
    fixture.set_value("acct:service", "salt", "dde32da404d8a534b6d6bbc498cb805e")
    fixture.set_value("acct:service", "privileges", ["admin_console"])
    fixture.set_value("session", "last_account", "legacy_user")
    fixture.save("user://accounts.cfg")
    backend = LocalAuthBackend.new()
    check(not backend.restore_session()["ok"], "Stored name restored authentication")
    check(bool(backend._cfg.get_value("acct:service", "disabled", false)), "Legacy service account remains enabled")
    check(not backend._cfg.has_section_key("acct:service", "role"), "Legacy role retained")
    var result := backend.login("Legacy_User", "oldpass")
    check(result["ok"] and result["profile"]["stats"]["wins"] == 7, "Legacy account migration lost access or stats")
    check(backend._cfg.get_value("acct:legacy_user", "scheme", "") == "pbkdf2-sha256", "Legacy password not upgraded")
    print("PASS: KDF vector, password validation, service retirement, session revocation, legacy migration")
    var start := Time.get_ticks_msec()
    result = backend.register("New_Player", "Sapphire rivers under moonlight 47!")
    check(result["ok"], "Registration failed")
    check(not result["profile"].has("role") and not result["profile"].has("privileges"), "Authority leaked into profile")
    check(int(backend._cfg.get_value("acct:new_player", "iterations")) == 600000, "Unexpected KDF work factor")
    check(backend._cfg.get_value("acct:new_player", "salt") != backend._cfg.get_value("acct:legacy_user", "salt"), "Salt reused")
    var password_ms := Time.get_ticks_msec() - start
    backend.logout()
    check(not backend.save_profile(result["profile"])["ok"], "Unauthenticated profile write accepted")
    check(backend.login("new_player", "Sapphire rivers under moonlight 47!")["ok"], "Case-normalized login failed")
    check(not backend.save_profile({"username": "Legacy_User", "display_name": "Changed"})["ok"], "Cross-account profile write accepted")
    print("PASS: registration, unique salts, login, profile ownership; KDF registration time ms=", password_ms)
    check(not backend.login("new_player", "incorrect password value")["ok"], "Wrong password accepted")
    for i in 4:
        backend.login("bad!name", "wrong")
    backend = LocalAuthBackend.new()
    check(backend._check_lock() != "", "Restart bypassed lockout")
    print("PASS: failed credentials and persistent lockout")
    backend._clear_failures()
    var service := root.get_node("ProfileService")
    service.backend = backend
    var before := ticks
    result = await service.authenticate_async("register", "Async_Player", "Another moonlit passphrase 83!")
    check(result["ok"] and ticks - before > 2, "Async authentication blocked main loop or failed")
    print("PASS: asynchronous authentication keeps main loop responsive; frames=", ticks - before)
    var corrupt := FileAccess.open("user://accounts.cfg", FileAccess.WRITE)
    corrupt.store_string("[broken\ninvalid=true")
    corrupt.close()
    var blocked := LocalAuthBackend.new()
    check(not blocked.register("No_Overwrite", "A valid long passphrase 45")["ok"], "Corrupt account storage was overwritten")
    check(FileAccess.get_file_as_string("user://accounts.cfg") == "[broken\ninvalid=true", "Corrupt storage not preserved")
    print("PASS: malformed account storage fails closed without overwriting data")
    print("PASS: all account security regressions")
    quit()
