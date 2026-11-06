class_name FogManager
extends Node
## FogManager.gd — туман войны: вражеские и нейтральные юниты скрыты, пока их не видит союзный юнит или здание.
## Вражеские здания после обнаружения остаются видимыми. Ночью обзор героев меньше.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


var _acc: float = 0.0


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.15:
		return
	_acc = 0.0
	var sources: Array = []
	var targets: Array = []
	for n in Global.units():
		if not is_instance_valid(n):
			continue
		var u := n as Unit
		if u == null or not u.alive:
			continue
		if u.team == Global.player_team:
			sources.append(u)
		else:
			targets.append(u)
	var off := not Global.fog_on or Global.test_mode
	for t in targets:
		if not is_instance_valid(t):
			continue
		var e: Unit = t
		var seen := off
		if not seen:
			for s in sources:
				if not is_instance_valid(s):
					continue
				var su: Unit = s
				if Global.flat_dist(su.global_position, e.global_position) <= _vision(su) + e.body_radius:
					seen = true
					break
		if e is Building:
			var b := e as Building
			if seen:
				b.discovered = true
			e.visible = seen or b.discovered
		else:
			e.visible = seen


func _vision(s: Unit) -> float:
	if s is Building:
		return 95.0 if (s as Building).is_throne else 80.0
	if s is BaseHero:
		return 90.0 if Global.is_day else 58.0
	if s is Courier:
		return 40.0
	return 55.0
