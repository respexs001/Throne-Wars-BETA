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
    global.selected_hero = "smugr"
    var game = load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    for seconds in [0.0, 300.0, 600.0]:
        clear_lane_units(global)
        global.elapsed = seconds
        global.siege_waves[0] = 0; global.siege_waves[1] = 0
        game._spawn_wave()
        var size := 5 if seconds == 0 else (6 if seconds == 300 else 7)
        for team in 2:
            for lane in 3:
                assert(count_lane(global, team, lane) == size)
        for i in 100: game._spawn_wave()
        for team in 2:
            for lane in 3:
                assert(count_lane(global, team, lane) <= 14, "Congested lane exceeded population limit")
        global.siege_waves[0] = 2; global.siege_waves[1] = 2
        game._spawn_wave()
        assert(global.siege_waves[0] == 2, "Congestion consumed an unspawned guardian wave")
        clear_lane_units(global)
        game._spawn_wave()
        assert(count_lane(global, 0, 1) == mini(size + 1, 7), "Empowered wave did not resume after lane cleared")
        clear_lane_units(global)
        global.siege_waves[0] = 2; global.siege_waves[1] = 2
        game._spawn_wave()
        assert(count_lane(global, 0, 1) == mini(size + 1, 7))
    for mesh in game.player.model.find_children("*", "MeshInstance3D", true, false):
        assert(mesh.material_overlay == null, "Selected hero still has per-part overlay")
    print("PASS: 5/6/7 wave sizes, guardian maximum 7, 100 congested waves bounded, resume and clean hero selection")
    quit()
func clear_lane_units(global: Node) -> void:
    for u in global.units().duplicate():
        if u.get_script().resource_path.ends_with("Creep.gd") and not u.neutral: u.free()
func count_lane(global: Node, team: int, lane: int) -> int:
    var count := 0
    for u in global.units():
        if u.get_script().resource_path.ends_with("Creep.gd") and u.alive and not u.neutral and u.team == team and u.lane == lane: count += 1
    return count

