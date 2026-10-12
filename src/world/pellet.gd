class_name Pellet
extends Area3D
## A fired-clay sling pellet. Quiet, good for knocking lamps, bells and eyes.

var velocity := Vector3.ZERO
var shooter: Node = null
var life := 2.5
var hostile := false
var damage := 1


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 4 if not hostile else 1 | 2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.09
	cs.shape = sh
	add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = B.sphere(0.06, -1, 8)
	mi.material_override = B.mat("terracotta", 6.0) if not hostile else B.emissive(Color(1.0, 0.5, 0.15), 3.0)
	add_child(mi)
	body_entered.connect(_hit)
	area_entered.connect(_hit)


func _physics_process(delta: float) -> void:
	velocity.y -= 9.0 * delta
	global_position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _hit(b: Node) -> void:
	if b == shooter:
		return
	var t: Node = b
	if b.has_meta("hit_owner"):
		t = b.get_meta("hit_owner")
	if hostile:
		if t is Player:
			t.take_damage(damage, global_position, "hit")
	elif t.has_method("take_hit"):
		t.take_hit(damage, global_position, "pellet")
	elif t.has_method("on_pellet"):
		t.on_pellet()
	Snd.sfx("pellet_hit", global_position, -4)
	Fx.sparks(global_position, 6, Color(1.0, 0.8, 0.6))
	Fx.dust(global_position, 3)
	Game.emit_noise(global_position, 7.0)
	queue_free()
