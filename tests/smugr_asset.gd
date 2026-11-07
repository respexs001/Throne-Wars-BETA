extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var scene := Node3D.new()
    root.add_child(scene)
    var model = load("res://scripts/UnitModel.gd").new()
    scene.add_child(model)
    model.build({"weapon": "daggers", "asset_scene": "res://assets/characters/smugr/smugr.glb"}, Color.CYAN)
    assert(model._asset_player != null)
    for clip in ["Idle", "Run", "Attack", "Cast", "Death", "Stun"]:
        assert(model._asset_player.has_animation(clip), "Missing " + clip)
        assert(model._asset_player.get_animation(clip).get_track_count() > 0)
    model.set_moving(true)
    await process_frame
    await process_frame
    assert(model._asset_clip == "Run")
    model.play_attack(false)
    await process_frame
    await process_frame
    assert(model._asset_clip == "Attack")
    model.play_death()
    await process_frame
    await process_frame
    assert(model._asset_clip == "Death")
    model.revive()
    model._attack_t = 0
    model.set_moving(false)
    await process_frame
    await process_frame
    assert(model._asset_clip == "Idle")
    var camera := Camera3D.new()
    scene.add_child(camera)
    camera.position = Vector3(2.4, 2.2, 3.1)
    camera.look_at(Vector3(0, 1.3, 0))
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-35, -30, 0)
    scene.add_child(sun)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color(0.045, 0.055, 0.08)
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color.WHITE
    env.environment.ambient_light_energy = 0.6
    scene.add_child(env)
    root.size = Vector2i(900, 900)
    for i in 8: await process_frame
    await process_frame
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://artifacts/smugr-preview.png")
        model.set_process(false)
        for clip in ["Run", "Attack", "Cast"]:
            model._asset_player.play(clip)
            model._asset_player.seek(0.2, true)
            model._asset_player.pause()
            await process_frame
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("res://artifacts/smugr-" + clip.to_lower() + ".png")
        model._asset_player.play("Idle")
        model._asset_player.seek(0, true)
        model._asset_player.pause()
        camera.position = Vector3(2.4, 2.1, -3.1)
        camera.look_at(Vector3(0, 1.3, 0))
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://artifacts/smugr-cloak.png")
    print("PASS: Smugr imported clips and game animation transitions")
    quit()

