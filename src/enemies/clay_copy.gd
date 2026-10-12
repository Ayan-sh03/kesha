extends Enemy
## Clay copies of Tesu, pulled up out of the wheel by Gaara.

var attack_cd := 0.0
var rising := 0.8


func setup() -> void:
	hp = 2
	speed = 3.4
	damage = 1
	var cm := CharModel.make("tesu", {"stepped": true, "step_fps": 8.0})
	puppet = cm if cm.player != null else Fig.tesu()
	puppet.set_material_all(Fig.clay_mat(Color(0.65, 0.5, 0.42), "raw"))
	puppet.stepped = true
	puppet.step_fps = 8.0
	add_child(puppet)
	shard_color = Color(0.45, 0.32, 0.25)


func think(delta: float) -> void:
	attack_cd = max(0.0, attack_cd - delta)
	if rising > 0.0:
		rising -= delta
		puppet.anim("cry")
		velocity.x = 0.0
		return
	var p := player()
	if p == null:
		return
	move_toward_x(p.global_position.x, speed, delta)
	puppet.anim("run", 0.8)
	if dist_to_player() < 1.2 and attack_cd <= 0.0:
		attack_cd = 1.2
		puppet.anim("attack", 0, randi() % 2)
