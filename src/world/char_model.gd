class_name CharModel
extends Puppet
## A rigged, motion-captured 3D character (generated: Rodin mesh, Uthana rig,
## text-to-motion clips retargeted in Blender). Speaks the same anim() language
## as the procedural Puppet so every script can drive either.
##
## Clay things set `stepped`: the AnimationPlayer then advances in stop-motion
## steps, so the given always move a little wrong.

const LOOPS := ["idle", "walk", "run", "sneak", "fall", "climb", "aim", "band", "pray", "sit", "sit_talk",
	"crawl", "cry", "carry", "shamble", "old_walk", "lie", "stand_guard"]
const STATE_CLIP := {
	"idle": "idle", "walk": "walk", "run": "run", "sneak": "sneak", "jump": "jump", "fall": "fall",
	"climb": "climb", "aim": "aim", "throw": "shoot", "block": "block", "roll": "roll", "band": "band",
	"pray": "band", "pray_palms": "pray", "reach": "reach", "sit": "sit", "kneel": "kneel", "lie": "lie",
	"crawl": "crawl", "carry": "carry", "hurt": "hurt", "dead": "death", "grab": "grab", "cry": "cry",
	"land": "land", "shamble": "shamble", "old_walk": "old_walk", "sit_talk": "sit_talk", "look_up": "look_up",
	"sweep": "sweep", "stand_guard": "stand_guard", "tpose": "",
}
const BONES := {
	"hips": "mixamorig_Hips", "chest": "mixamorig_Spine2", "head": "mixamorig_Head",
	"r_fore": "mixamorig_RightHand", "l_fore": "mixamorig_LeftHand",
	"r_arm": "mixamorig_RightArm", "l_arm": "mixamorig_LeftArm",
	"r_foot": "mixamorig_RightFoot", "l_foot": "mixamorig_LeftFoot",
}

static var _scenes := {}

var player: AnimationPlayer
var skeleton: Skeleton3D
var body: Node3D
var model_name := ""
var clip := ""
var blend := 0.15
var speed_mult := 1.0
var fallback := {}   # state -> clip when a clip is missing
var _step_acc := 0.0


static func make(name: String, opts: Dictionary = {}) -> CharModel:
	var c := CharModel.new()
	c.model_name = name
	c.name = name
	var path := "res://assets/chars/%s.glb" % name
	var ps: PackedScene = _scenes.get(path)
	if ps == null and ResourceLoader.exists(path):
		ps = load(path)
		_scenes[path] = ps
	if ps == null:
		push_warning("missing character " + name)
		return c
	c.body = ps.instantiate()
	c.add_child(c.body)
	c.body.scale = Vector3.ONE * opts.get("scale", 1.0)
	c.player = c.body.find_child("AnimationPlayer", true, false)
	c.skeleton = c.body.find_child("*Skeleton*", true, false) as Skeleton3D
	if c.skeleton == null:
		for n in c.body.find_children("*", "Skeleton3D", true, false):
			c.skeleton = n
			break
	for mi in c.body.find_children("*", "MeshInstance3D", true, false):
		c.meshes.append(mi)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if c.player:
		for a in c.player.get_animation_list():
			var an := c.player.get_animation(a)
			if a in LOOPS:
				an.loop_mode = Animation.LOOP_LINEAR
	if c.skeleton:
		for k in BONES:
			var idx := c.skeleton.find_bone(BONES[k])
			if idx == -1:
				idx = c.skeleton.find_bone(String(BONES[k]).replace("_", ":"))
			if idx != -1:
				var ba := BoneAttachment3D.new()
				ba.name = k
				ba.bone_idx = idx
				c.skeleton.add_child(ba)
				c.parts[k] = ba
	c.stepped = opts.get("stepped", false)
	c.step_fps = opts.get("step_fps", 10.0)
	if c.stepped and c.player:
		c.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return c


func _ready() -> void:
	_ground_feet()
	# bone attachments live under a (often 0.01-scaled) armature: give each a
	# counter-scaled socket so props can be authored in metres
	for k in parts.keys():
		var ba: Node3D = parts[k]
		if not (ba is BoneAttachment3D):
			continue
		var sock := Node3D.new()
		sock.name = "socket"
		ba.add_child(sock)
		var sc := ba.global_transform.basis.get_scale()
		sock.scale = Vector3(1.0 / max(sc.x, 1e-5), 1.0 / max(sc.y, 1e-5), 1.0 / max(sc.z, 1e-5))
		parts[k] = sock


func has_clip(n: String) -> bool:
	return player != null and player.has_animation(n)


func anim(new_state: String, spd: float = 0.0, sub_index: int = 0) -> void:
	if new_state != state or sub_index != sub:
		t_state = 0.0
	state = new_state
	speed = spd
	sub = sub_index
	if player == null:
		return
	var c: String = STATE_CLIP.get(new_state, new_state)
	if new_state == "attack":
		c = ["attack1", "attack2", "attack3"][clamp(sub_index, 0, 2)]
	if not has_clip(c):
		c = fallback.get(new_state, "idle")
		if not has_clip(c):
			return
	var sp := 1.0
	match new_state:
		"run":
			sp = clamp(0.7 + spd * 0.5, 0.7, 1.35)
		"walk", "sneak", "shamble", "old_walk", "crawl", "carry":
			sp = clamp(0.6 + spd * 1.2, 0.5, 1.5)
		"climb":
			sp = clamp(spd * 1.2, 0.0, 1.4)
		"attack":
			sp = 1.25
		"roll":
			sp = 1.5
		"jump":
			sp = 1.1
	sp *= speed_mult
	if c != clip:
		clip = c
		player.play(c, blend if not stepped else 0.0, sp)
		if new_state in ["attack", "throw", "hurt", "roll", "grab"]:
			player.seek(0.0, true)
	else:
		player.speed_scale = sp


func play_once(c: String, sp: float = 1.0) -> void:
	if player and has_clip(c):
		clip = c
		player.play(c, blend, sp)
		player.seek(0.0, true)


func clip_progress() -> float:
	if player == null or clip == "" or not has_clip(clip):
		return 1.0
	var l := player.get_animation(clip).length
	return clamp(player.current_animation_position / max(l, 0.01), 0.0, 1.0)


func _process(delta: float) -> void:
	t_state += delta
	if player == null or not stepped:
		return
	_step_acc += delta
	var step := 1.0 / step_fps
	if _step_acc >= step:
		player.advance(_step_acc * player.speed_scale)
		_step_acc = 0.0


func set_material_all(m: Material) -> void:
	for mi in meshes:
		mi.material_override = m


func tint_all(c: Color) -> void:
	for mi in meshes:
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var base := mesh.surface_get_material(i)
			if base is StandardMaterial3D:
				var m2: StandardMaterial3D = base.duplicate()
				m2.albedo_color = m2.albedo_color * c
				(mi as MeshInstance3D).set_surface_override_material(i, m2)


func _ground_feet() -> void:
	## Rigged models come with arbitrary origins: put the soles on y = 0.
	if skeleton == null or body == null:
		return
	var low := INF
	for bn in ["mixamorig_LeftToeBase", "mixamorig_RightToeBase", "mixamorig_LeftFoot", "mixamorig_RightFoot"]:
		var i := skeleton.find_bone(bn)
		if i == -1:
			continue
		var gp := (skeleton.global_transform * skeleton.get_bone_global_rest(i)).origin
		low = min(low, gp.y)
	if low == INF:
		return
	var sole := low - global_position.y - 0.035 * body.scale.y
	body.position.y -= sole
