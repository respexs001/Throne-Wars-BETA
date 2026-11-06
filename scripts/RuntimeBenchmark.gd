extends Node
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
var interrupted: bool = false
var tree: SceneTree
func _ready() -> void:
    tree = get_tree()
    process_mode = Node.PROCESS_MODE_ALWAYS
    if OS.get_environment("THRONE_WARS_TEST") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("/thronewars-runtime-"):
        tree.quit(2)
        return
    output = "user://runtime-benchmark.json"
    call_deferred("run")
func run() -> void:
    seed(1093)
    var global := tree.root.get_node("Global")
    tree.root.get_node("ProfileService").start_guest()
    global.quality = 1
    global.res_scale = 1.0
    global.fps_cap = 0
    global.prematch_on = false
    global.tutorial_seen = true
    global.team_size = 2
    global.selected_hero = "smugr"
    tree.root.size = Vector2i(1280, 720)
    tree.root.title = "Throne Wars · автоматический замер FPS (3 минуты)"
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var previous_scene := tree.current_scene
    game = load("res://scenes/Main.tscn").instantiate()
    tree.root.add_child(game)
    tree.current_scene = game
    if is_instance_valid(previous_scene): previous_scene.queue_free()
    for connection in global.request_pause.get_connections():
        global.request_pause.disconnect(connection.callable)
    for child in game.get_children():
        if child.get_script() == load("res://scripts/HUD.gd"): child._pause_panel.hide()
        if child.get_script() == load("res://scripts/PlayerController.gd"):
            child.set_process_unhandled_input(false)
            child.set_physics_process(false)
            child.set_process(false)
    tree.paused = false
    game.player.is_player = false
    game.player.auto_learn = true
    game._add_bot(game.player, 1)
    Engine.max_fps = 0
    Engine.time_scale = 1.0
    start_ms = Time.get_ticks_msec()
    print("BENCHMARK: x1, medium, 1280x720; 120s warmup + 60s sample")
func _process(_delta: float) -> void:
    if game == null: return
    if tree.paused: interrupted = true
    var now := Time.get_ticks_msec()
    if now - start_ms < 120000: return
    if sample_ms == 0:
        sample_ms = now
        previous_ms = now
        return
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
        report["version"] = tree.root.get_node("Global").VERSION
        report["debug_build"] = OS.is_debug_build()
        report["passed"] = fps >= 60.0 and not interrupted
        report["simulated_seconds"] = tree.root.get_node("Global").elapsed
        report["errors"] = []
        if fps < 60.0: report["errors"].append("Average FPS below 60")
        if interrupted: report["errors"].append("Benchmark was paused")
        var file := FileAccess.open(output, FileAccess.WRITE)
        file.store_string(JSON.stringify(report, "  "))
        file.close()
        print("RESULT ", JSON.stringify(report))
        tree.quit()
    return

