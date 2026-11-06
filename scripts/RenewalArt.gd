class_name RenewalArt
extends RefCounted
static var _materials: Dictionary = {}

static func surface(color: Color, cloth: bool = false) -> StandardMaterial3D:
    var key: String = color.to_html() + str(cloth)
    if _materials.has(key):
        return _materials[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.albedo_texture = load("res://assets/renewal/cloth.svg" if cloth else "res://assets/renewal/armor.svg")
    m.roughness = 0.9 if cloth else 0.38
    m.metallic = 0.0 if cloth else 0.65
    _materials[key] = m
    return m

static func dress(model: Node3D, torso: Node3D, bulk: float, body: Color, accent: Color, team: Color) -> void:
    # Layered cuirass and gilded seams, keeping the existing animated skeleton.
    _box(torso, Vector3(0.8 * bulk, 0.68, 0.12), Vector3(0, 1.57, 0.33 * bulk), surface(body.lightened(0.12)))
    for s in [-1.0, 1.0]:
        _box(torso, Vector3(0.08, 0.8, 0.09), Vector3(s * 0.31 * bulk, 1.57, 0.42 * bulk), surface(accent))
        var plate := _box(torso, Vector3(0.38 * bulk, 0.42, 0.12), Vector3(s * 0.25 * bulk, 0.91, 0.31), surface(body))
        plate.rotation.z = s * 0.12
    _box(torso, Vector3(0.19, 0.25, 0.1), Vector3(0, 1.65, 0.46 * bulk), Global.get_mat(team, 0.8))
    var banner := _box(torso, Vector3(0.46 * bulk, 0.8, 0.045), Vector3(0, 0.76, 0.37), surface(accent, true))
    banner.name = "HeraldicTabard"
    var ring := MeshInstance3D.new()
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.75
    mesh.outer_radius = 0.82
    mesh.rings = 20
    mesh.ring_segments = 8
    ring.mesh = mesh
    ring.material_override = Global.get_mat(team, 0.15)
    ring.position.y = 0.04
    model.add_child(ring)

static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    n.mesh = PrimitiveCache.box(size)
    n.position = pos
    n.material_override = mat
    parent.add_child(n)
    return n

static func decorate(root: Node3D) -> void:
    var stone := StandardMaterial3D.new()
    stone.albedo_texture = load("res://assets/renewal/slate.svg")
    stone.uv1_scale = Vector3(4, 4, 4)
    stone.roughness = 0.87
    # Symmetric sanctuaries at both river rune locations.
    for center in Global.RUNE_SPOTS:
        var p: Vector3 = center
        p.y = Global.height_at(p.x, p.z)
        var platform := MeshInstance3D.new()
        var disk := CylinderMesh.new()
        disk.top_radius = 13.0
        disk.bottom_radius = 14.0
        disk.height = 0.7
        disk.radial_segments = 12
        platform.mesh = disk
        platform.material_override = stone
        platform.position = p + Vector3(0, 0.35, 0)
        root.add_child(platform)
        for k in 4:
            var angle: float = PI * 0.25 + float(k) * PI * 0.5
            var pos: Vector3 = p + Vector3(cos(angle) * 12, 0, sin(angle) * 12)
            _box(root, Vector3(2.2, 5.0, 2.2), pos + Vector3(0, 2.5, 0), stone)
            var crystal := MeshInstance3D.new()
            var gem := PrismMesh.new()
            gem.size = Vector3(2.6, 4.0, 2.6)
            crystal.mesh = gem
            crystal.position = pos + Vector3(0, 6, 0)
            crystal.material_override = Global.get_mat(Color(0.15, 0.85, 0.78), 1.6)
            root.add_child(crystal)
    # Low roadside markers preserve the full playable lane width.
    for l in 3:
        var pts: Array = Global.LANES[l]
        for i in range(pts.size() - 1):
            var a: Vector3 = pts[i]
            var b: Vector3 = pts[i + 1]
            var direction: Vector3 = (b - a).normalized()
            var side := Vector3(-direction.z, 0, direction.x)
            var steps: int = maxi(1, int(a.distance_to(b) / 36.0))
            for j in range(1, steps):
                for sign_value in [-1.0, 1.0]:
                    var pos: Vector3 = a.lerp(b, float(j) / float(steps)) + side * (Global.LANE_WIDTH * 0.5 + 3) * sign_value
                    pos.y = Global.height_at(pos.x, pos.z)
                    _box(root, Vector3(1.8, 1.4, 1.8), pos + Vector3(0, 0.7, 0), stone)
                    var color := Color(0.15, 0.8, 0.85) if l != 2 else Color(1, 0.62, 0.2)
                    _box(root, Vector3(1.3, 0.2, 1.3), pos + Vector3(0, 1.5, 0), Global.get_mat(color, 1.0))
