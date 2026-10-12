class_name Region
extends Node3D
## Base for every region: environment, geometry helpers, camera zones,
## pickups, counting-cord knots, and the Mother's light that grows with
## every door given.

var info: Dictionary = {}
var index := 0
var spawn := Vector3(0, 0.1, 0)
var underground := false
var music := ""
var ambience := ""
var space := Vector2(0.4, 0.12)
var world_env: WorldEnvironment
var env: Environment
var moon: DirectionalLight3D
var mother_ambient := Color(0.55, 0.6, 1.0)
var base_ambient := 0.0
var rig: CameraRig
var exit_done := false
var boss: Node = null
var sky_mat: ShaderMaterial
var mother_lights: Array[Light3D] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1234


# ------------------------------------------------------------- lifecycle
func build() -> void:
	pass


func begin() -> void:
	## Called once the player is placed and the camera snapped.
	pass


func on_player_died() -> bool:
	## Return true if the region handles this death itself.
	return false


func flag(k: String) -> bool:
	return Game.flags.get(info.get("id", "") + ":" + k, false)


func set_flag(k: String, v: bool = true) -> void:
	Game.flags[info.get("id", "") + ":" + k] = v


func finish() -> void:
	if exit_done:
		return
	exit_done = true
	Game.main.next_region()


func _process(_delta: float) -> void:
	if underground and env:
		var l := Game.light_level()
		env.ambient_light_energy = base_ambient + l * 0.5
		env.volumetric_fog_emission_energy = l * 0.35
		for ml in mother_lights:
			if is_instance_valid(ml):
				ml.light_energy = ml.get_meta("base", 1.0) * l
				ml.visible = l > 0.0


# ------------------------------------------------------------- environment
func setup_env(c: Dictionary) -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	match c.get("bg", "dark"):
		"sky":
			var sky := Sky.new()
			sky_mat = ShaderMaterial.new()
			sky_mat.shader = B.shader("sky")
			for k in c.get("sky", {}):
				sky_mat.set_shader_parameter(k, c["sky"][k])
			sky.sky_material = sky_mat
			sky.radiance_size = Sky.RADIANCE_SIZE_128
			env.background_mode = Environment.BG_SKY
			env.sky = sky
		_:
			env.background_mode = Environment.BG_COLOR
			env.background_color = c.get("bg_color", Color(0.005, 0.004, 0.006))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = c.get("ambient", Color(0.3, 0.32, 0.45))
	base_ambient = c.get("ambient_energy", 0.15)
	env.ambient_light_energy = base_ambient
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG if c.get("bg", "dark") == "sky" else Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = c.get("exposure", 1.0)
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = c.get("glow", 0.9)
	env.glow_strength = 1.0
	env.glow_bloom = c.get("bloom", 0.08)
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT if c.get("glow_soft", false) else Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.7)
	env.set_glow_level(5, 0.5)
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.fog_enabled = c.get("fog", true)
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = c.get("fog_color", Color(0.08, 0.07, 0.1))
	env.fog_density = c.get("fog_density", 0.012)
	env.fog_sky_affect = c.get("fog_sky", 0.3)
	env.fog_aerial_perspective = c.get("aerial", 0.4)
	env.volumetric_fog_enabled = c.get("vfog", true)
	env.volumetric_fog_density = c.get("vfog_density", 0.025)
	env.volumetric_fog_albedo = c.get("vfog_albedo", Color(0.7, 0.68, 0.65))
	env.volumetric_fog_emission = mother_ambient * 0.08
	env.volumetric_fog_emission_energy = 0.0
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = c.get("vfog_length", 64.0)
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_ambient_inject = c.get("vfog_ambient", 0.0)
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_brightness = c.get("brightness", 1.0)
	env.adjustment_contrast = c.get("contrast", 1.1)
	env.adjustment_saturation = c.get("saturation", 1.05)
	world_env.environment = env
	add_child(world_env)
	if c.has("moon"):
		var m: Dictionary = c["moon"]
		moon = DirectionalLight3D.new()
		moon.light_color = m.get("color", Color(0.62, 0.68, 0.95))
		moon.light_energy = m.get("energy", 0.6)
		moon.rotation_degrees = m.get("rot", Vector3(-35, -40, 0))
		moon.shadow_enabled = true
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		moon.directional_shadow_max_distance = m.get("shadow_dist", 70.0)
		moon.light_angular_distance = 0.8
		moon.light_volumetric_fog_energy = m.get("vfog", 1.0)
		moon.shadow_blur = 1.5
		add_child(moon)
	Snd.set_space(space.x, space.y)


func mother_light(pos: Vector3, energy: float = 1.5, rng: float = 14.0) -> OmniLight3D:
	## Pale, shadowless light that seeps through cracks; grows with doors given.
	var l := OmniLight3D.new()
	l.light_color = mother_ambient
	l.omni_range = rng
	l.omni_attenuation = 0.8
	l.shadow_enabled = false
	l.light_specular = 0.1
	l.light_volumetric_fog_energy = 2.0
	l.set_meta("base", energy)
	add_child(l)
	l.position = pos
	mother_lights.append(l)
	return l


# ------------------------------------------------------------- geometry
func block(x0: float, x1: float, y0: float, y1: float, m: Variant = "silt", z0: float = -3.0, z1: float = 2.5) -> StaticBody3D:
	var mt: Material = m if m is Material else B.mat(String(m))
	var c := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var s := Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0))
	return B.static_box(self, c, s, mt)


func ground(x0: float, x1: float, y: float, m: Variant = "silt", thick: float = 8.0, z0: float = -4.0, z1: float = 6.5) -> StaticBody3D:
	return block(x0, x1, y - thick, y, m, z0, z1)


func deco(x0: float, x1: float, y0: float, y1: float, m: Variant, z0: float, z1: float) -> MeshInstance3D:
	## Visual-only box (backgrounds, foreground occluders).
	var mt: Material = m if m is Material else B.mat(String(m))
	var mi := MeshInstance3D.new()
	mi.mesh = B.mesh_box(Vector3(abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)))
	mi.material_override = mt
	add_child(mi)
	mi.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	return mi


func steps(x0: float, y0: float, n: int, run: float, rise: float, m: Variant = "brick", z0: float = -4.0, z1: float = 3.0) -> float:
	## Ghat steps. Positive rise climbs toward +x; negative descends.
	var x := x0
	var y := y0
	for i in n:
		y += rise
		var top: float = max(y, y - rise)
		block(x, x + run, top - 6.0, y, m, z0, z1)
		x += run
	return x


func wall(x: float, y0: float, y1: float, m: Variant = "silt", thick: float = 1.0) -> StaticBody3D:
	return block(x - thick * 0.5, x + thick * 0.5, y0, y1, m)


func ceiling(x0: float, x1: float, y: float, m: Variant = "soot", thick: float = 6.0) -> StaticBody3D:
	return block(x0, x1, y, y + thick, m)


func climbable(x: float, y0: float, y1: float, kind: String = "ring") -> void:
	## Well-rings, ropes, rough clay walls: Tesu is small and goes where grown men got stuck.
	Props.climb(self, Vector3(x, (y0 + y1) * 0.5, 0), Vector3(1.0, y1 - y0, 2.0))
	match kind:
		"ring":
			var y := y0
			var i := 0
			while y < y1:
				var r := B.pot(self, Vector3(x, y, -0.9), "ring", 0.55, B.mat("terracotta", 1.5), i * 0.7)
				r.scale = Vector3(0.55, 0.9, 0.55)
				y += 0.55
				i += 1
		"rope":
			var mi := MeshInstance3D.new()
			mi.mesh = B.cyl(0.04, 0.04, y1 - y0 + 1.0, 6)
			mi.material_override = B.mat("rope", 3.0)
			add_child(mi)
			mi.position = Vector3(x, (y0 + y1) * 0.5 + 0.5, -0.15)
			var y := y0 + 0.4
			while y < y1:
				B.add_mesh(self, B.sphere(0.07, -1, 8), B.mat("rope", 3.0), Vector3(x, y, -0.15))
				y += 0.7
		"wall":
			var y := y0 + 0.3
			while y < y1:
				var hold := B.add_mesh(self, B.mesh_box(Vector3(0.35, 0.12, 0.3)), B.mat("terracotta", 2.0), Vector3(x + randf_range(-0.25, 0.25), y, -0.5))
				hold.rotation.z = randf_range(-0.3, 0.3)
				y += randf_range(0.4, 0.6)
		"vine":
			pass


func cam_zone(x0: float, x1: float, y0: float, y1: float, params: Dictionary) -> Area3D:
	var a := Props.area(self, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0), Vector3(absf(x1 - x0), absf(y1 - y0), 4.0), 0, 2)
	a.body_entered.connect(func(b: Node) -> void:
		if b is Player and rig:
			rig.push_zone(params))
	a.body_exited.connect(func(b: Node) -> void:
		if b is Player and rig:
			rig.pop_zone(params))
	return a


func exit_at(x: float, y: float, h: float = 6.0) -> void:
	Props.trigger(self, Vector3(x, y + h * 0.5, 0), Vector3(1.0, h, 4.0), func(_p: Node) -> void: finish())


func void_below(y: float, x0: float = -500.0, x1: float = 3000.0) -> void:
	Props.hazard(self, Vector3((x0 + x1) * 0.5, y, 0), Vector3(x1 - x0, 2.0, 10.0), "void")


# ------------------------------------------------------------- things
func pickup(pos: Vector3, kind: String = "pellets", amount: int = 4) -> Node3D:
	var p := Pickup.new()
	p.kind = kind
	p.amount = amount
	add_child(p)
	p.position = pos
	return p


func lamp_niche(pos: Vector3) -> void:
	## A pre-lit lamp niche: a checkpoint the village left for its dead.
	var l := SetLamp.new()
	l.watch_radius = 4.0
	add_child(l)
	l.position = pos
	var cb := func(_p: Node) -> void:
		if Game.checkpoint.distance_to(pos) > 0.5:
			Game.checkpoint = pos + Vector3(0, 0.2, -0.3)
			Snd.sfx("checkpoint", pos, -6)
			Fx.embers(pos + Vector3(0, 0.3, 0), 14)
			Game.save_game()
	Props.trigger(self, pos + Vector3(0, 1, 0), Vector3(2, 3, 4), cb, false)


func knot(pos: Vector3, height: float = 6.0) -> Node3D:
	## One of Gaara's counting cords. Untie a knot to take one sense back.
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	var cord := MeshInstance3D.new()
	cord.mesh = B.cyl(0.035, 0.035, height, 6)
	cord.material_override = B.mat("rope", 3.0)
	root.add_child(cord)
	cord.position = Vector3(0, height * 0.5, 0)
	var k := B.add_mesh(root, B.sphere(0.13, -1, 10), B.mat("rope", 4.0), Vector3(0, 1.1, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	var glow := B.glow_card(root, Vector3(0, 1.1, 0.1), 0.8, Color(0.6, 0.65, 1.0, 0.5))
	var cb := func(_p: Node) -> void:
		if Game.hold() == 0:
			Game.show_hint("Nothing of yours is tied here.")
			return
		var d := Game.untie()
		Snd.sfx("knot_untie", root.global_position)
		Fx.indigo_dust(root.global_position + Vector3(0, 1.1, 0), 40)
		Fx.flash(Color(0.5, 0.55, 1.0, 0.35), 0.5)
		for m in get_tree().get_nodes_in_group("moth"):
			if m.has_method("fall"):
				m.fall()
		k.visible = false
		glow.visible = false
		Game.say("Your %s comes back to you. Below, Bindu loses it." % String(Game.DOOR_INFO[d]["name"]).to_lower(), "", 3.5)
		Game.say("Asking is the one sin. Somewhere below, more clay wakes.", "", 3.5)
	var it := Interact.make(root, Vector3(0, 1.0, 0), "untie the knot", cb, Vector3(1.4, 2.2, 2.0), true)
	it.set_meta("knot", true)
	return root


func asker(pos: Vector3, question: String, answers: Array, correct: int, on_good: Callable, kaki_hint: String = "") -> Node3D:
	## A voice behind a little curtain asks one question.
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	block_visual_door(root)
	var cl := B.cloth(root, Vector3(0, 1.15, -0.2), Vector2(0.9, 1.7), {"size": Vector2(0.9, 1.7), "wind": 0.4, "glow": 0.25, "tex_scale": 0.6}, 24)
	var asked := [false]
	var on_answer := func(i: int) -> void:
		asked[0] = true
		if i == correct:
			Game.say("...Yes.", "asker")
			Snd.sfx("bell", root.global_position)
			cl.material_override.set_shader_parameter("gap", 1.0)
			on_good.call()
		else:
			Game.say("No. I will follow you, and ask again.", "asker")
			var f := AskerVoice.new()
			add_child(f)
			f.global_position = root.global_position + Vector3(0, 1.5, 0)
	var cb := func(_p: Node) -> void:
		if asked[0]:
			return
		Game.main.ask_question(question, answers, on_answer, kaki_hint)
	Interact.make(root, Vector3(0, 1.0, 0.4), "answer the voice", cb, Vector3(1.4, 2.2, 2.0), false)
	return root


func block_visual_door(root: Node3D) -> void:
	var m := B.mat("terracotta", 1.5)
	B.add_mesh(root, B.mesh_box(Vector3(0.18, 2.1, 0.3)), m, Vector3(-0.55, 1.05, -0.2))
	B.add_mesh(root, B.mesh_box(Vector3(0.18, 2.1, 0.3)), m, Vector3(0.55, 1.05, -0.2))
	B.add_mesh(root, B.mesh_box(Vector3(1.3, 0.2, 0.34)), m, Vector3(0, 2.15, -0.2))


func spawn_enemy(script: Script, pos: Vector3, opts: Dictionary = {}) -> Node3D:
	var e: Node3D = script.new()
	for k in opts:
		e.set(k, opts[k])
	add_child(e)
	e.global_position = pos
	return e


# ------------------------------------------------------------- dressing
func scatter_pots(x0: float, x1: float, y: float, z0: float, z1: float, n: int, kinds: Array = ["matka", "matka", "surahi", "kulhad"], scale_range: Vector2 = Vector2(0.8, 1.4)) -> void:
	var mm := {}
	for k in kinds:
		if not mm.has(k):
			var mmi := MultiMeshInstance3D.new()
			var mesh := MultiMesh.new()
			mesh.transform_format = MultiMesh.TRANSFORM_3D
			mesh.mesh = B.lathe_mesh(k, 16)
			mmi.multimesh = mesh
			mmi.material_override = B.mat("terracotta", 2.5)
			add_child(mmi)
			mm[k] = [mmi, []]
	for i in n:
		var k: String = kinds[_rng.randi() % kinds.size()]
		var s := _rng.randf_range(scale_range.x, scale_range.y)
		var tr := Transform3D(Basis().rotated(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(_rng.randf_range(x0, x1), y, _rng.randf_range(z0, z1)))
		if _rng.randf() < 0.15:
			tr.basis = tr.basis.rotated(Vector3(0, 0, 1), PI * 0.5)
			tr.origin.y += 0.25 * s
		mm[k][1].append(tr)
	for k in mm:
		var arr: Array = mm[k][1]
		var mesh: MultiMesh = (mm[k][0] as MultiMeshInstance3D).multimesh
		mesh.instance_count = arr.size()
		for i in arr.size():
			mesh.set_instance_transform(i, arr[i])


func house(x: float, y: float, z: float, w: float = 4.0, h: float = 3.2, d: float = 3.5, roof: bool = true, lit: bool = false) -> Node3D:
	## A lime-washed mud house with a tiled roof and a door-niche of five tiny doors.
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(x, y, z)
	var wm := B.mat("limewash", 0.6)
	B.add_mesh(root, B.mesh_box(Vector3(w, h, d)), wm, Vector3(0, h * 0.5, 0))
	B.add_mesh(root, B.mesh_box(Vector3(w + 0.1, 0.5, d + 0.1)), B.tint("terracotta", Color(0.7, 0.55, 0.45), 0.6), Vector3(0, 0.25, 0))
	if roof:
		var rm := B.mat("terracotta", 1.2)
		var prism := PrismMesh.new()
		prism.size = Vector3(w + 0.8, 1.3, d + 0.8)
		B.add_mesh(root, prism, rm, Vector3(0, h + 0.65, 0))
	# doorway (dark) facing the camera
	B.add_mesh(root, B.mesh_box(Vector3(0.9, 1.8, 0.1)), B.mat("dark"), Vector3(-w * 0.2, 0.9, d * 0.5 + 0.02))
	# window
	B.add_mesh(root, B.mesh_box(Vector3(0.5, 0.5, 0.1)), B.mat("dark") if not lit else B.emissive(Color(1.0, 0.55, 0.25), 1.8), Vector3(w * 0.25, h * 0.6, d * 0.5 + 0.02))
	# the door-niche: five tiny clay doors with brass bells
	for i in 5:
		var nx := w * 0.05 + i * 0.16
		B.add_mesh(root, B.mesh_box(Vector3(0.11, 0.18, 0.05)), B.mat("terracotta", 4.0), Vector3(nx, 1.25, d * 0.5 + 0.04))
		var bell := B.add_mesh(root, B.lathe_mesh("bell", 10), B.mat("brass"), Vector3(nx, 1.08, d * 0.5 + 0.08), Vector3.ZERO, Vector3.ONE * 0.5)
		bell.add_to_group("niche_bell")
		bell.set_meta("door", Game.DOORS[i])
	return root


func kiln(pos: Vector3, scale: float = 1.0, lit: bool = false, smoke: bool = false) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	B.add_mesh(root, B.lathe_mesh("kiln", 28), B.mat("terracotta", 1.0), Vector3.ZERO, Vector3.ZERO, Vector3.ONE * scale)
	B.add_mesh(root, B.mesh_box(Vector3(0.9, 0.8, 0.4) * scale), B.mat("dark") if not lit else B.emissive(Color(1.0, 0.45, 0.12), 3.0), Vector3(0, 0.4 * scale, 1.55 * scale))
	if lit:
		B.lamp_light(root, Vector3(0, 0.6 * scale, 2.2 * scale), Color(1.0, 0.45, 0.15), 3.0, 6.0 * scale)
	if smoke:
		var p := Fx.particles(pos + Vector3(0, 2.6 * scale, 0), 24, Color(0.2, 0.19, 0.2, 0.5), {"one_shot": false, "explode": 0.0, "life": 6.0, "vmin": 0.4, "vmax": 0.8, "gravity": Vector3(0.15, 0.3, 0), "size": 1.4 * scale, "smin": 0.8, "smax": 1.6, "grow1": 3.0, "radius": 0.3})
		if p:
			p.reparent(root)
	return root


func backdrop_layer(x0: float, x1: float, z: float, y: float, count: int, fn: Callable) -> void:
	for i in count:
		var x: float = lerp(x0, x1, (float(i) + _rng.randf_range(0.0, 0.6)) / count)
		fn.call(x, y, z + _rng.randf_range(-2.0, 2.0), i)
