class_name Pickup
extends Node3D
## Pellets (from broken pots), spare clay lamps, water for the gourd.

var kind := "pellets"
var amount := 4
var _vis: Node3D
var _t := 0.0
var _taken := false


func _ready() -> void:
	_t = randf() * 6.0
	_vis = Node3D.new()
	add_child(_vis)
	match kind:
		"pellets":
			for i in 5:
				B.add_mesh(_vis, B.sphere(0.06, -1, 8), B.mat("terracotta", 6.0), Vector3(randf_range(-0.12, 0.12), 0.06 + i * 0.02, randf_range(-0.1, 0.1)))
			B.pot(_vis, Vector3(0.18, 0, 0), "kulhad", 1.6).rotation.z = 1.4
		"lamp":
			B.diya(_vis, Vector3(0, 0.05, 0), true, 0.8)
		"water":
			B.pot(_vis, Vector3.ZERO, "lota", 1.5, B.mat("brass"))
	B.glow_card(self, Vector3(0, 0.25, 0.1), 0.9, Color(1.0, 0.8, 0.5, 0.25))
	var a := Props.area(self, Vector3(0, 0.5, 0), Vector3(1.0, 1.2, 2.0), 0, 2)
	a.body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	_vis.position.y = 0.05 + sin(_t * 2.0) * 0.04
	_vis.rotation.y += delta * 0.6


func _on_body(b: Node) -> void:
	if _taken or not (b is Player):
		return
	_taken = true
	match kind:
		"pellets":
			Game.add_pellets(amount)
			Game.show_hint("+%d pellets" % amount)
		"lamp":
			Game.add_lamps(amount)
			Game.show_hint("A spare clay lamp. [E] to set it down: it watches, and you wake there.")
		"water":
			Game.water = 1.0
			Game.leaking = false
			Game.inventory_changed.emit()
			Game.show_hint("The gourd is full. [R] to pour it out.")
	Snd.sfx("pickup", global_position, -2)
	Fx.embers(global_position + Vector3(0, 0.3, 0), 8, Color(1.0, 0.8, 0.5))
	var t := create_tween()
	t.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25)
	t.tween_callback(queue_free)
