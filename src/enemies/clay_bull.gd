extends Enemy
## Clay Bulls (mitti ke bail): terracotta bulls given for herds that died
## in the drought. They charge only while nobody's watching.

var moving := false
var scale_f := 1.0
var _creak := 0.0
var _legs: Array[Node3D] = []
var _phase := 0.0
var _model: Node3D   # generated terracotta bull (rocked in stop-motion steps)
const MODEL_YAW := 0.0


func setup() -> void:
	hp = 4
	speed = 7.5
	damage = 2
	radius = 0.55 * scale_f
	height = 1.3 * scale_f
	knock_resist = 0.7
	visual = Node3D.new()
	add_child(visual)
	if ResourceLoader.exists("res://assets/chars/bull.glb"):
		_model = B.model(visual, "bull", Vector3.ZERO, scale_f, MODEL_YAW)
		shard_color = Color(0.78, 0.4, 0.25)
		return
	var body := Node3D.new()
	visual.add_child(body)
	body.rotation_degrees.y = 90  # model built along -x; turn it to face +z
	var m := Fig.clay_mat(Color(0.78, 0.4, 0.25))
	var s := scale_f
	B.add_mesh(body, B.capsule(0.42 * s, 1.7 * s, 14), m, Vector3(0, 0.95 * s, 0), Vector3(0, 0, PI * 0.5))
	B.add_mesh(body, B.sphere(0.36 * s, -1, 12), m, Vector3(-0.35 * s, 1.35 * s, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))  # hump
	var head := Node3D.new()
	body.add_child(head)
	head.position = Vector3(-0.95 * s, 1.15 * s, 0)
	B.add_mesh(head, B.capsule(0.2 * s, 0.6 * s, 10), m, Vector3(-0.15 * s, -0.1 * s, 0), Vector3(0, 0, 1.1))
	for side in [-1, 1]:
		B.add_mesh(head, B.cyl(0.02 * s, 0.06 * s, 0.4 * s, 6), m, Vector3(0.05 * s, 0.25 * s, side * 0.15 * s), Vector3(side * 0.6, 0, 0))
		B.add_mesh(head, B.sphere(0.035 * s, -1, 6), B.mat("dark"), Vector3(-0.3 * s, 0.0, side * 0.12 * s))
	# painted bands, garland
	B.add_mesh(body, B.cyl(0.44 * s, 0.44 * s, 0.08 * s, 16), Fig._m(Color(0.92, 0.85, 0.7)), Vector3(-0.55 * s, 0.95 * s, 0), Vector3(0, 0, PI * 0.5))
	for lx in [-0.6, 0.6]:
		for lz in [-0.22, 0.22]:
			var leg := Node3D.new()
			body.add_child(leg)
			leg.position = Vector3(lx * s, 0.7 * s, lz * s)
			B.add_mesh(leg, B.cyl(0.08 * s, 0.1 * s, 0.7 * s, 8), m, Vector3(0, -0.35 * s, 0))
			_legs.append(leg)
	B.add_mesh(body, B.cyl(0.02 * s, 0.03 * s, 0.7 * s, 5), m, Vector3(0.9 * s, 0.8 * s, 0), Vector3(0, 0, -0.4))
	shard_color = Color(0.78, 0.4, 0.25)


func think(delta: float) -> void:
	var p := player()
	if p == null:
		return
	var w := watched()
	if w:
		if moving:
			Snd.sfx("creak%d" % (randi() % 3), global_position, -2)
		moving = false
		velocity.x = 0.0
		return
	if dist_to_player() > 26.0:
		velocity.x = 0.0
		return
	if not moving:
		moving = true
		Snd.sfx("charge", global_position, -2)
	facing = int(dir_to_player()) if dir_to_player() != 0 else facing
	velocity.x = facing * speed
	_creak -= delta
	if _creak <= 0.0:
		_creak = 0.14
		_phase += 1.0
		for i in _legs.size():
			_legs[i].rotation.z = sin(_phase * 1.6 + i * PI * 0.5) * 0.5
		if _model:
			# a clay thing can't gallop: it lurches, one held pose per step
			_model.position.y = absf(sin(_phase * 1.6)) * 0.12 * scale_f
			_model.rotation.x = sin(_phase * 1.6) * 0.08
		Fx.dust(global_position + Vector3(-facing * 0.6, 0.1, 0), 2)


func on_hit_player(p: Player) -> void:
	p.external_push = Vector3(facing * 10.0, 4.0, 0)
	Fx.shake(0.5)
