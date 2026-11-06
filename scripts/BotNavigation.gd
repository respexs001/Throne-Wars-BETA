extends RefCounted
## Shared obstacle-aware routing. The map's collision circles are authoritative.
const CELL: float = 4.0
const HALF_CELLS: int = 75
static var _scene_id: int = 0
static var _grids: Dictionary = {}

static func route(from: Vector3, to: Vector3, radius: float, scene: Node) -> Array[Vector3]:
    if _scene_id != scene.get_instance_id():
        _scene_id = scene.get_instance_id()
        _grids.clear()
    var bucket: int = ceili(radius)
    if not _grids.has(bucket):
        var grid := AStarGrid2D.new()
        grid.region = Rect2i(-HALF_CELLS, -HALF_CELLS, HALF_CELLS * 2 + 1, HALF_CELLS * 2 + 1)
        grid.cell_size = Vector2.ONE * CELL
        grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
        grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
        grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
        grid.update()
        for x in range(-HALF_CELLS, HALF_CELLS + 1):
            for z in range(-HALF_CELLS, HALF_CELLS + 1):
                var pos := Vector3(float(x) * CELL, 0, float(z) * CELL)
                var displaced := Global.push_out(pos, float(bucket) + 0.75)
                if Global.flat_dist(pos, displaced) > 0.05:
                    grid.set_point_solid(Vector2i(x, z))
        _grids[bucket] = grid
    var grid: AStarGrid2D = _grids[bucket]
    var start := _open_cell(grid, from)
    var goal := _open_cell(grid, to)
    var path: Array[Vector3] = []
    if start == Vector2i(999, 999) or goal == Vector2i(999, 999):
        return path
    for cell in grid.get_id_path(start, goal):
        path.append(Vector3(float(cell.x) * CELL, 0, float(cell.y) * CELL))
    if not path.is_empty():
        var safe_goal := Global.push_out(to, radius + 0.1)
        if Global.flat_dist(path.back(), safe_goal) < CELL * 1.5:
            path.append(safe_goal)
    return path

static func _open_cell(grid: AStarGrid2D, pos: Vector3) -> Vector2i:
    var center := Vector2i(clampi(roundi(pos.x / CELL), -HALF_CELLS, HALF_CELLS), clampi(roundi(pos.z / CELL), -HALF_CELLS, HALF_CELLS))
    for r in range(0, 7):
        var best := Vector2i(999, 999)
        var distance: float = INF
        for x in range(-r, r + 1):
            for y in range(-r, r + 1):
                if r > 0 and absi(x) != r and absi(y) != r:
                    continue
                var c := center + Vector2i(x, y)
                if not grid.is_in_boundsv(c) or grid.is_point_solid(c):
                    continue
                var d := Vector2(pos.x, pos.z).distance_squared_to(Vector2(c) * CELL)
                if d < distance:
                    distance = d
                    best = c
        if best != Vector2i(999, 999):
            return best
    return Vector2i(999, 999)
