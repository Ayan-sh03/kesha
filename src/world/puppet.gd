class_name Puppet
extends Node3D
## A procedurally animated figure. Tesu animates smoothly; everything made of
## clay moves in stop-motion steps (`stepped`), so the given always move a
## little wrong.

var parts := {}          # pivot name -> Node3D
var rest := {}           # pivot name -> rest position
var stepped := false
var step_fps := 9.0
var smooth := 16.0
var state := "idle"
var sub := 0             # attack index etc.
var t_state := 0.0       # time in state
var speed := 0.0         # 0..1 locomotion speed
var phase := 0.0
var leg_len := 0.7
var hips_y := 0.7
var bob := Vector3.ZERO
var extra := {}          # pose overrides
var _acc := 0.0
var _cur := {}
var _time := 0.0
var _seed := 0.0
var meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	_seed = randf() * 10.0
	for k in parts:
		_cur[k] = Vector3.ZERO


func reg(name: String, n: Node3D) -> Node3D:
	parts[name] = n
	rest[name] = n.position
	return n


func anim(new_state: String, spd: float = 0.0, sub_index: int = 0) -> void:
	if new_state != state or sub_index != sub:
		t_state = 0.0
	state = new_state
	speed = spd
	sub = sub_index


func _process(delta: float) -> void:
	_time += delta
	t_state += delta
	var cadence := 1.6 + speed * 1.7
	phase += delta * cadence * TAU * (0.5 if state == "walk" or state == "sneak" else 1.0) * (0.55 if state == "crawl" else 1.0)
	if state == "climb":
		phase += delta * TAU * 1.4 * speed
	if stepped:
		_acc += delta
		if _acc < 1.0 / step_fps:
			return
		var dt := _acc
		_acc = 0.0
		_apply(_targets(), 1.0, dt)
	else:
		_apply(_targets(), clamp(delta * smooth, 0.0, 1.0), delta)


func _apply(tg: Dictionary, k: float, _dt: float) -> void:
	for name in parts:
		var target: Vector3 = tg.get(name, Vector3.ZERO)
		if extra.has(name):
			target += extra[name]
		var cur: Vector3 = _cur.get(name, Vector3.ZERO)
		cur = cur.lerp(target, k)
		_cur[name] = cur
		var n: Node3D = parts[name]
		n.rotation_degrees = cur
	if parts.has("hips"):
		var h: Node3D = parts["hips"]
		var targ_b: Vector3 = tg.get("_bob", Vector3.ZERO)
		bob = bob.lerp(targ_b, k)
		h.position = rest["hips"] + bob


func _targets() -> Dictionary:
	var s := sin(phase)
	var c := cos(phase)
	var br := sin(_time * 2.2 + _seed) # breathing
	var t := {}
	match state:
		"idle":
			t = {"chest": Vector3(2 + br * 1.5, 0, 0), "head": Vector3(-2 - br, sin(_time * 0.4 + _seed) * 6, 0),
				"l_arm": Vector3(0, 0, 6), "r_arm": Vector3(0, 0, -6), "l_fore": Vector3(-10, 0, 0), "r_fore": Vector3(-10, 0, 0),
				"_bob": Vector3(0, br * 0.006, 0)}
		"walk", "sneak":
			var a := 22.0 if state == "walk" else 14.0
			t = {"l_leg": Vector3(-s * a, 0, 0), "r_leg": Vector3(s * a, 0, 0),
				"l_shin": Vector3(max(0.0, c) * 30, 0, 0), "r_shin": Vector3(max(0.0, -c) * 30, 0, 0),
				"l_arm": Vector3(s * a * 0.8, 0, 5), "r_arm": Vector3(-s * a * 0.8, 0, -5),
				"l_fore": Vector3(-15, 0, 0), "r_fore": Vector3(-15, 0, 0),
				"chest": Vector3(4 if state == "walk" else 18, 0, 0), "head": Vector3(-2 if state == "walk" else -12, 0, 0),
				"_bob": Vector3(0, abs(s) * 0.03 - (0.1 if state == "sneak" else 0.0), 0)}
		"run":
			t = {"l_leg": Vector3(-s * 48, 0, 0), "r_leg": Vector3(s * 48, 0, 0),
				"l_shin": Vector3(max(0.0, c) * 75 + 10, 0, 0), "r_shin": Vector3(max(0.0, -c) * 75 + 10, 0, 0),
				"l_arm": Vector3(s * 50, 0, 8), "r_arm": Vector3(-s * 50, 0, -8),
				"l_fore": Vector3(-70, 0, 0), "r_fore": Vector3(-70, 0, 0),
				"chest": Vector3(14, -s * 6, 0), "head": Vector3(-10, s * 4, 0),
				"_bob": Vector3(0, abs(c) * 0.07 - 0.03, 0)}
		"jump":
			t = {"l_leg": Vector3(-50, 0, 0), "r_leg": Vector3(15, 0, 0), "l_shin": Vector3(70, 0, 0), "r_shin": Vector3(30, 0, 0),
				"l_arm": Vector3(-150, 0, 20), "r_arm": Vector3(30, 0, -20), "l_fore": Vector3(-20, 0, 0), "r_fore": Vector3(-40, 0, 0),
				"chest": Vector3(-6, 0, 0), "head": Vector3(-8, 0, 0)}
		"fall":
			var f := sin(_time * 14.0) * 6.0
			t = {"l_leg": Vector3(-20 + f, 0, 0), "r_leg": Vector3(10 - f, 0, 0), "l_shin": Vector3(40, 0, 0), "r_shin": Vector3(50, 0, 0),
				"l_arm": Vector3(-60 + f, 0, 60), "r_arm": Vector3(-50 - f, 0, -60), "l_fore": Vector3(-30, 0, 0), "r_fore": Vector3(-30, 0, 0),
				"chest": Vector3(6, 0, 0), "head": Vector3(10, 0, 0)}
		"climb":
			t = {"l_arm": Vector3(-160 + s * 25, 0, 15), "r_arm": Vector3(-160 - s * 25, 0, -15),
				"l_fore": Vector3(-30 - max(0.0, s) * 40, 0, 0), "r_fore": Vector3(-30 - max(0.0, -s) * 40, 0, 0),
				"l_leg": Vector3(-40 - s * 25, 0, 0), "r_leg": Vector3(-40 + s * 25, 0, 0),
				"l_shin": Vector3(70, 0, 0), "r_shin": Vector3(70, 0, 0), "chest": Vector3(10, 0, 0), "head": Vector3(-25, 0, 0)}
		"attack":
			var k: float = clamp(t_state / 0.16, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - k, 3.0)
			match sub:
				0:
					t = {"r_arm": Vector3(lerp(-150.0, 40.0, e), 0, -20), "r_fore": Vector3(lerp(-80.0, -10.0, e), 0, 0),
						"chest": Vector3(lerp(-10.0, 25.0, e), lerp(30.0, -30.0, e), 0), "l_arm": Vector3(30, 0, 20),
						"l_leg": Vector3(-30, 0, 0), "r_leg": Vector3(20, 0, 0), "l_shin": Vector3(30, 0, 0), "_bob": Vector3(0, -0.06, 0)}
				1:
					t = {"r_arm": Vector3(-80, 0, lerp(-110.0, 40.0, e)), "r_fore": Vector3(-20, 0, 0),
						"chest": Vector3(15, lerp(-40.0, 50.0, e), 0), "l_arm": Vector3(-20, 0, 40),
						"l_leg": Vector3(20, 0, 0), "r_leg": Vector3(-30, 0, 0), "r_shin": Vector3(30, 0, 0), "_bob": Vector3(0, -0.05, 0)}
				_:
					t = {"r_arm": Vector3(lerp(-190.0, 10.0, e), 0, 0), "l_arm": Vector3(lerp(-190.0, 10.0, e), 0, 0),
						"r_fore": Vector3(-20, 0, 0), "l_fore": Vector3(-20, 0, 0),
						"chest": Vector3(lerp(-25.0, 45.0, e), 0, 0), "head": Vector3(lerp(-10.0, 10.0, e), 0, 0),
						"l_leg": Vector3(-45, 0, 0), "r_leg": Vector3(25, 0, 0), "l_shin": Vector3(50, 0, 0), "r_shin": Vector3(20, 0, 0),
						"_bob": Vector3(0, lerp(0.0, -0.14, e), 0)}
		"aim":
			t = {"l_arm": Vector3(-90 + extra_aim(), 0, 0), "l_fore": Vector3(0, 0, 0),
				"r_arm": Vector3(-80 + extra_aim(), 0, -25), "r_fore": Vector3(-100, 0, 0),
				"chest": Vector3(0, 20, 0), "head": Vector3(-extra_aim() * 0.5, -10, 0),
				"l_leg": Vector3(-15, 0, 0), "r_leg": Vector3(15, 0, 0)}
		"throw":
			var k2: float = clamp(t_state / 0.12, 0.0, 1.0)
			t = {"l_arm": Vector3(-90, 0, 0), "r_arm": Vector3(lerp(-80.0, -100.0, k2), 0, -10), "r_fore": Vector3(lerp(-100.0, 0.0, k2), 0, 0),
				"chest": Vector3(0, lerp(20.0, -10.0, k2), 0)}
		"block":
			t = {"r_arm": Vector3(-95, 0, 30), "r_fore": Vector3(-80, 0, 0), "l_arm": Vector3(-70, 0, -30), "l_fore": Vector3(-90, 0, 0),
				"chest": Vector3(8, 0, 0), "head": Vector3(10, 0, 0), "l_leg": Vector3(-25, 0, 0), "r_leg": Vector3(25, 0, 0),
				"l_shin": Vector3(30, 0, 0), "r_shin": Vector3(20, 0, 0), "_bob": Vector3(0, -0.08, 0)}
		"roll":
			t = {"l_leg": Vector3(-110, 0, 0), "r_leg": Vector3(-100, 0, 0), "l_shin": Vector3(140, 0, 0), "r_shin": Vector3(140, 0, 0),
				"l_arm": Vector3(-60, 0, 20), "r_arm": Vector3(-60, 0, -20), "l_fore": Vector3(-100, 0, 0), "r_fore": Vector3(-100, 0, 0),
				"chest": Vector3(50, 0, 0), "head": Vector3(30, 0, 0), "_bob": Vector3(0, -0.25, 0)}
		"band", "pray":
			# the shut prayer: fingers in ears, head bowed, breath held
			var tremble := sin(_time * 30.0) * 0.6 if state == "band" else 0.0
			t = {"l_arm": Vector3(-20, 0, 78 + tremble), "r_arm": Vector3(-20, 0, -78 - tremble), "l_fore": Vector3(0, 0, 150), "r_fore": Vector3(0, 0, -150),
				"head": Vector3(22, 0, 0), "chest": Vector3(10, 0, 0), "_bob": Vector3(0, -0.02, 0)}
		"pray_palms":
			t = {"l_arm": Vector3(-40, 25, 10), "r_arm": Vector3(-40, -25, -10), "l_fore": Vector3(-85, 0, 0), "r_fore": Vector3(-85, 0, 0),
				"head": Vector3(25, 0, 0), "chest": Vector3(6, 0, 0)}
		"reach":
			t = {"r_arm": Vector3(-95, 0, -5), "l_arm": Vector3(-80, 0, 10), "r_fore": Vector3(-5, 0, 0), "l_fore": Vector3(-15, 0, 0),
				"chest": Vector3(18, 0, 0), "head": Vector3(-14, 0, 0), "l_leg": Vector3(-30, 0, 0), "r_leg": Vector3(25, 0, 0), "l_shin": Vector3(20, 0, 0)}
		"sit":
			t = {"l_leg": Vector3(-90, 0, 12), "r_leg": Vector3(-90, 0, -12), "l_shin": Vector3(95, 0, 0), "r_shin": Vector3(95, 0, 0),
				"chest": Vector3(12 + br, 0, 0), "head": Vector3(10, 0, 0), "l_arm": Vector3(-30, 0, 10), "r_arm": Vector3(-30, 0, -10),
				"l_fore": Vector3(-40, 0, 0), "r_fore": Vector3(-40, 0, 0), "_bob": Vector3(0, -hips_y * 0.68, 0)}
		"kneel":
			t = {"l_leg": Vector3(-80, 0, 0), "r_leg": Vector3(10, 0, 0), "l_shin": Vector3(80, 0, 0), "r_shin": Vector3(100, 0, 0),
				"chest": Vector3(20, 0, 0), "head": Vector3(10, 0, 0), "l_arm": Vector3(-40, 0, 0), "r_arm": Vector3(-40, 0, 0),
				"l_fore": Vector3(-30, 0, 0), "r_fore": Vector3(-30, 0, 0), "_bob": Vector3(0, -hips_y * 0.45, 0)}
		"lie":
			t = {"hips": Vector3(-90, 0, 0), "l_arm": Vector3(0, 0, 10), "r_arm": Vector3(0, 0, -10), "_bob": Vector3(0, -hips_y + 0.15, 0)}
		"crawl":
			t = {"hips": Vector3(70, 0, 0), "chest": Vector3(15, 0, 0), "head": Vector3(-70, 0, 0),
				"l_arm": Vector3(-80 + s * 30, 0, 10), "r_arm": Vector3(-80 - s * 30, 0, -10),
				"l_leg": Vector3(-60 - s * 20, 0, 0), "r_leg": Vector3(-60 + s * 20, 0, 0), "l_shin": Vector3(80, 0, 0), "r_shin": Vector3(80, 0, 0),
				"_bob": Vector3(0, -hips_y * 0.55, 0)}
		"carry":
			t = {"l_arm": Vector3(-170, 0, 25), "r_arm": Vector3(-170, 0, -25), "l_fore": Vector3(-40, 0, 0), "r_fore": Vector3(-40, 0, 0),
				"l_leg": Vector3(-s * 18 * speed, 0, 0), "r_leg": Vector3(s * 18 * speed, 0, 0), "head": Vector3(-4, 0, 0)}
		"hurt":
			t = {"chest": Vector3(-25, 0, 0), "head": Vector3(-20, 0, 0), "l_arm": Vector3(30, 0, 40), "r_arm": Vector3(30, 0, -40),
				"_bob": Vector3(0, -0.03, 0)}
		"dead":
			t = {"hips": Vector3(-80, 0, 0), "chest": Vector3(-10, 0, 0), "l_arm": Vector3(-20, 0, 70), "r_arm": Vector3(10, 0, -60), "_bob": Vector3(0, -hips_y + 0.12, 0)}
		"grab":
			t = {"l_arm": Vector3(-85 + s * 10, 0, -10), "r_arm": Vector3(-85 - s * 10, 0, 10), "l_fore": Vector3(-20, 0, 0), "r_fore": Vector3(-20, 0, 0),
				"chest": Vector3(25, 0, 0), "head": Vector3(-15, 0, 0)}
		"cry":
			t = {"head": Vector3(-40, 0, 0), "chest": Vector3(-15, 0, 0), "l_arm": Vector3(-150, 0, 30), "r_arm": Vector3(-150, 0, -30),
				"l_fore": Vector3(-60, 0, 0), "r_fore": Vector3(-60, 0, 0)}
		"tpose":
			t = {}
	return t


func extra_aim() -> float:
	return extra.get("_aim", Vector3.ZERO).x


func set_material_all(m: Material) -> void:
	for mi in meshes:
		mi.material_override = m


func set_overlay(m: Material) -> void:
	for mi in meshes:
		mi.material_overlay = m
