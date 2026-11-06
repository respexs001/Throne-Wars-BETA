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
    global.selected_hero = "titan"
    global.fps_cap = 0
    var game = load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    global.elapsed = 600.0
    global.tools_used = true
    game.next_wave_in = 1.0e9
    for connection in global.request_pause.get_connections(): global.request_pause.disconnect(connection.callable)
    var navigation = load("res://scripts/BotNavigation.gd")
    for id in MatchBalance.PRIMARY_HEROES:
        var sample = load("res://scripts/BaseHero.gd").new()
        sample.hero_id = id
        game.add_child(sample)
        sample.set_physics_process(false)
        for team in 2:
            for from in [Vector3(52, 0, -119), Vector3.ZERO, global.GUARDIAN_POS, Vector3(210, 0, 210), Vector3(-210, 0, -210)]:
                var route: Array = navigation.route(from, global.fountain_pos(team), sample.body_radius, game)
                assert(not route.is_empty(), "No fountain route for " + id + " team " + str(team) + " from " + str(from))
        sample.free()
    print("PASS: all four hero radii can route to both fountains from all map zones")
    var hero = game.player
    hero.position = Vector3(52, 0, -119)
    hero.max_hp = 10000
    hero.hp = hero.max_hp
    hero.inventory = ["", "", "", "", "", ""]
    hero.is_player = false
    game._add_bot(hero, 1)
    var shopper: Node
    for bot in get_nodes_in_group("strategic_bots"):
        if bot.hero == hero: shopper = bot
        else: bot.set_physics_process(false)
    for other in global.heroes_of(1): other.set_physics_process(false)
    hero.inventory = ["", "", "", "", "", ""]
    hero.gold = 2500
    shopper.mode = shopper.Mode.SHOP
    var arrived := false
    for frame in 5400:
        await physics_frame
        if global.flat_dist(hero.global_position, global.fountain_pos(0)) < 20 and hero.inventory.has("boots"):
            arrived = true
            break
    assert(arrived and hero.deaths == 0, "Titan failed to physically reach the fountain and buy without teleporting")
    print("PASS: Titan walks from the river to the real fountain and buys its build without teleporting")
    quit()
