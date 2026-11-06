class_name PrimitiveCache
extends RefCounted
## Immutable shared geometry. Callers animate instances, never these meshes.
static var _meshes: Dictionary = {}
static func box(size: Vector3) -> BoxMesh:
    var key := "box:" + str(size)
    if not _meshes.has(key):
        var mesh := BoxMesh.new()
        mesh.size = size
        _meshes[key] = mesh
    return _meshes[key]
static func sphere(radius: float, quality: int) -> SphereMesh:
    var key := "sphere:%s:%d" % [radius, quality]
    if not _meshes.has(key):
        var mesh := SphereMesh.new()
        mesh.radius = radius
        mesh.height = radius * 2.0
        mesh.radial_segments = [8, 12, 20, 32][clampi(quality, 0, 3)]
        mesh.rings = [4, 6, 10, 16][clampi(quality, 0, 3)]
        _meshes[key] = mesh
    return _meshes[key]
static func cylinder(top: float, bottom: float, height: float, quality: int) -> CylinderMesh:
    var key := "cylinder:%s:%s:%s:%d" % [top, bottom, height, quality]
    if not _meshes.has(key):
        var mesh := CylinderMesh.new()
        mesh.top_radius = top
        mesh.bottom_radius = bottom
        mesh.height = height
        mesh.radial_segments = [8, 12, 20, 32][clampi(quality, 0, 3)]
        _meshes[key] = mesh
    return _meshes[key]
static func capsule(radius: float, height: float, quality: int) -> CapsuleMesh:
    var key := "capsule:%s:%s:%d" % [radius, height, quality]
    if not _meshes.has(key):
        var mesh := CapsuleMesh.new()
        mesh.radius = radius
        mesh.height = height
        mesh.radial_segments = [8, 12, 20, 32][clampi(quality, 0, 3)]
        mesh.rings = [2, 4, 6, 8][clampi(quality, 0, 3)]
        _meshes[key] = mesh
    return _meshes[key]
