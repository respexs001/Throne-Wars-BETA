extends SceneTree
func _initialize() -> void:
    if OS.get_environment("THRONE_WARS_TEST") != "1":
        printerr("Use tools/test.py to isolate data.")
        quit(2)
        return
    call_deferred("run")
func run() -> void:
    var global := root.get_node("Global")
    assert(global.VERSION == ProjectSettings.get_setting("application/config/version"), "Project metadata version differs")
    assert(global.VERSION == MatchBalance.VERSION)
    var service := root.get_node("ProfileService")
    assert(AuthBackend.validate_password("NineChars") != "")
    assert(AuthBackend.validate_password("SkyRiver42") == "")
    service.start_guest()
    assert(service.has_session() and service.is_guest and not service.is_logged_in())
    global.reset_stats()
    service.record_match(true, 1, 0, 650, "smugr")
    assert(service.mastery_xp("smugr") == 150)
    service.record_match(true, 1, 0, 650, "smugr")
    assert(service.mastery_xp("smugr") == 150, "Duplicate result awarded XP")
    service.logout()
    service.start_guest()
    assert(service.mastery_xp("smugr") == 150, "Guest session lost within process")
    var result: Dictionary = service.register("alpha_tester", "Northern rivers 42")
    assert(result["ok"] and service.is_logged_in() and not service.is_guest)
    assert(service.mastery_xp("smugr") == 0, "Guest stats leaked into a new account")
    for id in MatchBalance.PRIMARY_HEROES:
        assert(BuildGuide.choices(id).size() == 2)
        for choice in BuildGuide.choices(id):
            for item in choice["items"]: assert(global.ITEMS.has(item))
    print("PASS: 10-character registration, guest lifetime, mastery deduplication, independent account and build guides")
    global.prematch_on = false
    global.tutorial_seen = true
    global.selected_hero = "smugr"
    global.team_size = 2
    global.experimental = false
    global.fps_cap = 0
    global.volume = 0
    var game = load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    var bots := get_nodes_in_group("strategic_bots")
    assert(bots.size() == 3)
    assert(game._guardian == null)
    assert(is_equal_approx(game._guardian_wait, 180.0))
    for node in global.heroes_of(0) + global.heroes_of(1):
        assert(node.hero_id in MatchBalance.PRIMARY_HEROES)
    var reservation = bots[0]
    reservation.task_position = game.player.position
    reservation.task_until = global.elapsed + 12
    var strategy = load("res://scripts/TeamStrategy.gd")
    assert(strategy.committed(self, reservation.hero.team, reservation.task_position, null) >= 1)
    var enemy_bots := bots.filter(func(b): return b.hero.team == 1)
    var caller = enemy_bots[0]
    var covering = enemy_bots[1]
    var old_position: Vector3 = covering.hero.position
    covering.hero.position = Vector3.ZERO
    covering.task_kind = "defend"
    covering.task_position = Vector3.ZERO
    covering.task_until = global.elapsed + 12
    assert(strategy.covering(self, 1, Vector3.ZERO, caller) == 1, "Nearby reserved defender counted twice")
    var traveller = game._make_hero("titan", 1, false, 0, 1)
    traveller.position = Vector3(200, 0, 0)
    game._add_bot(traveller, 1)
    var travel_bot: Node
    for b in get_nodes_in_group("strategic_bots"):
        if b.hero == traveller: travel_bot = b
    travel_bot.task_kind = "defend"
    travel_bot.task_position = Vector3.ZERO
    travel_bot.task_until = global.elapsed + 12
    assert(strategy.covering(self, 1, Vector3.ZERO, caller) == 2, "Travelling and nearby defenders were not combined")
    traveller.position = global.fountain_pos(1)
    traveller.gold = 2500
    travel_bot._physics_process(0.25)
    assert(traveller.inventory.has("boots") or traveller.inventory.has("battle_boots"), "Bot did not shop at the fountain")
    travel_bot.free()
    traveller.free()
    covering.hero.position = old_position
    game._spawn_guardian()
    var guardian = game._guardian
    guardian.take_damage(100000, game.player, "pure", false)
    assert(global.siege_waves[0] == 2 and game.player.objectives == 1)
    var count_before: int = global.units().filter(func(u): return u.get_script().resource_path.ends_with("Creep.gd") and u.siege and u.team == 0).size()
    game._spawn_wave()
    assert(global.siege_waves[0] == 1)
    var count_after: int = global.units().filter(func(u): return u.get_script().resource_path.ends_with("Creep.gd") and u.siege and u.team == 0).size()
    assert(count_after - count_before == 3, "Guardian wave did not add one siege creep per lane")
    assert(global.units().filter(func(u): return u.get_script().resource_path.ends_with("Creep.gd") and u.guardian_empowered).size() == 3)
    game._spawn_wave()
    assert(global.siege_waves[0] == 0)
    print("PASS: recommended 2v2 roster, task reservations, guardian start, rewards and exactly two empowered waves")
    # Verify actual game-over signal, result screen, restart and surrender.
    var matches: int = service.profile["stats"]["matches"]
    global.end_game(0)
    assert(service.profile["stats"]["matches"] == matches + 1)
    assert(service.mastery_xp("smugr") == 150)
    var hud: Node
    for child in game.get_children():
        if child.get_script() != null and child.get_script().resource_path.ends_with("HUD.gd"): hud = child
    assert(hud._over_panel.visible and hud._lbl_over.text.contains("Урон строениям"))
    global.end_game(0)
    assert(service.profile["stats"]["matches"] == matches + 1)
    hud._on_restart()
    await process_frame
    await process_frame
    game = current_scene
    assert(game != null and not global.is_over)
    for child in game.get_children():
        if child.get_script() != null and child.get_script().resource_path.ends_with("HUD.gd"): hud = child
    # Surrender uses the same end_game path as the pause-menu button.
    global.end_game(1)
    assert(service.profile["stats"]["matches"] == matches + 2)
    assert(service.profile["stats"]["losses"] == 1)
    var stored := LocalAuthBackend.new()
    assert(stored.login("alpha_tester", "Northern rivers 42")["profile"]["mastery"]["smugr"] == 250)
    hud._on_menu()
    paused = false
    var menu_deadline := Time.get_ticks_msec() + 10000
    while (current_scene == null or not current_scene.scene_file_path.ends_with("MainMenu.tscn")) and Time.get_ticks_msec() < menu_deadline:
        await process_frame
    assert(current_scene != null and current_scene.scene_file_path.ends_with("MainMenu.tscn"))
    print("PASS: victory, result contributions, duplicate protection, replay, defeat, persisted mastery and return to menu")
    quit()
