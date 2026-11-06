extends SceneTree
func _initialize() -> void:
    if OS.get_environment("THRONE_WARS_TEST") != "1":
        quit(2)
        return
    call_deferred("run")
func run() -> void:
    var global := root.get_node("Global")
    global.reset_stats()
    global.elapsed = 60.0
    global.clear_obstacles()
    var arena := Node3D.new()
    root.add_child(arena)
    current_scene = arena
    var hero = load("res://scripts/BaseHero.gd").new()
    hero.team = 0
    hero.hero_id = "titan"
    arena.add_child(hero)
    global.player_hero = hero
    var tower = load("res://scripts/Building.gd").new()
    tower.team = 1
    tower.lane = 0
    tower.position = Vector3(25, 0, 0)
    arena.add_child(tower)
    tower.set_physics_process(false)
    for i in 2:
        var creep = load("res://scripts/Creep.gd").new()
        creep.team = 0
        creep.position = Vector3(25, 0, 15 + i * 5)
        arena.add_child(creep)
        creep.set_physics_process(false)
    global.add_obstacle(Vector3(10, 0, 0), 3.0)
    var bot = load("res://scripts/StrategicBot.gd").new()
    bot.hero = hero
    bot.lane = 0
    arena.add_child(bot)
    bot.set_physics_process(false)
    bot.task_kind = "push"
    bot._ratio = 1.0
    for frame in 900:
        if frame % 12 == 0: bot._execute_objective()
        await physics_frame
        if hero.building_damage > 0: break
    assert(hero.building_damage > 0, "Bot failed to route around an obstacle and damage a covered tower")
    assert(tower.hp < tower.max_hp)
    print("PASS: obstacle-aware siege approach, attack order and actual building damage")
    quit()
