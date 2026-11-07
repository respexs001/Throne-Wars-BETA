class_name UnitModel
extends Node3D
## UnitModel.gd — процедурная модель человечка из примитивов + анимации:
## бег, дыхание в простое, удар, каст, оглушение (звёзды), смерть, вспышка при попадании, рост (форма дракона).

const ATTACK_DUR: float = 0.45
const CAST_DUR: float = 0.55

var cfg: Dictionary = {}
var base_scale: float = 1.0
var moving: bool = false
var stunned: bool = false
var dead: bool = false

var _root: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _cape: Node3D
var _weapon: Node3D
var _stars: Node3D
var _wings: Array = []
var _tail: Node3D
var _orbs: Node3D
var _aura: MeshInstance3D
var _bulk: float = 1.0
var _t: float = 0.0
var _run: float = 0.0
var _amp: float = 0.0
var _attack_t: float = 0.0
var _attack_ranged: bool = false
var _cast_t: float = 0.0
var _dead_t: float = 0.0
var _flash_t: float = 0.0
var _grow: float = 1.0
var _grow_target: float = 1.0
var _animation_acc: float = 0.0
var _asset_player: AnimationPlayer
var _asset_clip: String = ""


func build(c: Dictionary, team_col: Color) -> void:
    cfg = c
    base_scale = float(c.get("scale", 1.0))
    if c.has("asset_scene"):
        _root = load(String(c["asset_scene"])).instantiate()
        add_child(_root)
        _asset_player = _root.find_child("AnimationPlayer", true, false) as AnimationPlayer
        scale = Vector3.ONE * base_scale
        return
    var kind: String = c.get("build", "mid")
    _bulk = 0.8 if kind == "slim" else (1.3 if kind == "bulky" else 1.0)
    var body: Color = c.get("body", Color(0.5, 0.5, 0.5))
    var accent: Color = c.get("accent", team_col)
    var skin: Color = c.get("skin", Color(0.85, 0.7, 0.55))
    _root = Node3D.new()
    add_child(_root)
    # ноги
    _leg_l = _limb(Vector3(-0.25 * _bulk, 1.0, 0.0), 0.15 * _bulk, 1.0, body.darkened(0.35))
    _leg_r = _limb(Vector3(0.25 * _bulk, 1.0, 0.0), 0.15 * _bulk, 1.0, body.darkened(0.35))
    _root.add_child(_leg_l)
    _root.add_child(_leg_r)
    # торс
    _torso = Node3D.new()
    _root.add_child(_torso)
    _box(_torso, Vector3(0.95 * _bulk, 1.0, 0.55 * _bulk), Vector3(0.0, 1.5, 0.0), body)
    _box(_torso, Vector3(1.05 * _bulk, 0.18, 0.62 * _bulk), Vector3(0.0, 1.05, 0.0), accent)
    _sphere(_torso, 0.24 * _bulk, Vector3(-0.58 * _bulk, 1.95, 0.0), accent, 0.0)
    _sphere(_torso, 0.24 * _bulk, Vector3(0.58 * _bulk, 1.95, 0.0), accent, 0.0)
    # голова
    _head = Node3D.new()
    _head.position = Vector3(0.0, 2.25, 0.0)
    _torso.add_child(_head)
    _sphere(_head, 0.3, Vector3.ZERO, skin, 0.0)
    var eye: Color = c.get("eyes", Color(1.0, 1.0, 0.8))
    _sphere(_head, 0.055, Vector3(-0.12, 0.04, 0.27), eye, 2.0)
    _sphere(_head, 0.055, Vector3(0.12, 0.04, 0.27), eye, 2.0)
    _make_hat(c.get("hat", "none"), body, accent)
    # руки
    _arm_l = _limb(Vector3(-0.64 * _bulk, 1.92, 0.0), 0.12 * _bulk, 0.95, skin)
    _arm_r = _limb(Vector3(0.64 * _bulk, 1.92, 0.0), 0.12 * _bulk, 0.95, skin)
    _torso.add_child(_arm_l)
    _torso.add_child(_arm_r)
    _weapon = Node3D.new()
    _weapon.position = Vector3(0.0, -0.95, 0.05)
    _weapon.rotation_degrees = Vector3(40.0, 0.0, 0.0)
    _arm_r.add_child(_weapon)
    _make_weapon(_weapon, c.get("weapon", "fists"), accent)
    if c.get("weapon", "") in ["dagger", "daggers"]:
        var wl := Node3D.new()
        wl.position = Vector3(0.0, -0.95, 0.05)
        wl.rotation_degrees = Vector3(40.0, 0.0, 0.0)
        _arm_l.add_child(wl)
        _make_weapon(wl, "dagger", accent)
    if c.get("cape", false):
        _cape = Node3D.new()
        _cape.position = Vector3(0.0, 1.95, -0.32 * _bulk)
        _torso.add_child(_cape)
        var cm := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.85 * _bulk, 1.35, 0.05)
        cm.mesh = bm
        cm.material_override = RenewalArt.surface(accent.darkened(0.1), true)
        cm.position = Vector3(0.0, -0.68, 0.0)
        _cape.add_child(cm)
    _extras(c, body, accent, skin)
    RenewalArt.dress(self, _torso, _bulk, body, accent, team_col)
    # звёзды оглушения
    _stars = Node3D.new()
    _stars.position = Vector3(0.0, 0.55, 0.0)
    _head.add_child(_stars)
    for i in 3:
        var a := TAU / 3.0 * float(i)
        _sphere(_stars, 0.07, Vector3(cos(a) * 0.4, 0.0, sin(a) * 0.4), Color(1.0, 0.9, 0.2), 2.0)
    _stars.visible = false
    var vn := VisibleOnScreenNotifier3D.new()
    vn.aabb = AABB(Vector3(-2.5, -0.5, -2.5), Vector3(5.0, 6.5, 5.0))
    add_child(vn)
    vn.screen_entered.connect(func() -> void: set_process(true))
    vn.screen_exited.connect(func() -> void: set_process(false))
    # появление
    scale = Vector3.ONE * base_scale * 0.2
    _grow = 0.2


# ---------- конструкторы частей ----------
func _limb(pivot_pos: Vector3, radius: float, length: float, color: Color) -> Node3D:
    var pv := Node3D.new()
    pv.position = pivot_pos
    var mi := MeshInstance3D.new()
    mi.mesh = PrimitiveCache.capsule(radius, length, Global.quality)
    mi.material_override = Global.get_mat(color)
    mi.position = Vector3(0.0, -length * 0.5, 0.0)
    pv.add_child(mi)
    return pv

func enable_occlusion_outline() -> void:
    var outline := ShaderMaterial.new()
    outline.shader = preload("res://Shaders/hero_occlusion.gdshader")
    for mesh in find_children("*", "MeshInstance3D", true, false):
        mesh.material_overlay = outline


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = PrimitiveCache.box(size)
    mi.material_override = RenewalArt.surface(color) if glow == 0.0 else Global.get_mat(color, glow)
    mi.position = pos
    parent.add_child(mi)
    return mi


func _sphere(parent: Node3D, r: float, pos: Vector3, color: Color, glow: float) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = PrimitiveCache.sphere(r, Global.quality)
    mi.material_override = Global.get_mat(color, glow)
    mi.position = pos
    parent.add_child(mi)
    return mi


func _cyl(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = PrimitiveCache.cylinder(top_r, bot_r, h, Global.quality)
    mi.material_override = Global.get_mat(color, glow)
    mi.position = pos
    parent.add_child(mi)
    return mi


func _make_hat(kind: String, body: Color, accent: Color) -> void:
    var bone := Color(0.92, 0.88, 0.75)
    var metal := Color(0.72, 0.74, 0.8)
    match kind:
        "cone":
            _cyl(_head, 0.0, 0.42, 0.95, Vector3(0.0, 0.62, 0.0), body.darkened(0.1))
            _cyl(_head, 0.5, 0.5, 0.05, Vector3(0.0, 0.16, 0.0), body.darkened(0.2))
        "horns":
            var h1 := _cyl(_head, 0.0, 0.09, 0.5, Vector3(-0.24, 0.32, 0.0), bone)
            h1.rotation_degrees = Vector3(0.0, 0.0, 35.0)
            var h2 := _cyl(_head, 0.0, 0.09, 0.5, Vector3(0.24, 0.32, 0.0), bone)
            h2.rotation_degrees = Vector3(0.0, 0.0, -35.0)
        "helmet":
            _sphere(_head, 0.34, Vector3(0.0, 0.07, 0.0), metal, 0.0)
            _box(_head, Vector3(0.08, 0.3, 0.5), Vector3(0.0, 0.38, 0.0), accent)
        "hood":
            _sphere(_head, 0.37, Vector3(0.0, 0.03, -0.04), body.darkened(0.25), 0.0)
            _cyl(_head, 0.0, 0.22, 0.45, Vector3(0.0, 0.38, -0.12), body.darkened(0.25))
        "crown":
            _cyl(_head, 0.3, 0.3, 0.14, Vector3(0.0, 0.3, 0.0), Color(1.0, 0.85, 0.3), 0.6)
            for i in 4:
                var a := TAU / 4.0 * float(i)
                _cyl(_head, 0.0, 0.06, 0.2, Vector3(cos(a) * 0.26, 0.46, sin(a) * 0.26), Color(1.0, 0.85, 0.3), 0.6)
        "band":
            _cyl(_head, 0.32, 0.32, 0.09, Vector3(0.0, 0.14, 0.0), accent)


func _make_weapon(parent: Node3D, kind: String, accent: Color) -> void:
    var wood := Color(0.45, 0.3, 0.18)
    var steel := Color(0.8, 0.82, 0.88)
    match kind:
        "hammer":
            _cyl(parent, 0.06, 0.06, 1.4, Vector3(0.0, 0.7, 0.0), wood)
            _box(parent, Vector3(0.55, 0.42, 0.42), Vector3(0.0, 1.45, 0.0), Color(0.55, 0.55, 0.62))
        "staff":
            _cyl(parent, 0.05, 0.05, 2.0, Vector3(0.0, 0.8, 0.0), wood)
            _sphere(parent, 0.2, Vector3(0.0, 1.9, 0.0), accent, 2.5)
        "dagger", "daggers":
            _box(parent, Vector3(0.07, 0.55, 0.15), Vector3(0.0, 0.4, 0.0), steel)
            _box(parent, Vector3(0.3, 0.06, 0.1), Vector3(0.0, 0.1, 0.0), accent)
        "bow":
            var b1 := _box(parent, Vector3(0.06, 0.8, 0.06), Vector3(0.0, 0.95, 0.12), wood)
            b1.rotation_degrees = Vector3(20.0, 0.0, 0.0)
            var b2 := _box(parent, Vector3(0.06, 0.8, 0.06), Vector3(0.0, 0.25, 0.12), wood)
            b2.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
            _box(parent, Vector3(0.015, 1.5, 0.015), Vector3(0.0, 0.6, 0.0), Color(0.9, 0.9, 0.8))
        "sword":
            _box(parent, Vector3(0.11, 1.15, 0.04), Vector3(0.0, 0.85, 0.0), steel)
            _box(parent, Vector3(0.42, 0.08, 0.12), Vector3(0.0, 0.25, 0.0), accent)
            _cyl(parent, 0.04, 0.04, 0.25, Vector3(0.0, 0.1, 0.0), wood)
        "axe":
            _cyl(parent, 0.05, 0.05, 1.3, Vector3(0.0, 0.65, 0.0), wood)
            _box(parent, Vector3(0.55, 0.5, 0.08), Vector3(0.25, 1.15, 0.0), Color(0.6, 0.6, 0.66))
        "wand":
            _cyl(parent, 0.03, 0.03, 0.75, Vector3(0.0, 0.35, 0.0), wood)
            _sphere(parent, 0.11, Vector3(0.0, 0.8, 0.0), accent, 3.0)
        "spear":
            _cyl(parent, 0.04, 0.04, 2.3, Vector3(0.0, 0.9, 0.0), wood)
            _cyl(parent, 0.0, 0.1, 0.45, Vector3(0.0, 2.2, 0.0), steel)
        "club":
            _cyl(parent, 0.14, 0.07, 1.0, Vector3(0.0, 0.5, 0.0), wood)
        "fists":
            _sphere(parent, 0.17, Vector3.ZERO, accent, 0.4)


# ---------- управление анимацией ----------
func set_moving(m: bool) -> void:
    moving = m


func set_stunned(s: bool) -> void:
    stunned = s
    if _stars != null:
        _stars.visible = s and not dead


func play_attack(ranged: bool) -> void:
    _attack_t = ATTACK_DUR
    _attack_ranged = ranged


func play_cast() -> void:
    _cast_t = CAST_DUR


func play_death() -> void:
    dead = true
    if _stars != null:
        _stars.visible = false


func revive() -> void:
    dead = false
    _dead_t = 0.0
    _root.rotation = Vector3.ZERO
    _root.position = Vector3.ZERO
    _grow = 0.2


func flash() -> void:
    _flash_t = 0.16


func grow(mult: float, dur: float) -> void:
    _grow_target = mult
    get_tree().create_timer(dur).timeout.connect(_end_grow)


func _end_grow() -> void:
    _grow_target = 1.0


# ---------- анимация ----------
func _process(delta: float) -> void:
    if _root == null:
        return
    if _asset_player != null:
        _attack_t = maxf(0.0, _attack_t - delta)
        _cast_t = maxf(0.0, _cast_t - delta)
        var clip := "Death" if dead else ("Stun" if stunned else ("Attack" if _attack_t > 0 else ("Cast" if _cast_t > 0 else ("Run" if moving else "Idle"))))
        if clip != _asset_clip:
            _asset_clip = clip
            if _asset_player.has_animation(clip):
                _asset_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip in ["Idle", "Run", "Stun"] else Animation.LOOP_NONE
                _asset_player.play(clip, 0.08)
        scale = Vector3.ONE * base_scale * _grow_target
        return
    _animation_acc += delta
    var interval: float = 0.05 if Global.quality == 0 else (1.0 / 30.0 if Global.quality == 1 else 0.0)
    if _animation_acc < interval:
        return
    delta = _animation_acc
    _animation_acc = 0.0
    _t += delta
    if dead:
        _dead_t += delta
        var kd := clampf(_dead_t / 0.6, 0.0, 1.0)
        _root.rotation.x = lerpf(0.0, -1.5, kd)
        _root.position.y = lerpf(0.0, 0.25, kd)
        return
    _grow = lerpf(_grow, _grow_target, clampf(delta * 5.0, 0.0, 1.0))
    var desired_scale := Vector3.ONE * base_scale * _grow
    if scale != desired_scale:
        scale = desired_scale
    if _flash_t > 0.0:
        _flash_t -= delta
    var f := maxf(_flash_t, 0.0) * 1.4
    _root.scale = Vector3(1.0 + f, 1.0 - f * 0.5, 1.0 + f)
    var target_amp := 1.0 if moving else 0.0
    _amp = lerpf(_amp, target_amp, clampf(delta * 10.0, 0.0, 1.0))
    if moving:
        _run += delta * 11.0
    var sw := sin(_run)
    var idle := sin(_t * 2.0)
    _leg_l.rotation.x = sw * 0.9 * _amp
    _leg_r.rotation.x = -sw * 0.9 * _amp
    var al := -sw * 0.8 * _amp + idle * 0.05 * (1.0 - _amp)
    var ar := sw * 0.8 * _amp - idle * 0.05 * (1.0 - _amp) - 0.35
    if not moving and _attack_t <= 0.0 and _cast_t <= 0.0:
        match str(cfg.get("weapon", "")):
            "bow":
                al = -0.9
                ar = -1.1
            "staff": ar = -0.65
            "hammer": ar = -0.8
            "daggers":
                al = -0.35
                ar = -0.35
    var twist := 0.0
    if _attack_t > 0.0:
        _attack_t -= delta
        var ka := 1.0 - clampf(_attack_t / ATTACK_DUR, 0.0, 1.0)
        if _attack_ranged:
            ar = lerpf(-1.7, -1.4, ka)
            al = -1.5
        else:
            if ka < 0.4:
                ar = lerpf(-0.35, -2.6, ka / 0.4)
            else:
                ar = lerpf(-2.6, 0.7, minf((ka - 0.4) / 0.3, 1.0))
            twist = sin(ka * PI) * 0.35
    if _cast_t > 0.0:
        _cast_t -= delta
        var up := sin((1.0 - clampf(_cast_t / CAST_DUR, 0.0, 1.0)) * PI)
        al = lerpf(al, -2.6, up)
        ar = lerpf(ar, -2.6, up)
    _arm_l.rotation = Vector3(al, 0.0, 0.12)
    _arm_r.rotation = Vector3(ar, 0.0, -0.12)
    _torso.rotation.y = twist
    _torso.rotation.x = 0.18 * _amp + sin(_t * 2.0) * 0.015
    _root.position.y = absf(sin(_run)) * 0.14 * _amp
    _head.rotation.y = sin(_t * 0.7) * 0.15
    if stunned:
        _head.rotation.z = sin(_t * 18.0) * 0.35
        _stars.rotation.y += delta * 6.0
    else:
        _head.rotation.z = lerpf(_head.rotation.z, 0.0, 0.2)
    if _cape != null:
        _cape.rotation.x = 0.15 + 0.5 * _amp + sin(_t * 3.0) * 0.08
    for i in _wings.size():
        (_wings[i] as Node3D).rotation.z = (1.0 if i == 1 else -1.0) * (0.25 + sin(_t * (5.0 + 9.0 * _amp)) * 0.35)
    if _tail != null:
        _tail.rotation.y = sin(_t * 2.0 + _run) * 0.35 * (0.3 + _amp)
    if _orbs != null:
        _orbs.rotation.y += delta * 1.6
    if _aura != null:
        _aura.rotation.y += delta * 0.8
        _aura.scale = Vector3.ONE * (1.0 + sin(_t * 2.0) * 0.05)


# Детали героя: сапоги, перчатки, наплечники, волосы, лицо, плюм, щит, эмблема, крылья, хвост, орбы, аура.
func _extras(c: Dictionary, body: Color, accent: Color, skin: Color) -> void:
    var b := _bulk
    var boots: Color = c.get("boots", body.darkened(0.55))
    for leg in [_leg_l, _leg_r]:
        _box(leg, Vector3(0.36 * b, 0.24, 0.55 * b), Vector3(0.0, -1.0, 0.1), boots)
    var glove: Color = c.get("gloves", boots)
    for arm in [_arm_l, _arm_r]:
        _sphere(arm, 0.17 * b, Vector3(0.0, -0.98, 0.0), glove, 0.0)
    var pd: String = c.get("pauldron", "none")
    for sx in [-1.0, 1.0]:
        var px: float = float(sx) * 0.72 * b
        match pd:
            "round":
                _sphere(_torso, 0.38 * b, Vector3(px, 2.0, 0.0), accent.darkened(0.1), 0.0)
            "spiked":
                _sphere(_torso, 0.32 * b, Vector3(px, 2.0, 0.0), accent.darkened(0.15), 0.0)
                var sp := _cyl(_torso, 0.0, 0.13 * b, 0.6, Vector3(px, 2.45, 0.0), accent.lightened(0.25))
                sp.rotation_degrees = Vector3(0.0, 0.0, -28.0 * float(sx))
            "plate":
                _box(_torso, Vector3(0.55 * b, 0.16, 0.62 * b), Vector3(px, 2.05, 0.0), accent.darkened(0.25))
    var hair: Color = c.get("hair_color", Color(0.25, 0.18, 0.1))
    match str(c.get("hair", "none")):
        "short":
            _sphere(_head, 0.33, Vector3(0.0, 0.07, -0.03), hair, 0.0)
        "long":
            _sphere(_head, 0.33, Vector3(0.0, 0.07, -0.03), hair, 0.0)
            _box(_head, Vector3(0.5, 0.9, 0.12), Vector3(0.0, -0.4, -0.28), hair)
        "mohawk":
            _box(_head, Vector3(0.1, 0.32, 0.55), Vector3(0.0, 0.36, -0.02), hair)
    match str(c.get("face", "none")):
        "mask":
            _box(_head, Vector3(0.5, 0.26, 0.12), Vector3(0.0, -0.12, 0.27), body.darkened(0.3))
        "visor":
            _box(_head, Vector3(0.52, 0.1, 0.1), Vector3(0.0, 0.05, 0.28), accent, 2.5)
        "beard":
            _box(_head, Vector3(0.4, 0.45, 0.14), Vector3(0.0, -0.32, 0.22), c.get("beard_color", Color(0.85, 0.85, 0.85)))
    if c.has("plume"):
        var pl := _cyl(_head, 0.0, 0.1, 0.9, Vector3(0.0, 0.55, -0.15), c["plume"])
        pl.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
    if c.get("shield", false):
        _box(_arm_l, Vector3(0.12, 0.95, 0.75), Vector3(-0.2 * b, -0.75, 0.3), body.lightened(0.3))
        _box(_arm_l, Vector3(0.14, 0.3, 0.3), Vector3(-0.28 * b, -0.75, 0.3), accent, 1.5)
    if c.has("emblem"):
        _box(_torso, Vector3(0.28 * b, 0.28, 0.06), Vector3(0.0, 1.62, 0.3 * b), c["emblem"], 3.0)
        _sphere(_torso, 0.1, Vector3(0.0, 1.05, 0.34 * b), c["emblem"], 2.5)
    if c.has("wings"):
        for sx in [-1.0, 1.0]:
            var pv := Node3D.new()
            pv.position = Vector3(0.25 * float(sx), 1.9, -0.3)
            _torso.add_child(pv)
            var w := _box(pv, Vector3(1.9, 0.08, 1.1), Vector3(float(sx) * 1.0, 0.0, -0.2), c["wings"], 0.6)
            w.rotation_degrees = Vector3(0.0, float(sx) * -15.0, 0.0)
            _wings.append(pv)
    if c.get("tail", false):
        _tail = Node3D.new()
        _tail.position = Vector3(0.0, 1.0, -0.3)
        _root.add_child(_tail)
        for k in 4:
            _sphere(_tail, 0.2 - 0.03 * float(k), Vector3(0.0, -0.1 * float(k), -0.45 * float(k + 1)), c.get("tail_color", body), 0.0)
    var n := int(c.get("orbs", 0))
    if n > 0:
        _orbs = Node3D.new()
        _orbs.position = Vector3(0.0, 1.7, 0.0)
        _root.add_child(_orbs)
        var oc: Color = c.get("orb_color", accent)
        for k in n:
            var a := TAU / float(n) * float(k)
            _sphere(_orbs, 0.2, Vector3(cos(a) * 1.4, sin(a * 2.0) * 0.3, sin(a) * 1.4), oc, 3.0)
    if c.has("aura"):
        _aura = MeshInstance3D.new()
        var tm := TorusMesh.new()
        tm.inner_radius = 1.3
        tm.outer_radius = 1.5
        tm.rings = 32
        _aura.mesh = tm
        _aura.material_override = Global.get_mat(c["aura"], 0.25)
        _aura.position.y = 0.08
        add_child(_aura)
