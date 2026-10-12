class_name SetLamp
extends Node3D
## A set lamp is a checkpoint, and it keeps watching what you can't.

var watch_radius := 6.0
var _ring: MeshInstance3D


func _ready() -> void:
	add_to_group("watcher")
	add_to_group("set_lamp")
	B.diya(self, Vector3.ZERO, true, 1.8)
	var l := B.lamp_light(self, Vector3(0, 0.4, 0), Color(1.0, 0.7, 0.4), 2.0, watch_radius + 1.5, true)
	l.shadow_enabled = false
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.97
	tm.outer_radius = 1.0
	tm.rings = 64
	_ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.7, 0.35, 0.12)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring.material_override = m
	_ring.scale = Vector3(watch_radius, 1, watch_radius)
	_ring.rotation_degrees.x = 90
	_ring.position.y = 0.5
	add_child(_ring)
	Fx.embers(global_position + Vector3(0, 0.2, 0), 10)


func watches(pos: Vector3) -> bool:
	return global_position.distance_to(pos) < watch_radius
