class_name OneWay
extends StaticBody3D
## A platform Tesu can jump up through from below (eaves, ledges, rings).

var top := 0.0


func _physics_process(_delta: float) -> void:
	var p: Node3D = Game.player
	if p == null or not is_instance_valid(p):
		return
	var feet: float = p.global_position.y
	var falling: bool = (p as CharacterBody3D).velocity.y <= 0.5
	var dropping: bool = Input.is_action_pressed("down") and Input.is_action_pressed("jump")
	collision_layer = 1 if feet >= top - 0.12 and falling and not dropping else 0


static func make(parent: Node, center: Vector3, size: Vector3, m: Material) -> OneWay:
	var o := OneWay.new()
	o.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	o.add_child(cs)
	if m:
		var mi := MeshInstance3D.new()
		mi.mesh = B.mesh_box(size)
		mi.material_override = m
		o.add_child(mi)
	parent.add_child(o)
	o.position = center
	o.top = center.y + size.y * 0.5
	return o
