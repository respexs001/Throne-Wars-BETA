class_name TalentDB
extends RefCounted
## TalentDB.gd — таланты героя: 4 яруса (уровни 10, 15, 20, 25), в каждом выбор из двух усилений. Наборы зависят от основного атрибута.

const LEVELS: Array = [10, 15, 20, 25]


static func tiers(primary: String) -> Array:
    match primary:
        "str":
            return [
                [{"name": "+250 к здоровью", "stats": {"hp": 250.0}}, {"name": "+20 к урону", "stats": {"dmg": 20.0}}],
                [{"name": "+6 к броне", "stats": {"armor": 6.0}}, {"name": "+8 к регенерации HP", "stats": {"hp_regen": 8.0}}],
                [{"name": "+25 к силе", "stats": {"str": 25.0}}, {"name": "+30 к скорости атаки", "stats": {"aspd": 30.0}}],
                [{"name": "+12% вампиризма", "stats": {"lifesteal": 0.12}}, {"name": "+20% сопротивления магии", "stats": {"mr": 0.2}}],
            ]
        "agi":
            return [
                [{"name": "+20 к скорости атаки", "stats": {"aspd": 20.0}}, {"name": "+15 к урону", "stats": {"dmg": 15.0}}],
                [{"name": "+1.5 к скорости бега", "stats": {"ms": 1.5}}, {"name": "+15% уклонения", "stats": {"evasion": 0.15}}],
                [{"name": "+25 к ловкости", "stats": {"agi": 25.0}}, {"name": "+20% шанс крита", "stats": {"crit": 0.2}}],
                [{"name": "+60 к скорости атаки", "stats": {"aspd": 60.0}}, {"name": "+30 к урону", "stats": {"dmg": 30.0}}],
            ]
    return [
        [{"name": "+250 к мане", "stats": {"mp": 250.0}}, {"name": "+150 к здоровью", "stats": {"hp": 150.0}}],
        [{"name": "+4 к регенерации маны", "stats": {"mp_regen": 4.0}}, {"name": "+12 к интеллекту", "stats": {"int": 12.0}}],
        [{"name": "+25 к интеллекту", "stats": {"int": 25.0}}, {"name": "+400 к здоровью", "stats": {"hp": 400.0}}],
        [{"name": "+500 к мане", "stats": {"mp": 500.0}}, {"name": "+40 к урону", "stats": {"dmg": 40.0}}],
    ]
