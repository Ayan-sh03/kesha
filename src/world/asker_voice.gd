class_name AskerVoice
extends Node3D
## A bad answer: the voice follows you for the rest of the region,
## whispering, and every enemy can hear where you are.

var _t := 0.0
var _say := 0.0


func _ready() -> void:
	var g := B.glow_card(self, Vector3.ZERO, 1.2, Color(0.6, 0.55, 0.95, 0.5))
	g.name = "glow"
	Fx.indigo_dust(global_position, 20)


func _process(delta: float) -> void:
	_t += delta
	_say -= delta
	var p: Node3D = Game.player
	if p == null or not is_instance_valid(p):
		return
	var target := p.global_position + Vector3(-1.2 * (p as Player).facing, 2.0 + sin(_t * 1.3) * 0.3, 0.6)
	global_position = global_position.lerp(target, clamp(delta * 1.5, 0.0, 1.0))
	if _say <= 0.0:
		_say = randf_range(5.0, 9.0)
		Snd.sfx("whisper%d" % (randi() % 3), global_position, 0)
		Game.emit_noise(p.global_position, 14.0)
