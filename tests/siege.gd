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
    var own_tower = load("res://scripts/Building.gd").new()
    own_tower.team = 0
    own_tower.position = Vector3(-20, 0, 0)
    arena.add_child(own_tower)
    own_tower.hp = own_tower.max_hp * 0.3
    own_tower.set_physics_process(false)
    var enemy_creep = load("res://scripts/Creep.gd").new()
    enemy_creep.team = 1
    enemy_creep.position = own_tower.position
    arena.add_child(enemy_creep)
    enemy_creep.set_physics_process(false)
    var teammate = load("res://scripts/BaseHero.gd").new()
    teammate.team = 0
    teammate.position = Vector3(150, 0, 150)
    arena.add_child(teammate)
    teammate.set_physics_process(false)
    var defender = load("res://scripts/StrategicBot.gd").new()
    defender.hero = teammate
    arena.add_child(defender)
    defender.set_physics_process(false)
    defender.task_kind = "defend"
    defender.task_position = Vector3(150, 0, -150)
    defender.task_until = global.elapsed + 18
    bot._plan_objective()
    assert(bot.task_kind != "defend", "Both teammates abandoned siege for ordinary creep defense")
    defender.task_kind = "lane"
    bot._plan_at = 0
    bot._plan_objective()
    assert(bot.task_kind == "defend", "Unassigned endangered tower was ignored")
    print("PASS: obstacle-aware siege approach, attack order and actual building damage")
    print("PASS: one ordinary-wave defender preserves a teammate for proactive objectives")
    quit()
