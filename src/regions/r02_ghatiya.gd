extends Region
## II · Ghatiya — the potters' lanes, the hub.
## Narrow lanes of drying pots, cold kilns and door-niches. The elders post
## watchmen to keep everyone away from the river. Kaki's house is here.

const WatchmanS := preload("res://src/enemies/watchman.gd")
const ThirstyS := preload("res://src/enemies/thirsty.gd")
const KnockersS := preload("res://src/enemies/knockers.gd")

var kaki: Puppet
var baba: Puppet
var mouth_x := 196.0
var _fell := false


func build() -> void:
	music = "ghatiya_night"
	ambience = "amb_wind"
	space = Vector2(0.45, 0.12)
	set_meta("cam_dist", 8.5)
	set_meta("cam_height", 1.8)
	spawn = Vector3(4, 0.1, 0)
	var hold := Game.hold()
	setup_env({
		"bg": "sky",
		"sky": {"top_color": Color(0.012, 0.015, 0.05), "horizon_color": Color(0.14, 0.1, 0.16) if hold < 4 else Color(0.32, 0.12, 0.07),
			"moon_dir": Vector3(-0.5, 0.42, -1.0), "moon_size": 0.03, "moon_energy": 2.0, "fire": 0.7 if hold >= 4 else 0.0},
		"ambient": Color(0.3, 0.33, 0.55), "ambient_energy": 0.22,
		"fog_color": Color(0.08, 0.07, 0.1), "fog_density": 0.01, "vfog_density": 0.03, "vfog_albedo": Color(0.6, 0.58, 0.68),
		"moon": {"color": Color(0.55, 0.62, 0.95), "energy": 0.55, "rot": Vector3(-38, -30, 0), "shadow_dist": 60.0},
		"exposure": 1.2,
	})
	ground(-20, mouth_x - 4.0, 0, "silt", 8, -14, 3)
	block(mouth_x + 4.0, mouth_x + 60, -8, 0, "silt", -14, 3)
	_courtyard()
	_lanes()
	_kaki_house()
	_night_lanes()
	_burning_ground()
	_river_edge()
	_village_changes(hold)
	# far background: the rest of Ghatiya, kilns and roofs under the moon
	for i in 22:
		house(-10 + i * 10.0 + randf_range(-2, 2), 0, -22 - (i % 3) * 5.0, randf_range(4, 7), randf_range(3, 5), 4, true, i % 4 == 0)
	for i in 6:
		kiln(Vector3(10 + i * 30.0, 0, -34), 2.0, false, hold >= 3)


# ------------------------------------------------------------- pieces
func lane_house(x0: float, x1: float, h: float, z0: float = -4.0, z1: float = -1.2, lit: bool = false, climb_side: int = 0) -> void:
	## A walkable flat-roofed house in the lane: the roofs are the safe road.
	block(x0, x1, 0, h, B.mat("limewash", 0.6), z0, z1)
	block(x0 - 0.1, x1 + 0.1, h, h + 0.25, B.tint("terracotta", Color(0.75, 0.6, 0.5), 0.8), z0 - 0.1, z1 + 0.1)
	# a thin tiled chhajja over the lane: walkable, and you can jump up through it
	var eave := OneWay.make(self, Vector3((x0 + x1) * 0.5, h - 0.08, (z1 + 0.7) * 0.5), Vector3(x1 - x0 + 0.3, 0.16, 0.7 - z1), B.tint("terracotta", Color(0.8, 0.55, 0.45), 1.5))
	eave.rotation.x = -0.06
	for i in int((x1 - x0) / 1.4):
		B.add_mesh(self, B.mesh_box(Vector3(0.12, 0.35, 0.12)), B.mat("terracotta", 2.0), Vector3(x0 + 0.5 + i * 1.4, h - 0.32, z1 + 0.15))
	var w := x1 - x0
	B.add_mesh(self, B.mesh_box(Vector3(0.9, 1.9, 0.1)), B.mat("dark"), Vector3(x0 + w * 0.3, 0.95, z1 + 0.05))
	B.add_mesh(self, B.mesh_box(Vector3(0.6, 0.6, 0.1)), B.emissive(Color(1.0, 0.55, 0.25), 1.6) if lit else B.mat("dark"), Vector3(x0 + w * 0.7, h * 0.55, z1 + 0.05))
	if lit:
		B.lamp_light(self, Vector3(x0 + w * 0.7, h * 0.55, z1 + 0.8), Color(1.0, 0.55, 0.25), 0.8, 4.0)
	# door-niche of five tiny doors and bells
	for i in 5:
		var nx := x0 + w * 0.5 + i * 0.16
		B.add_mesh(self, B.mesh_box(Vector3(0.11, 0.18, 0.05)), B.mat("terracotta", 4.0), Vector3(nx, 1.25, z1 + 0.04))
		var bell := B.add_mesh(self, B.lathe_mesh("bell", 10), B.mat("brass"), Vector3(nx, 1.08, z1 + 0.08), Vector3.ZERO, Vector3.ONE * 0.5)
		bell.add_to_group("niche_bell")
	if climb_side != 0:
		climbable(x0 - 0.3 if climb_side < 0 else x1 + 0.3, 0, h + 0.2, "wall")
	# drying pots along the parapet
	for i in int(w / 1.2):
		B.pot(self, Vector3(x0 + 0.6 + i * 1.2, h + 0.25, z0 + 0.6), "matka", 0.8, null, i)


func _courtyard() -> void:
	# Tesu's house: the cold wheel, Baba with his lips sealed in grief
	lane_house(-14, -2, 4.0, -6, -2.5, true)
	var wheel := B.add_mesh(self, B.lathe_mesh("wheel", 32), B.mat("terracotta", 1.0), Vector3(1.0, 0.25, -1.4), Vector3.ZERO, Vector3(0.07, 0.25, 0.07))
	wheel.name = "baba_wheel"
	baba = Fig.baba()
	add_child(baba)
	baba.position = Vector3(1.0, 0, -2.3)
	baba.rotation_degrees.y = 10
	baba.anim("sit")
	kiln(Vector3(-6, 0, -1.8 - 2.0), 0.9, false, false)
	scatter_pots(-12, 12, 0, -2.2, -1.0, 18)
	# the family door-niche; Bindu's bell
	var niche := B.label(self, Vector3(-4.5, 1.7, -2.4), "बिंदु", 36, Color(0.95, 0.94, 0.88, 0.7), Hud.font_deva())
	niche.name = "bindu_name"
	B.chalk(self, Vector3(-3.0, 1.2, -2.42), "twins", 0.9, true)
	B.diya(self, Vector3(2.4, 0.0, -0.9), true, 1.2)
	Props.trigger(self, Vector3(8, 1.5, 0), Vector3(2, 4, 4), func(_p: Node) -> void:
		Game.say("That night he takes his father's paddle and his own slingshot.", "", 3.6)
		Game.say("Baba has pressed his own lips shut with clay. He won't speak again unless something changes.", "", 4.6))
	pickup(Vector3(10, 0.3, 0), "pellets", 6)


func _lanes() -> void:
	# the first lane: a watchman on the ground, the roofs above him
	lane_house(16, 24, 3.4, -4, -1.2, false, -1)
	lane_house(26, 33, 3.6, -4, -1.2, true)
	lane_house(35, 44, 3.3, -4, -1.2)
	lane_house(46, 52, 3.5, -4, -1.2, false, 1)
	scatter_pots(14, 54, 0, 1.0, 2.6, 30)
	spawn_enemy(WatchmanS, Vector3(36, 0.1, 0), {"a": 25.0, "b": 46.0})
	Props.trigger(self, Vector3(14, 1.5, 0), Vector3(2, 4, 4), func(_p: Node) -> void:
		Game.show_hint("Watchmen see in cones of lamplight. The roofs are the safe road. [W] climb rough walls."))
	for i in 3:
		Breakable.make(self, Vector3(20 + i * 9.0, 0, 0.9), "pot")
	B.chalk(self, Vector3(15.6, 2.0, -1.1), "ledge", 1.2)


func _kaki_house() -> void:
	# Kaki: the blind potter. She gave both eyes to the Veiled Mother as a girl.
	lane_house(56, 68, 3.8, -5, -2.0, true)
	kaki = Fig.kaki()
	add_child(kaki)
	kaki.position = Vector3(62, 0, -1.4)
	kaki.rotation_degrees.y = 20
	kaki.anim("sit")
	B.flame(self, Vector3(60.5, 0.05, -0.9), 1.4, true, 1.6)
	B.pot(self, Vector3(63.5, 0, -1.2), "matka", 1.3)
	var it := Interact.make(self, Vector3(62, 1.0, 0), "sit with Kaki", func(_p: Node) -> void: _kaki_scene(), Vector3(3, 2.4, 3), true)
	it.name = "kaki_talk"
	# the elders' lane gate: answers to Open
	Breakable.make(self, Vector3(72, 0, 0), "gate", {"opens_to": "open", "size": Vector3(1.0, 4.4, 2.0)})
	block(70.5, 73.5, 4.4, 9.0, B.mat("brick", 0.7))


func _kaki_scene() -> void:
	var p := Game.player as Player
	p.set_cutscene(true)
	p.puppet.anim("sit")
	var main = Game.main
	main.post.letterbox_target = 1.0
	rig.cinematic(Vector3(60.8, 1.3, 3.2), Vector3(62, 1.0, -1.4), 2.0, 34.0)
	await main.line("You're going to the curtain.", "kaki", "", 2.6)
	await main.line("Nobody in Ghatiya looks behind it. I did, when I was smaller than you.", "kaki", "", 4.0)
	await main.line("I gave her both my eyes to bring my brother back. She kept her word. She keeps every word.", "kaki", "", 5.0)
	await main.line("Listen. Prayer is silence. Spoken words are only for things you want to happen.", "kaki", "", 4.6)
	await main.line("Three of them. Say them out loud, with all five doors open.", "kaki", "", 3.8)
	rig.cinematic(Vector3(62, 1.6, 4.2), Vector3(62, 1.5, -1.4), 1.5, 30.0)
	Snd.voice("word_shut")
	Fx.text3d(Vector3(62, 2.2, 0), "बंद", Color(0.55, 0.65, 1.0), 140, 2.2, Hud.font_deva())
	await main.line("Band. Shut. For things that should stop.", "kaki", "", 3.2)
	Snd.voice("word_open")
	Fx.text3d(Vector3(62, 2.2, 0), "खुल", Color(1.0, 0.85, 0.5), 140, 2.2, Hud.font_deva())
	await main.line("Khul. Open. For what is closed against you.", "kaki", "", 3.2)
	Snd.voice("word_break")
	Fx.text3d(Vector3(62, 2.2, 0), "टूट", Color(1.0, 0.45, 0.25), 140, 2.2, Hud.font_deva())
	await main.line("Toot. Break. For raw clay. Nothing fired listens to that one.", "kaki", "", 3.6)
	await main.line("Below, there are voices behind little curtains. They ask questions.", "kaki", "", 3.6)
	await main.line("What is given... is kept. And nothing given is ever asked back. Remember that, and then forget it.", "kaki", "", 5.4)
	await main.line("Take a lamp. Set it down and it keeps watching. Clay only moves when nobody is looking.", "kaki", "", 4.6)
	Game.words_learned = true
	Game.flags["kaki_taught"] = true
	Game.add_lamps(2)
	Snd.sfx("lamp_light", p.global_position)
	main.post.letterbox_target = 0.0
	rig.release(1.0)
	p.set_cutscene(false)
	Game.show_hint("[1] Shut   [2] Open   [3] Break  —  speak them aloud. The gate ahead answers to Open.")
	Game.save_game()


func _night_lanes() -> void:
	# lanes of people praying with every door shut; Knockers in the dark
	lane_house(76, 86, 3.4, -4, -1.2, false, -1)
	lane_house(88, 96, 3.8, -4, -1.2)
	lane_house(99, 110, 3.2, -4, -1.2, true, 1)
	var r := RandomNumberGenerator.new()
	r.seed = 21
	for i in 12:
		var f := Fig.villager(300 + i, r.randf() < 0.5)
		add_child(f)
		f.position = Vector3(r.randf_range(76, 112), 0, r.randf_range(-1.0, -0.4) if i % 3 else r.randf_range(1.0, 2.2))
		f.rotation_degrees.y = r.randf_range(-30, 30)
		f.anim("band")
	var k: Node3D = KnockersS.new()
	k.set("x0", 76.0)
	k.set("x1", 114.0)
	add_child(k)
	Props.trigger(self, Vector3(75, 1.5, 0), Vector3(2, 6, 4), func(_p: Node) -> void:
		if Game.has("ear"):
			Game.say("Knocking. On every door of you. Nobody has ever seen one.", "", 3.6)
			Game.show_hint("[H] close your doors: cover your ears, hold your breath, shut your eyes."))
	spawn_enemy(WatchmanS, Vector3(104, 0.1, 0), {"a": 98.0, "b": 112.0})
	# a raw-clay wall the elders plastered over the old river road: Break
	Breakable.make(self, Vector3(116, 0, 0), "wall", {"size": Vector3(1.2, 4.0, 2.4), "hp": 6})
	block(115.3, 116.7, 4.0, 9.0, B.mat("brick", 0.7))
	lamp_niche(Vector3(113.5, 0, -0.8))
	for i in 2:
		Breakable.make(self, Vector3(90 + i * 6.0, 0, 0.9), "pot")


func _burning_ground() -> void:
	# past the last houses: the burning ground, and the Thirsty
	var bx := 128.0
	for i in 3:
		block(bx + i * 7.0, bx + i * 7.0 + 2.0, 0, 0.5, B.mat("soot", 0.8), -3.5, -1.5)
		B.flame(self, Vector3(bx + i * 7.0 + 1.0, 0.55, -2.5), 2.0, true, 1.6)
	Fx.embers(Vector3(bx + 7, 1.0, -2.0), 30)
	pickup(Vector3(124, 0.3, 0), "water")
	spawn_enemy(ThirstyS, Vector3(138, 0.1, 0))
	spawn_enemy(ThirstyS, Vector3(150, 0.1, 0))
	Props.trigger(self, Vector3(126, 1.5, 0), Vector3(2, 4, 4), func(_p: Node) -> void:
		Game.say("The drought's dead. They smell water from a long way off.", "", 3.6)
		Game.show_hint("[R] pour water on the ground. They'll crawl to it."))
	# the lone doorframe, far off in the field, with the indigo curtain
	var cs := Node3D.new()
	add_child(cs)
	cs.position = Vector3(160, 0, -26)
	var fm := B.mat("terracotta", 1.2)
	B.add_mesh(cs, B.mesh_box(Vector3(0.32, 3.3, 0.4)), fm, Vector3(-1.0, 1.65, 0))
	B.add_mesh(cs, B.mesh_box(Vector3(0.32, 3.3, 0.4)), fm, Vector3(1.0, 1.65, 0))
	B.add_mesh(cs, B.mesh_box(Vector3(2.8, 0.36, 0.5)), fm, Vector3(0, 3.4, 0))
	B.cloth(cs, Vector3(0, 1.62, 0), Vector2(1.7, 3.0), {"size": Vector2(1.7, 3.0), "wind": 0.05 if Game.hold() == 0 else 1.0, "glow": Game.hold() * 0.25}, 32)


func _river_edge() -> void:
	steps(160, 0, 8, 1.5, -0.5, B.mat("brick", 0.7), -8, 3)
	ground(172, mouth_x - 4.0, -4, "silt", 8, -14, 3)
	var pit := MeshInstance3D.new()
	pit.mesh = B.cyl(5.0, 2.5, 30, 24)
	pit.material_override = B.mat("void")
	add_child(pit)
	pit.position = Vector3(mouth_x, -19.2, -2.0)
	Props.trigger(self, Vector3(mouth_x - 5.0, -2, 0), Vector3(1.0, 6, 4), func(_p: Node) -> void: _the_mouth())


func _the_mouth() -> void:
	## Tesu's first try at the Mouth kills him.
	if _fell:
		return
	_fell = true
	var p := Game.player as Player
	p.set_cutscene(true)
	var main = Game.main
	main.post.letterbox_target = 1.0
	rig.cinematic(Vector3(mouth_x - 9, 1.0, 7), Vector3(mouth_x, -5, -2), 2.0, 40.0)
	p.puppet.anim("kneel")
	await main.line("The Mouth. It opened in the riverbed the summer the water stopped.", "", "", 3.8)
	await main.line("Somewhere below, Bindu.", "", "", 2.4)
	Snd.sfx("rumble", p.global_position, 0)
	Fx.shake(0.6)
	await main.wait(0.8)
	var t := p.create_tween()
	t.tween_property(p, "global_position", Vector3(mouth_x - 1.0, -4.0, 0), 0.6)
	t.tween_property(p, "global_position", Vector3(mouth_x, -30.0, -1.0), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	p.puppet.anim("fall")
	await main.wait(1.2)
	Fx.flash(Color.WHITE, 0.3)
	await main.post.fade_to(1.0, 0.4, Color(0.02, 0.02, 0.06)).finished
	Snd.sfx("heartbeat", null, 0, 0.0)
	Game.deaths += 1
	finish()


func _village_changes(hold: int) -> void:
	## Every door you give changes the lanes.
	if hold >= 2:
		var tw := create_tween().set_loops()
		tw.tween_callback(func() -> void:
			var bells := get_tree().get_nodes_in_group("niche_bell")
			if bells.is_empty():
				return
			var b: Node3D = bells[randi() % bells.size()]
			Snd.sfx("bell", b.global_position, -6)
			var t := b.create_tween()
			t.tween_property(b, "rotation:z", 0.6, 0.1)
			t.tween_property(b, "rotation:z", 0.0, 0.8).set_trans(Tween.TRANS_ELASTIC))
		tw.tween_interval(2.5)
	if hold >= 1:
		for i in 6:
			var m := Moth.new()
			m.home = Vector3(randf_range(20, 180), randf_range(2, 5), randf_range(-3, 1))
			add_child(m)
			m.global_position = m.home


func begin() -> void:
	if Game.words_learned:
		get_node_or_null("kaki_talk")
