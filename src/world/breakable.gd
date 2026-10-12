class_name Breakable
extends StaticBody3D
## Pots, bells, raw-clay walls, and gates that answer to words.

signal broken
signal rung

var kind := "pot"        # pot / bell / wall / gate / lamp
var hp := 1
var size := Vector3(1, 3, 2)
var opens_to := ""       # gate: "open" / "break" / "name"
var gate_name := ""
var drops := 2
var _vis: Node3D
var _gone := false
var _swing := 0.0


func _ready() -> void:
	collision_layer = 4 | (1 if kind in ["wall", "gate"] else 0)
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	_vis = Node3D.new()
	add_child(_vis)
	match kind:
		"pot":
			bs.size = Vector3(0.6, 0.6, 0.6)
			cs.position = Vector3(0, 0.3, 0)
			B.pot(_vis, Vector3.ZERO, ["matka", "surahi", "lota"][randi() % 3], randf_range(0.9, 1.3))
		"bell":
			bs.size = Vector3(0.4, 0.5, 0.4)
			cs.position = Vector3(0, -0.25, 0)
			B.add_mesh(_vis, B.cyl(0.015, 0.015, 1.2, 4), B.mat("rope", 3.0), Vector3(0, 0.3, 0))
			var bell := B.add_mesh(_vis, B.lathe_mesh("bell", 16), B.mat("brass"), Vector3(0, -0.4, 0), Vector3.ZERO, Vector3.ONE * 2.4)
			bell.name = "bell"
		"wall":
			bs.size = size
			cs.position = Vector3(0, size.y * 0.5, 0)
			B.add_mesh(_vis, B.mesh_box(size), B.mat("clay_raw"), Vector3(0, size.y * 0.5, 0))
			for i in 6:
				B.add_mesh(_vis, B.sphere(randf_range(0.2, 0.45), -1, 10), B.mat("clay_raw"), Vector3(randf_range(-0.3, 0.3), randf_range(0.3, size.y - 0.3), size.z * 0.4))
			B.chalk(_vis, Vector3(0, size.y * 0.5, size.z * 0.5 + 0.05), "cross", 1.0)
		"gate":
			bs.size = size
			cs.position = Vector3(0, size.y * 0.5, 0)
			var gm := B.mat("terracotta", 1.0)
			B.add_mesh(_vis, B.mesh_box(size), gm, Vector3(0, size.y * 0.5, 0))
			# five sealed doors carved in the gate
			for i in 5:
				B.add_mesh(_vis, B.mesh_box(Vector3(0.12, 0.3, 0.06)), B.mat("dark"), Vector3(0, 0.6 + i * 0.45, size.z * 0.5))
			var glyph := {"open": "खुल", "break": "टूट", "shut": "बंद", "name": "?"}.get(opens_to, "")
			if glyph != "":
				var l := B.label(_vis, Vector3(0, size.y * 0.8, size.z * 0.5 + 0.05), glyph, 96, Color(1.0, 0.8, 0.5, 0.8), Hud.font_deva())
				l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			B.glow_card(_vis, Vector3(0, size.y * 0.8, size.z * 0.5 + 0.1), 1.5, Color(1.0, 0.6, 0.3, 0.25))
	cs.shape = bs
	add_child(cs)
	if kind == "gate":
		Game.word_spoken.connect(_on_word)


func _process(delta: float) -> void:
	if kind == "bell" and _swing > 0.0:
		_swing = max(0.0, _swing - delta * 0.6)
		_vis.rotation.z = sin(Time.get_ticks_msec() * 0.012) * _swing * 0.6


func take_hit(_dmg: int, from: Vector3, kind_hit: String = "paddle") -> void:
	if _gone:
		return
	match kind:
		"bell":
			_ring()
		"pot":
			_break()
		"wall":
			if kind_hit == "word":
				_break()
			else:
				hp -= 1
				Fx.shards(global_position + Vector3(0, 1, size.z * 0.4), 5, Color(0.42, 0.28, 0.2), 0.12, 3.0)
				Snd.sfx("hit_clay%d" % (randi() % 3), global_position)
				if hp <= 0:
					_break()
		"gate":
			Snd.sfx("block", global_position)
			if opens_to == "open" or opens_to == "break":
				Game.show_hint("It won't move. It answers to a word.")


func on_pellet() -> void:
	take_hit(1, global_position, "pellet")


func _ring() -> void:
	_swing = 1.0
	Snd.sfx("bell", global_position, 0)
	Game.emit_noise(global_position, 14.0)
	Fx.ring(global_position + Vector3(0, -0.4, 0.2), 2.0, Color(1.0, 0.85, 0.5, 0.6), 0.6)
	rung.emit()


func _break() -> void:
	if _gone:
		return
	_gone = true
	Snd.sfx("shatter", global_position, -2 if kind == "pot" else 2)
	var c := Color(0.7, 0.35, 0.2) if kind != "wall" else Color(0.38, 0.25, 0.18)
	Fx.shards(global_position + Vector3(0, 0.4 if kind == "pot" else size.y * 0.5, 0), 10 if kind == "pot" else 22, c, 0.1 if kind == "pot" else 0.25, 5.0)
	Fx.dust(global_position + Vector3(0, 0.5, 0), 12)
	Game.emit_noise(global_position, 8.0)
	if kind == "pot":
		for i in drops:
			var pk := Pickup.new()
			pk.kind = "pellets"
			pk.amount = 2
			get_parent().add_child(pk)
			pk.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 0.2, 0)
	broken.emit()
	queue_free()


func open() -> void:
	if _gone:
		return
	_gone = true
	collision_layer = 0
	Snd.sfx("rumble", global_position, -4)
	Fx.dust(global_position + Vector3(0, 0.3, 0), 20)
	Fx.shake(0.3)
	var t := create_tween()
	t.tween_property(_vis, "position:y", -size.y - 0.2, 1.6).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(queue_free)
	broken.emit()


func _on_word(word: String, pos: Vector3, _b: bool) -> void:
	if _gone or global_position.distance_to(pos) > Player.WORD_RADIUS + 1.0:
		return
	if opens_to == "open" and word == "open":
		open()
	elif opens_to == "break" and word == "break":
		_break()
	elif opens_to == "shut" and word == "shut":
		open()


static func make(parent: Node, pos: Vector3, k: String, opts: Dictionary = {}) -> Breakable:
	var b := Breakable.new()
	b.kind = k
	for key in opts:
		b.set(key, opts[key])
	parent.add_child(b)
	b.position = pos
	return b
