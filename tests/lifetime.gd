extends SceneTree
func _initialize() -> void:
    if OS.get_environment("THRONE_WARS_TEST") != "1":
        printerr("Use tools/test.py to isolate data.")
        quit(2)
        return
    call_deferred("run")
func run() -> void:
    var settings := root.get_node("Global")
    settings.prematch_on = false
    settings.team_size = 1
    settings.selected_hero = "smugr"
    settings.fps_cap = 0
    var game = load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    var abilities = load("res://scripts/Abilities.gd")
    var ill = abilities.spawn_illusion(game.player, 18.0, 0.3, 2.5, game.player.position)
    var before: Array = settings.units().duplicate()
    assert(before.has(ill))
    ill.free()
    assert(settings._unit_frame == -1, "Removing a unit did not invalidate its cache")
    for unit in settings.units():
        assert(is_instance_valid(unit), "Freed unit remained cached in the same frame")
    settings.heroes_of(0)
    var reinforcement = game._make_hero("ranger", 0, false, 0, 1)
    assert(settings.heroes_of(0).has(reinforcement), "New hero missing from same-frame cache")
    reinforcement.free()
    for unit in settings.heroes_of(0):
        assert(is_instance_valid(unit), "Freed hero remained cached")
    print("PASS: same-frame creation/removal invalidates unit, spatial and hero caches")
    var fog = load("res://scripts/FogManager.gd").new()
    game.add_child(fog)
    # Reproduce the exact old failure, even with an independently stale snapshot.
    settings.units()
    settings._unit_cache = before
    settings._unit_frame = Engine.get_physics_frames()
    settings._unit_pframe = Engine.get_process_frames()
    fog._process(0.2)
    settings.invalidate_unit_cache()
    print("PASS: fog rejects a freed-object entry before attempting its Unit cast")
    for cycle in 30:
        var copies: Array = []
        for i in 3:
            copies.append(abilities.spawn_illusion(game.player, 0.05, 0.3, 2.5, game.player.position + Vector3(i * 3, 0, 0)))
        settings.units()
        for copy in copies:
            copy.dismiss()
        await process_frame
        await process_frame
        for unit in settings.units():
            assert(is_instance_valid(unit))
        fog._process(0.2)
    print("PASS: 90 Smugr illusions repeatedly replaced and freed with fog active")
    quit()
