class_name Biome
extends RefCounted
## Biome.gd — ландшафты: цвета земли, деревьев, камней, воды, неба и погоды. Выбор в Настройки - Ландшафт.

const ORDER: Array = ["forest", "autumn", "winter", "desert", "volcano", "swamp"]


static func cfg(id: String) -> Dictionary:
    var d: Dictionary = {
        "name": "Зелёный лес", "ground_a": Color(0.17, 0.36, 0.14), "ground_b": Color(0.34, 0.52, 0.2),
        "detail_a": Color(0.6, 0.6, 0.6), "detail_b": Color(1.0, 1.0, 1.0),
        "dirt_a": Color(0.45, 0.33, 0.2), "dirt_b": Color(0.64, 0.5, 0.33), "shore": Color(0.62, 0.57, 0.4), "rock": Color(0.5, 0.5, 0.52),
        "rock_a": Color(0.22, 0.2, 0.2), "rock_b": Color(0.42, 0.4, 0.4), "rock_tint_a": Color(0.3, 0.3, 0.3), "rock_tint_b": Color(0.55, 0.55, 0.58),
        "grass_a": Color(0.22, 0.5, 0.14), "grass_b": Color(0.42, 0.7, 0.24),
        "pine_a": Color(0.05, 0.24, 0.12), "pine_b": Color(0.12, 0.38, 0.2), "round_a": Color(0.16, 0.42, 0.1), "round_b": Color(0.34, 0.56, 0.15),
        "round_alt": Color(0.8, 0.45, 0.1), "trunk": Color(0.28, 0.18, 0.1), "pine_ratio": 0.65, "density": 1.0,
        "prop": "bush", "prop_color": Color(0.2, 0.5, 0.15), "prop_glow": 0.0, "prop_count": 300,
        "water_deep": Color(0.03, 0.3, 0.4), "water_shallow": Color(0.25, 0.64, 0.7), "water_alpha": 0.9, "water_glow": 0.0, "water_speed": 1.0,
        "sky_top": Color(0.25, 0.5, 0.85), "sky_horizon": Color(0.7, 0.8, 0.92), "fog": Color(0.7, 0.8, 0.9), "fog_mult": 1.0,
        "weather": "rain", "amp": 2.5,
    }
    var o: Dictionary = {}
    match id:
        "autumn":
            o = {"name": "Осенний лес", "ground_a": Color(0.36, 0.3, 0.12), "ground_b": Color(0.55, 0.4, 0.15), "shore": Color(0.55, 0.5, 0.35),
                "grass_a": Color(0.5, 0.4, 0.12), "grass_b": Color(0.75, 0.5, 0.15), "pine_a": Color(0.1, 0.28, 0.14), "pine_b": Color(0.2, 0.4, 0.15),
                "round_a": Color(0.75, 0.35, 0.1), "round_b": Color(0.9, 0.65, 0.15), "round_alt": Color(0.7, 0.15, 0.1), "pine_ratio": 0.3,
                "prop_color": Color(0.8, 0.4, 0.1), "sky_top": Color(0.35, 0.5, 0.75), "sky_horizon": Color(0.9, 0.75, 0.55), "fog": Color(0.85, 0.75, 0.6)}
        "winter":
            o = {"name": "Зима", "ground_a": Color(0.82, 0.86, 0.9), "ground_b": Color(0.95, 0.97, 1.0), "dirt_a": Color(0.55, 0.5, 0.45), "dirt_b": Color(0.7, 0.66, 0.6),
                "shore": Color(0.8, 0.88, 0.95), "rock": Color(0.55, 0.58, 0.65), "rock_a": Color(0.4, 0.42, 0.5), "rock_b": Color(0.7, 0.74, 0.82),
                "rock_tint_a": Color(0.6, 0.64, 0.7), "rock_tint_b": Color(0.85, 0.88, 0.95), "grass_a": Color(0.7, 0.8, 0.85), "grass_b": Color(0.9, 0.95, 1.0),
                "pine_a": Color(0.75, 0.85, 0.9), "pine_b": Color(0.95, 0.98, 1.0), "round_a": Color(0.6, 0.7, 0.78), "round_b": Color(0.82, 0.88, 0.95),
                "round_alt": Color(0.7, 0.8, 0.9), "trunk": Color(0.2, 0.15, 0.12), "pine_ratio": 0.8, "density": 0.8, "prop": "crystal",
                "prop_color": Color(0.5, 0.85, 1.0), "prop_glow": 1.5, "prop_count": 120, "water_deep": Color(0.55, 0.75, 0.88), "water_shallow": Color(0.88, 0.96, 1.0),
                "water_alpha": 0.97, "water_speed": 0.0, "sky_top": Color(0.45, 0.6, 0.8), "sky_horizon": Color(0.85, 0.9, 0.95), "fog": Color(0.85, 0.9, 0.95),
                "fog_mult": 1.6, "weather": "snow", "amp": 4.0}
        "desert":
            o = {"name": "Пустыня", "ground_a": Color(0.74, 0.6, 0.35), "ground_b": Color(0.88, 0.76, 0.48), "dirt_a": Color(0.55, 0.4, 0.25), "dirt_b": Color(0.7, 0.55, 0.35),
                "shore": Color(0.85, 0.75, 0.5), "rock": Color(0.6, 0.45, 0.32), "rock_a": Color(0.45, 0.32, 0.22), "rock_b": Color(0.7, 0.55, 0.4),
                "rock_tint_a": Color(0.55, 0.4, 0.3), "rock_tint_b": Color(0.78, 0.62, 0.45), "grass_a": Color(0.6, 0.55, 0.25), "grass_b": Color(0.8, 0.7, 0.3),
                "pine_a": Color(0.5, 0.45, 0.2), "pine_b": Color(0.65, 0.55, 0.25), "round_a": Color(0.55, 0.5, 0.2), "round_b": Color(0.7, 0.6, 0.25),
                "round_alt": Color(0.4, 0.5, 0.2), "trunk": Color(0.4, 0.3, 0.2), "pine_ratio": 0.4, "density": 0.35, "prop": "cactus",
                "prop_color": Color(0.2, 0.5, 0.25), "prop_count": 240, "water_deep": Color(0.1, 0.4, 0.5), "water_shallow": Color(0.4, 0.75, 0.75), "water_alpha": 0.85,
                "sky_top": Color(0.35, 0.6, 0.9), "sky_horizon": Color(0.95, 0.85, 0.65), "fog": Color(0.95, 0.85, 0.7), "fog_mult": 1.4, "weather": "sand", "amp": 6.0}
        "volcano":
            o = {"name": "Вулкан", "ground_a": Color(0.14, 0.12, 0.12), "ground_b": Color(0.28, 0.22, 0.2), "dirt_a": Color(0.18, 0.14, 0.12), "dirt_b": Color(0.32, 0.25, 0.22),
                "shore": Color(0.25, 0.2, 0.2), "rock": Color(0.15, 0.13, 0.13), "rock_a": Color(0.1, 0.09, 0.09), "rock_b": Color(0.3, 0.25, 0.22),
                "rock_tint_a": Color(0.15, 0.13, 0.13), "rock_tint_b": Color(0.35, 0.28, 0.25), "grass_a": Color(0.3, 0.15, 0.08), "grass_b": Color(0.5, 0.22, 0.1),
                "pine_a": Color(0.1, 0.08, 0.08), "pine_b": Color(0.22, 0.14, 0.1), "round_a": Color(0.2, 0.12, 0.1), "round_b": Color(0.4, 0.15, 0.08),
                "round_alt": Color(0.8, 0.3, 0.1), "trunk": Color(0.1, 0.08, 0.07), "pine_ratio": 0.5, "density": 0.55, "prop": "lava",
                "prop_color": Color(1.0, 0.4, 0.1), "prop_glow": 2.0, "prop_count": 160, "water_deep": Color(0.55, 0.08, 0.0), "water_shallow": Color(1.0, 0.5, 0.1),
                "water_alpha": 1.0, "water_glow": 2.0, "water_speed": 0.6, "sky_top": Color(0.25, 0.1, 0.1), "sky_horizon": Color(0.9, 0.35, 0.15),
                "fog": Color(0.5, 0.2, 0.12), "fog_mult": 2.0, "weather": "ash", "amp": 5.0}
        "swamp":
            o = {"name": "Болото", "ground_a": Color(0.12, 0.2, 0.1), "ground_b": Color(0.25, 0.32, 0.15), "dirt_a": Color(0.22, 0.2, 0.12), "dirt_b": Color(0.34, 0.3, 0.18),
                "shore": Color(0.2, 0.28, 0.18), "rock": Color(0.3, 0.35, 0.28), "rock_a": Color(0.18, 0.22, 0.17), "rock_b": Color(0.35, 0.4, 0.3),
                "rock_tint_a": Color(0.25, 0.3, 0.24), "rock_tint_b": Color(0.4, 0.45, 0.35), "grass_a": Color(0.15, 0.32, 0.12), "grass_b": Color(0.3, 0.5, 0.18),
                "pine_a": Color(0.06, 0.18, 0.14), "pine_b": Color(0.12, 0.3, 0.2), "round_a": Color(0.14, 0.28, 0.1), "round_b": Color(0.28, 0.42, 0.14),
                "round_alt": Color(0.4, 0.5, 0.2), "trunk": Color(0.2, 0.15, 0.1), "pine_ratio": 0.4, "density": 1.2, "prop": "reed",
                "prop_color": Color(0.4, 0.55, 0.2), "prop_count": 400, "water_deep": Color(0.1, 0.2, 0.1), "water_shallow": Color(0.3, 0.45, 0.2),
                "water_alpha": 0.92, "water_glow": 0.15, "water_speed": 0.5, "sky_top": Color(0.3, 0.4, 0.45), "sky_horizon": Color(0.65, 0.75, 0.6),
                "fog": Color(0.5, 0.62, 0.5), "fog_mult": 2.2, "weather": "rain", "amp": 1.2}
    d.merge(o, true)
    return d
