extends Enemy
## Gaanth, the cord-keepers: keepers made of knotted rope, moving along
## Gaara's counting cords. They ask your name and tie a knot for it.
## Give a false name [F] and they stop to untie it. Without a voice they
## tie you down as nobody, and they keep coming.

var asking := 0.0
var tied_cd := 0.0
var _prompt: Interact


func setup() -> void:
	hp = 3
	speed = 1.8
	damage = 0
	clay = false
	var cm := CharModel.make("gaanth", {"stepped": true, "step_fps": 8.0})
	cm.speed_mult = randf_range(0.9, 1.1)
	if cm.player != null:
		puppet = cm
		add_child(puppet)
	else:
		puppet = Fig.human({"name": "Gaanth", "height": 1.9, "clay": Fig.clay_mat(Color(0.75, 0.62, 0.42), "terracotta"), "head": "bald", "faceless": true, "thin": 0.7, "stepped": true})
		puppet.set_material_all(B.mat("rope", 4.0))
		add_child(puppet)
	# knots all over it (the generated model is already knotted)
	for i in (0 if puppet is CharModel else 9):
		B.add_mesh(puppet.parts["chest"], B.sphere(0.06, -1, 8), B.mat("rope", 5.0), Vector3(randf_range(-0.15, 0.15), randf_range(0.0, 0.4), 0.12))
	shard_color = Color(0.7, 0.6, 0.4)
	hit_sound = "knot_untie"


func think(delta: float) -> void:
	tied_cd = max(0.0, tied_cd - delta)
	var p := player()
	if p == null:
		return
	if asking > 0.0:
		asking -= delta
		velocity.x = 0.0
		puppet.anim("reach")
		if Game.has("mouth") and Input.is_action_just_pressed("interact"):
			asking = 0.0
			Game.say("\"Mitti.\" A false name. It stops to untie it.", "", 2.5)
			Snd.sfx("knot_untie", global_position)
			stunned = 6.0
			puppet.anim("grab")
			return
		if asking <= 0.0:
			_tie(p)
		return
	if dist_to_player() < 1.1 and tied_cd <= 0.0:
		asking = 1.4 if Game.has("mouth") else 0.01
		if Game.has("mouth"):
			Game.say("Name?", "keeper", 1.4)
			Game.show_hint("[F] give it a false name")
		return
	if dist_to_player() < 14.0:
		move_toward_x(p.global_position.x, speed, delta)
		puppet.anim("walk", 0.4)
	else:
		velocity.x = 0.0
		puppet.anim("idle")


func _tie(p: Player) -> void:
	tied_cd = 3.0
	Snd.sfx("knot_untie", p.global_position, 2)
	Fx.text3d(p.global_position + Vector3(0, 2.0, 0), "गाँठ", Color(0.9, 0.8, 0.6), 80, 1.6, Hud.font_deva())
	p.take_damage(1, global_position, "grab")
	p.hold(self, 0.0)
	Game.say("It ties you down as " + ("Tesu." if Game.has("mouth") else "nobody."), "", 2.4)
	await get_tree().create_timer(2.2, false).timeout
	if is_instance_valid(p):
		p.release(self)


func on_word(word: String, pos: Vector3) -> void:
	if word == "break":
		take_hit(2, pos, "word")
	elif word == "open":
		stunned = 3.0  # it comes undone for a moment
