extends Enemy
## Glazed Doubles (chamakdar): glazed pots that catch your lamplight and
## throw back a copy of you. The copies walk where you walk, until one of
## them doesn't. Break the pot, not the reflection.

var copy: Puppet
var copy_pos := Vector3.ZERO
var copy_state := "mimic"
var mimic_t := 0.0
var _copy_area: Area3D
var _copy_hit_cd := 0.0
var _mark: Sprite3D


func setup() -> void:
	hp = 2
	speed = 0.0
	damage = 0
	radius = 0.35
	height = 0.9
	no_gravity = true
	visual = Node3D.new()
	add_child(visual)
	B.pot(visual, Vector3.ZERO, "matka", 1.6, B.mat("glaze"))
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 0.9, 0.95)
	l.light_energy = 0.6
	l.omni_range = 3.0
	visual.add_child(l)
	l.position = Vector3(0, 0.6, 0.5)
	shard_color = Color(0.2, 0.55, 0.6)
	var cm := CharModel.make("tesu", {"stepped": true, "step_fps": 12.0})
	copy = cm if cm.player != null else Fig.tesu()
	copy.set_material_all(B.mat("glaze"))
	copy.stepped = true
	copy.step_fps = 12.0
	Game.level.add_child.call_deferred(copy)
	copy.visible = false
	_copy_area = Area3D.new()
	_copy_area.collision_layer = 4
	_copy_area.collision_mask = 2
	_copy_area.set_meta("hit_owner", self)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.2
	cs.shape = cap
	cs.position = Vector3(0, 0.6, 0)
	_copy_area.add_child(cs)
	copy.add_child(_copy_area)
	mimic_t = randf_range(4.0, 6.0)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead or copy == null or not copy.is_inside_tree():
		return
	var p := player()
	if p == null:
		return
	_copy_hit_cd = max(0.0, _copy_hit_cd - delta)
	var near := global_position.distance_to(p.global_position) < 12.0 and p.lamp_light.visible
	copy.visible = near
	if not near:
		copy_state = "mimic"
		mimic_t = randf_range(4.0, 6.0)
		return
	match copy_state:
		"mimic":
			# a mirror across the pot
			copy_pos = Vector3(2.0 * global_position.x - p.global_position.x, p.global_position.y, 0)
			copy.global_position = copy_pos
			copy.rotation_degrees.y = -80.0 * p.facing
			copy.anim(p.puppet.state, p.puppet.speed, p.puppet.sub)
			mimic_t -= delta
			if mimic_t <= 0.0:
				copy_state = "hunt"
				Snd.sfx("creak0", copy.global_position, 0)
		"hunt":
			var d := signf(p.global_position.x - copy_pos.x)
			copy_pos.x += d * 4.2 * delta
			copy_pos.y = lerp(copy_pos.y, p.global_position.y, delta * 4.0)
			copy.global_position = copy_pos
			copy.rotation_degrees.y = 80.0 * d
			copy.anim("run", 0.8)
			if copy_pos.distance_to(p.global_position) < 0.9 and _copy_hit_cd <= 0.0:
				copy.anim("attack", 0, 0)
				if p.take_damage(1, copy_pos, "hit"):
					_copy_hit_cd = 1.2
				copy_state = "mimic"
				mimic_t = randf_range(3.0, 5.0)


func take_hit(dmg: int, from: Vector3, kind: String = "paddle") -> void:
	var p := player()
	# hits that land near the copy only shatter the reflection; it reforms
	if copy and copy.visible and from.distance_to(copy.global_position) < from.distance_to(global_position):
		Fx.sparks(copy.global_position + Vector3(0, 0.8, 0), 18, Color(0.5, 0.95, 1.0))
		Snd.sfx("parry", copy.global_position, -4)
		copy_state = "mimic"
		mimic_t = 3.0
		Game.show_hint("Only a reflection. Break the pot.")
		return
	super.take_hit(dmg, from, kind)


func on_death() -> void:
	if copy:
		Fx.sparks(copy.global_position + Vector3(0, 0.8, 0), 24, Color(0.5, 0.95, 1.0))
		copy.queue_free()
