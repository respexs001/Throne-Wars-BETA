class_name LaneWaveSpawner
extends RefCounted
## Owns lane population and deferred guardian waves; Main only schedules ticks.
var _siege_lane_pending: Dictionary = {}

func spawn(game: Node3D, wave_number: int) -> void:
	var siege_wave := wave_number % 4 == 0
	var living := {}
	for unit in Global.units():
		if unit is Creep and unit.alive and not unit.neutral:
			var key := Vector2i(unit.team, unit.lane)
			living[key] = int(living.get(key, 0)) + 1
	for t in [0, 1]:
		var remaining := 0
		for lane in 3:
			remaining = maxi(remaining, int(_siege_lane_pending.get(Vector2i(t, lane), 0)))
		if Global.siege_waves[t] == 0 or Global.siege_waves[t] > remaining:
			for lane in 3:
				_siege_lane_pending[Vector2i(t, lane)] = Global.siege_waves[t]
		for lane in 3:
			var count := MatchBalance.wave_size(Global.elapsed)
			var empowered := int(_siege_lane_pending.get(Vector2i(t, lane), 0)) > 0
			if empowered:
				count = mini(7, count + 1)
			# Keep complete waves: congested lanes wait instead of accumulating units.
			if int(living.get(Vector2i(t, lane), 0)) + count > MatchBalance.MAX_LANE_CREEPS_PER_TEAM:
				continue
			var path: Array = Global.lane_path(t, lane)
			var p0: Vector3 = path[0]
			var p1: Vector3 = path[1]
			var dir := (p1 - p0).normalized()
			var side := Vector3(-dir.z, 0.0, dir.x)
			# Полная пачка из 5–7 бойцов; осадный заменяет ближнего.
			var kinds: Array = ["melee", "melee", "melee", "melee", "ranged"]
			while kinds.size() < count:
				kinds.insert(0, "melee")
			if siege_wave:
				kinds[0] = "siege"
			if empowered:
				kinds[0] = "guardian_siege"
			for i in kinds.size():
				var c := Creep.new()
				c.team = t
				c.lane = lane
				c.wave = wave_number
				c.ranged_creep = kinds[i] == "ranged"
				c.siege = kinds[i] in ["siege", "guardian_siege"]
				c.guardian_empowered = kinds[i] == "guardian_siege"
				c.path = path
				c.goal_pos = Global.throne_pos(1 - t)
				var sp := p0 - dir * (float(i) * 4.6) + side * ((float(i % 2) - 0.5) * 4.0)
				c.position = Vector3(clampf(sp.x, -Global.MAP_HALF + 4.0, Global.MAP_HALF - 4.0), 0.0, clampf(sp.z, -Global.MAP_HALF + 4.0, Global.MAP_HALF - 4.0))
				game.add_child(c)
			if empowered:
				_siege_lane_pending[Vector2i(t, lane)] -= 1

	for t in 2:
		Global.siege_waves[t] = 0
		for lane in 3:
			Global.siege_waves[t] = maxi(Global.siege_waves[t], int(_siege_lane_pending.get(Vector2i(t, lane), 0)))


