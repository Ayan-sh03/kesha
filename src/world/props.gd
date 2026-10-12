class_name Props
extends RefCounted
## Small helpers to make trigger areas, interactables, hazards and climbables.


static func area(parent: Node, center: Vector3, size: Vector3, layer: int = 32, mask: int = 0) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = layer
	a.collision_mask = mask
	a.monitoring = mask != 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	a.add_child(cs)
	parent.add_child(a)
	a.position = center
	return a


static func trigger(parent: Node, center: Vector3, size: Vector3, cb: Callable, once: bool = true) -> Area3D:
	## Fires cb(player) when Tesu enters.
	var a := area(parent, center, size, 0, 2)
	var fired := [false]
	a.body_entered.connect(func(b: Node) -> void:
		if b is Player and not (once and fired[0]):
			fired[0] = true
			cb.call(b))
	return a


static func hazard(parent: Node, center: Vector3, size: Vector3, kind: String, deadly: bool = false) -> Area3D:
	var a := area(parent, center, size, 64, 0)
	a.set_meta("hazard", kind)
	a.set_meta("deadly", deadly)
	a.add_to_group("hazard_" + kind)
	return a


static func climb(parent: Node, center: Vector3, size: Vector3) -> Area3D:
	var a := area(parent, center, size, 128, 0)
	a.add_to_group("climb")
	return a
