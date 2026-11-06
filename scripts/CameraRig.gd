class_name CameraRig
extends Node3D
## CameraRig.gd — классическая MOBA-камера. ПК: колесо = зум, края экрана/стрелки = прокрутка, Пробел = к герою, Y = фиксация.
## Телефон: щипок = зум, два пальца = прокрутка карты, тап по миникарте = переместить камеру.

const MIN_DIST: float = 36.0
const MAX_DIST: float = 150.0
const PITCH: float = 57.0

var target: Node3D
var cam: Camera3D
var distance: float = 70.0
var locked: bool = true
var _want: float = 70.0
var _shake: float = 0.0
var _touches: Dictionary = {}


func _ready() -> void:
    cam = Camera3D.new()
    cam.far = 1600.0
    cam.fov = 50.0
    add_child(cam)
    cam.current = true
    add_to_group("camera_rig")
    _place()


func center() -> void:
    locked = true


func look_at_world(p: Vector3) -> void:
    locked = false
    global_position = Vector3(clampf(p.x, -Global.MAP_HALF, Global.MAP_HALF), 0.0, clampf(p.z, -Global.MAP_HALF, Global.MAP_HALF))


func shake(amount: float) -> void:
    _shake = maxf(_shake, amount)


func _process(delta: float) -> void:
    _shake = maxf(0.0, _shake - delta * 2.5)
    if Input.is_action_just_pressed("camera_lock"):
        locked = not locked
    if locked and is_instance_valid(target):
        global_position = global_position.lerp(target.global_position, clampf(delta * 7.0, 0.0, 1.0))
    if not Global.is_touch():
        _edge_scroll(delta)
    distance = lerpf(distance, _want, clampf(delta * 8.0, 0.0, 1.0))
    _place()


func _edge_scroll(delta: float) -> void:
    var dir := Vector3.ZERO
    if Input.is_key_pressed(KEY_LEFT):
        dir.x -= 1.0
    if Input.is_key_pressed(KEY_RIGHT):
        dir.x += 1.0
    if Input.is_key_pressed(KEY_UP):
        dir.z -= 1.0
    if Input.is_key_pressed(KEY_DOWN):
        dir.z += 1.0
    if Global.edge_scroll and DisplayServer.window_is_focused():
        var vp := get_viewport()
        var m := vp.get_mouse_position()
        var sz := vp.get_visible_rect().size
        if m.x >= 0.0 and m.y >= 0.0 and m.x <= sz.x and m.y <= sz.y:
            if m.x <= 3.0:
                dir.x -= 1.0
            elif m.x >= sz.x - 4.0:
                dir.x += 1.0
            if m.y <= 3.0:
                dir.z -= 1.0
            elif m.y >= sz.y - 4.0:
                dir.z += 1.0
    if dir != Vector3.ZERO:
        locked = false
        global_position += dir.normalized() * delta * distance * 1.6
        global_position.x = clampf(global_position.x, -Global.MAP_HALF, Global.MAP_HALF)
        global_position.z = clampf(global_position.z, -Global.MAP_HALF, Global.MAP_HALF)


func _place() -> void:
    var p := deg_to_rad(PITCH)
    cam.position = Vector3(0.0, sin(p) * distance, cos(p) * distance) + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake
    cam.rotation_degrees = Vector3(-PITCH, 0.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _want = clampf(_want - 5.0, MIN_DIST, MAX_DIST)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _want = clampf(_want + 5.0, MIN_DIST, MAX_DIST)
    elif event is InputEventMagnifyGesture and _touches.size() < 2:
        _want = clampf(_want / (event as InputEventMagnifyGesture).factor, MIN_DIST, MAX_DIST)


# Мультитач: щипок и прокрутка двумя пальцами.
func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_MIDDLE != 0:
        var rel := (event as InputEventMouseMotion).relative
        locked = false
        global_position -= Vector3(rel.x, 0.0, rel.y) * distance * 0.0022
        global_position.x = clampf(global_position.x, -Global.MAP_HALF, Global.MAP_HALF)
        global_position.z = clampf(global_position.z, -Global.MAP_HALF, Global.MAP_HALF)
        return
    if event is InputEventScreenTouch:
        var st := event as InputEventScreenTouch
        if st.pressed:
            _touches[st.index] = st.position
        else:
            _touches.erase(st.index)
        if _touches.size() >= 2:
            Global.pinch_latch = true
    elif event is InputEventScreenDrag:
        var sd := event as InputEventScreenDrag
        if not _touches.has(sd.index):
            return
        var old_d := _pinch_dist()
        var old_c := _centroid()
        _touches[sd.index] = sd.position
        if _touches.size() == 2:
            Global.pinch_latch = true
            _want = clampf(_want - (_pinch_dist() - old_d) * 0.06, MIN_DIST, MAX_DIST)
            var dc := _centroid() - old_c
            if dc.length() > 0.5:
                locked = false
                var k := distance * 0.0022
                global_position -= Vector3(dc.x, 0.0, dc.y) * k
                global_position.x = clampf(global_position.x, -Global.MAP_HALF, Global.MAP_HALF)
                global_position.z = clampf(global_position.z, -Global.MAP_HALF, Global.MAP_HALF)


func _pinch_dist() -> float:
    if _touches.size() < 2:
        return 0.0
    var v: Array = _touches.values()
    return (v[0] as Vector2).distance_to(v[1] as Vector2)


func _centroid() -> Vector2:
    if _touches.size() < 2:
        return Vector2.ZERO
    var v: Array = _touches.values()
    return ((v[0] as Vector2) + (v[1] as Vector2)) * 0.5
