class_name Interact
extends Area3D
## Something Tesu can do something to: untie a knot, talk, read a cord.

var prompt := "interact"
var enabled := true
var callback: Callable
var once := false


static func make(parent: Node, pos: Vector3, text: String, cb: Callable, size: Vector3 = Vector3(1.6, 2.0, 2.0), one_shot: bool = false) -> Interact:
	var i := Interact.new()
	i.prompt = text
	i.callback = cb
	i.once = one_shot
	i.collision_layer = 32
	i.collision_mask = 0
	i.monitoring = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	i.add_child(cs)
	parent.add_child(i)
	i.position = pos
	return i


func interact(p: Node) -> void:
	if not enabled:
		return
	if once:
		enabled = false
	if callback.is_valid():
		callback.call(p)
