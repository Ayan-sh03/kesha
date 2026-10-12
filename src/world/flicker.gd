extends OmniLight3D
## Fire is the only light there is: it breathes.

var base_energy := -1.0
var _t := 0.0
var _seed := 0.0
var speed := 1.0


func _ready() -> void:
	base_energy = light_energy
	_seed = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta * speed
	var f := 0.82 + 0.12 * sin(_t * 9.1 + _seed) + 0.07 * sin(_t * 23.7 + _seed * 2.0) + 0.05 * sin(_t * 3.3)
	light_energy = base_energy * f
