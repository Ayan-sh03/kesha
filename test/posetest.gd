extends Node3D
var f := 0
func _ready():
	var c := Camera3D.new(); add_child(c); c.position = Vector3(5, 1.2, 7); c.look_at(Vector3(5,0.9,0))
	var l := DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-40, 30, 0)
	var e := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.2,0.2,0.25); env.ambient_light_color = Color(0.5,0.5,0.5); env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.environment = env; add_child(e)
	var poses := ["idle","run","jump","climb","attack","aim","block","band","pray_palms","sit","kneel","crawl","reach","grab","cry","roll"]
	for i in poses.size():
		var p: Puppet = Fig.tesu() if i % 2 == 0 else Fig.villager(i, i % 4 == 1)
		add_child(p)
		p.position = Vector3((i % 8) * 1.4, -(i / 8) * 2.0 + 1.0, 0)
		p.rotation_degrees.y = 35
		p.anim(poses[i])
		p.phase = 1.0
		var lab := Label3D.new(); lab.text = poses[i]; lab.font_size = 32; lab.position = Vector3(0, -0.2, 0.3); p.add_child(lab)
func _process(_d):
	f += 1
	if f == 40:
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-user-kesha/2c7d21f2-3dce-592f-95ab-7e6eb9a9eb0e/scratchpad/shots/poses.png"); get_tree().quit()
