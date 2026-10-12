class_name FirePatch
extends Node3D
## Burning floor. Safe for fired skin.

var life := 5.0
var width := 1.6
var kind := "fire"


static func spawn(parent: Node, pos: Vector3, t: float = 5.0, w: float = 1.6, k: String = "fire") -> FirePatch:
	var f := FirePatch.new()
	f.life = t
	f.width = w
	f.kind = k
	parent.add_child(f)
	f.global_position = Vector3(pos.x, pos.y, 0)
	return f


func _ready() -> void:
	# snap to the floor below
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0), global_position + Vector3(0, -6, 0), 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		global_position.y = hit["position"].y
	Props.hazard(self, Vector3(0, 0.4, 0), Vector3(width, 0.8, 2.0), kind)
	var n := int(width / 0.5)
	for i in n:
		B.flame(self, Vector3(-width * 0.5 + (i + 0.5) * width / n, 0.05, 0), 1.2, i == n / 2, 1.2)
	B.add_mesh(self, B.mesh_box(Vector3(width, 0.02, 1.2)), B.emissive(Color(1.0, 0.35, 0.08), 2.0), Vector3(0, 0.01, 0))
	if life > 0.0:
		var t := create_tween()
		t.tween_interval(life)
		t.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.6)
		t.tween_callback(queue_free)
