extends Node
## Explicit checks: assertions are disabled in release templates.
var failures: Array[String] = []
var output: String = ""
var tree: SceneTree
func _ready() -> void:
    tree = get_tree()
    process_mode = Node.PROCESS_MODE_ALWAYS
    if OS.get_environment("THRONE_WARS_TEST") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("/thronewars-runtime-"):
        tree.quit(2)
        return
    output = "user://runtime-verification.json"
    phase("initialize")
    call_deferred("run")
func phase(name: String) -> void:
    var file := FileAccess.open(output, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"passed": false, "errors": ["Stopped at " + name]}))
        file.close()
func check(condition: bool, message: String) -> void:
    if not condition: failures.append(message)
func run() -> void:
    var global := tree.root.get_node("Global")
    var service := tree.root.get_node("ProfileService")
    var gate := tree.current_scene
    check(gate != null and gate.has_method("_guest"), "Packaged guest entry missing")
    if gate == null or not gate.has_method("_guest"):
        finish()
        return
    gate._guest()
    var entry_deadline := Time.get_ticks_msec() + 10000
    while (tree.current_scene == null or not tree.current_scene.scene_file_path.ends_with("MainMenu.tscn")) and Time.get_ticks_msec() < entry_deadline:
        await tree.process_frame
    check(tree.current_scene != null and tree.current_scene.scene_file_path.ends_with("MainMenu.tscn"), "Guest entry did not reach menu")
    if not failures.is_empty():
        finish()
        return
    check(service.has_session() and service.is_guest, "Guest session unavailable")
    global.prematch_on = false
    global.tutorial_seen = true
    global.selected_hero = "smugr"
    global.team_size = 2
    global.fps_cap = 0
    phase("load match")
    var menu_scene := tree.current_scene
    var game = load("res://scenes/Main.tscn").instantiate()
    tree.root.add_child(game)
    tree.current_scene = game
    menu_scene.queue_free()
    phase("match ready")
    check(tree.get_nodes_in_group("strategic_bots").size() == 3, "Wrong 2v2 roster")
    global.end_game(0)
    check(service.mastery_xp("smugr") == 150, "Victory XP missing")
    var hud: Node
    for child in game.get_children():
        if child.get_script() != null and child.get_script().resource_path.ends_with("HUD.gd"): hud = child
    check(hud != null, "Packaged HUD missing")
    if hud == null:
        finish()
        return
    check(hud._over_panel.visible, "Result screen missing")
    hud._on_restart()
    await tree.process_frame
    await tree.process_frame
    game = tree.current_scene
    check(game != null and not global.is_over, "Replay failed")
    global.end_game(1)
    check(service.mastery_xp("smugr") == 250, "Defeat XP or replay result missing")
    check(service.profile["stats"]["matches"] == 2, "Match result duplicated or lost")
    for child in game.get_children():
        if child.get_script() != null and child.get_script().resource_path.ends_with("HUD.gd"): hud = child
    hud._on_menu()
    tree.paused = false
    var deadline := Time.get_ticks_msec() + 10000
    while (tree.current_scene == null or not tree.current_scene.scene_file_path.ends_with("MainMenu.tscn")) and Time.get_ticks_msec() < deadline:
        await tree.process_frame
    check(tree.current_scene != null and tree.current_scene.scene_file_path.ends_with("MainMenu.tscn"), "Return to menu failed")
    finish()
func finish() -> void:
    check(not FileAccess.file_exists("user://accounts.cfg"), "Guest verification wrote a permanent account")
    check(not ResourceLoader.exists("res://tests/auth.gd"), "External test sources were included in the game pack")
    var file := FileAccess.open(output, FileAccess.WRITE)
    file.store_string(JSON.stringify({"passed": failures.is_empty(), "errors": failures, "guest_matches": 2, "version": tree.root.get_node("Global").VERSION, "permanent_account_written": FileAccess.file_exists("user://accounts.cfg")}, "  "))
    file.close()
    tree.quit(0 if failures.is_empty() else 1)

