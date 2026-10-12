extends Node3D
## Knockers (khatkhat). Nobody has seen one. You hear them knocking on the
## doors of your body. Listen too long and something gets in, and your
## hands stop doing what you tell them. Deaf players are immune: a door
## that's gone can't be knocked on. Cover your ears [H].

var x0 := -INF
var x1 := INF
var meter := 0.0
var _next := 1.0
var active := true


func _ready() -> void:
	add_to_group("knockers")


func _process(delta: float) -> void:
	var p: Player = Game.player as Player if Game.player and is_instance_valid(Game.player) else null
	if p == null or not active or p.state in ["dead", "cutscene"]:
		return
	var x := p.global_position.x
	if x < x0 or x > x1:
		meter = max(0.0, meter - delta)
		return
	_next -= delta
	if _next <= 0.0:
		_next = randf_range(1.2, 2.6)
		var side := -1.0 if randf() < 0.5 else 1.0
		var pos := p.global_position + Vector3(side * randf_range(2.0, 5.0), randf_range(0.5, 2.5), randf_range(-2.0, 2.0))
		Snd.sfx("knock%d" % (randi() % 3), pos, 2.0)
		if not Game.has("ear"):
			Fx.ring(pos, 1.5, Color(0.95, 0.94, 0.88, 0.7), 0.7)
	if not Game.has("ear"):
		meter = 0.0
		return
	if p.band_on:
		meter = max(0.0, meter - delta * 0.6)
	else:
		meter += delta * 0.11
	Game.main.post.knock = max(Game.main.post.knock, meter * 0.6)
	if meter >= 1.0:
		meter = 0.0
		p.hands_lost = 3.5
		Snd.sfx("whisper%d" % (randi() % 3), p.global_position, 4.0)
		Fx.pulse("knock", 1.0)
		Fx.shake(0.3)
		Game.show_hint("Something got in. Your hands aren't yours.")
