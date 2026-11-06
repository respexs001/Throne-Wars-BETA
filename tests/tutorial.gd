extends SceneTree
func _initialize() -> void:
    if OS.get_environment("THRONE_WARS_TEST") != "1":
        quit(2)
        return
    call_deferred("run")
func run() -> void:
    var global := root.get_node("Global")
    global.prematch_on = false
    global.tutorial_seen = false
    global.selected_hero = "smugr"
    global.team_size = 2
    global.fps_cap = 0
    var game = load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    var guide: Node
    var controller: Node
    for child in game.get_children():
        if child.get_script() == load("res://scripts/FirstMatchGuide.gd"): guide = child
        if child.get_script() == load("res://scripts/PlayerController.gd"): controller = child
    assert(guide != null and controller != null)
    for connection in global.request_pause.get_connections(): global.request_pause.disconnect(connection.callable)
    paused = false
    for frame in 150: await physics_frame
    assert(guide.step == 0, "Automatic lane movement skipped the movement lesson")
    global.clear_obstacles()
    controller._o_move(game.player.position + Vector3(30, 0, 0), false)
    for frame in 180: await physics_frame
    assert(guide.step == 1, "Actual player movement was not recognized")
    var enemy = load("res://scripts/BaseHero.gd").new()
    enemy.team = 1
    game.add_child(enemy)
    enemy.position = game.player.position + Vector3(4, 0, 0)
    enemy.set_physics_process(false)
    enemy.take_damage(20, game.player, "pure")
    for frame in 3: await process_frame
    assert(guide.step == 2)
    assert(game.player.learn_ability(0))
    assert(game.player.cast_now(0, null, game.player.position))
    for frame in 3: await process_frame
    assert(guide.step == 3)
    assert(game.player.buy_item("health_potion"))
    assert(game.player.use_item(game.player.inventory.find("health_potion"), game.player.position))
    for frame in 3: await process_frame
    assert(guide.step == 4, "Consumed item use was missed")
    for unit in global.units():
        if unit.get_script().resource_path.ends_with("Building.gd") and unit.team == 1 and unit.tier == 0:
            unit.take_damage(50, game.player, "pure")
            break
    for frame in 3: await process_frame
    assert(global.tutorial_seen and not is_instance_valid(guide))
    print("PASS: all five tutorial steps, no automatic movement skip, consumed item and completion saved")
    quit()
