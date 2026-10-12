extends Enemy
## Stokers (jhonkne-wale): Gaara's fire-tenders. Faceless, carrying baskets
## of burning dung cakes on their heads. They find you by the heat of your
## body. Fired skin runs cold: they walk right past you.

var a := 0.0
var b := 0.0
var throw_cd := 0.0
var sees := false


func setup() -> void:
	hp = 3
	speed = 1.5
	damage = 1
	puppet = Fig.human({"name": "Stoker", "height": 1.85, "clay": Fig.clay_mat(Color(0.3, 0.22, 0.18), "terracotta"), "head": "bald", "faceless": true, "stepped": true, "bulk": 1.2})
	add_child(puppet)
	puppet.anim("carry")
	var head: Node3D = puppet.parts["head"]
	var basket := B.add_mesh(head, B.cyl(0.32, 0.22, 0.22, 14), B.mat("rope", 3.0), Vector3(0, 0.36, 0))
	basket.name = "basket"
	B.flame(head, Vector3(0, 0.5, 0), 2.2, true, 1.6)
	shard_color = Color(0.3, 0.22, 0.18)
	if a == 0.0 and b == 0.0:
		a = global_position.x - 4.0
		b = global_position.x + 4.0


func think(delta: float) -> void:
	throw_cd = max(0.0, throw_cd - delta)
	var p := player()
	sees = p != null and p.is_hot() and dist_to_player() < 8.0 and p.state != "dead"
	if sees:
		facing = int(dir_to_player())
		move_toward_x(p.global_position.x, speed * 1.4, delta)
		puppet.anim("carry", 0.6)
		if not ledge_ahead():
			velocity.x = 0.0
		if throw_cd <= 0.0 and dist_to_player() > 2.0:
			throw_cd = 2.2
			_throw(p)
		return
	var tx := b if facing > 0 else a
	move_toward_x(tx, speed, delta)
	puppet.anim("carry", 0.3)
	if abs(global_position.x - tx) < 0.3 or not ledge_ahead():
		facing = -facing


func _throw(p: Player) -> void:
	var cake := DungCake.new()
	Game.level.add_child(cake)
	cake.global_position = global_position + Vector3(0, 2.2, 0)
	var dx := p.global_position.x - global_position.x
	cake.velocity = Vector3(dx * 0.9, 7.0, 0)
	Snd.sfx("fire_whoosh", global_position, -4)
