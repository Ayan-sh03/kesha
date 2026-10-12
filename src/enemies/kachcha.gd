extends Enemy
## Kachcha, the unfired: raw-clay people Gaara hasn't fired yet. Wet, heavy
## and cold. They grab, and you feel the weight drag you before you see
## them. A paddle-block cracks clay off them.

var holding := false
var hold_t := 0.0


func setup() -> void:
	hp = 4
	speed = 1.3
	damage = 0
	knock_resist = 0.5
	var cm := CharModel.make("kachcha", {"stepped": true, "step_fps": 6.0})
	cm.speed_mult = randf_range(0.85, 1.1)
	if cm.player != null:
		puppet = cm
		add_child(puppet)
	else:
		puppet = Fig.clay_person(1.7, Color(0.75, 0.68, 0.62), "raw", true)
		puppet.step_fps = 6.0
		add_child(puppet)
	# lumps of unfired clay (the generated model is already lumpy)
	for i in (0 if puppet is CharModel else 7):
		B.add_mesh(puppet.parts["chest"], B.sphere(randf_range(0.07, 0.14), -1, 8), B.mat("clay_raw"), Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.5), randf_range(-0.1, 0.12)))
	shard_color = Color(0.36, 0.25, 0.18)


func think(delta: float) -> void:
	var p := player()
	if p == null:
		return
	if holding:
		hold_t += delta
		velocity.x = 0.0
		puppet.anim("grab")
		if dist_to_player() > 1.8 or p.state == "dead":
			_let_go(p)
		elif hold_t > 1.6:
			hold_t = 0.0
			p.take_damage(1, global_position, "grab")
		return
	if dist_to_player() < 12.0:
		move_toward_x(p.global_position.x, speed, delta)
		puppet.anim("walk", 0.3)
		if not ledge_ahead():
			velocity.x = 0.0
		if dist_to_player() < 0.9:
			holding = true
			hold_t = 0.0
			p.hold(self, 0.4)
			Snd.sfx("step_silt1", p.global_position, 4)
			if Game.has("skin"):
				Fx.pulse("hurt", 0.4)
	else:
		velocity.x = 0.0
		puppet.anim("idle")


func _let_go(p: Player) -> void:
	holding = false
	if is_instance_valid(p):
		p.release(self)


func on_parried(p: Player) -> void:
	_let_go(p)
	super.on_parried(p)


func take_hit(dmg: int, from: Vector3, kind: String = "paddle") -> void:
	super.take_hit(dmg, from, kind)
	if stunned > 0.0 and holding:
		_let_go(player())


func on_death() -> void:
	_let_go(player())
