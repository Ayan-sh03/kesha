extends Node3D
## Kiln Smoke (dhuaan): smoke that moves on its own, filling tunnels to the
## roof and following your breath back to you. Hold your breath [H], or let
## Bindu breathe for you, and walk straight through it.

var size := Vector3(3.0, 3.5, 3.0)
var speed := 1.1
var wall := false   # a smoke wall: stays put; with Bindu's breath it stops being a wall
var _fog: FogVolume
var _area: Area3D
var _t := 0.0
var _block: StaticBody3D


func _ready() -> void:
	_fog = FogVolume.new()
	_fog.size = size
	_fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	var fm := FogMaterial.new()
	fm.density = 1.6
	fm.albedo = Color(0.12, 0.11, 0.1)
	fm.emission = Color(0.05, 0.02, 0.0)
	fm.height_falloff = 0.0
	fm.edge_fade = 0.6
	var nt := NoiseTexture3D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.08
	nt.noise = fn
	nt.width = 32
	nt.height = 32
	nt.depth = 32
	fm.density_texture = nt
	_fog.material = fm
	add_child(_fog)
	_area = Props.hazard(self, Vector3.ZERO, size * 0.8, "smoke")
	var p := Fx.particles(global_position, 30, Color(0.18, 0.16, 0.15, 0.6), {"one_shot": false, "explode": 0.0, "life": 3.0, "vmin": 0.2, "vmax": 0.6, "gravity": Vector3(0, 0.3, 0), "size": 1.4, "radius": size.x * 0.4, "grow1": 2.0, "turb": 0.5})
	if p:
		p.reparent(self)
	if wall:
		_block = StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(size.x * 0.6, size.y, 3.0)
		cs.shape = bs
		_block.add_child(cs)
		add_child(_block)
		Game.doors_changed.connect(_update_wall)
		_update_wall()


func _update_wall() -> void:
	if _block:
		# Bindu's breath: smoke walls stop being walls
		_block.collision_layer = 1 if Game.has("nose") else 0


func _process(delta: float) -> void:
	_t += delta
	if wall:
		return
	var p: Player = Game.player as Player if Game.player and is_instance_valid(Game.player) else null
	if p == null:
		return
	var tx := p.global_position.x
	if p.band_on:
		tx = global_position.x + sin(_t * 0.5) * 3.0  # no breath to follow
	var d := tx - global_position.x
	if abs(d) < 30.0:
		global_position.x += clamp(d, -1.0, 1.0) * speed * delta
	global_position.y = lerp(global_position.y, p.global_position.y + 1.2, delta * 0.5)
