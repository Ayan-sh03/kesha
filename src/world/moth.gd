class_name Moth
extends Node3D
## Indigo Moths: the Mother's attendants. At a weak hold they only watch.
## At a strong one they swarm. Untie a knot and they fall away like dust.

var home := Vector3.ZERO
var agitation := 0.4
var swarm := false
var _vel := Vector3.ZERO
var _t := 0.0
var _wing: Sprite3D
var _dead := false


func _ready() -> void:
	add_to_group("moth")
	_t = randf() * 10.0
	_wing = Sprite3D.new()
	_wing.texture = B.tex("moth")
	_wing.pixel_size = 0.0022
	_wing.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_wing.shaded = false
	_wing.modulate = Color(0.6, 0.65, 1.0, 0.95)
	add_child(_wing)
	var g := B.glow_card(self, Vector3.ZERO, 0.35, Color(0.4, 0.5, 1.0, 0.35))
	g.name = "glow"


func _process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	var target := home
	if swarm and Game.player and is_instance_valid(Game.player):
		target = (Game.player as Node3D).global_position + Vector3(sin(_t * 3.0) * 0.6, 1.5 + cos(_t * 2.3) * 0.5, 0.4)
	var wander := Vector3(sin(_t * 1.7 + home.x), sin(_t * 2.3 + home.y) * 0.6, cos(_t * 1.3)) * agitation
	_vel = _vel.lerp((target - global_position) * 0.8 + wander * 2.0, clamp(delta * 2.0, 0.0, 1.0))
	global_position += _vel * delta
	_wing.scale = Vector3(abs(sin(_t * 22.0)) * 0.8 + 0.2, 1, 1)


func fall() -> void:
	if _dead:
		return
	_dead = true
	Fx.indigo_dust(global_position, 10)
	var t := create_tween()
	t.tween_property(self, "global_position:y", global_position.y - 2.0, 1.2)
	t.parallel().tween_property(_wing, "modulate:a", 0.0, 1.2)
	t.tween_callback(queue_free)
