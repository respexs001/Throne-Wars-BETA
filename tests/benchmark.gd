extends SceneTree
var start_ms: int
var sample_ms: int = 0
var frames: int = 0
var frame_ms: Array[float] = []
var previous_ms: int = 0
var output: String = ""
var game: Node
var process_ms: float = 0.0
var physics_ms: float = 0.0
var draw_calls: float = 0.0
var primitives: float = 0.0
func _initialize() -> void:
    if OS.get_environment("THRONE_WARS_TEST") != "1":
        quit(2)
        return
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    call_deferred("run")
func run() -> void:
    var global := root.get_node("Global")
    global.quality = 1
    global.res_scale = 1.0
    global.fps_cap = 0
    global.prematch_on = false
    global.tutorial_seen = true
    global.team_size = 2
    global.selected_hero = "smugr"
    root.size = Vector2i(1280, 720)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    game = load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    for connection in global.request_pause.get_connections():
        global.request_pause.disconnect(connection.callable)
    for child in game.get_children():
        if child.get_script() == load("res://scripts/HUD.gd"): child._pause_panel.hide()
    paused = false
    game.player.is_player = false
    game.player.auto_learn = true
    game._add_bot(game.player, 1)
    Engine.max_fps = 0
    Engine.time_scale = 1.0
    start_ms = Time.get_ticks_msec()
    print("BENCHMARK: x1, medium, 1280x720; 120s warmup + 60s sample")
func _process(_delta: float) -> bool:
    if game == null: return false
    var now := Time.get_ticks_msec()
    if now - start_ms < 120000: return false
    if sample_ms == 0:
        sample_ms = now
        previous_ms = now
        return false
    frames += 1
    process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
    physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
    draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
    primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
    frame_ms.append(float(now - previous_ms))
    previous_ms = now
    if now - sample_ms >= 60000:
        frame_ms.sort()
        var fps := frames * 1000.0 / float(now - sample_ms)
        var report := {"average_fps": fps, "p99_frame_ms": frame_ms[int(frame_ms.size() * 0.99)], "sample_seconds": (now - sample_ms) / 1000.0, "resolution": "1280x720", "quality": "medium", "time_scale": Engine.time_scale, "rendering_device": RenderingServer.get_video_adapter_name(), "processor": OS.get_processor_name(), "passed_60fps": fps >= 60.0}
        report["average_process_ms"] = process_ms / frames
        report["average_physics_ms"] = physics_ms / frames
        report["average_draw_calls"] = draw_calls / frames
        report["average_primitives"] = primitives / frames
        var file := FileAccess.open(output, FileAccess.WRITE)
        file.store_string(JSON.stringify(report, "  "))
        file.close()
        print("RESULT ", JSON.stringify(report))
        quit()
    return false
