extends Region
## I · Dry Ghat — prologue, the giving, night.
## The village gathers on the stone steps above the cracked riverbed, every
## adult with their doors shut. You play the walk down the steps, and the
## moment you try to stop it.

var elders: Array = []
var bindu: Node3D
var boat: Node3D
var boat_light: OmniLight3D
var baba: Puppet
var mouth_x := 64.0
var crowd: Array = []
var _scene_started := false


func build() -> void:
	music = "ghatiya"
	ambience = "amb_wind"
	space = Vector2(0.5, 0.15)
	set_meta("cam_dist", 8.5)
	set_meta("cam_height", 1.7)
	spawn = Vector3(-14, 12.1, 0)
	setup_env({
		"bg": "sky",
		"sky": {"top_color": Color(0.01, 0.014, 0.045), "horizon_color": Color(0.16, 0.11, 0.16), "moon_dir": Vector3(0.7, 0.24, -1.0), "moon_size": 0.035, "moon_energy": 2.2, "dust": 0.5},
		"ambient": Color(0.32, 0.34, 0.55), "ambient_energy": 0.3,
		"fog_color": Color(0.1, 0.08, 0.12), "fog_density": 0.008, "vfog_density": 0.018, "vfog_albedo": Color(0.65, 0.6, 0.7),
		"moon": {"color": Color(0.6, 0.66, 0.95), "energy": 0.8, "rot": Vector3(-18, 160, 0), "shadow_dist": 80.0},
		"exposure": 1.15,
	})
	_terrain()
	_village_top()
	_crowd()
	_riverbed()
	_far_bank()
	_tutorial()
	# camera: wide as the river opens
	cam_zone(30, 110, -5, 20, {"dist": 14.0, "height": 3.0, "fov": 40.0})
	Props.trigger(self, Vector3(44, 2, 0), Vector3(2, 10, 4), func(_p: Node) -> void: _giving())


func _terrain() -> void:
	var brick := B.mat("brick", 0.7)
	# the village terrace
	ground(-40, 0, 12, "silt", 14)
	block(-40, 0, -2, 12, brick, 3.0, 5.0)
	# the ghat: 24 broad brick steps down to the dead river
	steps(0, 12, 24, 1.5, -0.5, brick, -12.0, 3.0)
	# low walls and pavilions (chhatri) at the side of the steps
	for i in 3:
		var x := 6.0 + i * 11.0
		var y := 12.0 - (x / 1.5) * 0.5
		_chhatri(Vector3(x, y, -7.0))
	ground(36, 59.5, 0, "silt", 8)
	ground(mouth_x + 4.5, 140, 0, "silt", 8)
	# lip of the Mouth: a jagged edge and the dark below
	var pit := MeshInstance3D.new()
	pit.mesh = B.cyl(5.0, 2.5, 30, 24)
	pit.material_override = B.mat("void")
	add_child(pit)
	pit.position = Vector3(mouth_x, -15.2, -2.0)
	for i in 14:
		var a := TAU * i / 14.0
		var rock := B.add_mesh(self, B.mesh_box(Vector3(1.4, 0.6, 1.0)), B.mat("silt", 0.6), Vector3(mouth_x + cos(a) * 4.7, -0.2, -2.0 + sin(a) * 4.7), Vector3(randf_range(-0.3, 0.3), a, randf_range(-0.4, 0.4)))
		rock.scale = Vector3(1, randf_range(0.6, 1.4), 1)
	block(59.5, mouth_x + 4.5, -40, -6, "void", -8, 3)
	# the curtain of air: invisible barrier that catches him at the lip
	var wallb := StaticBody3D.new()
	wallb.name = "lip_wall"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 10, 4)
	cs.shape = bs
	wallb.add_child(cs)
	add_child(wallb)
	wallb.position = Vector3(58.5, 5, 0)


func _chhatri(p: Vector3) -> void:
	var m := B.mat("brick", 0.7)
	for dx in [-1.4, 1.4]:
		for dz in [-1.4, 1.4]:
			B.add_mesh(self, B.mesh_box(Vector3(0.35, 3.0, 0.35)), m, p + Vector3(dx, 1.5, dz))
	B.add_mesh(self, B.mesh_box(Vector3(3.6, 0.3, 3.6)), m, p + Vector3(0, 3.1, 0))
	var dome := B.add_mesh(self, B.lathe_mesh("dome", 24), B.mat("limewash", 0.8), p + Vector3(0, 3.2, 0), Vector3.ZERO, Vector3(1.7, 1.4, 1.7))
	dome.name = "dome"
	B.diya(self, p + Vector3(0, 0.05, 1.6), true, 0.8)


func _village_top() -> void:
	for i in 7:
		var x := -38.0 + i * 5.5
		house(x, 12, -8.0 - (i % 3) * 3.0, randf_range(3.5, 5.0), randf_range(2.8, 3.6), 3.5, true, i % 2 == 0)
	kiln(Vector3(-20, 12, -16), 1.3)
	kiln(Vector3(-6, 12, -13), 1.0)
	scatter_pots(-38, -2, 12, -6, -3, 40)
	# Baba at the top of the steps, eyes shut
	baba = Fig.human({"name": "Baba", "height": 1.72, "skin": Color(0.4, 0.23, 0.14), "cloth": Color(0.86, 0.84, 0.78), "cloth2": Color(0.86, 0.84, 0.78), "head": "hair", "bulk": 1.1, "sleeves": false})
	add_child(baba)
	baba.position = Vector3(-11, 12, -0.9)
	baba.rotation_degrees.y = 70
	baba.anim("band")


func _crowd() -> void:
	## Whole lanes of motionless people: the most unsettling thing in Ghatiya.
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 34:
		var x := r.randf_range(-6, 40)
		var y: float = 12.0 - clampf(x / 1.5, 0.0, 24.0) * 0.5 if x > 0 else 12.0
		if x > 36:
			y = 0.0
		y = 12.0 - floor(clamp(x, 0.0, 35.99) / 1.5 + 1.0) * 0.5 if x > 0.0 and x < 36.0 else y
		var z := r.randf_range(-4.5, -1.0) if r.randf() < 0.75 else r.randf_range(1.2, 2.4)
		var f := Fig.villager(i * 13 + 5, r.randf() < 0.5)
		add_child(f)
		f.position = Vector3(x, y, z)
		f.rotation_degrees.y = r.randf_range(140, 220)
		var pose := "band" if r.randf() < 0.6 else "pray_palms"
		f.anim(pose)
		crowd.append(f)
		if pose == "pray_palms":
			# a lamp in every hand
			var hp: Node3D = f.parts["r_fore"]
			B.diya(hp, Vector3(0, -0.32, 0.05), true, 0.0)
			B.glow_card(f, Vector3(0, 1.1, 0.3), 0.7, Color(1.0, 0.6, 0.3, 0.5))
		if i % 6 == 0:
			B.lamp_light(self, Vector3(x, y + 1.2, z + 0.5), Color(1.0, 0.6, 0.3), 0.8, 5.0)
	# lamps along every step
	for i in 24:
		var x := i * 1.5 + 0.75
		var y := 12.0 - (i + 1) * 0.5
		for z in [-5.5, 2.6]:
			B.diya(self, Vector3(x, y, z), true, 0.0)
		B.glow_card(self, Vector3(x, y + 0.1, -5.5), 0.5, Color(1.0, 0.6, 0.3, 0.6))


func _riverbed() -> void:
	# the boat, the five elders, Bindu sealed in clay
	var bx := 52.0
	boat = Node3D.new()
	add_child(boat)
	boat.position = Vector3(bx, 0, -1.6)
	var hull := B.add_mesh(boat, B.lathe_mesh("dome", 28), B.mat("terracotta", 1.2), Vector3(0, 0.55, 0), Vector3(PI, 0, 0), Vector3(1.1, 0.55, 0.55))
	hull.name = "hull"
	bindu = Fig.bindu_sealed()
	boat.add_child(bindu)
	bindu.position = Vector3(-0.55, 0.32, 0)
	bindu.rotation_degrees.y = 90
	var lamp := B.diya(boat, Vector3(0.75, 0.6, 0.1), true, 0.0)
	lamp.name = "boat_lamp"
	boat_light = B.lamp_light(boat, Vector3(0.75, 1.0, 0.3), Color(1.0, 0.62, 0.3), 2.4, 7.0, true)
	for i in 5:
		var e := Fig.elder(100 + i)
		add_child(e)
		var a := PI * (0.15 + 0.7 * i / 4.0)
		e.position = Vector3(bx + cos(a) * 2.4, 0, -1.6 - sin(a) * 1.6 + 1.0)
		e.look_at_from_position(e.position, Vector3(bx, 0, -1.6), Vector3.UP)
		e.rotate_y(PI)
		e.anim("band")
		elders.append(e)
	# the cord-count: a long knotted cord on a post
	B.add_mesh(self, B.cyl(0.08, 0.1, 2.2, 8), B.mat("terracotta", 1.0), Vector3(bx - 4.0, 1.1, -3.0))
	for i in 9:
		B.add_mesh(self, B.sphere(0.07, -1, 8), B.mat("rope", 3.0), Vector3(bx - 4.0 + 0.12, 1.9 - i * 0.18, -2.9))
	B.add_mesh(self, B.sphere(0.09, -1, 8), B.emissive(Color(0.9, 0.5, 0.3), 1.5), Vector3(bx - 4.0 + 0.12, 1.9 - 9 * 0.18, -2.9))
	# cracked riverbed dressing: dry boats, broken pots, bones of the old river
	scatter_pots(38, 100, 0, -10, -3, 30, ["matka", "kulhad", "surahi"], Vector2(0.6, 1.2))
	for i in 3:
		var hb := B.add_mesh(self, B.lathe_mesh("dome", 20), B.tint("terracotta", Color(0.7, 0.62, 0.55), 1.0), Vector3(75 + i * 9, 0.2, -6 - i * 2), Vector3(PI + 0.3, i, 0.2), Vector3(1.5, 0.5, 0.7))
		hb.name = "old_boat"


func _far_bank() -> void:
	# the far bank: a silhouette of another, empty ghat
	var m := B.tint("brick", Color(0.5, 0.45, 0.5), 0.5)
	for i in 14:
		block(10 + i * 9, 19 + i * 9, 0, 3 + (i % 4) * 1.5, m, -70, -50)
	for i in 6:
		_chhatri(Vector3(18 + i * 18, 3 + (i % 3) * 1.5, -58))
	# foreground: stacks of drying pots passing close in front of the camera
	for i in 10:
		var x := -12 + i * 11.0
		var y: float = 12.0 - floor(clampf(x, 0.0, 35.99) / 1.5 + 1.0) * 0.5 if x > 0.0 and x < 36.0 else (12.0 if x <= 0.0 else 0.0)
		for k in 3:
			B.pot(self, Vector3(x + k * 0.6, y - 0.6, 4.2 + k * 0.3), "matka", 1.6, B.tint("terracotta", Color(0.35, 0.3, 0.32), 2.0), k)


func _tutorial() -> void:
	Props.trigger(self, Vector3(-12, 13, 0), Vector3(2, 4, 4), func(_p: Node) -> void:
		Game.say("Every adult has their doors shut: eyes closed, ears stopped, lips pressed, breath held.", "", 4.0)
		Game.say("They can't see you. They can't hear you.", "", 3.0))
	Props.trigger(self, Vector3(-2, 13, 0), Vector3(2, 4, 4), func(_p: Node) -> void:
		Game.show_hint("[A / D] run   ·   [Space] jump   ·   [S] creep"))
	# offerings: clay pots to break with the paddle
	for i in 4:
		var b := Breakable.make(self, Vector3(4.6 + i * 1.5, 12.0 - (4 + i) * 0.5, 0.6), "pot")
		b.drops = 1
	Props.trigger(self, Vector3(4, 11, 0), Vector3(2, 4, 4), func(_p: Node) -> void:
		Game.show_hint("[Left mouse / J] swing Baba's paddle. Three in a row."))
	# bells to knock with the sling
	for i in 3:
		var bl := Breakable.make(self, Vector3(18 + i * 4.5, 12.0 - ((18 + i * 4.5) / 1.5) * 0.5 + 4.2, -0.4), "bell")
		bl.rung.connect(func() -> void: Game.flags["rang_bell"] = true)
	Props.trigger(self, Vector3(15, 6, 0), Vector3(2, 8, 4), func(_p: Node) -> void:
		Game.show_hint("[Right mouse / K] hold to aim the sling, release to loose. Knock the bells."))
	Props.trigger(self, Vector3(28, 3, 0), Vector3(2, 8, 4), func(_p: Node) -> void:
		Game.show_hint("[Q] block. Block just as a blow lands to parry.   [Shift] roll."))


func begin() -> void:
	Game.say("In the third year of drought, the river Sookhi is a crack in the ground.", "", 4.2)
	Game.say("Tonight the elders give a potter's daughter to the god beneath it.", "", 4.2)


func _giving() -> void:
	if _scene_started:
		return
	_scene_started = true
	var p := Game.player as Player
	p.set_cutscene(true)
	var main = Game.main
	main.post.letterbox_target = 1.0
	rig.cinematic(Vector3(46, 4.5, 13.0), Vector3(53, 1.0, -1.5), 3.0, 38.0)
	await main.line("The five elders read the drought the old way.", "", "", 3.4)
	await main.line("Twins are two bodies sharing one house of five doors.", "elder", "", 3.6)
	await main.line("In a bad year, one is given Below, so the other can have a whole house.", "elder", "", 4.4)
	rig.cinematic(Vector3(50.5, 1.6, 2.6), Vector3(52, 0.7, -1.6), 2.5, 34.0)
	for e in elders:
		(e as Puppet).anim("kneel")
	await main.wait(1.0)
	await main.line("They seal her five doors with river clay: eyes, ears, lips, nostrils, palms.", "", "", 4.4)
	Snd.sfx("step_silt0", boat.global_position, 0)
	await main.wait(0.6)
	Snd.sfx("step_silt2", boat.global_position, 0)
	await main.line("Bindu.", "tesu", "", 1.6)
	for e in elders:
		(e as Puppet).anim("grab")
	rig.cinematic(Vector3(55, 6.0, 12.0), Vector3(mouth_x, -0.5, -2.0), 3.0, 40.0)
	# the boat is carried to the lip of the Mouth
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(boat, "position", Vector3(mouth_x - 3.5, 0, -2.0), 3.0)
	await main.wait(3.2)
	# control returns: the moment you try to stop it
	main.post.letterbox_target = 0.0
	rig.release(1.0)
	p.set_cutscene(false)
	Game.show_hint("Run.")
	Snd.music("")
	Snd.sfx("heartbeat", null, 0, 0.0)
	var t2 := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t2.tween_property(boat, "position", Vector3(mouth_x, -0.3, -2.0), 2.4)
	t2.tween_property(boat, "rotation_degrees:z", -28.0, 0.8)
	t2.tween_property(boat, "position:y", -22.0, 4.5)
	t2.parallel().tween_property(boat_light, "light_energy", 0.0, 4.5)
	await main.wait(2.6)
	p.set_cutscene(true)
	main.post.letterbox_target = 1.0
	p.puppet.anim("reach")
	rig.cinematic(Vector3(p.global_position.x - 1.5, 1.6, 4.0), Vector3(mouth_x, -2.0, -2.0), 1.4, 36.0)
	Snd.sfx("rumble", boat.global_position, -6)
	await main.wait(3.4)
	Snd.sfx("splash", Vector3(mouth_x, -10, -2), 0)
	main.post.desat = 0.6
	Fx.shake(0.3)
	await main.line("The Mouth swallows her lamp.", "", "", 3.0)
	await main.line("Her twin feels it happen. Half of everything goes quiet.", "", "", 4.4)
	await main.post.fade_to(1.0, 2.5).finished
	main.post.desat = 0.0
	finish()
