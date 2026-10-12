class_name CurtainSet
extends Region
## The field past the burning ground: a doorframe standing alone with an
## indigo curtain in it. The curtain is the game's progress bar.

var curtain: MeshInstance3D
var frame_root: Node3D
var curtain_pos := Vector3(0, 0, -2.0)
var village_x := -60.0
var mode := "death"   # title / death / first / ending
var _moths: Array = []
var _t := 0.0
var _shape: Node3D
var fires: Array = []


func build() -> void:
	underground = false
	music = "veil" if mode != "title" else "title"
	ambience = "amb_wind"
	var hold := Game.hold()
	var burning := hold >= 4
	setup_env({
		"bg": "sky",
		"sky": {"top_color": Color(0.012, 0.016, 0.05), "horizon_color": Color(0.13, 0.1, 0.17) if not burning else Color(0.3, 0.12, 0.08),
			"moon_dir": Vector3(0.55, 0.28, -1.0), "moon_size": 0.05, "fire": 0.8 if burning else 0.0, "dust": 0.4},
		"ambient": Color(0.35, 0.38, 0.6), "ambient_energy": 0.25,
		"fog_color": Color(0.1, 0.09, 0.14), "fog_density": 0.01, "vfog_density": 0.02,
		"vfog_albedo": Color(0.5, 0.52, 0.7),
		"moon": {"color": Color(0.6, 0.66, 0.95), "energy": 0.9, "rot": Vector3(-24, 150, 0), "shadow_dist": 50.0},
		"exposure": 1.1, "glow": 1.0,
	})
	# the field: cracked dry earth that goes on forever
	var gm := B.mat("silt", 0.25)
	block(-200, 200, -6, 0, gm, -120, 30)
	_grass()
	_frame()
	_burning_ground(Vector3(-14, 0, -18))
	_village()
	# dust in the moonlight
	var dust := Fx.particles(Vector3(0, 2, -4), 120, Color(0.8, 0.75, 0.7, 0.25), {"one_shot": false, "explode": 0.0, "life": 8.0, "vmin": 0.1, "vmax": 0.4, "gravity": Vector3(0.2, 0.0, 0), "size": 0.05, "spark": true, "radius": 12.0, "grow0": 1.0, "grow1": 1.0, "turb": 0.4})
	if dust:
		dust.reparent(self)
	# moths: the Mother's attendants
	for i in 6 + hold * 4:
		var m := Moth.new()
		m.home = curtain_pos + Vector3(randf_range(-2, 2), randf_range(0.8, 3.0), randf_range(-0.5, 1.5))
		add_child(m)
		m.global_position = m.home
		_moths.append(m)
	update_hold(0.0)


func _grass() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var blade := PrismMesh.new()
	blade.size = Vector3(0.05, 0.5, 0.01)
	mm.mesh = blade
	mm.instance_count = 2400
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for i in mm.instance_count:
		var p := Vector3(r.randf_range(-40, 40), 0.2, r.randf_range(-45, 6))
		if Vector2(p.x - curtain_pos.x, p.z - curtain_pos.z).length() < 2.5:
			p.y = -2
		var b := Basis().rotated(Vector3.UP, r.randf() * TAU).rotated(Vector3(1, 0, 0), r.randf_range(-0.4, 0.4)).scaled(Vector3(1, r.randf_range(0.4, 1.6), 1))
		mm.set_instance_transform(i, Transform3D(b, p))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.36, 0.24)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	add_child(mi)


func _frame() -> void:
	frame_root = Node3D.new()
	add_child(frame_root)
	frame_root.position = curtain_pos
	var fm := B.mat("terracotta", 1.2)
	var old := B.tint("terracotta", Color(0.75, 0.62, 0.55), 1.2)
	B.add_mesh(frame_root, B.mesh_box(Vector3(0.32, 3.3, 0.4)), fm, Vector3(-1.0, 1.65, 0))
	B.add_mesh(frame_root, B.mesh_box(Vector3(0.32, 3.3, 0.4)), fm, Vector3(1.0, 1.65, 0))
	B.add_mesh(frame_root, B.mesh_box(Vector3(2.8, 0.36, 0.5)), old, Vector3(0, 3.4, 0))
	B.add_mesh(frame_root, B.mesh_box(Vector3(2.4, 0.18, 0.6)), old, Vector3(0, 0.09, 0))
	# handprints of women who whispered here, eyes shut
	for i in 7:
		var hp := Sprite3D.new()
		hp.texture = B.tex("handprint")
		hp.pixel_size = 0.0018
		hp.modulate = Color(0.85, 0.55, 0.45, 0.7)
		frame_root.add_child(hp)
		hp.position = Vector3(-1.0 if i % 2 == 0 else 1.0, 0.9 + i * 0.28, 0.21)
		hp.rotation.z = randf_range(-0.5, 0.5)
	# little lamps left at the threshold, long cold
	for i in 5:
		B.diya(frame_root, Vector3(-0.8 + i * 0.4, 0.18, 0.5), i == 2, 0.0)
	curtain = B.cloth(frame_root, Vector3(0, 1.62, 0.0), Vector2(1.7, 3.0), {"size": Vector2(1.7, 3.0), "tex_scale": 0.85}, 64)
	# behind the cloth: a shape that is not there in daylight
	_shape = Node3D.new()
	frame_root.add_child(_shape)
	_shape.position = Vector3(0, 0, -0.6)
	var sm := B.emissive(Color(0.55, 0.6, 1.0), 2.5)
	B.add_mesh(_shape, B.sphere(0.32, -1, 16), sm, Vector3(0, 2.3, 0), Vector3.ZERO, Vector3(0.9, 1.1, 0.9))
	B.add_mesh(_shape, B.cyl(0.25, 0.7, 2.0, 16), sm, Vector3(0, 1.1, 0))
	_shape.visible = false
	var bl := OmniLight3D.new()
	bl.name = "backlight"
	bl.light_color = Color(0.6, 0.65, 1.0)
	bl.omni_range = 6.0
	bl.light_energy = 0.0
	bl.light_volumetric_fog_energy = 3.0
	frame_root.add_child(bl)
	bl.position = Vector3(0, 1.8, -0.9)


func _burning_ground(at: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	for i in 4:
		var p := Vector3(i * 2.6 - 4.0, 0, randf_range(-1.5, 1.5))
		B.add_mesh(root, B.mesh_box(Vector3(1.8, 0.4, 1.0)), B.mat("soot", 1.0), p + Vector3(0, 0.2, 0))
		var f := B.flame(root, p + Vector3(0, 0.45, 0), 1.6 if i != 1 else 2.6, i % 2 == 0, 1.4)
		fires.append(f)
	Fx.embers(at + Vector3(0, 1, 0), 30)
	var ep := Fx.particles(at + Vector3(0, 1.0, 0), 30, Color(1.0, 0.55, 0.2, 1.0), {"one_shot": false, "explode": 0.0, "spark": true, "add": true, "vmin": 0.4, "vmax": 1.4, "life": 3.5, "gravity": Vector3(0.3, 0.8, 0), "size": 0.06, "turb": 1.0, "radius": 2.5, "grow1": 0.2})
	if ep:
		ep.reparent(root)


func _village() -> void:
	## Ghatiya in the distance; it shows what each door is costing.
	var hold := Game.hold()
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(0, 0, -70)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for i in 26:
		var x := r.randf_range(-70, 50)
		var w := r.randf_range(3, 6)
		var h := r.randf_range(2.5, 4.5)
		var hx := Node3D.new()
		root.add_child(hx)
		hx.position = Vector3(x, 0, r.randf_range(-12, 8))
		B.add_mesh(hx, B.mesh_box(Vector3(w, h, 3)), B.tint("limewash", Color(0.6, 0.6, 0.65), 0.6), Vector3(0, h * 0.5, 0))
		var pr := PrismMesh.new()
		pr.size = Vector3(w + 0.6, 1.2, 3.6)
		B.add_mesh(hx, pr, B.mat("terracotta", 1.0), Vector3(0, h + 0.6, 0))
		if r.randf() < 0.5:
			B.glow_card(hx, Vector3(r.randf_range(-1, 1), h * 0.5, 1.6), 1.2, Color(1.0, 0.6, 0.3, 0.7))
		# at four doors the houses at the edge of the village burn
		if hold >= 4 and x < -35:
			B.flame(hx, Vector3(0, h + 0.5, 0), 6.0, i % 3 == 0, 3.0)
	for i in 5:
		var kx := r.randf_range(-50, 40)
		kiln(root.position + Vector3(kx, 0, r.randf_range(-8, 4)), 1.4, false, hold >= 3)


func update_hold(dur: float = 1.5) -> void:
	var hold := Game.hold()
	var m: ShaderMaterial = curtain.material_override
	var target := {
		"wind": [0.05, 1.0, 1.1, 1.3, 1.6, 2.0][hold],
		"press": [0.0, 0.3, 0.45, 0.75, 0.95, 1.0][hold],
		"hand": [0.0, 0.0, 1.0, 1.0, 1.0, 1.0][hold],
		"glow": [0.0, 0.25, 0.45, 0.7, 1.0, 1.4][hold],
		"gap": 1.0 if hold >= 4 else 0.0,
		"burn": 0.35 if not Game.has("skin") else 0.0,
		"breathe": 1.0 if hold >= 3 else 0.0,
	}
	for k in target:
		if dur <= 0.0:
			m.set_shader_parameter(k, target[k])
		else:
			var from: float = m.get_shader_parameter(k) if m.get_shader_parameter(k) != null else 0.0
			var t := create_tween()
			t.tween_method(func(v: float) -> void: m.set_shader_parameter(k, v), from, float(target[k]), dur)
	_shape.visible = hold >= 1
	var bl: OmniLight3D = frame_root.get_node("backlight")
	bl.light_energy = hold * 0.6
	for mo in _moths:
		if is_instance_valid(mo):
			mo.agitation = 0.3 + hold * 0.3


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if _shape and _shape.visible:
		_shape.position.x = sin(_t * 0.3) * 0.15
