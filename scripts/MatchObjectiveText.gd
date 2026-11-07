class_name MatchObjectiveText
extends RefCounted
## Read-only tactical presentation, independent of HUD node layout.
static func text_for(hero: BaseHero) -> String:
	if Global.test_mode:
		return "Песочница: пробуйте способности и предметы. Прогресс здесь не начисляется."
	var objective := "Цель: идите со своей волной к вражеской башне. Затем разрушьте трон."
	if hero.hp < hero.max_hp * 0.3:
		objective = "Цель: отступите к своему фонтану и восстановите здоровье."
	elif Global.elapsed < MatchBalance.GUARDIAN_FIRST and Global.elapsed >= MatchBalance.GUARDIAN_FIRST - 30.0:
		objective = "Страж через %d с — восстановитесь и соберитесь с союзником." % int(ceilf(MatchBalance.GUARDIAN_FIRST - Global.elapsed))
	elif Global.siege_waves[hero.team] > 0:
		objective = "Цель: используйте усиленные осадные волны для атаки башен."
	var purchase := "Сборка завершена — помогите союзнику на карте."
	if is_instance_valid(hero.courier) and not hero.courier.stash.is_empty():
		purchase = "Курьер несёт покупки: кнопка «Курьер» отправит его к вам."
	else:
		for id in BuildGuide.items(hero.hero_id, hero.build_choice):
			if id == "boots" and hero.inventory.has("battle_boots"): continue
			if hero.inventory.has(id): continue
			purchase = "F4: %s · %d золота" % [Global.ITEMS[id]["name"], Global.item_price(hero.inventory, id)]
			break
	if hero.alive and hero.hp >= hero.max_hp * 0.3 and Global.siege_waves[hero.team] <= 0 and not (Global.elapsed >= MatchBalance.GUARDIAN_FIRST - 30.0 and Global.elapsed < MatchBalance.GUARDIAN_FIRST):
		var target: Node = null
		var distance := INF
		for unit in Global.units():
			if unit is Building and unit.team != hero.team and unit.team < 2 and unit.alive and not unit.invulnerable:
				var d := Global.flat_dist(hero.global_position, unit.global_position)
				if d < distance:
					distance = d
					target = unit
		if target != null:
			objective = "Цель: %s · %d%% прочности. Подведите союзную волну." % ["вражеский трон" if target.is_throne else "ближайшая открытая башня", int(100.0 * target.hp / target.max_hp)]
	return objective + "\n" + purchase


