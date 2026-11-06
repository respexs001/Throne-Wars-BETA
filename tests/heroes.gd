extends SceneTree
func _initialize() -> void:
    if OS.get_environment("THRONE_WARS_TEST") != "1":
        quit(2)
        return
    call_deferred("run")
func run() -> void:
    var global := root.get_node("Global")
    global.clear_obstacles()
    global.volume = 0.0
    global.test_mode = true
    var hero_script = load("res://scripts/BaseHero.gd")
    var abilities = load("res://scripts/Abilities.gd")
    seed(2468)
    for id in MatchBalance.PRIMARY_HEROES:
        var definition := HeroDB.get_hero(id)
        for index in definition["abilities"].size():
            var arena := Node3D.new()
            root.add_child(arena)
            current_scene = arena
            var hero = hero_script.new()
            hero.hero_id = id
            hero.team = 0
            arena.add_child(hero)
            hero.set_physics_process(false)
            hero.position = Vector3.ZERO
            hero.ab_level[index] = 1
            hero.mp = 10000.0
            var enemy = hero_script.new()
            enemy.hero_id = "titan"
            enemy.team = 1
            arena.add_child(enemy)
            enemy.position = Vector3(6, 0, 0)
            enemy.set_physics_process(false)
            enemy.max_hp = 100000.0
            enemy.hp = enemy.max_hp
            global.invalidate_unit_cache()
            var ab: Dictionary = hero.abilities[index]
            var kind: String = ab["kind"]
            if kind == "p_dmg":
                assert(hero._passive_totals()["dmg"] > 0)
                assert(not hero.can_cast(index))
            elif kind == "p_illusion":
                for hit in 100: hero._on_attack_hit(enemy)
                assert(enemy.has_status("slow"))
                assert(get_nodes_in_group("illusions").size() > 0)
                assert(not hero.can_cast(index))
            else:
                var before: float = hero.mp
                assert(hero.cast_now(index, enemy, enemy.position), id + ": " + ab["name"])
                assert(hero.mp < before and hero.ab_cd[index] > 0)
                assert(not hero.cast_now(index, enemy, enemy.position), "Cooldown bypass")
                if kind == "blink":
                    assert(hero.position.distance_to(Vector3.ZERO) > 1)
                elif kind == "buff":
                    for buff in ab["buffs"]: assert(hero.has_status(buff))
                elif kind == "illusions":
                    assert(get_nodes_in_group("illusions").size() == 2)
                else:
                    if kind in ["proj_aoe", "proj_line", "zone"]:
                        for frame in 180: await physics_frame
                    assert(enemy.hp < enemy.max_hp, id + ": no damage from " + ab["name"])
                    if kind == "debuff":
                        for effect in ab["fx"]: assert(enemy.has_status(effect))
                    if kind == "stun_point": assert(enemy.has_status("stun"))
                    if kind == "nova" and ab.has("stun"): assert(enemy.has_status("stun"))
            print("PASS: ", id, " / ", ab["name"], " / ", kind)
            arena.free()
            await process_frame
    print("PASS: four primary heroes, every ability, costs, cooldowns and advertised effects")
    quit()
