# ThroneWars — архитектурные заметки (SignalBus)

## Правило
Событие эмитит тот, кто им владеет. Остальные системы подписываются на `SignalBus` и не вызываются из игровых классов напрямую.
Параметры сигналов типизированы как `Node`, а не `Unit`: автозагрузка не должна зависеть от `class_name` игровых скриптов.

## Эмиттеры
| Сигнал | Кто эмитит |
|---|---|
| `unit_died(unit, killer)` | `Unit._die()` (подписчик: `Global._on_unit_died` → награды) |
| `unit_damaged(target, attacker, amount)` | `Unit.take_damage()` (без тиков DoT) |
| `hero_spawned(hero)` / `hero_died(hero, killer)` | `BaseHero` (только настоящие герои, не иллюзии) |
| `day_night_changed(is_day)`, `rune_spawned(rune)` | `Main` |
| `game_state_changed("match_started" / "game_over")` | `Main`, `Global.end_game()` |

## Пока без эмиттеров
`gold_changed`, `item_purchased`, `talent_unlocked`, `shrine_captured`. Золото меняется напрямую в нескольких местах:
сначала нужна единая точка изменения (`BaseHero.change_gold()`), потом эмит.

## Дальше по плану
1. Единая точка изменения золота → `gold_changed`.
2. Общий `StateMachine`/`State` для `BotController` (сейчас `enum Mode`, ~20 присваиваний) и `Courier` (`state: int` 0/1/2).
3. Вынос из `Global` (≈990 строк): награды/статистика, эффекты (`spawn_*`, `float_text`, `sfx`), кэш юнитов и сетка, настройки.

## Аккаунты и профиль (подготовка к онлайну)
`ProfilePanel` (UI) → `ProfileService` (автозагрузка, сигналы `session_changed`, `profile_updated`, `auth_result`) → `AuthBackend` (контракт) → `LocalAuthBackend`.
- Данные: `user://accounts.cfg` (запись через временный файл + rename). Профиль: `player_id` (зарезервирован под серверный ID), `display_name`, `avatar`, `created_unix`, `stats`, версия схемы `v`.
- Для онлайна: `HttpAuthBackend` с теми же методами (`register`, `login`, `restore_session`, `logout`, `save_profile`), токен сессии хранить вне профиля. Сетевые вызовы асинхронны, поэтому UI уже работает на сигналах сервиса.
- Валидацию (`AuthBackend.validate_*`) сервер обязан повторять. Статистика сейчас считается клиентом и подделываема: при появлении сервера результат матча должен подтверждаться им.
- Сейчас засчитывается только игра в основном режиме; тест героя и брошенные матчи не учитываются.
