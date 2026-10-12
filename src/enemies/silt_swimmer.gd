extends Enemy
## Silt Swimmers (daldal): long things that swim under the mud floors of the
## drowned town. You feel the floor shift a moment before they come up.
## Never stand still on silt. Fired skin is too hard to bite.

var x0 := 0.0
var x1 := 10.0
var floor_y := 0.0
var still_t := 0.0
var surfaced := 0.0
var _mound: MeshInstance3D
var _body: Node3D
var _last_px := 0.0
var _seg: Array[MeshInstance3D] = []


func setup() -> void:
	hp = 3
	speed = 3.0
	damage = 0
	radius = 0.4
	height = 0.8
	no_gravity = true
	collision_layer = 0
	collision_mask = 0
	floor_y = global_position.y
	_mound = MeshInstance3D.new()
	_mound.mesh = B.sphere(0.6, 0.5, 12)
	_mound.material_override = B.mat("silt", 1.0)
	add_child(_mound)
	_body = Node3D.new()
	add_child(_body)
	var m := Fig.clay_mat(Color(0.35, 0.33, 0.3), "silt")
	for i in 7:
		var s := B.add_mesh(_body, B.sphere(0.32 - i * 0.03, -1, 10), m, Vector3(-i * 0.38, 0, 0))
		_seg.append(s)
	B.add_mesh(_body, B.cyl(0.0, 0.18, 0.4, 8), Fig._m(Color(0.9, 0.85, 0.75)), Vector3(0.3, 0.1, 0.15), Vector3(0, 0, -1.4))
	B.add_mesh(_body, B.cyl(0.0, 0.18, 0.4, 8), Fig._m(Color(0.9, 0.85, 0.75)), Vector3(0.3, 0.1, -0.15), Vector3(0, 0, -1.4))
	_body.visible = false
	visual = _body
	shard_color = Color(0.4, 0.38, 0.33)


func think(delta: float) -> void:
	var p := player()
	if p == null:
		return
	var on_silt: bool = p.surface == "silt" and p.global_position.x > x0 and p.global_position.x < x1 and abs(p.global_position.y - floor_y) < 1.5
	if surfaced > 0.0:
		surfaced -= delta
		if surfaced <= 0.0:
			_dive()
		return
	if on_silt:
		if abs(p.global_position.x - _last_px) < 0.05 and p.is_on_floor():
			still_t += delta
		else:
			still_t = max(0.0, still_t - delta * 0.5)
		_last_px = p.global_position.x
		var tx: float = clamp(p.global_position.x, x0, x1)
		global_position.x = move_toward(global_position.x, tx, speed * delta)
		facing = 1 if tx > global_position.x else -1
		_mound.position.y = 0.05 + sin(_t * 12.0) * 0.04
		_mound.visible = true
		if still_t > 0.9 and abs(global_position.x - p.global_position.x) < 1.2:
			_burst(p)
		elif still_t > 0.4:
			Fx.shake(0.06)  # the floor shifts
	else:
		still_t = 0.0
		_mound.position.y = -0.4


func _burst(p: Player) -> void:
	still_t = 0.0
	surfaced = 1.6
	_mound.visible = false
	_body.visible = true
	collision_layer = 4
	_body.position = Vector3(0, -1.0, 0)
	_body.rotation.z = 1.0 * facing
	var t := create_tween()
	t.tween_property(_body, "position:y", 0.6, 0.18).set_trans(Tween.TRANS_BACK)
	Snd.sfx("burst", global_position, 2)
	Fx.dust(global_position, 20, Color(0.4, 0.38, 0.33, 0.7))
	Fx.shake(0.3)
	if not Game.has("skin"):
		# fired skin: too hard to bite
		Snd.sfx("block", global_position)
		Fx.sparks(p.global_position + Vector3(0, 0.5, 0), 12)
		Game.show_hint("Its teeth skid off fired skin.")
	elif abs(p.global_position.x - global_position.x) < 1.4:
		p.take_damage(2, global_position + Vector3(0, -1, 0), "bite")


func _dive() -> void:
	collision_layer = 0
	var t := create_tween()
	t.tween_property(_body, "position:y", -1.2, 0.3)
	t.tween_callback(func() -> void: _body.visible = false)
	Fx.dust(global_position, 10, Color(0.4, 0.38, 0.33, 0.6))


func can_be_hit(_kind: String) -> bool:
	return surfaced > 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	if dead:
		return
	think(delta)
