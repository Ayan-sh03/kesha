class_name CameraRig
extends Node3D
## Side-on 2.5D camera with deep parallax. Tight in the well shafts and
## tunnels, pulled far back in the big chambers so Tesu reads as very small.
## Handles look-ahead, zones, trauma shake, dutch tilt and cinematic moves.

var cam: Camera3D
var target: Node3D
var dist := 9.0
var height := 1.9
var fov := 42.0
var pitch := -6.0
var tilt := 0.0
var lookahead := 2.2
var y_lock := INF
var x_min := -INF
var x_max := INF
var _dist := 9.0
var _height := 1.9
var _fov := 42.0
var _pitch := -6.0
var _ahead := 0.0
var _pos := Vector3.ZERO
var _noise := FastNoiseLite.new()
var _t := 0.0
var cine := false
var cine_pos := Vector3.ZERO
var cine_look := Vector3.ZERO
var _cine_tween: Tween
var zone_stack: Array = []
var base := {"dist": 9.0, "height": 1.9, "fov": 42.0, "pitch": -6.0}
var orbit := 0.0  # yaw offset around the target (degrees) for set pieces
var _orbit := 0.0
var attrs: CameraAttributesPractical


func _ready() -> void:
	cam = Camera3D.new()
	cam.current = true
	cam.near = 0.05
	cam.far = 900.0
	add_child(cam)
	attrs = CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 30.0
	attrs.dof_blur_far_transition = 25.0
	attrs.dof_blur_amount = 0.06
	cam.attributes = attrs
	_noise.seed = 7
	_noise.frequency = 0.9
	Game.camera = cam


func set_base(d: float, h: float, f: float = 42.0, p: float = -6.0) -> void:
	base = {"dist": d, "height": h, "fov": f, "pitch": p}
	_apply_zone()


func push_zone(z: Dictionary) -> void:
	zone_stack.append(z)
	_apply_zone()


func pop_zone(z: Dictionary) -> void:
	zone_stack.erase(z)
	_apply_zone()


func _apply_zone() -> void:
	var z: Dictionary = base.duplicate()
	if not zone_stack.is_empty():
		z.merge(zone_stack[zone_stack.size() - 1], true)
	dist = z.get("dist", 9.0)
	height = z.get("height", 1.9)
	fov = z.get("fov", 42.0)
	pitch = z.get("pitch", -6.0)
	tilt = z.get("tilt", 0.0)
	y_lock = z.get("y_lock", INF)
	lookahead = z.get("ahead", 2.2)
	orbit = z.get("orbit", 0.0)


func snap() -> void:
	if target:
		_pos = target.global_position
		_dist = dist
		_height = height
		_fov = fov
		_pitch = pitch
		_orbit = orbit
	_update(0.0)


func cinematic(pos: Vector3, look: Vector3, dur: float = 1.5, f: float = -1.0) -> void:
	## Glide the camera to a framing (or cut, if dur == 0).
	if _cine_tween:
		_cine_tween.kill()
	if not cine:
		cine_pos = cam.global_position
		cine_look = cam.global_position + -cam.global_basis.z * 10.0
	cine = true
	if dur <= 0.0:
		cine_pos = pos
		cine_look = look
		if f > 0.0:
			cam.fov = f
		return
	_cine_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cine_tween.tween_property(self, "cine_pos", pos, dur)
	_cine_tween.tween_property(self, "cine_look", look, dur)
	if f > 0.0:
		_cine_tween.tween_property(cam, "fov", f, dur)


func release(dur: float = 1.2) -> void:
	if not cine:
		return
	if _cine_tween:
		_cine_tween.kill()
	if target == null:
		cine = false
		return
	var p := _desired_pos()
	_cine_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cine_tween.tween_property(self, "cine_pos", p[0], dur)
	_cine_tween.tween_property(self, "cine_look", p[1], dur)
	_cine_tween.tween_property(cam, "fov", fov, dur)
	_cine_tween.chain().tween_callback(func() -> void: cine = false)


func _desired_pos() -> Array:
	var tp := _pos
	var off := Vector3(0, _height, _dist)
	off = off.rotated(Vector3.UP, deg_to_rad(_orbit))
	var p := Vector3(tp.x + _ahead, tp.y, tp.z) + off
	var look := Vector3(tp.x + _ahead, tp.y + _height + tan(deg_to_rad(_pitch)) * _dist, tp.z)
	return [p, look]


func _process(delta: float) -> void:
	_update(delta)


func _update(delta: float) -> void:
	_t += delta
	var k := 1.0 - exp(-delta * 5.0) if delta > 0.0 else 1.0
	_dist = lerp(_dist, dist, 1.0 - exp(-delta * 2.0) if delta > 0.0 else 1.0)
	_height = lerp(_height, height, k)
	_fov = lerp(_fov, fov, 1.0 - exp(-delta * 2.0) if delta > 0.0 else 1.0)
	_pitch = lerp(_pitch, pitch, k)
	_orbit = lerp(_orbit, orbit, 1.0 - exp(-delta * 1.5) if delta > 0.0 else 1.0)
	if target and is_instance_valid(target):
		var tp := target.global_position
		var vel := Vector3.ZERO
		if target is CharacterBody3D:
			vel = (target as CharacterBody3D).velocity
		var face := 0
		if target is Player:
			face = (target as Player).facing
			if (target as Player).look_up:
				tp.y += 3.5
		var want_ahead: float = face * lookahead + clamp(vel.x * 0.25, -2.0, 2.0)
		_ahead = lerp(_ahead, want_ahead, 1.0 - exp(-delta * 1.6) if delta > 0.0 else 1.0)
		var ty := tp.y if y_lock == INF else y_lock
		# vertical dead-zone: only follow jumps loosely
		var fy: float = 1.0 - exp(-delta * (3.0 if abs(ty - _pos.y) > 1.2 or vel.y < -8.0 else 1.6)) if delta > 0.0 else 1.0
		_pos.x = lerp(_pos.x, tp.x, 1.0 - exp(-delta * 7.0) if delta > 0.0 else 1.0)
		_pos.y = lerp(_pos.y, ty, fy)
		_pos.z = tp.z
		_pos.x = clamp(_pos.x, x_min, x_max)
	var d := _desired_pos()
	var p: Vector3 = d[0]
	var look: Vector3 = d[1]
	if cine:
		p = cine_pos
		look = cine_look
	else:
		cam.fov = _fov
	# handheld breathing + trauma shake
	var tr := Fx.trauma * Fx.trauma
	var sx := _noise.get_noise_2d(_t * 25.0, 0.0) * tr * 0.6 + _noise.get_noise_2d(_t * 0.6, 50.0) * 0.05
	var sy := _noise.get_noise_2d(0.0, _t * 25.0) * tr * 0.5 + _noise.get_noise_2d(70.0, _t * 0.5) * 0.04
	var roll := _noise.get_noise_2d(_t * 20.0, 99.0) * tr * 4.0 + tilt
	cam.global_position = p + Vector3(sx, sy, 0)
	if p.distance_to(look) > 0.01:
		cam.look_at(look + Vector3(sx, sy, 0) * 0.5, Vector3.UP)
	cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(roll))
	if attrs:
		attrs.dof_blur_far_distance = max(_dist * 2.6, 18.0)
