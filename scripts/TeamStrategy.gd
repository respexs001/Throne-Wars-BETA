class_name TeamStrategy
extends RefCounted
## Reservations include defenders still travelling, not just heroes at the goal.
static func committed(tree: SceneTree, team: int, goal: Vector3, exclude: Node) -> int:
    var count: int = 0
    for bot in tree.get_nodes_in_group("strategic_bots"):
        if bot == exclude or not is_instance_valid(bot.hero) or not bot.hero.alive or bot.hero.team != team:
            continue
        if bot.task_until > Global.elapsed and Global.flat_dist(bot.task_position, goal) < 70.0:
            count += 1
    return count

static func covering(tree: SceneTree, team: int, goal: Vector3, exclude: Node) -> int:
    var heroes: Dictionary = {}
    for hero in Global.heroes_of(team):
        if hero != exclude.hero and hero.alive and Global.flat_dist(hero.global_position, goal) < 90.0:
            heroes[hero.get_instance_id()] = true
    for bot in tree.get_nodes_in_group("strategic_bots"):
        if bot == exclude or not is_instance_valid(bot.hero) or not bot.hero.alive or bot.hero.team != team:
            continue
        if bot.task_kind == "defend" and bot.task_until > Global.elapsed and Global.flat_dist(bot.task_position, goal) < 70.0:
            heroes[bot.hero.get_instance_id()] = true
    return heroes.size()
