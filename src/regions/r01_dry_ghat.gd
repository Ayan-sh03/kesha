extends Region
## I · Dry Ghat — prologue, the giving, night.
## The village gathers on the stone steps above the cracked riverbed, every
## adult with their doors shut. You play the walk down the steps, and the
## moment you try to stop it.

const ART := "res://assets/art/dry_ghat/"

var elders: Array = []
var bindu: Node3D
var boat: Node3D
var boat_light: OmniLight3D
var baba: Puppet
var mouth_x := 64.0
var _scene_started := false
var _night := Color(0.46, 0.5, 0.72)


func step_y(x: float) -> float:
	## Height of the ghat at x (24 steps of 1.5 m run, 0.5 m rise, from x=0).
	if x <= 0.0:
		return 12.0
	if x >= 36.0:
		return 0.0
	return 12.0 - floor(x / 1.5 + 1.0) * 0.5


func build() -> void:
	music = "ghatiya"
	ambience = "amb_wind"
	space = Vector2(0.55, 0.16)
	set_meta("cam_dist", 6.6)
	set_meta("cam_height", 1.55)
	set_meta("cam_fov", 38.0)
	set_meta("cam_pitch", -4.0)
	spawn = Vector3(-14, 12.1, 0)
	setup_env({
		"bg": "color", "bg_color": Color(0.035, 0.05, 0.085),
		"ambient": Color(0.3, 0.33, 0.55), "ambient_energy": 0.32,
		"fog_color": Color(0.09, 0.08, 0.13), "fog_density": 0.006, "aerial": 0.0,
		"vfog_density": 0.022, "vfog_albedo": Color(0.62, 0.6, 0.72), "vfog_length": 80.0,
		"moon": {"color": Color(0.58, 0.64, 0.95), "energy": 1.1, "rot": Vector3(-22, 150, 0), "shadow_dist": 60.0, "vfog": 1.4},
		"exposure": 1.15, "glow": 1.0, "bloom": 0.06, "contrast": 1.12, "saturation": 1.08,
	})
	_backdrop()
	_terrain()
	_village_top()
	_crowd()
	_riverbed()
	_foreground()
	_tutorial()
	cam_zone(32, 110, -5, 20, {"dist": 11.0, "height": 2.4, "fov": 38.0, "pitch": -5.0})
	Props.trigger(self, Vector3(44, 2, 0), Vector3(2, 10, 4), func(_p: Node) -> void: _giving())


# ------------------------------------------------------------- layers
func _paint(file: String, pos: Vector3, h: float, opts: Dictionary = {}) -> MeshInstance3D:
	var path := ART + file
	if not ResourceLoader.exists(path):
		return null
	var o := {"grade": _night}
	o.merge(opts, true)
	return B.painting(self, path, pos, h, o)


func _backdrop() -> void:
	# the far bank across the dead river: a painted panorama far behind.
	# Its bottom edge (the far riverbank) tucks behind the near ground's horizon.
	var h := 44.0
	var w := h * 3136.0 / 835.0
	for i in 3:
		_paint("far_town.png", Vector3(-70.0 + i * w * 0.995, -2.5, -110.0), h, {"grade": Color(0.78, 0.8, 0.92), "keep_lights": 1.0, "desat": 0.05, "mirror": float(i % 2), "far": true})


func _terrain() -> void:
	var brick := B.mat("brick", 0.5)
	ground(-46, 0, 12, "earth", 14, -40, 6.5)
	block(-46, 0, -2, 12, B.mat("oldbrick", 0.5), 5.2, 7.0)
	steps(0, 12, 24, 1.5, -0.5, brick, -14.0, 6.5)
	ground(36, 59.5, 0, "silt", 8, -30, 6.5)
	ground(mouth_x + 4.5, 150, 0, "silt", 8, -30, 6.5)
	# side walls of the ghat, receding
	block(0, 36, -3, 12.5, B.mat("oldbrick", 0.5), -16, -14)
	# the Mouth: a sinkhole into the dark
	var pit := MeshInstance3D.new()
	pit.mesh = B.cyl(5.0, 2.5, 30, 32)
	pit.material_override = B.mat("void")
	add_child(pit)
	pit.position = Vector3(mouth_x, -15.2, -2.0)
	block(59.5, mouth_x + 4.5, -40, -6, "void", -8, 3)
	for i in 18:
		var a := TAU * i / 18.0
		var rock := B.add_mesh(self, B.mesh_box(Vector3(1.6, 0.7, 1.1)), B.mat("silt", 0.6), Vector3(mouth_x + cos(a) * 4.9, -0.25, -2.0 + sin(a) * 4.9), Vector3(randf_range(-0.3, 0.3), a, randf_range(-0.5, 0.5)))
		rock.scale = Vector3(1, randf_range(0.5, 1.4), 1)
	_paint("mouth.png", Vector3(mouth_x, -1.6, -7.0), 6.0, {"grade": Color(0.55, 0.55, 0.75)})
	mother_light(Vector3(mouth_x, -8, -2), 0.0, 10.0)
	var deep := OmniLight3D.new()
	deep.light_color = Color(0.35, 0.4, 1.0)
	deep.light_energy = 1.2
	deep.omni_range = 9.0
	deep.light_volumetric_fog_energy = 4.0
	add_child(deep)
	deep.position = Vector3(mouth_x, -6.0, -2.0)
	var wallb := StaticBody3D.new()
	wallb.name = "lip_wall"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 10, 4)
	cs.shape = bs
	wallb.add_child(cs)
	add_child(wallb)
	wallb.position = Vector3(58.5, 5, 0)


func _village_top() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var houses := ["house1.png", "house2.png"]
	for i in 7:
		var x := -44.0 + i * 6.2
		_paint(houses[i % 2], Vector3(x, 12.0, -10.0 - (i % 3) * 2.5), r.randf_range(5.2, 6.4), {"mirror": float(i % 3 == 1), "keep_lights": 1.0, "grade": Color(0.2, 0.23, 0.38), "desat": 0.35})
	for i in 3:
		_paint("kiln.png", Vector3(-40.0 + i * 15.0, 12.0, -18.0), 6.5, {"mirror": float(i % 2), "grade": Color(0.32, 0.34, 0.5)})
	_paint("pots.png", Vector3(-30, 12.0, -5.5), 2.4)
	_paint("pots.png", Vector3(-8, 12.0, -6.0), 2.1, {"mirror": 1.0})
	for i in 5:
		B.model(self, "matka", Vector3(-38.0 + i * 6.5, 12.0, -3.4 + (i % 2) * 0.6), 1.0, i)
	B.model(self, "wheel", Vector3(-24.0, 12.0, -3.2), 1.2)
	# Baba at the top of the steps, every door shut
	baba = CharModel.make("baba")
	add_child(baba)
	baba.position = Vector3(-11.0, 12.0, -1.3)
	baba.rotation_degrees.y = 60
	baba.anim("band")


func _villager(pos: Vector3, i: int, pose: String) -> void:
	var f := CharModel.make("villager_f" if i % 2 == 0 else "villager_m")
	add_child(f)
	f.position = pos
	f.rotation_degrees.y = randf_range(-35, 35) + (180.0 if pos.z < -3.0 else 0.0) * 0.0
	f.anim(pose)
	if f.player:
		f.player.seek(randf() * 2.0, true)
	if pose == "pray_palms" and f.parts.has("r_fore"):
		B.diya(f.parts["r_fore"], Vector3(0, 0.1, 0.06), true, 0.0)


func _crowd() -> void:
	## Whole lanes of motionless people: the most unsettling thing in Ghatiya.
	var r := RandomNumberGenerator.new()
	r.seed = 3
	# painted crowds deeper on the steps
	for i in 9:
		var x := -4.0 + i * 4.6
		var y := step_y(x)
		_paint(["crowd1.png", "crowd2.png"][i % 2], Vector3(x, y, -7.5 - (i % 3) * 1.6), 1.95, {"mirror": float(i % 3 == 0), "keep_lights": 1.0, "flicker": 1.0})
	# 3D villagers close to the walking line, some in front of it
	for i in 16:
		var x := r.randf_range(-6, 38)
		var z := r.randf_range(-3.6, -1.4) if r.randf() < 0.7 else r.randf_range(1.4, 2.6)
		_villager(Vector3(x, step_y(x), z), i, "band" if r.randf() < 0.55 else "pray_palms")
		if i % 4 == 0:
			B.lamp_light(self, Vector3(x, step_y(x) + 1.3, z + 0.6), Color(1.0, 0.6, 0.3), 0.55, 4.5)
	# a lamp on every step
	for i in 24:
		var x := i * 1.5 + 0.75
		var y := 12.0 - (i + 1) * 0.5
		B.diya(self, Vector3(x, y, -4.6), true, 0.0)
		B.diya(self, Vector3(x + 0.4, y, 3.4), true, 0.0)
		if i % 3 == 0:
			B.lamp_light(self, Vector3(x, y + 0.5, 3.0), Color(1.0, 0.58, 0.28), 0.6, 3.5)
		if i % 2 == 0:
			_paint("lamps.png", Vector3(x, y - 0.02, -5.4), 0.55, {"keep_lights": 1.0, "flicker": 1.0})
	# chhatri pavilions beside the steps
	for i in 3:
		var x := 7.0 + i * 11.0
		_paint("chhatri.png", Vector3(x, step_y(x), -11.5), 7.0, {"keep_lights": 1.0, "flicker": 1.0})
		B.lamp_light(self, Vector3(x, step_y(x) + 2.0, -10.5), Color(1.0, 0.55, 0.25), 1.4, 7.0)


func _riverbed() -> void:
	var bx := 52.0
	boat = Node3D.new()
	add_child(boat)
	boat.position = Vector3(bx, 0, -1.6)
	var hull := B.model(boat, "boat", Vector3.ZERO, 1.6, PI * 0.5)
	hull.name = "hull"
	bindu = CharModel.make("bindu")
	boat.add_child(bindu)
	bindu.position = Vector3(-0.1, 0.22, 0)
	bindu.rotation_degrees.y = 90
	(bindu as CharModel).anim("lie")
	var lamp := B.diya(boat, Vector3(0.95, 0.35, 0.15), true, 0.0)
	lamp.name = "boat_lamp"
	boat_light = B.lamp_light(boat, Vector3(0.95, 0.9, 0.4), Color(1.0, 0.62, 0.3), 2.6, 7.0, true)
	for i in 5:
		var e := CharModel.make("elder")
		add_child(e)
		var a := PI * (0.12 + 0.76 * i / 4.0)
		e.position = Vector3(bx + cos(a) * 2.3, 0, -1.6 - sin(a) * 1.5 + 0.9)
		e.look_at_from_position(e.position, Vector3(bx, 0, -1.6), Vector3.UP)
		e.rotate_y(PI)
		e.anim("band")
		elders.append(e)
	_paint("elders.png", Vector3(bx + 9.0, 0, -9.0), 2.0, {"keep_lights": 1.0})
	# the cord-count: a long knotted cord on a post, a new knot at the end
	B.add_mesh(self, B.cyl(0.08, 0.1, 2.2, 10), B.mat("terracotta", 1.0), Vector3(bx - 4.0, 1.1, -3.0))
	for i in 9:
		B.add_mesh(self, B.sphere(0.07, -1, 8), B.mat("rope", 3.0), Vector3(bx - 4.0 + 0.12, 1.9 - i * 0.18, -2.9))
	B.add_mesh(self, B.sphere(0.09, -1, 8), B.emissive(Color(0.9, 0.5, 0.3), 1.5), Vector3(bx - 4.0 + 0.12, 1.9 - 9 * 0.18, -2.9))
	for i in 10:
		B.model(self, ["matka", "surahi"][i % 2], Vector3(38.0 + i * 7.3, 0, -6.0 - (i % 3) * 3.0), 1.0, i * 0.7)
	for i in 4:
		B.model(self, "boat", Vector3(76.0 + i * 11.0, 0.05, -8.0 - i * 2.5), 1.8, 0.4 + i).rotation.z = 0.25


func _foreground() -> void:
	# dark silhouettes passing between the camera and Tesu: deep parallax
	for i in 12:
		var x := -40.0 + i * 13.0
		var y := step_y(x) - 0.7
		_paint("fg_pots.png", Vector3(x, y, 4.8), 1.15, {"grade": Color(0.12, 0.11, 0.14), "keep_lights": 0.0, "mirror": float(i % 2)})


func _tutorial() -> void:
	Props.trigger(self, Vector3(-12, 13, 0), Vector3(2, 4, 4), func(_p: Node) -> void:
		Game.say("Every adult has their doors shut: eyes closed, ears stopped, lips pressed, breath held.", "", 4.0)
		Game.say("They can't see you. They can't hear you.", "", 3.0))
	Props.trigger(self, Vector3(-2, 13, 0), Vector3(2, 4, 4), func(_p: Node) -> void:
		Game.show_hint("[A / D] run   ·   [Space] jump   ·   [S] creep"))
	for i in 4:
		var b := Breakable.make(self, Vector3(4.6 + i * 1.5, 12.0 - (4 + i) * 0.5, 0.6), "pot")
		b.drops = 1
	Props.trigger(self, Vector3(4, 11, 0), Vector3(2, 4, 4), func(_p: Node) -> void:
		Game.show_hint("[Left mouse / J] swing Baba's paddle. Three in a row."))
	for i in 3:
		var bl := Breakable.make(self, Vector3(18 + i * 4.5, step_y(18 + i * 4.5) + 4.2, -0.4), "bell")
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
	p.puppet.anim("idle")
	var main = Game.main
	main.post.letterbox_target = 1.0
	rig.cinematic(Vector3(45, 3.2, 10.5), Vector3(53, 0.9, -1.5), 3.0, 36.0)
	await main.line("The five elders read the drought the old way.", "", "", 3.4)
	await main.line("Twins are two bodies sharing one house of five doors.", "elder", "", 3.6)
	await main.line("In a bad year, one is given Below, so the other can have a whole house.", "elder", "", 4.4)
	rig.cinematic(Vector3(50.2, 1.2, 2.4), Vector3(52, 0.5, -1.6), 2.5, 32.0)
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
	rig.cinematic(Vector3(54, 5.0, 11.0), Vector3(mouth_x, -0.5, -2.0), 3.0, 38.0)
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(boat, "position", Vector3(mouth_x - 3.5, 0, -2.0), 3.0)
	await main.wait(3.2)
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
	rig.cinematic(Vector3(p.global_position.x - 1.6, p.global_position.y + 1.3, 3.6), Vector3(mouth_x, -2.0, -2.0), 1.4, 34.0)
	Snd.sfx("rumble", boat.global_position, -6)
	await main.wait(3.4)
	Snd.sfx("splash", Vector3(mouth_x, -10, -2), 0)
	main.post.desat = 0.6
	Fx.shake(0.3)
	await main.line("The Mouth swallows her lamp.", "", "", 3.0)
	p.puppet.anim("kneel")
	await main.line("Her twin feels it happen. Half of everything goes quiet.", "", "", 4.4)
	await main.post.fade_to(1.0, 2.5).finished
	main.post.desat = 0.0
	finish()
