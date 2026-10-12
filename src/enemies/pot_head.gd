extends Enemy
## Pot-heads (matka-sir): figures with clay water-pots for heads. The pots
## ring with every sound in the room, and the figures turn toward it.

var a := 0.0
var b := 0.0
var listen_t := 0.0
var rush_t := 0.0
var pot: MeshInstance3D
var attack_cd := 0.0


func setup() -> void:
	hp = 3
	speed = 1.2
	damage = 1
	puppet = Fig.clay_person(1.75, Color(0.55, 0.42, 0.35), "silt", true)
	add_child(puppet)
	var head: Node3D = puppet.parts["head"]
	head.get_node("skull").visible = false
	pot = B.pot(head, Vector3(0, -0.02, 0), "matka", 0.85, B.mat("terracotta", 2.0))
	shard_color = Color(0.55, 0.42, 0.35)
	if a == 0.0 and b == 0.0:
		a = global_position.x - 3.0
		b = global_position.x + 3.0


func heard(pos: Vector3) -> void:
	noise_pos = pos
	listen_t = 0.4
	rush_t = 4.0
	# the pot rings with every sound in the room
	pot.rotation.z = 0.25
	create_tween().tween_property(pot, "rotation:z", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC)


func think(delta: float) -> void:
	attack_cd = max(0.0, attack_cd - delta)
	if listen_t > 0.0:
		listen_t -= delta
		facing = 1 if noise_pos.x > global_position.x else -1
		velocity.x = 0.0
		puppet.anim("idle")
		return
	if rush_t > 0.0 and noise_pos != Vector3.INF:
		rush_t -= delta
		move_toward_x(noise_pos.x, 4.2, delta, 30.0)
		puppet.anim("run", 0.8)
		if not ledge_ahead():
			velocity.x = 0.0
		var p := player()
		if p and dist_to_player() < 1.3 and attack_cd <= 0.0:
			attack_cd = 1.0
			puppet.anim("attack", 0, 1)
		if abs(noise_pos.x - global_position.x) < 0.4:
			rush_t = 0.0
			noise_pos = Vector3.INF
		return
	var tx := b if facing > 0 else a
	move_toward_x(tx, speed, delta)
	puppet.anim("walk", 0.3)
	if abs(global_position.x - tx) < 0.3 or not ledge_ahead() or wall_ahead():
		facing = -facing
