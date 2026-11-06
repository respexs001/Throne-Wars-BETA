extends SceneTree
var game: Node
var settings: Node
var random_seed: int = 1
var limit: float = 1200.0
var mode: String = "match"
var output: String = "user://autoplay.json"
var total: float = 0.0
var checkpoint: float = 0.0
var next_illusion: float = 2.0
var completed: int = 0
var copies: int = 0
var first_damage: float = -1.0
var first_purchase: float = -1.0
var first_tower: float = -1.0
var peak_units: int = 0
var done: bool = false
var _sample_at: float = 0.0
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--seed="): random_seed = int(arg.get_slice("=", 1))
        elif arg.begins_with("--seconds="): limit = float(arg.get_slice("=", 1))
        elif arg.begins_with("--mode="): mode = arg.get_slice("=", 1)
        elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    if OS.get_environment("THRONE_WARS_TEST") != "1":
        printerr("Use tools/test.py; it isolates account and settings data.")
        quit(2)
        return
    call_deferred("start")
func start() -> void:
    seed(random_seed + completed)
    settings = root.get_node("Global")
    settings.prematch_on = false
    settings.team_size = 2
    settings.experimental = false
    settings.selected_hero = MatchBalance.PRIMARY_HEROES[(random_seed - 1) % 4]
    settings.tutorial_seen = true
    settings.difficulty = 1
    settings.fps_cap = 0
    settings.volume = 0.0
    settings.edge_scroll = false
    game = load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    for connection in settings.request_pause.get_connections():
        settings.request_pause.disconnect(connection.callable)
    game.player.auto_learn = true
    game.player.auto_learn_next()
    # Both sides use the same controller, including automatic illusion following.
    game.player.is_player = false
    game._add_bot(game.player, 1)
    Engine.time_scale = 1.0
    Engine.physics_ticks_per_second = 60
    Engine.max_fps = 0
    print("AUTOPLAY seed=", random_seed, " mode=", mode)
func _process(delta: float) -> bool:
    if game == null or done: return false
    total += delta
    if total >= _sample_at:
        _sample_at = total + 1.0
        for unit in settings.units():
            if DisplayServer.get_name() == "headless" and unit.model != null:
                unit.model.set_process(false)
        for node in settings.heroes_of(0) + settings.heroes_of(1):
            if first_damage < 0 and node.damage_dealt > 0: first_damage = settings.elapsed
            if first_purchase < 0 and node.inventory.has("boots"): first_purchase = settings.elapsed
        if first_tower < 0 and int(settings.stats["towers"][0]) + int(settings.stats["towers"][1]) > 0: first_tower = settings.elapsed
    if total >= checkpoint:
        checkpoint = total + 120.0
        peak_units = maxi(peak_units, settings.units().size())
        print("t=", int(total), " kills=", settings.stats["kills"], " towers=", settings.stats["towers"], " units=", settings.units().size())
        for node in settings.heroes_of(0) + settings.heroes_of(1):
            if first_damage < 0 and node.damage_dealt > 0: first_damage = settings.elapsed
            if first_purchase < 0 and node.inventory.has("boots"): first_purchase = settings.elapsed
        if first_tower < 0 and int(settings.stats["towers"][0]) + int(settings.stats["towers"][1]) > 0: first_tower = settings.elapsed
    if mode == "stress" and total >= next_illusion:
        next_illusion = total + 2.0
        if game.player.alive:
            for i in 3:
                load("res://scripts/Abilities.gd").spawn_illusion(game.player, 0.08, 0.3, 2.5, game.player.position + Vector3(i * 3, 0, 0))
                copies += 1
    if settings.is_over:
        completed += 1
        if mode == "stress" and total < limit:
            var old := game
            game = null
            old.queue_free()
            restart.call_deferred()
        else:
            finish(true)
    elif total >= limit:
        finish(false)
    return false
func restart() -> void:
    await process_frame
    start()
func finish(won: bool) -> void:
    done = true
    var report := {"seed": random_seed, "mode": mode, "seconds": settings.elapsed, "total_seconds": total, "finished": won, "completed_matches": completed, "kills": settings.stats["kills"], "towers": settings.stats["towers"], "first_damage": first_damage, "first_purchase": first_purchase, "first_tower": first_tower, "peak_units": peak_units, "stress_illusions": copies}
    var hero_reports: Array = []
    for hero in settings.heroes_of(0) + settings.heroes_of(1):
        hero_reports.append({"hero": hero.hero_id, "team": hero.team, "level": hero.level, "last_hits": hero.last_hits, "building_damage": hero.building_damage, "objectives": hero.objectives, "gold": hero.gold, "inventory": hero.inventory})
    report["final_match_heroes"] = hero_reports
    var file := FileAccess.open(output, FileAccess.WRITE)
    if file == null:
        push_error("Cannot write autoplay report: " + output)
        quit(3)
        return
    file.store_string(JSON.stringify(report, "  "))
    file.close()
    print("RESULT ", JSON.stringify(report))
    quit()
