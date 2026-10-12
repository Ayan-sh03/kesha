class_name DungCake
extends Area3D
## A burning dung cake. Bursts into fire where it lands.

var velocity := Vector3.ZERO
var life := 4.0
var patch_time := 5.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.18
	cs.shape = sh
	add_child(cs)
	B.add_mesh(self, B.cyl(0.18, 0.18, 0.06, 10), Fig._m(Color(0.2, 0.15, 0.1)), Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
	B.flame(self, Vector3(0, 0.1, 0), 0.9, true, 1.0)
	body_entered.connect(_hit)


func _physics_process(delta: float) -> void:
	velocity.y -= 14.0 * delta
	global_position += velocity * delta
	rotation.z += delta * 8.0
	life -= delta
	if life <= 0.0:
		queue_free()


func _hit(b: Node) -> void:
	if b is Player:
		(b as Player).take_damage(1, global_position, "fire")
	FirePatch.spawn(Game.level, global_position, patch_time)
	Snd.sfx("fire_whoosh", global_position)
	Fx.embers(global_position, 20)
	queue_free()
