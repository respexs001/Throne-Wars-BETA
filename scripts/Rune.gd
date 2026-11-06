class_name Rune
extends Node3D
## Rune.gd — руна: парит, вращается, подписана. 7 видов. Подбирается героем рядом.

const NAMES: Dictionary = {"haste": "Скорость", "dd": "Двойной урон", "regen": "Регенерация", "arcane": "Арканная",
    "shield": "Щит", "wisdom": "Мудрость", "bounty": "Богатство"}

var kind: String = "haste"
var _t: float = 0.0
var _mesh: MeshInstance3D
var _life: float = 150.0


static func colour_of(k: String) -> Color:
    match k:
        "haste":
            return Color(0.3, 0.8, 1.0)
        "dd":
            return Color(0.7, 0.4, 1.0)
        "regen":
            return Color(0.4, 1.0, 0.5)
        "arcane":
            return Color(1.0, 0.45, 0.85)
        "shield":
            return Color(1.0, 0.65, 0.25)
        "wisdom":
            return Color(0.75, 0.9, 1.0)
    return Color(1.0, 0.85, 0.2)


func _ready() -> void:
    add_to_group("runes")
    _mesh = MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(1.8, 1.8, 1.8)
    _mesh.mesh = bm
    _mesh.material_override = Global.get_mat(colour_of(kind), 2.5)
    _mesh.position.y = 4.0
    add_child(_mesh)
    var light := OmniLight3D.new()
    light.light_color = colour_of(kind)
    light.omni_range = 14.0
    light.position.y = 4.0
    add_child(light)
    var lbl := Label3D.new()
    lbl.text = NAMES.get(kind, kind)
    lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    lbl.no_depth_test = true
    lbl.pixel_size = 0.03
    lbl.font_size = 36
    lbl.outline_size = 8
    lbl.modulate = colour_of(kind)
    lbl.position = Vector3(0.0, 8.2, 0.0)
    add_child(lbl)


func _physics_process(delta: float) -> void:
    _t += delta
    _life -= delta
    _mesh.rotation = Vector3(_t * 1.2, _t * 2.0, _t * 0.7)
    _mesh.position.y = 4.0 + sin(_t * 3.0) * 0.6
    if _life <= 0.0:
        queue_free()
        return
    for n in get_tree().get_nodes_in_group("heroes"):
        var h := n as BaseHero
        if h != null and h.alive and Global.flat_dist(h.global_position, global_position) < 6.0:
            Global.apply_rune(h, kind)
            Global.spawn_burst(global_position, 6.0, colour_of(kind))
            queue_free()
            return
