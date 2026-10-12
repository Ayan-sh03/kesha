class_name Enemy
extends CharacterBody3D
## Base for the things in the dark. Each one tests a door.

signal killed

var hp := 3
var max_hp := 3
var clay := true          # made of clay: stop-motion, Shut and Break work on it
var speed := 2.5
var damage := 1
var gravity := 30.0
var facing := 1
var puppet: Puppet
var visual: Node3D
var stunned := 0.0
var frozen_t := 0.0
var invuln := 0.0
var dead := false
var contact: Area3D
var contact_cd := 0.0
var flash_mat: StandardMaterial3D
var radius := 0.4
var height := 1.6
var knock_resist := 0.0
var drops := 2
var hit_sound := "hit_clay"
var shard_color := Color(0.7, 0.35, 0.2)
var aware := false
var home := Vector3.ZERO
var noise_pos := Vector3.INF
var no_gravity := false
var _t := 0.0


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	axis_lock_linear_z = true
	home = global_position
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = max(height, radius * 2.0)
	cs.shape = cap
	cs.position = Vector3(0, height * 0.5, 0)
	add_child(cs)
	contact = Area3D.new()
	contact.collision_layer = 0
	contact.collision_mask = 2
	var cs2 := CollisionShape3D.new()
	var cap2 := CapsuleShape3D.new()
	cap2.radius = radius + 0.1
	cap2.height = max(height, radius * 2.0 + 0.2)
	cs2.shape = cap2
	cs2.position = Vector3(0, height * 0.5, 0)
	contact.add_child(cs2)
	add_child(contact)
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1, 0.9, 0.8, 0.0)
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	setup()
	if visual == null and puppet != null:
		visual = puppet
	_apply_overlay(visual)
	Game.noise.connect(_on_noise)
	Game.word_spoken.connect(_on_word)
	max_hp = max(max_hp, hp)
	hp += Game.wake if clay else 0
	max_hp = hp


func _apply_overlay(n: Node) -> void:
	if n == null:
		return
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).material_overlay = flash_mat
	for c in n.get_children():
		_apply_overlay(c)


func setup() -> void:
	pass


func think(_delta: float) -> void:
	pass


func player() -> Player:
	return Game.player as Player if Game.player and is_instance_valid(Game.player) else null


func dist_to_player() -> float:
	var p := player()
	return INF if p == null else global_position.distance_to(p.global_position)


func dir_to_player() -> float:
	var p := player()
	return 0.0 if p == null else signf(p.global_position.x - global_position.x)


func watched() -> bool:
	return Game.is_watched(global_position + Vector3(0, height * 0.6, 0))


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	invuln = max(0.0, invuln - delta)
	contact_cd = max(0.0, contact_cd - delta)
	if not no_gravity:
		velocity.y = max(velocity.y - gravity * delta, -30.0)
	if frozen_t > 0.0:
		frozen_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		move_and_slide()
		return
	if stunned > 0.0:
		stunned -= delta
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		move_and_slide()
		return
	think(delta)
	move_and_slide()
	if visual:
		var want := deg_to_rad(80.0 * facing)
		if clay:
			# stop-motion: snap the turn
			visual.rotation.y = want
		else:
			visual.rotation.y = lerp_angle(visual.rotation.y, want, clamp(delta * 8.0, 0.0, 1.0))
	_contact_damage()


func _contact_damage() -> void:
	if damage <= 0 or contact_cd > 0.0:
		return
	for b in contact.get_overlapping_bodies():
		if b is Player:
			if (b as Player).take_damage(damage, global_position, "hit"):
				contact_cd = 1.0
				on_hit_player(b)


func on_hit_player(_p: Player) -> void:
	pass


func take_hit(dmg: int, from: Vector3, kind: String = "paddle") -> void:
	if dead or invuln > 0.0:
		return
	if not can_be_hit(kind):
		Snd.sfx("block", global_position, -4)
		Fx.sparks(global_position + Vector3(0, height * 0.6, 0), 6)
		return
	hp -= dmg
	invuln = 0.12
	var dir := signf(global_position.x - from.x)
	velocity.x = dir * (5.0 if kind == "paddle" else 2.5) * (1.0 - knock_resist)
	velocity.y = 3.0 * (1.0 - knock_resist)
	stunned = max(stunned, 0.25 * (1.0 - knock_resist))
	Snd.sfx("%s%d" % [hit_sound, randi() % 3] if hit_sound == "hit_clay" else hit_sound, global_position, 0)
	Fx.shards(global_position + Vector3(0, height * 0.6, 0), 4, shard_color, 0.09, 4.0)
	flash_mat.albedo_color.a = 0.85
	create_tween().tween_property(flash_mat, "albedo_color:a", 0.0, 0.18)
	on_damaged(dmg, kind)
	if hp <= 0:
		die()


func can_be_hit(_kind: String) -> bool:
	return true


func on_damaged(_dmg: int, _kind: String) -> void:
	pass


func on_parried(_p: Player) -> void:
	stunned = 1.4
	velocity.x = -facing * 6.0
	if clay:
		# a well-timed block cracks raw clay off anything made of it
		hp -= 1
		Fx.shards(global_position + Vector3(0, height * 0.6, 0), 8, shard_color, 0.12, 5.0)
		Snd.sfx("shatter", global_position, -6)
		if hp <= 0:
			die()


func die() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	contact.monitoring = false
	Snd.sfx("shatter", global_position, 0)
	Fx.shards(global_position + Vector3(0, height * 0.5, 0), 14, shard_color, 0.14, 6.0)
	Fx.dust(global_position + Vector3(0, height * 0.4, 0), 14, Color(shard_color, 0.5))
	Fx.shake(0.2)
	for i in drops:
		if randf() < 0.5:
			var pk := Pickup.new()
			pk.kind = "pellets"
			pk.amount = 2
			Game.level.add_child(pk)
			pk.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.3, 0)
	killed.emit()
	on_death()
	if visual:
		var t := create_tween()
		t.tween_property(visual, "scale", Vector3(1.2, 0.05, 1.2), 0.25)
		t.tween_callback(queue_free)
	else:
		queue_free()


func on_death() -> void:
	pass


func _on_noise(pos: Vector3, r: float) -> void:
	if dead:
		return
	if global_position.distance_to(pos) <= r:
		heard(pos)


func heard(pos: Vector3) -> void:
	noise_pos = pos


func _on_word(word: String, pos: Vector3, _by_bindu: bool) -> void:
	if dead or global_position.distance_to(pos) > Player.WORD_RADIUS:
		return
	on_word(word, pos)


func on_word(word: String, _pos: Vector3) -> void:
	match word:
		"shut":
			if clay:
				frozen_t = 3.5
				Fx.ring(global_position + Vector3(0, height * 0.5, 0), 1.2, Color(0.55, 0.65, 1.0, 0.8))
		"break":
			if clay:
				take_hit(2, global_position - Vector3(facing, 0, 0), "word")


func move_toward_x(target_x: float, spd: float, delta: float, accel: float = 20.0) -> void:
	var d := target_x - global_position.x
	if abs(d) < 0.15:
		velocity.x = move_toward(velocity.x, 0.0, accel * delta)
		return
	facing = 1 if d > 0 else -1
	velocity.x = move_toward(velocity.x, facing * spd, accel * delta)


func ledge_ahead() -> bool:
	## Is there floor in front of us?
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(facing * (radius + 0.3), 0.5, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -1.6, 0), 1)
	return not space.intersect_ray(q).is_empty()


func wall_ahead() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.5, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(facing * (radius + 0.4), 0, 0), 1)
	return not space.intersect_ray(q).is_empty()
