extends Enemy
## The Thirsty (pyaase): the drought's dead, with skin like the cracked
## riverbed. They smell water from a long way off, and Tesu carries a gourd
## of it. Pour water on the ground [R] and they crawl to it.

var drinking := 0.0
var target_puddle: Node3D
var grab_cd := 0.0


func setup() -> void:
	hp = 2
	speed = 1.9
	damage = 0
	radius = 0.35
	height = 0.8
	var cm := CharModel.make("thirsty", {"stepped": true, "step_fps": 7.0})
	cm.speed_mult = randf_range(0.85, 1.15)
	if cm.player != null:
		puppet = cm
	else:
		puppet = Fig.human({"name": "Thirsty", "height": 1.6, "clay": Fig.clay_mat(Color(0.7, 0.64, 0.56), "silt"), "head": "bald", "thin": 0.65, "stepped": true})
	add_child(puppet)
	puppet.step_fps = 7.0
	shard_color = Color(0.62, 0.56, 0.48)


func think(delta: float) -> void:
	grab_cd = max(0.0, grab_cd - delta)
	if drinking > 0.0:
		drinking -= delta
		velocity.x = 0.0
		puppet.anim("crawl", 0.0)
		return
	# puddles first
	var best: Node3D = null
	var bd := 16.0
	for pd in get_tree().get_nodes_in_group("puddle"):
		var d: float = (pd as Node3D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = pd
	if best:
		move_toward_x(best.global_position.x, speed * 1.3, delta)
		puppet.anim("crawl", 1.0)
		if abs(best.global_position.x - global_position.x) < 0.5:
			drinking = 7.0
			Snd.sfx("drip", global_position)
		return
	var p := player()
	if p and Game.water > 0.05 and dist_to_player() < 15.0:
		move_toward_x(p.global_position.x, speed, delta)
		puppet.anim("crawl", 1.0)
		if not ledge_ahead():
			velocity.x = 0.0
		if dist_to_player() < 1.0 and grab_cd <= 0.0:
			grab_cd = 1.6
			if p.take_damage(1, global_position, "grab"):
				Game.water = max(0.0, Game.water - 0.25)
				Game.inventory_changed.emit()
				Snd.sfx("pour", global_position, -4)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		puppet.anim("crawl", 0.0)
