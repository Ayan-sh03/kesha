extends Node
## Sensations: shake, hitstop, slow motion, flashes, and spawned effects
## (dust, clay shards, embers, sound rings, chalk dust).

signal flash_requested(color: Color, dur: float)
signal pulse_requested(kind: String, amount: float)

var trauma := 0.0
var _hitstop_until := 0
var _mats := {}
var _puff_tex: Texture2D
var _spark_tex: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_puff_tex = load("res://assets/textures/puff.png")
	_spark_tex = load("res://assets/textures/spark.png")


func _process(delta: float) -> void:
	trauma = max(0.0, trauma - delta * 1.6)


func shake(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)


func hitstop(dur: float = 0.06, scale: float = 0.03) -> void:
	if Game.autotest:
		return
	Engine.time_scale = scale
	var id := Time.get_ticks_msec()
	_hitstop_until = id
	await get_tree().create_timer(dur, true, false, true).timeout
	if _hitstop_until == id:
		Engine.time_scale = 1.0


func slowmo(scale: float, dur: float) -> void:
	if Game.autotest:
		return
	Engine.time_scale = scale
	var id := Time.get_ticks_msec() + 1
	_hitstop_until = id
	await get_tree().create_timer(dur, true, false, true).timeout
	if _hitstop_until == id:
		var t := create_tween().set_ignore_time_scale(true)
		t.tween_property(Engine, "time_scale", 1.0, 0.25)


func flash(color: Color = Color(1, 1, 1, 0.8), dur: float = 0.25) -> void:
	flash_requested.emit(color, dur)


func pulse(kind: String, amount: float = 1.0) -> void:
	pulse_requested.emit(kind, amount)


# ------------------------------------------------------------- spawns
func _world() -> Node:
	if Game.level != null and is_instance_valid(Game.level):
		return Game.level
	return get_tree().current_scene


func _billboard_mat(tex: Texture2D, color: Color, additive: bool = false) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [tex.resource_path, color.to_html(), additive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mats[key] = m
	return m


func particles(pos: Vector3, amount: int, color: Color, opts: Dictionary = {}) -> GPUParticles3D:
	var w := _world()
	if w == null:
		return null
	var p := GPUParticles3D.new()
	p.amount = max(1, amount)
	p.one_shot = opts.get("one_shot", true)
	p.explosiveness = opts.get("explode", 0.9)
	p.lifetime = opts.get("life", 0.8)
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = opts.get("dir", Vector3.UP)
	pm.spread = opts.get("spread", 60.0)
	pm.initial_velocity_min = opts.get("vmin", 1.0)
	pm.initial_velocity_max = opts.get("vmax", 3.0)
	pm.gravity = opts.get("gravity", Vector3(0, -2, 0))
	pm.damping_min = opts.get("damp", 1.0)
	pm.damping_max = opts.get("damp", 1.0) * 2.0
	pm.scale_min = opts.get("smin", 0.2)
	pm.scale_max = opts.get("smax", 0.5)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = opts.get("radius", 0.2)
	var grad := Gradient.new()
	grad.set_color(0, Color(color, color.a))
	grad.set_color(1, Color(color, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	var curve := Curve.new()
	curve.add_point(Vector2(0, opts.get("grow0", 0.6)))
	curve.add_point(Vector2(1, opts.get("grow1", 1.4)))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	if opts.has("turb"):
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = opts["turb"]
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE * opts.get("size", 0.6)
	q.material = _billboard_mat(_spark_tex if opts.get("spark", false) else _puff_tex, Color.WHITE, opts.get("add", false))
	p.draw_pass_1 = q
	w.add_child(p)
	p.global_position = pos
	p.emitting = true
	if p.one_shot:
		get_tree().create_timer(p.lifetime + 0.6).timeout.connect(p.queue_free)
	return p


func dust(pos: Vector3, amount: int = 8, color: Color = Color(0.62, 0.55, 0.46, 0.55)) -> void:
	particles(pos, amount, color, {"dir": Vector3.UP, "spread": 80.0, "vmin": 0.6, "vmax": 1.8, "life": 0.9, "gravity": Vector3(0, 0.3, 0), "size": 0.5, "smin": 0.4, "smax": 0.9, "damp": 2.0})


func embers(pos: Vector3, amount: int = 20, color: Color = Color(1.0, 0.55, 0.2, 1.0)) -> void:
	particles(pos, amount, color, {"spark": true, "add": true, "vmin": 2.0, "vmax": 6.0, "life": 1.2, "gravity": Vector3(0, 2.0, 0), "size": 0.12, "smin": 0.5, "smax": 1.0, "spread": 70.0, "turb": 1.5, "grow1": 0.2})


func sparks(pos: Vector3, amount: int = 14, color: Color = Color(1.0, 0.85, 0.55, 1.0)) -> void:
	particles(pos, amount, color, {"spark": true, "add": true, "vmin": 4.0, "vmax": 9.0, "life": 0.35, "gravity": Vector3(0, -12, 0), "size": 0.08, "spread": 180.0, "grow1": 0.1})


func indigo_dust(pos: Vector3, amount: int = 30) -> void:
	particles(pos, amount, Color(0.35, 0.4, 0.95, 0.9), {"spark": true, "add": true, "vmin": 0.3, "vmax": 1.4, "life": 2.0, "gravity": Vector3(0, -0.6, 0), "size": 0.1, "spread": 180.0, "turb": 0.8, "radius": 0.6})


func chalk_dust(pos: Vector3) -> void:
	particles(pos, 12, Color(0.95, 0.94, 0.88, 0.7), {"vmin": 0.2, "vmax": 0.8, "life": 1.0, "gravity": Vector3(0, -0.8, 0), "size": 0.18, "spread": 180.0})


func shards(pos: Vector3, count: int = 8, color: Color = Color(0.7, 0.33, 0.2), size: float = 0.14, force: float = 5.0) -> void:
	## Physical clay shards that bounce and fade.
	var w := _world()
	if w == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	for i in count:
		var b := RigidBody3D.new()
		b.collision_layer = 0
		b.collision_mask = 1
		b.mass = 0.2
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		var s := Vector3(randf_range(0.5, 1.4), randf_range(0.3, 0.8), randf_range(0.5, 1.2)) * size
		sh.size = s
		cs.shape = sh
		b.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := PrismMesh.new() if i % 2 == 0 else BoxMesh.new()
		bm.size = s
		mi.mesh = bm
		mi.material_override = m
		b.add_child(mi)
		w.add_child(b)
		b.global_position = pos + Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.3), randf_range(-0.2, 0.2))
		b.linear_velocity = Vector3(randf_range(-1, 1), randf_range(0.5, 1.6), randf_range(-0.6, 0.6)) * force
		b.angular_velocity = Vector3(randf(), randf(), randf()) * 12.0
		var t := b.create_tween()
		t.tween_interval(randf_range(1.6, 2.6))
		t.tween_property(mi, "scale", Vector3.ZERO, 0.4)
		t.tween_callback(b.queue_free)


func ring(pos: Vector3, radius: float, color: Color = Color(0.95, 0.94, 0.88, 0.9), dur: float = 0.9) -> void:
	## A chalk sound-ring (Bindu hears for him) or a word's shockwave.
	var w := _world()
	if w == null:
		return
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	mi.global_position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.scale = Vector3.ONE * 0.2
	var t := mi.create_tween().set_parallel()
	t.tween_property(mi, "scale", Vector3(radius, 1.0, radius), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, dur)
	t.chain().tween_callback(mi.queue_free)


func text3d(pos: Vector3, text: String, color: Color = Color(0.95, 0.94, 0.88), size: int = 64, dur: float = 1.6, font: Font = null) -> void:
	var w := _world()
	if w == null:
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 0
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	if font:
		l.font = font
	w.add_child(l)
	l.global_position = pos
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y + 1.2, dur).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, dur).set_delay(dur * 0.5)
	t.chain().tween_callback(l.queue_free)
