class_name Puddle
extends Node3D
## Water poured on the ground. The Thirsty crawl to it.

var small := false
var life := 12.0


func _ready() -> void:
	add_to_group("puddle")
	if small:
		life = 6.0
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var r := 0.25 if small else 0.7
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.01
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.1, 0.12, 0.85)
	m.roughness = 0.02
	m.metallic_specular = 1.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	add_child(mi)
	mi.scale = Vector3(1, 1, 0.6)
	if not small:
		Fx.ring(global_position + Vector3(0, 0.03, 0), 1.0, Color(0.7, 0.8, 0.9, 0.5), 0.9)
	var t := create_tween()
	t.tween_interval(life - 2.0)
	t.tween_property(mi, "scale", Vector3(0.01, 1, 0.01), 2.0)
	t.tween_callback(queue_free)
