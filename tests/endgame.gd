extends SceneTree
func _initialize() -> void:
    if OS.get_environment("THRONE_WARS_TEST") != "1":
        quit(2)
        return
    call_deferred("run")
func run() -> void:
    var global := root.get_node("Global")
    global.prematch_on = false
    global.tutorial_seen = true
    global.team_size = 2
    global.selected_hero = "ranger"
    global.fps_cap = 0
    var game = load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    global.elapsed = 600.0
    global.tools_used = true
    game.next_wave_in = 1.0e9
    for connection in global.request_pause.get_connections(): global.request_pause.disconnect(connection.callable)
    game.player.is_player = false
    game._add_bot(game.player, 1)
    var throne: Node
    for unit in global.units().duplicate():
        if unit.get_script().resource_path.ends_with("Building.gd") and unit.team == 1:
            if unit.is_throne: throne = unit
            elif unit.tier < 3:
                unit.invulnerable = false
                unit.take_damage(100000, null, "pure")
    for hero in global.heroes_of(0):
        hero.position = Vector3(120, 0, -120)
        hero.level = 12
        hero.recalc_stats()
        hero.hp = hero.max_hp
        hero.mp = hero.max_mp
        hero.gold = 10000
        for id in BuildGuide.items(hero.hero_id): hero.buy_item(id)
        hero.gold = 0
    for hero in global.heroes_of(1):
        hero.position = Vector3(-270, 0, -270)
        hero.set_physics_process(false)
    for bot in get_nodes_in_group("strategic_bots"):
        if bot.hero.team == 1: bot.set_physics_process(false)
        else:
            bot.mode = bot.Mode.LANE
            bot.task_kind = "push"
            bot.lane = 1
            bot._plan_at = global.elapsed + 1000
    for i in 5:
        var creep = load("res://scripts/Creep.gd").new()
        creep.team = 0
        creep.lane = 1
        creep.wave = 24
        creep.siege = true
        creep.position = Vector3(175 + i * 3, 0, -175)
        creep.goal_pos = global.throne_pos(1)
        game.add_child(creep)
    for frame in 5400:
        await physics_frame
        if global.is_over: break
    print("ENDGAME elapsed=", global.elapsed, " hero damage=", game.player.building_damage, " throne hp=", throne.hp if is_instance_valid(throne) else -1)
    assert(global.is_over, "A covered late-game siege failed to destroy T4 towers and finish the throne")
    print("PASS: actual map siege converts exposed T4 towers into a throne victory")
    quit()
