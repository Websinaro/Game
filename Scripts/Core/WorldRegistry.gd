class_name WorldRegistry
extends RefCounted
## Shared placement registry. Regions register circular exclusion zones
## (buildings, paths of interest, story objects) so that vegetation scatter
## from any region avoids them. Cleared whenever the world is rebuilt.

static var _zones: Array[Vector3] = []

static func clear() -> void:
	_zones.clear()

static func add_exclusion(x: float, z: float, radius: float) -> void:
	_zones.append(Vector3(x, z, radius))

static func is_excluded(x: float, z: float, margin: float = 0.0) -> bool:
	for zone: Vector3 in _zones:
		var dx: float = x - zone.x
		var dz: float = z - zone.y
		var r: float = zone.z + margin
		if dx * dx + dz * dz < r * r:
			return true
	return false
