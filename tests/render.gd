extends SceneTree
var output := ""
func _initialize() -> void:
    if OS.get_environment("THRONE_WARS_TEST") != "1":
        quit(2)
        return
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    call_deferred("run")
func capture(name: String) -> void:
    for i in range(20): await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func run() -> void:
    var global := root.get_node("Global")
    root.get_node("ProfileService").start_guest()
    global.quality = 1
    global.fps_cap = 0
    Engine.max_fps = 0
    root.size = Vector2i(1280, 720)
    var menu = load("res://scenes/MainMenu.tscn").instantiate()
    root.add_child(menu)
    current_scene = menu
    menu._pick("smugr")
    await capture("menu-1280")
    root.size = Vector2i(1920, 1080)
    await capture("menu-1920")
    menu.queue_free()
    await process_frame
    root.size = Vector2i(1280, 720)
    global.prematch_on = false
    global.tutorial_seen = false
    var game = load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    for connection in global.request_pause.get_connections():
        global.request_pause.disconnect(connection.callable)
    for child in game.get_children():
        if child.get_script() == load("res://scripts/HUD.gd"):
            child._pause_panel.hide()
    paused = false
    await capture("hud-1280")
    root.size = Vector2i(1920, 1080)
    await capture("hud-1920")
    print("PASS: rendered menu and HUD at 1280x720 and 1920x1080")
    quit()
