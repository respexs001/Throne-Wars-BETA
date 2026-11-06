class_name HeroDB
extends RefCounted
## HeroDB.gd — база данных героев: атрибуты, модель, способности (по уровням). 12 героев, у каждого есть ульта.
## Порядок способностей: обычные (Q W E D F), последняя в списке - ульта (R). Два героя (Archmage, Dragonknight) имеют по 6.

static var _cache: Array = []


static func all() -> Array:
    if _cache.is_empty():
        _cache = _build()
    return _cache


static func get_hero(id: String) -> Dictionary:
    for h in all():
        if h["id"] == id:
            return h
    return all()[0]


static func _a(aname: String, kind: String, target: String, d: Dictionary) -> Dictionary:
    var r: Dictionary = {"name": aname, "kind": kind, "target": target}
    r.merge(d)
    return r


static func _build() -> Array:
    var fire := Color(1.0, 0.45, 0.1)
    var ice := Color(0.5, 0.85, 1.0)
    var bolt := Color(1.0, 0.95, 0.3)
    var arc := Color(0.7, 0.4, 1.0)
    var holy := Color(1.0, 0.95, 0.6)
    var blood := Color(0.9, 0.2, 0.2)
    var shade := Color(0.5, 0.2, 0.8)
    var green := Color(0.4, 1.0, 0.4)
    return [
        {"id": "titan", "name": "Titan", "role": "Танк / инициатор", "primary": "str", "melee": true,
         "str": 27.0, "agi": 13.0, "int": 14.0, "str_gain": 3.4, "agi_gain": 1.5, "int_gain": 1.4,
         "base_dmg": 22.0, "armor": 1.0, "ms": 7.6, "bat": 1.75, "range": 2.2, "attack_point": 0.35,
         "model": {"scale": 1.15, "build": "bulky", "body": Color(0.5, 0.38, 0.3), "accent": Color(0.9, 0.72, 0.3), "skin": Color(0.85, 0.65, 0.5), "weapon": "hammer", "hat": "horns", "pauldron": "spiked", "face": "beard", "beard_color": Color(0.45, 0.3, 0.2), "boots": Color(0.25, 0.2, 0.18), "emblem": Color(1.0, 0.8, 0.3), "aura": Color(0.7, 0.5, 0.25)},
         "abilities": [
            _a("Thunder Slam", "stun_point", "point", {"icon": "bolt", "desc": "Удар молнии по области: урон и оглушение.", "range": 8.0, "radius": 3.5, "color": bolt,
                "dmg": [90.0, 150.0, 210.0, 270.0], "stun": [1.2, 1.5, 1.8, 2.1], "mana": [75.0, 85.0, 95.0, 105.0], "cd": [12.0, 11.0, 10.0, 9.0]}),
            _a("Battle Rage", "buff", "none", {"icon": "fang", "desc": "+урон и скорость на время.", "color": blood, "dur": [6.0, 7.0, 8.0, 9.0],
                "buffs": {"rage": [0.25, 0.35, 0.45, 0.55], "haste": [0.1, 0.12, 0.14, 0.16]}, "mana": [50.0, 55.0, 60.0, 65.0], "cd": [18.0, 17.0, 16.0, 15.0]}),
            _a("Iron Skin", "buff", "none", {"icon": "shield", "desc": "Щит и броня.", "color": Color(0.8, 0.8, 0.9), "dur": 8.0,
                "buffs": {"shield": [150.0, 250.0, 350.0, 450.0], "armor": [3.0, 4.0, 5.0, 6.0]}, "mana": [60.0, 65.0, 70.0, 75.0], "cd": [20.0, 19.0, 18.0, 17.0]}),
            _a("Earthquake", "nova", "none", {"icon": "nova", "desc": "УЛЬТА: землетрясение вокруг героя, урон, оглушение и замедление.", "radius": 9.0, "color": Color(0.7, 0.5, 0.3),
                "dmg": [200.0, 320.0, 440.0], "stun": [1.4, 1.8, 2.2], "slow": 0.4, "slow_dur": 3.0, "mana": [150.0, 200.0, 250.0], "cd": [80.0, 70.0, 60.0]}),
         ]},
        {"id": "pyro", "name": "Pyromancer", "role": "Маг / нюкер", "primary": "int", "melee": false,
         "str": 18.0, "agi": 15.0, "int": 28.0, "str_gain": 2.0, "agi_gain": 1.8, "int_gain": 3.4,
         "base_dmg": 20.0, "armor": -0.5, "ms": 7.3, "bat": 1.7, "range": 11.0, "proj_speed": 24.0, "attack_point": 0.4,
         "model": {"scale": 1.0, "build": "slim", "body": Color(0.8, 0.28, 0.12), "accent": Color(1.0, 0.65, 0.2), "skin": Color(0.9, 0.75, 0.6), "weapon": "staff", "hat": "cone", "cape": true, "hair": "long", "hair_color": Color(1.0, 0.5, 0.15), "orbs": 2, "orb_color": Color(1.0, 0.5, 0.1), "emblem": Color(1.0, 0.6, 0.15), "aura": Color(1.0, 0.45, 0.1), "boots": Color(0.35, 0.12, 0.08)},
         "abilities": [
            _a("Fireball", "proj_aoe", "point", {"icon": "fire", "desc": "Огненный шар: урон по области.", "range": 20.0, "radius": 5.0, "speed": 24.0, "color": fire,
                "dmg": [100.0, 170.0, 240.0, 310.0], "mana": [90.0, 100.0, 110.0, 120.0], "cd": [8.0, 7.5, 7.0, 6.5]}),
            _a("Blink", "blink", "point", {"icon": "dash", "desc": "Телепорт в точку.", "color": arc, "range": [8.0, 10.0, 12.0, 14.0], "mana": 45.0, "cd": [14.0, 13.0, 12.0, 11.0]}),
            _a("Inferno Blast", "debuff", "unit", {"icon": "meteor", "desc": "Цель горит: урон и поджог.", "range": 13.0, "color": fire, "dmg": [60.0, 100.0, 140.0, 180.0], "dur": 4.0,
                "fx": {"burn": [20.0, 32.0, 44.0, 56.0]}, "mana": [70.0, 75.0, 80.0, 85.0], "cd": 11.0}),
            _a("Mana Barrier", "buff", "none", {"icon": "orb", "desc": "Магический щит.", "color": arc, "dur": 8.0, "buffs": {"shield": [120.0, 200.0, 280.0, 360.0]}, "mana": 60.0, "cd": [22.0, 21.0, 20.0, 19.0]}),
            _a("Meteor Storm", "zone", "point", {"icon": "meteor", "desc": "УЛЬТА: метеориты с неба по области, урон и оглушение.", "range": 18.0, "radius": 7.0, "delay": 1.1, "zdur": 3.0, "tick": 1.0, "color": fire,
                "dmg": [180.0, 260.0, 340.0], "stun": [0.8, 1.0, 1.2], "mana": [180.0, 230.0, 280.0], "cd": [90.0, 80.0, 70.0]}),
         ]},
        {"id": "shade", "name": "Shade", "role": "Ассасин", "primary": "agi", "melee": true,
         "str": 19.0, "agi": 26.0, "int": 14.0, "str_gain": 2.1, "agi_gain": 3.2, "int_gain": 1.4,
         "base_dmg": 22.0, "armor": 0.0, "ms": 8.2, "bat": 1.6, "range": 2.0, "attack_point": 0.3,
         "model": {"scale": 1.0, "build": "slim", "body": Color(0.14, 0.14, 0.2), "accent": Color(0.55, 0.25, 0.85), "skin": Color(0.75, 0.7, 0.8), "weapon": "dagger", "hat": "hood", "cape": true, "eyes": Color(0.8, 0.3, 1.0), "face": "mask", "pauldron": "plate", "boots": Color(0.08, 0.08, 0.12), "aura": Color(0.5, 0.2, 0.8), "emblem": Color(0.7, 0.3, 1.0)},
         "abilities": [
            _a("Shadow Step", "dash", "unit", {"icon": "dash", "desc": "Прыжок к цели: урон и короткое оглушение.", "range": [10.0, 12.0, 14.0, 16.0], "color": shade, "dmg": [70.0, 120.0, 170.0, 220.0],
                "stun": [0.4, 0.5, 0.6, 0.7], "mana": [60.0, 65.0, 70.0, 75.0], "cd": [11.0, 10.0, 9.0, 8.0]}),
            _a("Venom Dart", "debuff", "unit", {"icon": "fang", "desc": "Яд и замедление цели.", "range": 13.0, "color": green, "dmg": [40.0, 70.0, 100.0, 130.0], "dur": [5.0, 6.0, 7.0, 8.0],
                "fx": {"poison": [18.0, 28.0, 38.0, 48.0], "slow": [0.25, 0.3, 0.35, 0.4]}, "mana": 55.0, "cd": 9.0}),
            _a("Shadow Cloak", "buff", "none", {"icon": "eye", "desc": "Скорость и уклонение.", "color": shade, "dur": 5.0,
                "buffs": {"haste": [0.2, 0.25, 0.3, 0.35], "evasion": [0.3, 0.4, 0.5, 0.6]}, "mana": 50.0, "cd": [18.0, 17.0, 16.0, 15.0]}),
            _a("Death Mark", "execute", "unit", {"icon": "skull", "desc": "УЛЬТА: чистый урон + % от недостающего здоровья цели.", "range": 11.0, "color": blood,
                "dmg": [150.0, 250.0, 350.0], "pct": [0.25, 0.35, 0.45], "mana": [120.0, 160.0, 200.0], "cd": [60.0, 50.0, 40.0]}),
         ]},
        {"id": "ranger", "name": "Ranger", "role": "Дальний керри", "primary": "agi", "melee": false,
         "str": 18.0, "agi": 24.0, "int": 16.0, "str_gain": 1.9, "agi_gain": 3.0, "int_gain": 1.7,
         "base_dmg": 21.0, "armor": 0.0, "ms": 7.7, "bat": 1.6, "range": 14.0, "proj_speed": 30.0, "attack_point": 0.3,
         "model": {"scale": 1.0, "build": "slim", "body": Color(0.25, 0.45, 0.25), "accent": Color(0.85, 0.75, 0.3), "skin": Color(0.85, 0.7, 0.55), "weapon": "bow", "hat": "hood", "cape": true, "hair": "short", "hair_color": Color(0.35, 0.22, 0.1), "pauldron": "round", "boots": Color(0.3, 0.2, 0.1), "aura": Color(0.4, 0.8, 0.3)},
         "abilities": [
            _a("Powershot", "proj_line", "point", {"icon": "arrow", "desc": "Мощный выстрел по прямой, бьёт всех на пути.", "range": 30.0, "width": 2.5, "speed": 40.0, "color": Color(1.0, 1.0, 0.7),
                "dmg": [110.0, 180.0, 250.0, 320.0], "mana": [90.0, 95.0, 100.0, 105.0], "cd": 9.0}),
            _a("Frost Arrow", "debuff", "unit", {"icon": "ice", "desc": "Ледяная стрела: урон и замедление.", "range": 15.0, "color": ice, "dmg": [30.0, 60.0, 90.0, 120.0], "dur": 3.0,
                "fx": {"slow": [0.3, 0.4, 0.5, 0.6]}, "mana": 40.0, "cd": 5.0}),
            _a("Windrun", "buff", "none", {"icon": "wind", "desc": "Ветер: скорость и уклонение.", "color": Color(0.7, 1.0, 0.8), "dur": 4.0,
                "buffs": {"haste": [0.3, 0.35, 0.4, 0.45], "evasion": [0.6, 0.7, 0.8, 0.9]}, "mana": 50.0, "cd": [16.0, 15.0, 14.0, 13.0]}),
            _a("Trueshot", "p_dmg", "passive", {"icon": "eye", "desc": "Пассивно: +урон.", "val": [10.0, 20.0, 30.0, 40.0]}),
            _a("Arrow Rain", "zone", "point", {"icon": "arrow", "desc": "УЛЬТА: ливень стрел, урон и замедление.", "range": 20.0, "radius": 8.0, "delay": 0.3, "zdur": 5.0, "tick": 0.5, "color": Color(0.9, 0.9, 0.6),
                "dmg": [60.0, 90.0, 120.0], "slow": 0.4, "mana": [170.0, 210.0, 250.0], "cd": [80.0, 70.0, 60.0]}),
         ]},
        {"id": "warden", "name": "Warden", "role": "Паладин / поддержка", "primary": "str", "melee": true,
         "str": 25.0, "agi": 15.0, "int": 17.0, "str_gain": 3.0, "agi_gain": 1.7, "int_gain": 1.8,
         "base_dmg": 22.0, "armor": 2.0, "ms": 7.5, "bat": 1.7, "range": 2.2, "attack_point": 0.35,
         "model": {"scale": 1.08, "build": "bulky", "body": Color(0.7, 0.7, 0.78), "accent": Color(0.9, 0.75, 0.3), "skin": Color(0.9, 0.75, 0.6), "weapon": "sword", "hat": "helmet", "cape": true, "plume": Color(0.85, 0.2, 0.2), "shield": true, "pauldron": "round", "emblem": Color(1.0, 0.85, 0.35), "aura": Color(1.0, 0.85, 0.35), "boots": Color(0.45, 0.45, 0.5)},
         "abilities": [
            _a("Smite", "debuff", "unit", {"icon": "star", "desc": "Кара: урон и безмолвие.", "range": 10.0, "color": holy, "dmg": [100.0, 160.0, 220.0, 280.0], "dur": [2.0, 2.5, 3.0, 3.5],
                "fx": {"silence": 1.0}, "mana": [80.0, 85.0, 90.0, 95.0], "cd": 10.0}),
            _a("Divine Shield", "buff", "none", {"icon": "shield", "desc": "Щит и регенерация.", "color": holy, "dur": 6.0,
                "buffs": {"shield": [150.0, 250.0, 350.0, 450.0], "regen_pct": [0.01, 0.015, 0.02, 0.025]}, "mana": 70.0, "cd": [18.0, 17.0, 16.0, 15.0]}),
            _a("Aura of Courage", "p_armor", "passive", {"icon": "heart", "desc": "Пассивно: +броня.", "val": [2.0, 3.0, 4.0, 5.0]}),
            _a("Judgement", "nova", "none", {"icon": "nova", "desc": "УЛЬТА: суд вокруг героя, урон, оглушение и лечение себя.", "radius": 8.0, "color": holy,
                "dmg": [250.0, 400.0, 550.0], "stun": 1.0, "heal_pct": 0.5, "mana": [150.0, 200.0, 250.0], "cd": [90.0, 80.0, 70.0]}),
         ]},
        {"id": "cryo", "name": "Cryomancer", "role": "Маг контроля", "primary": "int", "melee": false,
         "str": 17.0, "agi": 14.0, "int": 27.0, "str_gain": 1.9, "agi_gain": 1.6, "int_gain": 3.3,
         "base_dmg": 19.0, "armor": 0.0, "ms": 7.2, "bat": 1.7, "range": 10.5, "proj_speed": 22.0, "attack_point": 0.4,
         "model": {"scale": 1.0, "build": "mid", "body": Color(0.5, 0.75, 0.95), "accent": Color(0.9, 0.95, 1.0), "skin": Color(0.85, 0.9, 1.0), "weapon": "wand", "hat": "crown", "eyes": Color(0.4, 0.9, 1.0), "hair": "long", "hair_color": Color(0.85, 0.95, 1.0), "orbs": 3, "orb_color": Color(0.6, 0.9, 1.0), "wings": Color(0.7, 0.9, 1.0), "aura": Color(0.5, 0.85, 1.0), "emblem": Color(0.6, 0.95, 1.0)},
         "abilities": [
            _a("Ice Shard", "proj_line", "point", {"icon": "ice", "desc": "Ледяная глыба: урон и замедление по линии.", "range": 22.0, "width": 2.5, "speed": 30.0, "color": ice,
                "dmg": [90.0, 150.0, 210.0, 270.0], "slow": [0.3, 0.35, 0.4, 0.45], "slow_dur": 2.5, "mana": [80.0, 85.0, 90.0, 95.0], "cd": 8.0}),
            _a("Frostbite", "debuff", "unit", {"icon": "ice", "desc": "Цель вмерзает: урон и обездвиживание.", "range": 11.0, "color": ice, "dmg": [60.0, 100.0, 140.0, 180.0], "dur": [1.5, 2.0, 2.5, 3.0],
                "fx": {"root": 1.0}, "mana": [90.0, 95.0, 100.0, 105.0], "cd": 10.0}),
            _a("Glacial Armor", "buff", "none", {"icon": "shield", "desc": "Ледяной щит и броня.", "color": ice, "dur": 8.0, "buffs": {"shield": [100.0, 180.0, 260.0, 340.0], "armor": [3.0, 4.0, 5.0, 6.0]}, "mana": 65.0, "cd": [20.0, 19.0, 18.0, 17.0]}),
            _a("Blizzard", "zone", "point", {"icon": "ice", "desc": "УЛЬТА: буря: урон и сильное замедление в области.", "range": 18.0, "radius": 9.0, "delay": 0.4, "zdur": 7.0, "tick": 0.75, "color": ice,
                "dmg": [70.0, 105.0, 140.0], "slow": 0.45, "mana": [200.0, 260.0, 320.0], "cd": [100.0, 90.0, 80.0]}),
         ]},
        {"id": "berserker", "name": "Berserker", "role": "Силовой керри", "primary": "str", "melee": true,
         "str": 29.0, "agi": 18.0, "int": 12.0, "str_gain": 3.5, "agi_gain": 2.0, "int_gain": 1.2,
         "base_dmg": 24.0, "armor": 0.5, "ms": 7.8, "bat": 1.7, "range": 2.2, "attack_point": 0.35,
         "model": {"scale": 1.15, "build": "bulky", "body": Color(0.6, 0.25, 0.2), "accent": Color(0.9, 0.5, 0.2), "skin": Color(0.8, 0.55, 0.4), "weapon": "axe", "hat": "horns", "eyes": Color(1.0, 0.3, 0.2), "hair": "mohawk", "hair_color": Color(0.8, 0.15, 0.1), "face": "beard", "beard_color": Color(0.5, 0.2, 0.1), "pauldron": "spiked", "aura": Color(0.9, 0.2, 0.15), "emblem": Color(1.0, 0.3, 0.2)},
         "abilities": [
            _a("Savage Leap", "leap", "point", {"icon": "dash", "desc": "Прыжок: урон и оглушение при приземлении.", "range": [9.0, 10.0, 11.0, 12.0], "radius": 3.0, "color": blood,
                "dmg": [70.0, 120.0, 170.0, 220.0], "stun": [0.8, 1.0, 1.2, 1.4], "mana": 70.0, "cd": [12.0, 11.0, 10.0, 9.0]}),
            _a("Bloodlust", "buff", "none", {"icon": "fang", "desc": "+урон и скорость.", "color": blood, "dur": 8.0, "buffs": {"rage": [0.2, 0.3, 0.4, 0.5], "haste": [0.15, 0.2, 0.25, 0.3]}, "mana": 45.0, "cd": [18.0, 17.0, 16.0, 15.0]}),
            _a("Thick Skin", "p_regen", "passive", {"icon": "heart", "desc": "Пассивно: регенерация здоровья.", "val": [2.0, 4.0, 6.0, 8.0]}),
            _a("Axe Throw", "debuff", "unit", {"icon": "axe", "desc": "Бросок топора: урон и замедление.", "range": 12.0, "color": Color(0.8, 0.8, 0.85), "dmg": [80.0, 130.0, 180.0, 230.0], "dur": 2.5,
                "fx": {"slow": 0.5}, "mana": 60.0, "cd": 9.0}),
            _a("Rampage", "buff", "none", {"icon": "skull", "desc": "УЛЬТА: вампиризм, огромный урон, иммунитет к магии.", "color": blood, "dur": [10.0, 12.0, 14.0],
                "buffs": {"rage": [0.5, 0.7, 0.9], "lifesteal": [0.3, 0.45, 0.6], "haste": 0.2, "immune": 1.0}, "mana": [100.0, 120.0, 140.0], "cd": [90.0, 80.0, 70.0]}),
         ]},
        {"id": "storm", "name": "Stormcaller", "role": "Маг / AoE", "primary": "int", "melee": false,
         "str": 19.0, "agi": 15.0, "int": 26.0, "str_gain": 2.0, "agi_gain": 1.6, "int_gain": 3.2,
         "base_dmg": 20.0, "armor": 0.0, "ms": 7.4, "bat": 1.7, "range": 11.0, "proj_speed": 26.0, "attack_point": 0.4,
         "model": {"scale": 1.0, "build": "mid", "body": Color(0.25, 0.3, 0.7), "accent": Color(1.0, 0.95, 0.3), "skin": Color(0.85, 0.75, 0.65), "weapon": "staff", "hat": "hood", "eyes": Color(1.0, 0.95, 0.3), "hair": "short", "hair_color": Color(0.5, 0.7, 1.0), "orbs": 3, "orb_color": Color(1.0, 0.95, 0.3), "emblem": Color(1.0, 0.95, 0.3), "aura": Color(1.0, 0.95, 0.3), "pauldron": "plate"},
         "abilities": [
            _a("Chain Lightning", "chain", "unit", {"icon": "chain", "desc": "Молния перепрыгивает между врагами.", "range": 14.0, "color": bolt, "bounces": [3.0, 4.0, 5.0, 6.0], "falloff": 0.85,
                "dmg": [90.0, 140.0, 190.0, 240.0], "mana": [90.0, 95.0, 100.0, 105.0], "cd": 9.0}),
            _a("Static Silence", "silence_point", "point", {"icon": "bolt", "desc": "Разряд: урон и безмолвие в области.", "range": 16.0, "radius": 5.0, "color": bolt,
                "dmg": [50.0, 80.0, 110.0, 140.0], "dur": [2.0, 2.5, 3.0, 3.5], "mana": 80.0, "cd": 14.0}),
            _a("Thunder Clap", "nova", "none", {"icon": "nova", "desc": "Хлопок грома: урон и замедление вокруг.", "radius": 7.0, "color": bolt,
                "dmg": [80.0, 130.0, 180.0, 230.0], "slow": 0.35, "slow_dur": 3.0, "mana": 75.0, "cd": 10.0}),
            _a("Overcharge", "p_aspd", "passive", {"icon": "bolt", "desc": "Пассивно: +скорость атаки.", "val": [20.0, 35.0, 50.0, 65.0]}),
            _a("Thunderstorm", "zone", "point", {"icon": "bolt", "desc": "УЛЬТА: гроза, молнии бьют область 6 секунд.", "range": 14.0, "radius": 10.0, "delay": 0.4, "zdur": 6.0, "tick": 0.6, "color": bolt,
                "dmg": [60.0, 90.0, 120.0], "mana": [200.0, 250.0, 300.0], "cd": [90.0, 80.0, 70.0]}),
         ]},
        {"id": "archmage", "name": "Archmage", "role": "Верховный маг (6 способностей)", "primary": "int", "melee": false,
         "str": 18.0, "agi": 12.0, "int": 30.0, "str_gain": 1.9, "agi_gain": 1.4, "int_gain": 3.6,
         "base_dmg": 18.0, "armor": -1.0, "ms": 7.0, "bat": 1.75, "range": 10.0, "proj_speed": 22.0, "attack_point": 0.45,
         "model": {"scale": 1.02, "build": "mid", "body": Color(0.4, 0.2, 0.6), "accent": Color(0.9, 0.6, 1.0), "skin": Color(0.9, 0.8, 0.75), "weapon": "staff", "hat": "cone", "cape": true, "eyes": Color(0.8, 0.5, 1.0), "face": "beard", "beard_color": Color(0.92, 0.92, 0.95), "orbs": 4, "orb_color": Color(0.8, 0.5, 1.0), "emblem": Color(0.9, 0.6, 1.0), "aura": Color(0.7, 0.4, 1.0)},
         "abilities": [
            _a("Arcane Bolt", "debuff", "unit", {"icon": "orb", "desc": "Магический снаряд: большой урон.", "range": 15.0, "color": arc, "dmg": [100.0, 170.0, 240.0, 310.0], "dur": 0.1, "fx": {}, "mana": 80.0, "cd": 6.0}),
            _a("Rune Prison", "debuff", "unit", {"icon": "gem", "desc": "Цель в клетке: оглушение.", "range": 13.0, "color": arc, "dmg": 40.0, "dur": [1.6, 2.0, 2.4, 2.8], "fx": {"stun": 1.0}, "mana": 100.0, "cd": 14.0}),
            _a("Mana Shield", "buff", "none", {"icon": "orb", "desc": "Щит.", "color": arc, "dur": 10.0, "buffs": {"shield": [150.0, 250.0, 350.0, 450.0]}, "mana": 60.0, "cd": 20.0}),
            _a("Time Warp", "nova", "none", {"icon": "nova", "desc": "Искажение времени: замедляет всех рядом.", "radius": 10.0, "color": Color(0.5, 0.8, 1.0), "dmg": 50.0, "slow": 0.6, "slow_dur": [2.0, 3.0, 4.0, 5.0], "mana": 90.0, "cd": 16.0}),
            _a("Overload", "buff", "none", {"icon": "orb", "desc": "Перегрузка: +урон и скорость атаки.", "color": arc, "dur": 8.0, "buffs": {"rage": [0.25, 0.35, 0.45, 0.55], "aspd": [30.0, 50.0, 70.0, 90.0]}, "mana": 70.0, "cd": 22.0}),
            _a("Cataclysm", "zone", "point", {"icon": "meteor", "desc": "УЛЬТА: катаклизм - огромный урон и оглушение в большой области.", "range": 20.0, "radius": 10.0, "delay": 1.5, "zdur": 4.0, "tick": 1.0, "color": arc,
                "dmg": [300.0, 450.0, 600.0], "stun": 1.5, "mana": [250.0, 350.0, 450.0], "cd": [120.0, 110.0, 100.0]}),
         ]},
        {"id": "dragon", "name": "Dragonknight", "role": "Рыцарь-дракон (6 способностей)", "primary": "str", "melee": true,
         "str": 26.0, "agi": 16.0, "int": 16.0, "str_gain": 3.1, "agi_gain": 1.8, "int_gain": 1.7,
         "base_dmg": 23.0, "armor": 1.5, "ms": 7.5, "bat": 1.7, "range": 2.4, "attack_point": 0.35,
         "model": {"scale": 1.12, "build": "bulky", "body": Color(0.2, 0.5, 0.35), "accent": Color(0.95, 0.75, 0.2), "skin": Color(0.45, 0.65, 0.4), "weapon": "spear", "hat": "helmet", "cape": true, "eyes": Color(1.0, 0.6, 0.1), "plume": Color(1.0, 0.5, 0.1), "tail": true, "tail_color": Color(0.2, 0.5, 0.35), "wings": Color(0.2, 0.55, 0.35), "pauldron": "spiked", "emblem": Color(1.0, 0.6, 0.15), "aura": Color(0.5, 0.9, 0.3)},
         "abilities": [
            _a("Fire Breath", "cone", "point", {"icon": "fire", "desc": "Дыхание огня конусом.", "range": 12.0, "angle": 60.0, "color": fire, "dmg": [100.0, 170.0, 240.0, 310.0], "mana": 85.0, "cd": 9.0}),
            _a("Dragon Skin", "buff", "none", {"icon": "shield", "desc": "Броня и щит.", "color": green, "dur": 8.0, "buffs": {"armor": [4.0, 6.0, 8.0, 10.0], "shield": [100.0, 180.0, 260.0, 340.0]}, "mana": 60.0, "cd": 18.0}),
            _a("Tail Sweep", "nova", "none", {"icon": "nova", "desc": "Удар хвостом: урон и оглушение рядом.", "radius": 5.0, "color": green, "dmg": [70.0, 110.0, 150.0, 190.0], "stun": [0.6, 0.8, 1.0, 1.2], "mana": 70.0, "cd": 11.0}),
            _a("Dragon Blood", "p_regen", "passive", {"icon": "heart", "desc": "Пассивно: регенерация.", "val": [3.0, 5.0, 7.0, 9.0]}),
            _a("Dragon Dive", "leap", "point", {"icon": "dash", "desc": "Пикирование: урон и оглушение.", "range": 12.0, "radius": 4.0, "color": fire, "dmg": [90.0, 150.0, 210.0, 270.0], "stun": 0.6, "mana": 80.0, "cd": 14.0}),
            _a("Elder Dragon Form", "buff", "none", {"icon": "crown", "desc": "УЛЬТА: превращение в дракона - рост, урон и щит.", "color": fire, "dur": [16.0, 20.0, 24.0], "grow": 1.4,
                "buffs": {"rage": [0.4, 0.6, 0.8], "shield": [300.0, 500.0, 700.0], "haste": 0.1, "armor": 6.0}, "mana": [150.0, 200.0, 250.0], "cd": [110.0, 100.0, 90.0]}),
         ]},
        {"id": "luna", "name": "Moon Priestess", "role": "Жрица / нюкер", "primary": "int", "melee": false,
         "str": 17.0, "agi": 18.0, "int": 24.0, "str_gain": 1.9, "agi_gain": 2.0, "int_gain": 3.0,
         "base_dmg": 20.0, "armor": 0.0, "ms": 7.6, "bat": 1.6, "range": 10.0, "proj_speed": 24.0, "attack_point": 0.35,
         "model": {"scale": 0.98, "build": "slim", "body": Color(0.85, 0.85, 0.95), "accent": Color(0.6, 0.7, 1.0), "skin": Color(0.95, 0.9, 0.95), "weapon": "wand", "hat": "crown", "cape": true, "eyes": Color(0.6, 0.8, 1.0), "hair": "long", "hair_color": Color(0.85, 0.88, 1.0), "wings": Color(0.9, 0.93, 1.0), "orbs": 2, "orb_color": Color(0.85, 0.9, 1.0), "aura": Color(0.7, 0.8, 1.0), "emblem": Color(0.7, 0.8, 1.0)},
         "abilities": [
            _a("Moonbeam", "debuff", "unit", {"icon": "moon", "desc": "Лунный луч: урон по цели.", "range": 15.0, "color": Color(0.8, 0.9, 1.0), "dmg": [90.0, 150.0, 210.0, 270.0], "dur": 0.1, "fx": {}, "mana": 75.0, "cd": 7.0}),
            _a("Lunar Blessing", "buff", "none", {"icon": "moon", "desc": "+скорость и скорость атаки.", "color": Color(0.8, 0.9, 1.0), "dur": 8.0, "buffs": {"haste": [0.15, 0.2, 0.25, 0.3], "aspd": [20.0, 30.0, 40.0, 50.0]}, "mana": 50.0, "cd": 16.0}),
            _a("Mist", "silence_point", "point", {"icon": "wind", "desc": "Туман: безмолвие и урон.", "range": 15.0, "radius": 5.0, "color": Color(0.7, 0.8, 1.0), "dmg": 40.0, "dur": [1.5, 2.0, 2.5, 3.0], "mana": 70.0, "cd": 13.0}),
            _a("Eclipse", "zone", "point", {"icon": "moon", "desc": "УЛЬТА: затмение - лунные лучи бьют область 5 секунд.", "range": 14.0, "radius": 9.0, "delay": 0.4, "zdur": 5.0, "tick": 0.5, "color": Color(0.8, 0.9, 1.0),
                "dmg": [55.0, 80.0, 105.0], "mana": [180.0, 230.0, 280.0], "cd": [90.0, 80.0, 70.0]}),
         ]},
        {"id": "wind", "name": "Windwalker", "role": "Мастер боевых искусств", "primary": "agi", "melee": true,
         "str": 20.0, "agi": 25.0, "int": 14.0, "str_gain": 2.2, "agi_gain": 3.1, "int_gain": 1.4,
         "base_dmg": 23.0, "armor": 0.0, "ms": 8.4, "bat": 1.5, "range": 1.9, "attack_point": 0.25,
         "model": {"scale": 1.0, "build": "slim", "body": Color(0.9, 0.55, 0.15), "accent": Color(1.0, 0.9, 0.5), "skin": Color(0.85, 0.65, 0.5), "weapon": "fists", "hat": "band", "hair": "short", "hair_color": Color(0.9, 0.4, 0.1), "boots": Color(0.5, 0.25, 0.1), "gloves": Color(1.0, 0.85, 0.4), "emblem": Color(1.0, 0.9, 0.4), "aura": Color(1.0, 0.85, 0.3)},
         "abilities": [
            _a("Whirlwind", "nova", "none", {"icon": "wind", "desc": "Вихрь: урон и замедление вокруг.", "radius": 5.0, "color": Color(1.0, 0.9, 0.6), "dmg": [80.0, 130.0, 180.0, 230.0], "slow": 0.4, "slow_dur": 2.0, "mana": 60.0, "cd": 8.0}),
            _a("Dash", "blink", "point", {"icon": "dash", "desc": "Рывок вперёд.", "color": Color(1.0, 0.9, 0.6), "range": [9.0, 11.0, 13.0, 15.0], "mana": 35.0, "cd": 12.0}),
            _a("Counter Stance", "buff", "none", {"icon": "shield", "desc": "Уклонение и броня.", "color": Color(1.0, 0.8, 0.3), "dur": 5.0, "buffs": {"evasion": [0.4, 0.55, 0.7, 0.85], "armor": [2.0, 3.0, 4.0, 5.0]}, "mana": 55.0, "cd": 16.0}),
            _a("Concussion", "p_bash", "passive", {"icon": "fang", "desc": "Пассивно: шанс оглушить ударом.", "chance": [0.15, 0.2, 0.25, 0.3], "dur": 0.8, "dmg": [20.0, 30.0, 40.0, 50.0]}),
            _a("Thousand Strikes", "nova", "none", {"icon": "star", "desc": "УЛЬТА: шквал ударов вокруг героя - огромный урон и оглушение.", "radius": 6.0, "color": Color(1.0, 0.7, 0.2),
                "dmg": [450.0, 700.0, 950.0], "stun": 1.0, "dtype": "phys", "mana": [150.0, 200.0, 250.0], "cd": [70.0, 60.0, 50.0]}),
         ]},
    
        {"id": "smugr", "name": "Смугр", "role": "Иллюзионист / ловкач", "primary": "agi", "melee": true,
         "str": 19.0, "agi": 24.0, "int": 18.0, "str_gain": 2.0, "agi_gain": 3.2, "int_gain": 1.8,
         "base_dmg": 24.0, "armor": 2.0, "ms": 8.1, "bat": 1.5, "range": 2.1, "attack_point": 0.28,
         "model": {"scale": 1.0, "build": "slim", "body": Color(0.55, 0.2, 0.75), "accent": Color(0.85, 0.4, 1.0), "skin": Color(0.75, 0.65, 0.85), "weapon": "daggers", "hat": "hood", "cape": true, "eyes": Color(0.9, 0.3, 1.0), "hair": "short", "hair_color": Color(0.3, 0.1, 0.4), "aura": Color(0.7, 0.3, 0.9), "emblem": Color(0.8, 0.4, 1.0)},
         "abilities": [
            _a("Mirror Image", "illusions", "none", {"icon": "star", "desc": "Зеркальная копия: создает 2 иллюзии на 18 сек.", "count": 2, "dur": 18.0, "dmg_deal": [0.25, 0.35, 0.45, 0.55], "dmg_take": 2.5, "mana": 85.0, "cd": [24.0, 22.0, 20.0, 18.0]}),
            _a("Phantom Shift", "blink", "point", {"icon": "dash", "desc": "Призрачный шаг: телепорт в выбранную точку.", "range": [11.0, 13.0, 15.0, 17.0], "color": Color(0.7, 0.3, 0.9), "mana": 65.0, "cd": 12.0}),
            _a("Deceptive Blade", "p_illusion", "passive", {"icon": "fang", "desc": "Пассивно: шанс 25% замедлить врага и призвать иллюзию.", "chance": 0.25, "slow": 0.3, "dur": 6.0}),
            _a("Illusion Chaos", "nova", "none", {"icon": "crown", "desc": "УЛЬТА: всплеск зеркальной энергии наносит магический урон врагам вокруг.", "radius": 12.0, "color": Color(0.8, 0.3, 1.0), "dmg": [200.0, 350.0, 500.0], "blind": 0.5, "mana": [150.0, 200.0, 250.0], "cd": [90.0, 80.0, 70.0]}),
         ]},
]
