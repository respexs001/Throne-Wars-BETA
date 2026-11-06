class_name AuthBackend
extends RefCounted
## AuthBackend.gd — контракт бэкенда аккаунтов.
## Сейчас есть только LocalAuthBackend (аккаунты на устройстве). Для онлайна достаточно написать
## HttpAuthBackend с теми же методами и подменить его в ProfileService._make_backend().
## Каждый метод возвращает {"ok": bool, "error": String, "profile": Dictionary}.
## Валидация общая (static): сервер обязан повторять её у себя, клиентской проверке верить нельзя.

const USERNAME_MIN: int = 3
const USERNAME_MAX: int = 16
const PASSWORD_MIN: int = 10
const PASSWORD_MAX: int = 128
const DISPLAY_MIN: int = 2
const DISPLAY_MAX: int = 20


static func validate_username(username: String) -> String:
    if username.length() < USERNAME_MIN or username.length() > USERNAME_MAX:
        return "Логин: от %d до %d символов." % [USERNAME_MIN, USERNAME_MAX]
    var re := RegEx.new()
    re.compile("^[A-Za-z0-9_]+$")
    if re.search(username) == null:
        return "Логин: только латиница, цифры и «_»."
    return ""


static func validate_password(password: String) -> String:
    if password.length() < PASSWORD_MIN or password.length() > PASSWORD_MAX:
        return "Пароль: от %d до %d символов." % [PASSWORD_MIN, PASSWORD_MAX]
    if password.strip_edges().is_empty():
        return "Пароль не может состоять только из пробелов."
    var unique: Dictionary = {}
    for i in password.length():
        var code := password.unicode_at(i)
        if code < 32 or code == 127:
            return "Пароль не должен содержать управляющие символы."
        unique[code] = true
    if unique.size() < 4:
        return "Выберите менее предсказуемый пароль или длинную фразу."
    if password.to_lower() in ["passwordpassword", "123456789012345", "qwertyuiopasdfgh", "letmeinletmeinletmein"]:
        return "Этот пароль слишком распространён. Выберите другой."
    return ""


static func validate_display_name(text: String) -> String:
    var t := text.strip_edges()
    if t.length() < DISPLAY_MIN or t.length() > DISPLAY_MAX:
        return "Ник: от %d до %d символов." % [DISPLAY_MIN, DISPLAY_MAX]
    for i in t.length():
        if t.unicode_at(i) < 32 or t[i] in ["[", "]"]:
            return "Ник не должен содержать разметку или управляющие символы."
    return ""


static func fail(message: String) -> Dictionary:
    return {"ok": false, "error": message, "profile": {}}


static func success(profile: Dictionary = {}) -> Dictionary:
    return {"ok": true, "error": "", "profile": profile}


# ---------- контракт (переопределяется в наследниках) ----------
func register(_username: String, _password: String) -> Dictionary:
    return fail("Регистрация не поддерживается.")


func login(_username: String, _password: String) -> Dictionary:
    return fail("Вход не поддерживается.")


func restore_session() -> Dictionary:
    return fail("")


func logout() -> void:
    pass


func save_profile(_profile: Dictionary) -> Dictionary:
    return fail("Сохранение не поддерживается.")
