class_name BuildGuide
extends RefCounted
const GUIDES: Dictionary = {
    "titan": [
        {"name": "Передовая", "tip": "Выдерживайте урон и открывайте бой для союзника.", "items": ["boots", "bulwark", "battle_boots", "titan_plate", "bkb", "heart"]},
        {"name": "Натиск", "tip": "Догоняйте изолированные цели и давите башни с волной.", "items": ["boots", "battle_boots", "warlord_blade", "crystalys", "bkb", "heart"]}],
    "pyro": [
        {"name": "Вспышка", "tip": "Короткие атаки способностями; берегите путь отступления.", "items": ["boots", "arcane_orb", "dagon", "blink_dagger", "bkb", "mage_cloak"]},
        {"name": "Долгий бой", "tip": "Запас маны и защита для повторных применений заклинаний.", "items": ["boots", "arcane_orb", "mage_cloak", "battle_boots", "titan_plate", "bkb"]}],
    "ranger": [
        {"name": "Меткий выстрел", "tip": "Урон с дистанции. Стойте за союзником и крипами.", "items": ["boots", "battle_boots", "warlord_blade", "crystalys", "butterfly", "bkb"]},
        {"name": "Живучесть", "tip": "Сохраните дистанцию и переживите первый вражеский натиск.", "items": ["boots", "battle_boots", "bulwark", "mage_cloak", "butterfly", "bkb"]}],
    "smugr": [
        {"name": "Зеркальный натиск", "tip": "Давите копиями и заходите на ослабленного противника.", "items": ["boots", "battle_boots", "warlord_blade", "crystalys", "butterfly", "bkb"]},
        {"name": "Скользящая тень", "tip": "Выходите из опасности рывком и возвращайтесь после восстановления.", "items": ["boots", "battle_boots", "bulwark", "mage_cloak", "butterfly", "bkb"]}],
}
static func choices(id: String) -> Array:
    return GUIDES.get(id, [{"name": "Базовая", "tip": "Экспериментальный герой.", "items": ["boots", "battle_boots", "bulwark", "warlord_blade", "bkb", "heart"]}])
static func items(id: String, choice: int = 0) -> Array:
    var options := choices(id)
    return options[clampi(choice, 0, options.size() - 1)]["items"]
