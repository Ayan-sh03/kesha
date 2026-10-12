extends Enemy
## Watchmen (human): the elders post them to keep everyone away from the
## river. They carry lamps and see in cones. They only catch you.

var a := 0.0
var b := 0.0
var cone: SpotLight3D
var wait_t := 0.0
var alert := 0.0
var caught := false
var view := 9.0
var half_angle := 26.0


func setup() -> void:
	clay = false
	damage = 0
	hp = 999
	speed = 1.6
	var cm := CharModel.make("watchman")
	cm.speed_mult = randf_range(0.9, 1.1)
	puppet = cm if cm.player != null else Fig.watchman(randi() % 4)
	add_child(puppet)
	puppet.stepped = false
	cone = SpotLight3D.new()
	cone.light_color = Color(1.0, 0.7, 0.4)
	cone.light_energy = 3.0
	cone.spot_range = view
	cone.spot_angle = half_angle
	cone.spot_attenuation = 0.8
	cone.light_volumetric_fog_energy = 4.0
	cone.shadow_enabled = true
	add_child(cone)
	cone.position = Vector3(0, 1.5, 0)
	if puppet is CharModel:
		# sockets exist after _ready: hang the lamp from the hand next frame
		_hang_lamp.call_deferred()
	else:
		B.diya(puppet.parts["r_fore"], Vector3(0, -0.32, 0.05), true, 0.0)
	if a == 0.0 and b == 0.0:
		a = global_position.x - 4.0
		b = global_position.x + 4.0


func _hang_lamp() -> void:
	if puppet.parts.has("r_fore"):
		B.diya(puppet.parts["r_fore"], Vector3(0, -0.12, 0.04), true, 0.0)


func think(delta: float) -> void:
	if caught:
		velocity.x = 0.0
		return
	if wait_t > 0.0:
		wait_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		puppet.anim("stand_guard" if puppet is CharModel and (puppet as CharModel).has_clip("stand_guard") else "idle")
	else:
		var tx := b if facing > 0 else a
		move_toward_x(tx, speed, delta)
		puppet.anim("walk", 0.4)
		if abs(global_position.x - tx) < 0.3:
			facing = -facing
			wait_t = 1.6
	cone.rotation = Vector3(deg_to_rad(-12), deg_to_rad(-90 * facing), 0)
	if _sees_player():
		alert += delta * 2.4
		cone.light_color = Color(1.0, 0.35, 0.2)
		if alert > 1.0:
			_catch()
	else:
		alert = max(0.0, alert - delta)
		cone.light_color = Color(1.0, 0.7, 0.4)


func _sees_player() -> bool:
	var p := player()
	if p == null or p.state == "dead" or p.state == "cutscene":
		return false
	var eye := global_position + Vector3(0, 1.5, 0)
	var to := p.global_position + Vector3(0, 0.8, 0) - eye
	if to.length() > view:
		return false
	var fwd := Vector3(facing, -0.2, 0).normalized()
	if rad_to_deg(fwd.angle_to(to.normalized())) > half_angle:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, eye + to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _catch() -> void:
	caught = true
	var p := player()
	p.set_cutscene(true)
	Snd.sfx("bell_low", global_position, 0)
	Game.say(["Who's there? Get back from the river!", "The potter's boy. Home, now.", "Nobody goes to the river."][randi() % 3], "elder", 2.6)
	Fx.flash(Color(1.0, 0.6, 0.3, 0.3), 0.3)
	var main = Game.main
	await get_tree().create_timer(1.8, false).timeout
	await main.post.fade_to(1.0, 0.8).finished
	var back: Vector3 = Game.checkpoint if Game.checkpoint != Vector3.INF else Game.level.spawn
	p.respawn_at(back)
	p.set_cutscene(false)
	main.rig.snap()
	main.post.fade_to(0.0, 0.8)
	alert = 0.0
	caught = false
	facing = -facing


func take_hit(_dmg: int, from: Vector3, _kind: String = "paddle") -> void:
	# a grown man; a boy's paddle only makes him angry
	velocity.x = signf(global_position.x - from.x) * 2.0
	stunned = 0.6
	alert = 1.0
	Snd.sfx("block", global_position)


func on_word(word: String, _pos: Vector3) -> void:
	if word == "shut":
		# his eyes shut for him: he prays
		stunned = 4.0
		puppet.anim("band")
		Game.show_hint("The watchman shuts every door and prays.")
