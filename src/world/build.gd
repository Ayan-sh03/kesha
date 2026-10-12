class_name B
extends RefCounted
## Builder: materials, lathe-turned clay meshes, lights and fire.
## Everything in Ghatiya is turned on a wheel, so most meshes are lathes.

const TEX := "res://assets/textures/"

static var _mats := {}
static var _meshes := {}
static var _shaders := {}


# ------------------------------------------------------------- materials
static func tex(name: String) -> Texture2D:
	return load(TEX + name + ".png")


static func shader(name: String) -> Shader:
	if not _shaders.has(name):
		_shaders[name] = load("res://src/shaders/%s.gdshader" % name)
	return _shaders[name]


static func mat(kind: String, scale: float = 0.5) -> Material:
	var key := "%s@%s" % [kind, scale]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var set_name := kind
	match kind:
		"terracotta", "silt", "limewash", "brick", "soot", "wetclay", "indigo":
			pass
		"rope":
			set_name = "rope"
		_:
			set_name = ""
	if set_name != "":
		m.albedo_texture = tex(set_name + "_albedo")
		m.normal_enabled = true
		m.normal_texture = tex(set_name + "_normal")
		m.roughness_texture = tex(set_name + "_rough")
		m.roughness = 1.0
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
		m.uv1_triplanar_sharpness = 6.0
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match kind:
		"soot":
			m.emission_enabled = true
			m.emission_texture = tex("soot_emission")
			m.emission = Color(1, 0.4, 0.1)
			m.emission_energy_multiplier = 0.0
		"wetclay":
			m.roughness = 0.6
			m.metallic_specular = 0.7
		"indigo":
			m.normal_scale = 0.6
		"dark":
			m.albedo_color = Color(0.02, 0.018, 0.02)
			m.roughness = 1.0
		"void":
			m.albedo_color = Color(0, 0, 0)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"skin":
			m.albedo_texture = tex("skin_albedo")
			m.roughness = 0.62
			m.rim_enabled = true
			m.rim = 0.25
			m.rim_tint = 0.6
		"ochre":
			m.albedo_texture = tex("ochre_albedo")
			m.normal_enabled = true
			m.normal_texture = tex("ochre_normal")
			m.roughness = 0.95
		"glaze":
			m.albedo_texture = tex("glaze_albedo")
			m.normal_enabled = true
			m.normal_texture = tex("glaze_normal")
			m.roughness = 0.08
			m.metallic = 0.2
			m.metallic_specular = 1.0
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
		"brass":
			m.albedo_color = Color(0.78, 0.6, 0.28)
			m.metallic = 0.95
			m.roughness = 0.32
		"hair":
			m.albedo_color = Color(0.03, 0.025, 0.02)
			m.roughness = 0.55
		"cotton":
			m.albedo_color = Color(0.86, 0.84, 0.78)
			m.roughness = 1.0
		"wood":
			m.albedo_color = Color(0.35, 0.22, 0.12)
			m.roughness = 0.8
		"eye":
			m.albedo_color = Color(0.02, 0.015, 0.01)
			m.roughness = 0.1
			m.metallic_specular = 1.0
		"clay_raw":
			m.albedo_texture = tex("wetclay_albedo")
			m.albedo_color = Color(0.85, 0.75, 0.7)
			m.normal_enabled = true
			m.normal_texture = tex("wetclay_normal")
			m.roughness = 0.45
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 1.5
	_mats[key] = m
	return m


static func tint(kind: String, color: Color, scale: float = 0.5) -> StandardMaterial3D:
	var key := "%s#%s@%s" % [kind, color.to_html(), scale]
	if _mats.has(key):
		return _mats[key]
	var base: StandardMaterial3D = mat(kind, scale)
	var m: StandardMaterial3D = base.duplicate()
	m.albedo_color = color
	_mats[key] = m
	return m


static func emissive(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "emit#%s@%s" % [color.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static func shader_mat(name: String, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(name)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


# ------------------------------------------------------------- lathe
static func lathe(profile: PackedVector2Array, segments: int = 24, close_top: bool = false) -> ArrayMesh:
	## Revolve a (radius, height) profile around Y, like clay on a wheel.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	var total := 0.0
	var lens := [0.0]
	for i in range(1, n):
		total += profile[i].distance_to(profile[i - 1])
		lens.append(total)
	for s in segments:
		var a0 := TAU * float(s) / segments
		var a1 := TAU * float(s + 1) / segments
		for i in range(n - 1):
			var p0 := profile[i]
			var p1 := profile[i + 1]
			var v0: float = lens[i] / max(total, 0.001)
			var v1: float = lens[i + 1] / max(total, 0.001)
			var u0 := float(s) / segments
			var u1 := float(s + 1) / segments
			var q00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var q10 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var q01 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var q11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			st.set_uv(Vector2(u0, v0)); st.add_vertex(q00)
			st.set_uv(Vector2(u0, v1)); st.add_vertex(q01)
			st.set_uv(Vector2(u1, v1)); st.add_vertex(q11)
			st.set_uv(Vector2(u0, v0)); st.add_vertex(q00)
			st.set_uv(Vector2(u1, v1)); st.add_vertex(q11)
			st.set_uv(Vector2(u1, v0)); st.add_vertex(q10)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func profile(kind: String) -> PackedVector2Array:
	match kind:
		"matka":
			return PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0.005), Vector2(0.2, 0.05), Vector2(0.265, 0.15), Vector2(0.28, 0.25), Vector2(0.25, 0.36), Vector2(0.18, 0.44), Vector2(0.11, 0.48), Vector2(0.1, 0.52), Vector2(0.135, 0.56), Vector2(0.13, 0.575), Vector2(0.09, 0.55), Vector2(0.085, 0.5)])
		"surahi":
			return PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0.01), Vector2(0.18, 0.08), Vector2(0.2, 0.18), Vector2(0.16, 0.3), Vector2(0.06, 0.38), Vector2(0.045, 0.55), Vector2(0.07, 0.6), Vector2(0.04, 0.6)])
		"diya":
			return PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0.0), Vector2(0.075, 0.025), Vector2(0.08, 0.04), Vector2(0.065, 0.035), Vector2(0.03, 0.015), Vector2(0, 0.015)])
		"kulhad":
			return PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.055, 0.1), Vector2(0.05, 0.1), Vector2(0.036, 0.01), Vector2(0, 0.01)])
		"ring":
			return PackedVector2Array([Vector2(0.86, 0), Vector2(1.0, 0), Vector2(1.03, 0.05), Vector2(1.0, 0.1), Vector2(1.0, 0.5), Vector2(1.03, 0.55), Vector2(1.0, 0.6), Vector2(0.86, 0.6), Vector2(0.86, 0)])
		"kiln":
			return PackedVector2Array([Vector2(1.6, 0), Vector2(1.65, 0.6), Vector2(1.5, 1.4), Vector2(1.1, 2.0), Vector2(0.5, 2.35), Vector2(0.3, 2.4), Vector2(0.3, 2.6), Vector2(0.2, 2.6)])
		"bell":
			return PackedVector2Array([Vector2(0.0, 0.16), Vector2(0.02, 0.16), Vector2(0.04, 0.14), Vector2(0.05, 0.08), Vector2(0.065, 0.02), Vector2(0.075, 0.0), Vector2(0.06, 0.0), Vector2(0.05, 0.03)])
		"lota":
			return PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0.0), Vector2(0.11, 0.05), Vector2(0.12, 0.1), Vector2(0.09, 0.16), Vector2(0.06, 0.18), Vector2(0.075, 0.21), Vector2(0.065, 0.21)])
		"stupa":
			return PackedVector2Array([Vector2(1.0, 0), Vector2(1.0, 0.4), Vector2(0.9, 0.5), Vector2(0.95, 1.4), Vector2(0.7, 2.4), Vector2(0.35, 3.4), Vector2(0.12, 4.2), Vector2(0.15, 4.4), Vector2(0.02, 5.0)])
		"wheel":
			return PackedVector2Array([Vector2(0, 0.6), Vector2(10.0, 0.6), Vector2(10.4, 0.45), Vector2(10.5, 0.0), Vector2(10.2, -0.6), Vector2(2.0, -1.2), Vector2(0, -1.2)])
		"dome":
			var p := PackedVector2Array()
			for i in 13:
				var a := PI * 0.5 * float(i) / 12.0
				p.append(Vector2(cos(a), sin(a)))
			return p
	return PackedVector2Array([Vector2(0, 0), Vector2(0.2, 0), Vector2(0.2, 0.4), Vector2(0, 0.4)])


static func lathe_mesh(kind: String, segments: int = 24) -> ArrayMesh:
	var key := "%s/%d" % [kind, segments]
	if not _meshes.has(key):
		_meshes[key] = lathe(profile(kind), segments)
	return _meshes[key]


static func pot(parent: Node, pos: Vector3, kind: String = "matka", scale: float = 1.0, material: Material = null, rot: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = lathe_mesh(kind, 20 if scale < 2.0 else 32)
	mi.material_override = material if material else mat("terracotta", 2.0)
	parent.add_child(mi)
	mi.position = pos
	mi.scale = Vector3.ONE * scale
	mi.rotation.y = rot
	return mi


# ------------------------------------------------------------- primitives
static func mesh_box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func add_mesh(parent: Node, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	parent.add_child(mi)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	return mi


static func sphere(r: float, h: float = -1.0, seg: int = 16) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h if h > 0 else r * 2.0
	m.radial_segments = seg
	m.rings = max(6, seg / 2)
	return m


static func capsule(r: float, h: float, seg: int = 12) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = max(h, r * 2.0)
	m.radial_segments = seg
	m.rings = 4
	return m


static func cyl(r_top: float, r_bot: float, h: float, seg: int = 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


static func static_box(parent: Node, center: Vector3, size: Vector3, material: Material, layer: int = 1) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	if material:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh_box(size)
		mi.material_override = material
		sb.add_child(mi)
	parent.add_child(sb)
	sb.position = center
	return sb


# ------------------------------------------------------------- light & fire
static func lamp_light(parent: Node, pos: Vector3, color: Color = Color(1.0, 0.62, 0.3), energy: float = 2.0, rng: float = 7.0, shadows: bool = false, flicker: bool = true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	l.light_volumetric_fog_energy = 1.6
	l.light_specular = 0.6
	if flicker:
		l.set_script(load("res://src/world/flicker.gd"))
	parent.add_child(l)
	l.position = pos
	return l


static func flame(parent: Node, pos: Vector3, scale: float = 1.0, with_light: bool = true, light_energy: float = 1.6) -> Node3D:
	## A small fire: additive flame card + embers + light.
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	var p := GPUParticles3D.new()
	p.amount = int(10 * clamp(scale, 0.5, 4.0))
	p.lifetime = 0.55
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.4 * scale
	pm.initial_velocity_max = 0.9 * scale
	pm.gravity = Vector3(0, 1.5 * scale, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.03 * scale
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.9, 0.6, 1.0), Color(1.0, 0.5, 0.12, 0.8), Color(0.5, 0.1, 0.02, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.2))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.24) * scale
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex("spark")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	if with_light:
		lamp_light(root, Vector3(0, 0.15 * scale, 0), Color(1.0, 0.58, 0.25), light_energy * scale, 4.0 + 3.0 * scale)
	return root


static func diya(parent: Node, pos: Vector3, lit: bool = true, light_energy: float = 1.2) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = lathe_mesh("diya", 14)
	mi.material_override = mat("terracotta", 4.0)
	mi.scale = Vector3.ONE * 1.4
	root.add_child(mi)
	if lit:
		flame(root, Vector3(0.07, 0.06, 0), 0.6, light_energy > 0.0, light_energy)
	return root


static func glow_card(parent: Node, pos: Vector3, size: float, color: Color) -> MeshInstance3D:
	## Cheap emissive halo for distant lamps (no real light).
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex("spark")
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	return mi


static func chalk(parent: Node, pos: Vector3, kind: String, size: float = 1.0, always: bool = false, rot: float = 0.0) -> Sprite3D:
	## Bindu's chalk marks. Only visible once she can see (eye door given),
	## unless `always`.
	var s := Sprite3D.new()
	s.texture = tex("chalk_" + kind)
	s.pixel_size = size / 256.0
	s.modulate = Color(1, 1, 1, 0.95)
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.transparent = true
	s.double_sided = true
	s.rotation.z = rot
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(s)
	s.position = pos
	if not always:
		s.add_to_group("chalk")
		s.visible = not Game.has("eye")
	return s


static func label(parent: Node, pos: Vector3, text: String, size: int = 48, color: Color = Color.WHITE, font: Font = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_size = 0
	if font:
		l.font = font
	parent.add_child(l)
	l.position = pos
	return l


static func cloth(parent: Node, pos: Vector3, size: Vector2, params: Dictionary = {}, subdiv: int = 48) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = subdiv
	pm.subdivide_depth = subdiv
	pm.orientation = PlaneMesh.FACE_Z
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var p := {"cloth_tex": tex("indigo_albedo"), "cloth_normal": tex("indigo_normal")}
	p.merge(params, true)
	mi.material_override = shader_mat("curtain", p)
	parent.add_child(mi)
	mi.position = pos
	return mi
