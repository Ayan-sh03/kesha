class_name Player
extends CharacterBody3D
## Tesu, 12, the potter's son. Sling, paddle, words, lamp, climb, give.

signal died

const RUN := 6.2
const SNEAK := 2.3
const ACCEL := 60.0
const AIR_ACCEL := 32.0
const JUMP_V := 11.6
const GRAVITY := 32.0
const FALL_MULT := 1.4
const MAX_FALL := 28.0
const COYOTE := 0.12
const BUFFER := 0.14
const CLIMB_SPEED := 3.4
const ROLL_SPEED := 9.8
const ROLL_TIME := 0.42
const WORD_CD := 3.5
const WORD_RADIUS := 7.5

var puppet: Puppet
var facing := 1
var state := "normal"
var control := true
var frozen := false
var invuln := 0.0
var coyote := 0.0
var buffer := 0.0
var attack_i := 0
var attack_t := 0.0
var attack_queued := false
var attack_hit := {}
var combo_window := 0.0
var roll_t := 0.0
var roll_cd := 0.0
var block_t := -1.0
var aim_dir := Vector2(1, 0.2)
var climb_zones := 0
var slow := 1.0
var holders := {}
var hands_lost := 0.0
var band_on := false
var word_cd := {"shut": 0.0, "open": 0.0, "break": 0.0}
var step_acc := 0.0
var surface := "dust"
var was_on_floor := true
var fall_speed := 0.0
var look_up := false
var hot_tick := 0.0
var hazard_tick := 0.0
var leak_tick := 0.0
var interact_target: Node = null
var knock_meter := 0.0
var hurt_flash := 0.0
var air_time := 0.0
var external_push := Vector3.ZERO

var lamp_light: OmniLight3D
var lamp_node: Node3D
var hitbox: Area3D
var sensor: Area3D
var aim_line: MeshInstance3D
var _aim_mesh: ImmediateMesh


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)
	axis_lock_linear_z = true
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.25
	cs.shape = cap
	cs.position = Vector3(0, 0.625, 0)
	add_child(cs)
	puppet = Fig.tesu()
	add_child(puppet)
	puppet.rotation_degrees.y = 80
	for mi in puppet.meshes:
		mi.layers = 2
	_build_lamp()
	_build_hitbox()
	_build_sensor()
	_build_aim_line()
	Game.player = self
	Game.doors_changed.connect(_on_doors)
	_on_doors()


func _build_lamp() -> void:
	var hold: Node3D = puppet.parts["l_fore"].get_node("lamp_hold")
	lamp_node = B.diya(hold, Vector3.ZERO, true, 0.0)
	lamp_node.scale = Vector3.ONE * 1.2
	lamp_light = OmniLight3D.new()
	lamp_light.light_color = Color(1.0, 0.64, 0.32)
	lamp_light.light_energy = 1.5
	lamp_light.omni_range = 9.0
	lamp_light.omni_attenuation = 1.2
	lamp_light.shadow_enabled = true
	lamp_light.shadow_bias = 0.08
	lamp_light.light_volumetric_fog_energy = 1.2
	if "shadow_caster_mask" in lamp_light:
		lamp_light.set("shadow_caster_mask", 0xFFFFFFFF & ~2)
	lamp_light.set_script(load("res://src/world/flicker.gd"))
	add_child(lamp_light)
	lamp_light.position = Vector3(0.2, 1.9, 0.9)


func _build_hitbox() -> void:
	hitbox = Area3D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 4 | 1
	hitbox.monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.3, 1.2, 1.6)
	cs.shape = bs
	hitbox.add_child(cs)
	add_child(hitbox)
	hitbox.position = Vector3(0.75, 0.7, 0)


func _build_sensor() -> void:
	sensor = Area3D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 32 | 64 | 128
	sensor.monitorable = false
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.3
	cs.shape = cap
	cs.position = Vector3(0, 0.65, 0)
	sensor.add_child(cs)
	add_child(sensor)
	sensor.area_entered.connect(_on_area_entered)
	sensor.area_exited.connect(_on_area_exited)


func _build_aim_line() -> void:
	aim_line = MeshInstance3D.new()
	_aim_mesh = ImmediateMesh.new()
	aim_line.mesh = _aim_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.6, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	aim_line.material_override = m
	aim_line.top_level = true
	aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aim_line)


func _on_doors() -> void:
	Fig.update_tesu_doors(puppet)


# ------------------------------------------------------------- areas
func _on_area_entered(a: Area3D) -> void:
	if a.collision_layer & 128:
		climb_zones += 1


func _on_area_exited(a: Area3D) -> void:
	if a.collision_layer & 128:
		climb_zones = max(0, climb_zones - 1)


func _overlapping(group: String) -> Array:
	var out := []
	for a in sensor.get_overlapping_areas():
		if a.is_in_group(group):
			out.append(a)
	return out


# ------------------------------------------------------------- input helpers
func _ix() -> float:
	if not control:
		return 0.0
	if Game.autotest:
		return Game.flags.get("auto_x", 0.0)
	var x := Input.get_axis("left", "right")
	if hands_lost > 0.0:
		x = -x
	return x


func _iy() -> float:
	if not control:
		return 0.0
	return Input.get_axis("down", "up")


func _pressed(a: String) -> bool:
	return control and Input.is_action_just_pressed(a)


func _held(a: String) -> bool:
	return control and Input.is_action_pressed(a)


# ------------------------------------------------------------- physics
func _physics_process(delta: float) -> void:
	if frozen:
		return
	invuln = max(0.0, invuln - delta)
	roll_cd = max(0.0, roll_cd - delta)
	hands_lost = max(0.0, hands_lost - delta)
	hurt_flash = max(0.0, hurt_flash - delta * 2.5)
	for k in word_cd:
		word_cd[k] = max(0.0, word_cd[k] - delta)
	slow = 1.0
	for h in holders.values():
		slow *= h
	if Game.bound:
		slow *= 0.8

	match state:
		"dead":
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.y -= GRAVITY * delta
			move_and_slide()
			puppet.anim("dead")
			return
		"cutscene":
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.y = max(velocity.y - GRAVITY * delta, -MAX_FALL)
			move_and_slide()
			return
		"climb":
			_climb(delta)
		"roll":
			_roll(delta)
		_:
			_move(delta)
	_post_move(delta)


func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	var ix := _ix()
	var sneaking := on_floor and _held("down") and climb_zones == 0
	band_on = _held("band") and state != "attack"
	Snd.set_band(band_on)
	var max_speed := RUN
	if sneaking:
		max_speed = SNEAK
	if band_on:
		max_speed = 1.2
	if state == "aim":
		max_speed = 2.0
	if state == "attack":
		max_speed = 1.4
	if block_t >= 0.0:
		max_speed = 1.0
	max_speed *= slow
	var target := ix * max_speed
	var acc := ACCEL if on_floor else AIR_ACCEL
	velocity.x = move_toward(velocity.x, target, acc * delta)
	if abs(ix) > 0.1 and state != "attack" and state != "aim":
		facing = 1 if ix > 0 else -1
	# gravity
	var g := GRAVITY
	if velocity.y < 0.0:
		g *= FALL_MULT
	elif not _held("jump"):
		g *= 2.2  # variable jump height
	velocity.y = max(velocity.y - g * delta, -MAX_FALL)
	if on_floor:
		coyote = COYOTE
		air_time = 0.0
	else:
		coyote -= delta
		air_time += delta
	buffer -= delta
	if _pressed("jump"):
		buffer = BUFFER
	if buffer > 0.0 and coyote > 0.0 and not band_on and state != "attack":
		velocity.y = JUMP_V * (0.9 if slow < 0.9 else 1.0)
		buffer = 0.0
		coyote = 0.0
		Snd.sfx("jump", global_position, -6)
		Fx.dust(global_position, 5)
	# climb entry
	if climb_zones > 0 and (_iy() > 0.5 or (not on_floor and _iy() < -0.5)) and state == "normal":
		state = "climb"
		velocity = Vector3.ZERO
	# combat & tools
	_combat(delta)
	_tools()
	velocity += external_push
	external_push = external_push.lerp(Vector3.ZERO, clamp(delta * 6.0, 0.0, 1.0))
	move_and_slide()
	look_up = on_floor and _iy() > 0.5 and climb_zones == 0 and abs(ix) < 0.1
	# animation
	if state == "attack":
		puppet.anim("attack", 0.0, attack_i)
	elif state == "aim":
		puppet.anim("aim")
	elif block_t >= 0.0:
		puppet.anim("block")
	elif band_on:
		puppet.anim("band", abs(velocity.x) / RUN)
	elif not is_on_floor():
		puppet.anim("jump" if velocity.y > 1.0 else "fall")
	elif abs(velocity.x) > 0.3:
		puppet.anim("sneak" if sneaking else ("run" if abs(velocity.x) > 3.5 else "walk"), abs(velocity.x) / RUN)
	else:
		puppet.anim("idle")
	puppet.parts["r_fore"].get_node("paddle").visible = state == "attack" or block_t >= 0.0
	puppet.parts["chest"].get_node("paddle_back").visible = not puppet.parts["r_fore"].get_node("paddle").visible


func _climb(delta: float) -> void:
	var ix := _ix()
	var iy := _iy()
	velocity = Vector3(ix * CLIMB_SPEED * 0.7, iy * CLIMB_SPEED, 0) * slow
	if abs(ix) > 0.1:
		facing = 1 if ix > 0 else -1
	puppet.anim("climb", (abs(iy) + abs(ix)) * 0.8)
	move_and_slide()
	step_acc += velocity.length() * delta
	if step_acc > 0.7:
		step_acc = 0.0
		Snd.sfx("step_silt%d" % (randi() % 4), global_position, -12)
	if _pressed("jump"):
		state = "normal"
		velocity = Vector3(ix * RUN, JUMP_V * 0.9, 0)
		Snd.sfx("jump", global_position, -6)
	elif climb_zones == 0:
		state = "normal"
		if iy > 0.1:
			velocity.y = 7.5  # vault over the lip
			velocity.x = facing * 2.5
	elif is_on_floor() and iy < -0.1:
		state = "normal"


func _roll(delta: float) -> void:
	roll_t -= delta
	velocity.x = facing * ROLL_SPEED * slow * clamp(roll_t / ROLL_TIME + 0.4, 0.0, 1.0)
	velocity.y = max(velocity.y - GRAVITY * delta, -MAX_FALL)
	puppet.anim("roll")
	puppet.rotation.x = lerp(0.0, -TAU, 1.0 - clamp(roll_t / ROLL_TIME, 0.0, 1.0)) * 0.0
	move_and_slide()
	if roll_t <= 0.0:
		state = "normal"


func _combat(delta: float) -> void:
	# block / parry
	if _held("block") and state == "normal" and is_on_floor() and hands_lost <= 0.0:
		if block_t < 0.0:
			block_t = 0.0
		else:
			block_t += delta
	else:
		block_t = -1.0
	# roll
	if _pressed("roll") and roll_cd <= 0.0 and is_on_floor() and state in ["normal", "aim"] and not band_on:
		state = "roll"
		roll_t = ROLL_TIME
		roll_cd = 0.55
		invuln = max(invuln, ROLL_TIME * 0.85)
		var ix := _ix()
		if abs(ix) > 0.1:
			facing = 1 if ix > 0 else -1
		Fx.dust(global_position, 6)
		Snd.sfx("swing0", global_position, -8, 0.2)
		return
	# paddle
	if state == "attack":
		attack_t += delta
		if attack_t > 0.05 and attack_t < 0.2:
			_do_hits()
		if _pressed("attack"):
			attack_queued = true
		var dur := 0.34 if attack_i < 2 else 0.5
		if attack_t >= dur:
			if attack_queued and attack_i < 2:
				_start_attack(attack_i + 1)
			else:
				state = "normal"
				combo_window = 0.35
				attack_i = (attack_i + 1) % 3 if attack_queued else 0
		return
	combo_window = max(0.0, combo_window - delta)
	if _pressed("attack") and state == "normal" and not band_on and hands_lost <= 0.0:
		_start_attack(attack_i if combo_window > 0.0 else 0)
		return
	# sling
	if _held("aim") and state in ["normal", "aim"] and not band_on and hands_lost <= 0.0:
		state = "aim"
		_update_aim()
	elif state == "aim":
		state = "normal"
		_aim_mesh.clear_surfaces()
		_fire()


func _start_attack(i: int) -> void:
	state = "attack"
	attack_i = i
	attack_t = 0.0
	attack_queued = false
	attack_hit = {}
	var ix := _ix()
	if abs(ix) > 0.1:
		facing = 1 if ix > 0 else -1
	velocity.x += facing * (2.5 if i < 2 else 4.0)
	Snd.sfx("swing%d" % i, global_position, -3)
	Game.emit_noise(global_position, 6.0)


func _do_hits() -> void:
	hitbox.position = Vector3(0.75 * facing, 0.7, 0)
	for b in hitbox.get_overlapping_bodies() + hitbox.get_overlapping_areas():
		var t: Node = b
		if b.has_meta("hit_owner"):
			t = b.get_meta("hit_owner")
		if t == self or attack_hit.has(t.get_instance_id()):
			continue
		if t.has_method("take_hit"):
			attack_hit[t.get_instance_id()] = true
			var dmg := 1 if attack_i < 2 else 2
			t.take_hit(dmg, global_position, "paddle")
			Fx.hitstop(0.05 if attack_i < 2 else 0.09)
			Fx.shake(0.18 if attack_i < 2 else 0.35)
			var p: Vector3 = (b as Node3D).global_position if b is Node3D else global_position
			Fx.sparks(global_position.lerp(p, 0.6) + Vector3(0, 0.8, 0), 10)


func _aim_target() -> Vector2:
	var cam := Game.camera
	var origin := global_position + Vector3(0, 1.0, 0)
	var joy := Vector2(Input.get_axis("aim_left", "aim_right"), Input.get_axis("aim_down", "aim_up"))
	if joy.length() > 0.3:
		return joy.normalized()
	if cam != null and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE and get_viewport() != null:
		var mp := get_viewport().get_mouse_position()
		var ro := cam.project_ray_origin(mp)
		var rd := cam.project_ray_normal(mp)
		if abs(rd.z) > 0.001:
			var t := -ro.z / rd.z
			var hit := ro + rd * t
			var d := Vector2(hit.x - origin.x, hit.y - origin.y)
			if d.length() > 0.2:
				return d.normalized()
	return Vector2(facing, 0.25 + _iy() * 0.5).normalized()


func _update_aim() -> void:
	aim_dir = _aim_target()
	if abs(aim_dir.x) > 0.05:
		facing = 1 if aim_dir.x > 0 else -1
	puppet.extra["_aim"] = Vector3(-rad_to_deg(asin(clamp(aim_dir.y, -1.0, 1.0))), 0, 0)
	puppet.extra["l_arm"] = Vector3(-rad_to_deg(asin(clamp(aim_dir.y, -1.0, 1.0))), 0, 0)
	# dotted trajectory
	_aim_mesh.clear_surfaces()
	_aim_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var p := global_position + Vector3(facing * 0.3, 1.05, 0)
	var v := Vector3(aim_dir.x, aim_dir.y, 0) * 22.0
	for i in 24:
		var p2 := p + v * 0.025
		v.y -= 9.0 * 0.025
		if i % 2 == 0:
			_aim_mesh.surface_add_vertex(p)
			_aim_mesh.surface_add_vertex(p2)
		p = p2
	_aim_mesh.surface_end()


func _fire() -> void:
	puppet.extra.erase("_aim")
	puppet.extra.erase("l_arm")
	if Game.pellets <= 0:
		Snd.sfx("ui_move", global_position, -6)
		Game.show_hint("No pellets. Fired clay pellets lie where pots broke.")
		return
	Game.pellets -= 1
	Game.inventory_changed.emit()
	var pel := Pellet.new()
	Game.level.add_child(pel)
	pel.global_position = global_position + Vector3(facing * 0.35, 1.05, 0)
	pel.velocity = Vector3(aim_dir.x, aim_dir.y, 0) * 22.0
	pel.shooter = self
	puppet.anim("throw")
	Snd.sfx("sling", global_position, -2)
	Game.emit_noise(global_position, 3.0)


func _tools() -> void:
	# lamp: set a spare diya, which is a checkpoint and keeps watching
	if _pressed("lamp") and is_on_floor():
		var near := _nearest_in_group("set_lamp", 1.6)
		if near != null:
			Game.show_hint("A set lamp is already burning here.")
		elif Game.lamps > 0:
			Game.lamps -= 1
			Game.inventory_changed.emit()
			var l := SetLamp.new()
			Game.level.add_child(l)
			l.global_position = global_position + Vector3(facing * 0.5, 0, 0.3)
			Game.checkpoint = l.global_position + Vector3(0, 0.2, -0.3)
			Snd.sfx("lamp_set", l.global_position)
			Game.show_hint("Lamp set. It will watch, and you will wake here.")
		else:
			Game.show_hint("No spare lamps.")
	# interact
	interact_target = _find_interactable()
	if _pressed("interact") and interact_target != null:
		interact_target.call("interact", self)
	# words
	for w in ["shut", "open", "break"]:
		if _pressed("word_" + w):
			speak(w)
	# pour water for the Thirsty
	if _pressed("pour"):
		pour()
	# breath
	var smoke_free := not Game.has("nose")
	if band_on and not smoke_free:
		Game.breath = max(0.0, Game.breath - get_physics_process_delta_time() / 5.0)
		if Game.breath <= 0.0:
			band_on = false
			Snd.sfx("breath_in", global_position, 0)
			Game.show_hint("Out of breath.")
	else:
		Game.breath = min(1.0, Game.breath + get_physics_process_delta_time() / 2.5)


func _nearest_in_group(g: String, r: float) -> Node3D:
	var best: Node3D = null
	var bd := r
	for n in get_tree().get_nodes_in_group(g):
		var d: float = (n as Node3D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = n
	return best


func _find_interactable() -> Node:
	var best: Node = null
	var bd := 99.0
	for a in sensor.get_overlapping_areas():
		var t: Node = a
		if a.has_meta("owner_node"):
			t = a.get_meta("owner_node")
		if t.has_method("interact") and t.get("enabled") != false:
			var d: float = (a as Node3D).global_position.distance_to(global_position)
			if d < bd:
				bd = d
				best = t
	return best


func speak(word: String) -> void:
	if not Game.words_learned:
		Game.show_hint("You don't know any words of power yet.")
		return
	if word_cd[word] > 0.0:
		return
	word_cd[word] = WORD_CD
	if Game.has("mouth"):
		Snd.voice("word_" + word)
		_word_effect(word, global_position + Vector3(0, 1.0, 0), false)
	else:
		# press a wet clay handprint; Bindu says the word for him from below
		var hp := Sprite3D.new()
		hp.texture = B.tex("handprint")
		hp.pixel_size = 0.0025
		hp.shaded = true
		Game.level.add_child(hp)
		hp.global_position = global_position + Vector3(facing * 0.3, 1.0, -0.55)
		puppet.anim("reach")
		Snd.sfx("step_silt0", hp.global_position, 0)
		var pos := hp.global_position
		var t := get_tree().create_timer(1.6)
		t.timeout.connect(func() -> void:
			Snd.voice("bindu_" + word)
			_word_effect(word, pos, true)
			var tw := hp.create_tween()
			tw.tween_interval(6.0)
			tw.tween_property(hp, "modulate:a", 0.0, 2.0)
			tw.tween_callback(hp.queue_free))


func _word_effect(word: String, pos: Vector3, by_bindu: bool) -> void:
	var col: Color = {"shut": Color(0.55, 0.65, 1.0), "open": Color(1.0, 0.85, 0.5), "break": Color(1.0, 0.45, 0.25)}[word]
	var glyph: String = {"shut": "बंद", "open": "खुल", "break": "टूट"}[word]
	Fx.ring(pos, WORD_RADIUS, Color(col, 0.9), 0.8)
	Fx.ring(pos, WORD_RADIUS * 0.6, Color(col, 0.6), 0.6)
	Fx.text3d(pos + Vector3(0, 0.6, 0.5), glyph, col, 120, 1.8, Hud.font_deva())
	Fx.shake(0.25)
	Fx.pulse("word", 1.0)
	Game.word_spoken.emit(word, pos, by_bindu)
	Game.emit_noise(pos, 12.0)


func pour() -> void:
	if Game.water < 0.2:
		Game.show_hint("The gourd is empty.")
		return
	Game.water = max(0.0, Game.water - 0.34)
	Game.inventory_changed.emit()
	var pd := Puddle.new()
	Game.level.add_child(pd)
	pd.global_position = global_position + Vector3(facing * 0.8, 0.02, 0)
	Snd.sfx("pour", global_position)


func _post_move(delta: float) -> void:
	puppet.rotation.y = lerp_angle(puppet.rotation.y, deg_to_rad(80.0 * facing), clamp(delta * 14.0, 0.0, 1.0))
	if state == "climb":
		puppet.rotation.y = lerp_angle(puppet.rotation.y, PI, clamp(delta * 10.0, 0.0, 1.0))
	var on_floor := is_on_floor()
	# footsteps make noise
	if on_floor and abs(velocity.x) > 0.5 and state != "roll":
		step_acc += abs(velocity.x) * delta
		var stride: float = 0.55 if abs(velocity.x) > 3.5 else 0.42
		if step_acc > stride:
			step_acc = 0.0
			var loud: float = 1.0 if abs(velocity.x) > 3.5 else 0.35
			if band_on:
				loud = 0.15
			Snd.step(surface, global_position, loud)
			var r := 6.5 * loud * (1.8 if surface == "water" else 1.0)
			Game.emit_noise(global_position, r)
			if surface == "water":
				Fx.ring(global_position + Vector3(0, 0.05, 0), 1.2, Color(0.7, 0.8, 0.9, 0.4), 0.8)
			elif loud > 0.5:
				Fx.dust(global_position + Vector3(0, 0.05, 0), 2, Color(0.55, 0.5, 0.42, 0.3))
	if on_floor and not was_on_floor:
		if fall_speed > 8.0:
			Snd.sfx("land", global_position, -2 + clamp(fall_speed - 12.0, 0.0, 8.0))
			Fx.dust(global_position, 10)
			Game.emit_noise(global_position, 9.0)
			if fall_speed > 14.0:
				Fx.shake(0.25)
		if fall_speed > 25.0 and state != "dead":
			take_damage(2, global_position + Vector3(0, -1, 0), "fall")
	if not on_floor:
		fall_speed = -velocity.y
	was_on_floor = on_floor
	_hazards(delta)
	if Game.leaking and Game.water > 0.0:
		leak_tick += delta
		if leak_tick > 1.5:
			leak_tick = 0.0
			Game.water = max(0.0, Game.water - 0.02)
			var d := Puddle.new()
			d.small = true
			Game.level.add_child(d)
			d.global_position = global_position
			if Game.has("nose"):
				Fx.particles(global_position + Vector3(0, 1.0, 0), 4, Color(0.5, 0.6, 0.7, 0.35), {"vmin": 0.2, "vmax": 0.5, "life": 1.4, "gravity": Vector3(0, 0.5, 0)})
	# void / fell out of the world
	if global_position.y < -80.0 and state != "dead":
		take_damage(99, global_position, "void")


func _hazards(delta: float) -> void:
	surface = "dust"
	var in_smoke := false
	for a in sensor.get_overlapping_areas():
		var kind: String = a.get_meta("hazard", "")
		match kind:
			"water":
				surface = "water"
			"silt", "mud":
				surface = "silt"
			"hot":
				if Game.has("skin"):
					hot_tick += delta
					if hot_tick > 0.45:
						hot_tick = 0.0
						take_damage(1, global_position + Vector3(0, -1, 0), "fire")
			"fire":
				if Game.has("skin") or a.get_meta("deadly", false):
					take_damage(1, a.global_position, "fire")
			"smoke", "gas":
				in_smoke = true
				if not band_on and Game.has("nose"):
					hazard_tick += delta
					if hazard_tick > 0.8:
						hazard_tick = 0.0
						take_damage(1, a.global_position, "smoke")
			"void":
				take_damage(99, global_position, "void")
	Game.flags["in_smoke"] = in_smoke


func take_damage(amount: int, from: Vector3, kind: String = "hit") -> bool:
	if state == "dead" or invuln > 0.0 and kind != "void":
		return false
	if Game.autotest and Game.flags.get("god", false):
		return false
	var dir := signf(global_position.x - from.x)
	if dir == 0:
		dir = -facing
	var in_front := signf(from.x - global_position.x) == float(facing)
	if block_t >= 0.0 and in_front and kind in ["hit", "grab", "charge"]:
		if block_t < 0.2:
			Snd.sfx("parry", global_position, 0)
			Fx.sparks(global_position + Vector3(facing * 0.5, 1.0, 0), 20)
			Fx.hitstop(0.12)
			Fx.shake(0.3)
			Fx.flash(Color(1, 0.95, 0.8, 0.35), 0.12)
			for e in get_tree().get_nodes_in_group("enemy"):
				if (e as Node3D).global_position.distance_to(from) < 2.5 and e.has_method("on_parried"):
					e.on_parried(self)
			return false
		Snd.sfx("block", global_position, 0)
		external_push = Vector3(dir * 6.0, 0, 0)
		Fx.shake(0.15)
		return false
	Game.hurt(amount)
	invuln = 0.9
	velocity = Vector3(dir * 7.5, 6.0, 0)
	if state in ["attack", "aim", "climb"]:
		state = "normal"
		_aim_mesh.clear_surfaces()
	puppet.anim("hurt")
	if Game.has("skin"):
		hurt_flash = 1.0
		Fx.pulse("hurt", 1.0)
		Snd.sfx("hurt%d" % (randi() % 2), global_position, -2)
		Fx.flash(Color(0.6, 0.0, 0.0, 0.25), 0.18)
	else:
		# fired skin: no pain, no flash. Bindu feels it instead, and you hear her.
		Snd.sfx("bindu_cry", null, -4, 0.1, "Voice")
		Fx.pulse("bindu", 1.0)
	Fx.shake(0.45)
	Fx.hitstop(0.08)
	if Game.hp <= 0:
		die(kind)
	return true


func die(kind: String = "") -> void:
	if state == "dead":
		return
	state = "dead"
	control = false
	band_on = false
	Snd.set_band(false)
	_aim_mesh.clear_surfaces()
	Fx.slowmo(0.25, 0.8)
	Fx.shake(0.6)
	Snd.sfx("heartbeat", null, 0, 0.0)
	died.emit()


func respawn_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	state = "normal"
	control = true
	frozen = false
	invuln = 1.5
	holders.clear()
	Game.breath = 1.0
	puppet.anim("idle")


func set_cutscene(on: bool) -> void:
	if on:
		state = "cutscene"
		control = false
		_aim_mesh.clear_surfaces()
		block_t = -1.0
		band_on = false
		Snd.set_band(false)
	elif state != "dead":
		state = "normal"
		control = true


func hold(by: Node, factor: float) -> void:
	holders[by.get_instance_id()] = factor


func release(by: Node) -> void:
	holders.erase(by.get_instance_id())


func is_hot() -> bool:
	## Stokers find you by the heat of your body. Fired skin runs cold.
	return Game.has("skin")


func eyes_open() -> bool:
	return not band_on and state != "dead"
