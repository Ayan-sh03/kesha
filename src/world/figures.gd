class_name Fig
extends RefCounted
## Figure builders: villagers, Tesu, Bindu, the elders, and clay things.

const SKIN_TONES := [Color(0.42, 0.25, 0.16), Color(0.5, 0.31, 0.2), Color(0.36, 0.21, 0.13), Color(0.56, 0.36, 0.24)]
const CLOTH := [Color(0.72, 0.36, 0.14), Color(0.55, 0.12, 0.1), Color(0.82, 0.62, 0.25), Color(0.86, 0.84, 0.78),
	Color(0.2, 0.28, 0.5), Color(0.45, 0.5, 0.3), Color(0.68, 0.2, 0.32), Color(0.9, 0.55, 0.2)]


static func _m(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


static func cloth_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = B.tex("ochre_albedo")
	m.albedo_color = Color(color.r * 1.6, color.g * 1.9, color.b * 2.6)
	m.normal_enabled = true
	m.normal_texture = B.tex("ochre_normal")
	m.roughness = 0.95
	m.uv1_scale = Vector3(3, 3, 3)
	return m


static func skin_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.5
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.25
	return m


static func clay_mat(color: Color = Color(0.72, 0.36, 0.22), kind: String = "terracotta") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var set_name := "wetclay" if kind == "raw" else ("silt" if kind == "silt" else "terracotta")
	m.albedo_texture = B.tex(set_name + "_albedo")
	m.albedo_color = color
	m.normal_enabled = true
	m.normal_texture = B.tex(set_name + "_normal")
	m.normal_scale = 1.4
	m.roughness = 0.85 if kind != "raw" else 0.35
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 1.8
	return m


static func _part(p: Puppet, parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := B.add_mesh(parent, mesh, m, pos, rot * (PI / 180.0), scl)
	p.meshes.append(mi)
	return mi


static func human(o: Dictionary = {}) -> Puppet:
	## Options: height, skin, cloth, cloth2, garment ("dhoti","lehenga","kurta"),
	## head ("hair","pagdi","odhni","bald","veil","none"), beard, clay (material for all),
	## faceless, eyes, thin, bulk, stepped.
	var p := Puppet.new()
	p.name = o.get("name", "Figure")
	var h: float = o.get("height", 1.7)
	var s := h / 1.7
	var thin: float = o.get("thin", 1.0)
	var bulk: float = o.get("bulk", 1.0)
	var all_mat: Material = o.get("clay", null)
	var sk: Material = all_mat if all_mat else skin_mat(o.get("skin", SKIN_TONES[0]))
	var c1: Material = all_mat if all_mat else cloth_mat(o.get("cloth", CLOTH[0]))
	var c2: Material = all_mat if all_mat else cloth_mat(o.get("cloth2", CLOTH[3]))
	var hair: Material = all_mat if all_mat else B.mat("hair")
	var leg := 0.82 * s
	var thigh := 0.42 * s
	var shin := 0.4 * s
	p.leg_len = leg
	p.hips_y = leg
	var hips := Node3D.new()
	hips.name = "hips"
	p.add_child(hips)
	hips.position = Vector3(0, leg, 0)
	p.reg("hips", hips)
	# torso
	_part(p, hips, B.capsule(0.15 * s * bulk * thin, 0.42 * s), c1, Vector3(0, 0.14 * s, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.75))
	var chest := Node3D.new()
	chest.name = "chest"
	hips.add_child(chest)
	chest.position = Vector3(0, 0.22 * s, 0)
	p.reg("chest", chest)
	_part(p, chest, B.capsule(0.17 * s * bulk * thin, 0.46 * s), c1, Vector3(0, 0.2 * s, 0), Vector3.ZERO, Vector3(1.05, 1.0, 0.72))
	# head
	var head := Node3D.new()
	head.name = "head"
	chest.add_child(head)
	head.position = Vector3(0, 0.46 * s, 0)
	p.reg("head", head)
	_part(p, head, B.capsule(0.045 * s, 0.14 * s, 8), sk, Vector3(0, 0.03 * s, 0))
	var hr := 0.105 * s
	var skull := _part(p, head, B.sphere(hr, -1, 16), sk, Vector3(0, 0.14 * s, 0.0), Vector3.ZERO, Vector3(0.92, 1.08, 1.0))
	skull.name = "skull"
	if not o.get("faceless", false) and all_mat == null:
		var em := B.mat("eye")
		_part(p, head, B.sphere(0.014 * s, -1, 8), em, Vector3(0.037 * s, 0.155 * s, 0.088 * s))
		_part(p, head, B.sphere(0.014 * s, -1, 8), em, Vector3(-0.037 * s, 0.155 * s, 0.088 * s))
		_part(p, head, B.sphere(0.018 * s, -1, 8), sk, Vector3(0, 0.125 * s, 0.1 * s), Vector3.ZERO, Vector3(0.8, 1.2, 1.0))
	elif o.get("faceless", false):
		# smooth, featureless
		pass
	elif all_mat != null and o.get("hollow_eyes", true):
		var dm := _m(Color(0.04, 0.02, 0.02))
		_part(p, head, B.sphere(0.02 * s, -1, 8), dm, Vector3(0.038 * s, 0.15 * s, 0.085 * s))
		_part(p, head, B.sphere(0.02 * s, -1, 8), dm, Vector3(-0.038 * s, 0.15 * s, 0.085 * s))
	match o.get("head", "hair"):
		"hair":
			_part(p, head, B.sphere(hr * 1.06, -1, 14), hair, Vector3(0, 0.16 * s, -0.012 * s), Vector3(-10, 0, 0), Vector3(0.95, 0.9, 1.0))
		"bun":
			_part(p, head, B.sphere(hr * 1.06, -1, 14), hair, Vector3(0, 0.16 * s, -0.012 * s), Vector3(-10, 0, 0), Vector3(0.95, 0.9, 1.0))
			_part(p, head, B.sphere(hr * 0.5, -1, 10), hair, Vector3(0, 0.13 * s, -0.11 * s))
		"pagdi":
			var pm: Material = all_mat if all_mat else cloth_mat(o.get("pagdi_color", Color(0.9, 0.88, 0.82)))
			var tor := TorusMesh.new()
			tor.inner_radius = hr * 0.75
			tor.outer_radius = hr * 1.2
			_part(p, head, tor, pm, Vector3(0, 0.2 * s, 0), Vector3(-8, 0, 0), Vector3(1, 1.6, 1))
			_part(p, head, B.sphere(hr * 0.98, -1, 12), pm, Vector3(0, 0.22 * s, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
		"odhni", "veil":
			var om: Material = all_mat if all_mat else cloth_mat(o.get("odhni_color", Color(0.7, 0.15, 0.2)))
			_part(p, head, B.sphere(hr * 1.2, -1, 14), om, Vector3(0, 0.16 * s, -0.02 * s), Vector3(-15, 0, 0), Vector3(1.0, 1.05, 1.05))
			_part(p, head, B.cyl(hr * 1.1, hr * 2.0, 0.42 * s, 14), om, Vector3(0, -0.06 * s, -0.04 * s), Vector3(-6, 0, 0))
			if o.get("head", "") == "veil":
				_part(p, head, B.cyl(hr * 1.15, hr * 1.3, 0.22 * s, 14), om, Vector3(0, 0.1 * s, 0.01 * s))
		"bald":
			pass
	if o.get("beard", false):
		_part(p, head, B.sphere(hr * 0.75, -1, 10), _m(Color(0.85, 0.85, 0.82)), Vector3(0, 0.07 * s, 0.06 * s), Vector3.ZERO, Vector3(1, 1.2, 0.8))
	# arms
	var arm_len := 0.3 * s
	for side in [1, -1]:
		var sname := "l" if side == 1 else "r"
		var sh := Node3D.new()
		sh.name = sname + "_arm"
		chest.add_child(sh)
		sh.position = Vector3(0.2 * s * side * bulk, 0.36 * s, 0)
		p.reg(sname + "_arm", sh)
		_part(p, sh, B.capsule(0.045 * s * bulk, arm_len + 0.06 * s), c1 if o.get("sleeves", true) else sk, Vector3(0, -arm_len * 0.5, 0))
		var el := Node3D.new()
		el.name = sname + "_fore"
		sh.add_child(el)
		el.position = Vector3(0, -arm_len, 0)
		p.reg(sname + "_fore", el)
		_part(p, el, B.capsule(0.038 * s, arm_len), sk, Vector3(0, -arm_len * 0.45, 0))
		var hand := _part(p, el, B.sphere(0.045 * s, -1, 10), sk, Vector3(0, -arm_len * 0.95, 0.0), Vector3.ZERO, Vector3(0.8, 1.1, 0.6))
		hand.name = "hand"
		var hp := Node3D.new()
		hp.name = "hand_point"
		el.add_child(hp)
		hp.position = Vector3(0, -arm_len * 1.0, 0.02)
	# legs
	for side in [1, -1]:
		var sname := "l" if side == 1 else "r"
		var hj := Node3D.new()
		hj.name = sname + "_leg"
		hips.add_child(hj)
		hj.position = Vector3(0.085 * s * side, 0, 0)
		p.reg(sname + "_leg", hj)
		_part(p, hj, B.capsule(0.06 * s * bulk, thigh + 0.08 * s), c2, Vector3(0, -thigh * 0.5, 0))
		var kn := Node3D.new()
		kn.name = sname + "_shin"
		hj.add_child(kn)
		kn.position = Vector3(0, -thigh, 0)
		p.reg(sname + "_shin", kn)
		_part(p, kn, B.capsule(0.045 * s, shin), sk if o.get("garment", "dhoti") != "lehenga" else c2, Vector3(0, -shin * 0.5, 0))
		_part(p, kn, B.mesh_box(Vector3(0.07, 0.04, 0.16) * s), sk, Vector3(0, -shin + 0.0, 0.04 * s))
	match o.get("garment", "dhoti"):
		"dhoti":
			_part(p, hips, B.cyl(0.17 * s * bulk, 0.2 * s * bulk, 0.34 * s, 14), c2, Vector3(0, -0.13 * s, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
		"lehenga":
			_part(p, hips, B.cyl(0.16 * s, 0.34 * s, 0.82 * s, 18), c2, Vector3(0, -0.36 * s, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
		"kurta":
			_part(p, hips, B.cyl(0.17 * s, 0.24 * s, 0.4 * s, 14), c1, Vector3(0, -0.15 * s, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	p.stepped = o.get("stepped", false)
	return p


static func villager(seed: int, female: bool = false, height: float = 1.65) -> Puppet:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var o := {
		"height": height * r.randf_range(0.93, 1.05),
		"skin": SKIN_TONES[r.randi() % SKIN_TONES.size()],
		"cloth": CLOTH[r.randi() % CLOTH.size()],
		"cloth2": CLOTH[r.randi() % CLOTH.size()] if female else Color(0.86, 0.84, 0.78),
		"garment": "lehenga" if female else "dhoti",
		"head": "odhni" if female else ("pagdi" if r.randf() < 0.6 else "hair"),
		"odhni_color": CLOTH[r.randi() % CLOTH.size()],
		"pagdi_color": [Color(0.9, 0.88, 0.82), Color(0.85, 0.5, 0.15), Color(0.7, 0.15, 0.15)][r.randi() % 3],
		"bulk": r.randf_range(0.92, 1.12),
	}
	return human(o)


static func tesu() -> Puppet:
	var p := human({"name": "Tesu", "height": 1.32, "skin": Color(0.45, 0.26, 0.16), "cloth": Color(0.85, 0.42, 0.12),
		"cloth2": Color(0.86, 0.84, 0.78), "garment": "dhoti", "head": "hair", "bulk": 0.95, "sleeves": false})
	# tesu-flower orange kurta, red thread, father's paddle on his back, slingshot at waist
	var chest: Node3D = p.parts["chest"]
	var hips: Node3D = p.parts["hips"]
	var s := 1.32 / 1.7
	var thread := Fig._m(Color(0.75, 0.05, 0.05))
	_part(p, chest, B.cyl(0.13 * s, 0.13 * s, 0.015, 16), thread, Vector3(0, 0.2 * s, 0), Vector3(0, 0, 25), Vector3(1.05, 1, 0.75))
	var paddle_back := Node3D.new()
	paddle_back.name = "paddle_back"
	chest.add_child(paddle_back)
	paddle_back.position = Vector3(0, 0.25 * s, -0.12)
	paddle_back.rotation_degrees = Vector3(0, 0, 35)
	var pm := B.mat("wood")
	_part(p, paddle_back, B.mesh_box(Vector3(0.18, 0.28, 0.035)), pm, Vector3(0, 0.12, 0))
	_part(p, paddle_back, B.cyl(0.018, 0.018, 0.3, 6), pm, Vector3(0, -0.15, 0))
	# paddle in hand (hidden until attacking)
	var rf: Node3D = p.parts["r_fore"]
	var paddle := Node3D.new()
	paddle.name = "paddle"
	rf.add_child(paddle)
	paddle.position = Vector3(0, -0.25, 0.03)
	paddle.rotation_degrees = Vector3(-90, 0, 0)
	_part(p, paddle, B.cyl(0.018, 0.018, 0.28, 6), pm, Vector3(0, 0.08, 0))
	_part(p, paddle, B.mesh_box(Vector3(0.2, 0.3, 0.035)), pm, Vector3(0, 0.36, 0))
	paddle.visible = false
	# slingshot at waist
	var sl := Node3D.new()
	sl.name = "sling"
	hips.add_child(sl)
	sl.position = Vector3(0.14, 0.02, 0.06)
	_part(p, sl, B.cyl(0.012, 0.012, 0.12, 5), pm, Vector3(0, 0, 0), Vector3(0, 0, 10))
	# lamp hand
	var lf: Node3D = p.parts["l_fore"]
	var lamp_hold := Node3D.new()
	lamp_hold.name = "lamp_hold"
	lf.add_child(lamp_hold)
	lamp_hold.position = Vector3(0, -0.27, 0.03)
	# gourd
	var gourd := B.add_mesh(hips, B.sphere(0.07, -1, 10), B.tint("terracotta", Color(0.7, 0.55, 0.3), 3.0), Vector3(-0.15, -0.05, -0.02), Vector3.ZERO, Vector3(1, 1.3, 1))
	gourd.name = "gourd"
	p.meshes.append(gourd)
	# door patches (indigo cloth the Mother ties over each given door)
	var head: Node3D = p.parts["head"]
	var ind := B.tint("indigo", Color(0.9, 0.9, 1.0), 6.0)
	var eye_patch := Node3D.new()
	eye_patch.name = "patch_eye"
	head.add_child(eye_patch)
	_part(p, eye_patch, B.cyl(0.108 * s, 0.108 * s, 0.014 * s, 16), ind, Vector3(0, 0.16 * s, 0.0), Vector3(-14, 0, 0), Vector3(1.0, 1.0, 1.04))
	_part(p, eye_patch, B.sphere(0.034 * s, -1, 10), ind, Vector3(0.04 * s, 0.155 * s, 0.09 * s), Vector3.ZERO, Vector3(1.0, 1.0, 0.45))
	var ear_patch := _part(p, head, B.sphere(0.04 * s, -1, 8), ind, Vector3(0.1 * s, 0.14 * s, 0), Vector3.ZERO, Vector3(0.6, 1.2, 1.0))
	ear_patch.name = "patch_ear"
	var mouth_patch := _part(p, head, B.cyl(0.1 * s, 0.1 * s, 0.05 * s, 14), ind, Vector3(0, 0.09 * s, 0.0), Vector3(-12, 0, 0), Vector3(1.0, 1.0, 1.05))
	mouth_patch.name = "patch_mouth"
	var nose_patch := _part(p, head, B.sphere(0.03 * s, -1, 8), ind, Vector3(0, 0.125 * s, 0.103 * s))
	nose_patch.name = "patch_nose"
	for n in ["patch_eye", "patch_ear", "patch_mouth", "patch_nose"]:
		head.get_node(n).visible = false
	return p


static func update_tesu_doors(p: Puppet) -> void:
	var head: Node3D = p.parts["head"]
	head.get_node("patch_eye").visible = not Game.has("eye")
	head.get_node("patch_ear").visible = not Game.has("ear")
	head.get_node("patch_mouth").visible = not Game.has("mouth")
	head.get_node("patch_nose").visible = not Game.has("nose")
	# fired skin: his skin hardens like a pot in the kiln
	var fired := not Game.has("skin")
	var sk := skin_mat(Color(0.45, 0.26, 0.16)) if not fired else clay_mat(Color(0.95, 0.5, 0.3))
	for name in ["l_fore", "r_fore", "l_shin", "r_shin"]:
		var n: Node3D = p.parts[name]
		for c in n.get_children():
			if c is MeshInstance3D and c.name != "paddle":
				(c as MeshInstance3D).material_override = sk


static func bindu_sealed() -> Node3D:
	## Bindu sealed in river clay, five doors pressed shut.
	var root := Node3D.new()
	var p := human({"name": "Bindu", "height": 1.3, "skin": Color(0.45, 0.26, 0.16), "cloth": Color(0.68, 0.2, 0.32),
		"cloth2": Color(0.55, 0.12, 0.1), "garment": "lehenga", "head": "bun"})
	root.add_child(p)
	p.anim("lie")
	var clay := clay_mat(Color(0.62, 0.55, 0.48), "silt")
	var head: Node3D = p.parts["head"]
	var s := 1.3 / 1.7
	for v in [Vector3(0.037, 0.155, 0.095), Vector3(-0.037, 0.155, 0.095), Vector3(0, 0.09, 0.098), Vector3(0, 0.125, 0.11), Vector3(0.1, 0.14, 0), Vector3(-0.1, 0.14, 0)]:
		B.add_mesh(head, B.sphere(0.028 * s, -1, 8), clay, v * s, Vector3.ZERO, Vector3(1.3, 0.8, 0.6))
	for hn in ["l_fore", "r_fore"]:
		var f: Node3D = p.parts[hn]
		B.add_mesh(f, B.sphere(0.06 * s, -1, 8), clay, Vector3(0, -0.29 * s, 0.0))
	root.set_meta("puppet", p)
	return root


static func elder(seed: int) -> Puppet:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return human({"name": "Elder", "height": 1.7, "skin": SKIN_TONES[r.randi() % 4].darkened(0.1), "cloth": Color(0.88, 0.86, 0.8),
		"cloth2": Color(0.88, 0.86, 0.8), "garment": "kurta", "head": "pagdi", "pagdi_color": Color(0.92, 0.9, 0.85), "beard": true, "thin": 0.9})


static func kaki() -> Puppet:
	var p := human({"name": "Kaki", "height": 1.5, "skin": Color(0.38, 0.22, 0.14), "cloth": Color(0.32, 0.3, 0.35),
		"cloth2": Color(0.3, 0.28, 0.3), "garment": "lehenga", "head": "odhni", "odhni_color": Color(0.85, 0.83, 0.78), "faceless": true})
	var head: Node3D = p.parts["head"]
	# her eyes, given to the Mother long ago: an indigo band
	var ind := B.tint("indigo", Color.WHITE, 6.0)
	B.add_mesh(head, B.cyl(0.085, 0.085, 0.03, 14), ind, Vector3(0, 0.14, 0), Vector3(-0.15, 0, 0), Vector3(1, 1, 1.08))
	return p


static func baba() -> Puppet:
	var p := human({"name": "Baba", "height": 1.72, "skin": Color(0.4, 0.23, 0.14), "cloth": Color(0.86, 0.84, 0.78),
		"cloth2": Color(0.86, 0.84, 0.78), "garment": "dhoti", "head": "hair", "bulk": 1.1, "sleeves": false})
	var head: Node3D = p.parts["head"]
	# lips sealed with clay in grief
	B.add_mesh(head, B.sphere(0.03, -1, 8), clay_mat(Color(0.62, 0.55, 0.48), "silt"), Vector3(0, 0.095, 0.1), Vector3.ZERO, Vector3(1.6, 0.7, 0.6))
	return p


static func watchman(seed: int) -> Puppet:
	return human({"name": "Watchman", "height": 1.75, "skin": SKIN_TONES[seed % 4], "cloth": Color(0.25, 0.22, 0.2),
		"cloth2": Color(0.8, 0.78, 0.7), "garment": "dhoti", "head": "pagdi", "pagdi_color": Color(0.75, 0.2, 0.1), "bulk": 1.15})


static func clay_person(height: float, color: Color = Color(0.74, 0.38, 0.24), kind: String = "terracotta", faceless: bool = false) -> Puppet:
	var m := clay_mat(color, kind)
	var p := human({"name": "Clay", "height": height, "clay": m, "garment": "dhoti", "head": "bald", "faceless": faceless, "stepped": true})
	return p
