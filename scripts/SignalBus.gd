extends Node
## SignalBus.gd — Глобальная шина сигналов (Event Bus).

## Контракт: сигналы эмитит владелец события, слушают любые системы. Типы Node (а не Unit) — чтобы
## автозагрузка не зависела от class_name игровых скриптов (нет циклических ссылок).
##   unit_died        — Unit._die(): любая смерть (награды и статистика слушают Global).
##   hero_spawned     — BaseHero._after_ready(): настоящий герой (не иллюзия).
##   hero_died        — BaseHero._on_death(): смерть настоящего героя.
##   unit_damaged     — Unit.take_damage(): прошедший урон (без тиков DoT).
##   day_night_changed, rune_spawned — Main.
##   game_state_changed — Main/Global: "match_started", "game_over".
## Пока без эмиттеров: gold_changed, item_purchased, talent_unlocked, shrine_captured.

signal unit_died(unit: Node, killer: Node)
signal hero_spawned(hero: Node)
signal hero_died(hero: Node, killer: Node)
signal unit_damaged(target: Node, attacker: Node, amount: float)
signal gold_changed(team: int, amount: int)
signal item_purchased(hero: Node, item_id: String)
signal talent_unlocked(hero: Node, talent_id: String)
signal game_state_changed(state_name: String)
signal day_night_changed(is_day: bool)
signal shrine_captured(shrine: Node, team: int)
signal rune_spawned(rune: Node)
signal player_movement_ordered(hero: Node)
signal item_used(hero: Node, item_id: String)
