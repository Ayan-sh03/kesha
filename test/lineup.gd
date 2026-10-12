extends Node3D
var f := 0
var names := ["tesu", "bindu", "baba", "kaki", "elder", "villager_m", "villager_f", "watchman", "thirsty", "kachcha", "pothead", "stoker", "gaanth", "mother", "knot_keeper", "first", "fire_tender", "gaara"]
var anim := "idle"
func _ready():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--anim="): anim = a.substr(7)
	var c := Camera3D.new(); add_child(c); c.position = Vector3(12.5, 1.6, 15); c.look_at(Vector3(12.5, 1.2, 0)); c.fov = 45
	var l := DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-35, 25, 0); l.light_energy = 1.4; l.shadow_enabled = true
	var e := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.25,0.25,0.3); env.ambient_light_color = Color(0.6,0.6,0.65); env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.tonemap_mode = Environment.TONE_MAPPER_AGX; e.environment = env; add_child(e)
	var x := 0.0
	for n in names:
		var m := CharModel.make(n)
		add_child(m)
		m.position = Vector3(x, 0, 0)
		m.anim(anim)
		var lab := Label3D.new(); lab.text = n; lab.font_size = 40; lab.pixel_size = 0.004; lab.position = Vector3(x, -0.25, 0.5); add_child(lab)
		x += 1.5
	var gnd := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 10); gnd.mesh = pm; add_child(gnd); gnd.position = Vector3(12, 0, 0)
func _process(_d):
	f += 1
	if f == 50:
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-user-kesha/2c7d21f2-3dce-592f-95ab-7e6eb9a9eb0e/scratchpad/shots/lineup_%s.png" % anim); get_tree().quit()
