extends Node
## The conductor: title, regions, the die → give → return loop, questions,
## pause, endings. Also a small test harness (see README).

var world: Node3D
var region: Region
var player: Player
var rig: CameraRig
var hud: Hud
var post: PostFX
var ui: CanvasLayer
var state := "boot"
var busy := false
var _args := {}
var _frame := 0
var _menu: Control
var _pause: Control


func _ready() -> void:
	Game.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	rig = CameraRig.new()
	rig.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rig)
	post = PostFX.new()
	add_child(post)
	hud = Hud.new()
	add_child(hud)
	ui = CanvasLayer.new()
	ui.layer = 70
	add_child(ui)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
		elif a.begins_with("--"):
			_args[a.substr(2)] = "1"
	if _args.has("autotest"):
		Game.autotest = true
	post.fade = 1.0
	if _args.has("region"):
		Game.new_game()
		Game.words_learned = true
		for d in String(_args.get("doors", "")).split(",", false):
			Game.give(d)
		if _args.has("god"):
			Game.flags["god"] = true
		if _args.has("auto_x"):
			Game.flags["auto_x"] = float(_args["auto_x"])
		start_region(int(_args["region"]))
	elif _args.has("ending"):
		Game.new_game()
		for d in String(_args.get("doors", "")).split(",", false):
			Game.give(d)
		play_ending(_args["ending"])
	elif _args.has("curtain"):
		Game.new_game()
		for d in String(_args.get("doors", "")).split(",", false):
			Game.give(d)
		_spawn_player()
		curtain_visit(false)
	else:
		show_title()


func _process(_delta: float) -> void:
	_frame += 1
	if _args.has("shots"):
		for f in String(_args["shots"]).split(",", false):
			if _frame == int(f):
				var img := get_viewport().get_texture().get_image()
				img.save_png("%s_%s.png" % [_args.get("shot", "user://shot"), f])
	if _args.has("quit_after") and _frame >= int(_args["quit_after"]):
		get_tree().quit()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") and state == "play" and not busy:
		toggle_pause()


# ------------------------------------------------------------- helpers
func wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


func line(text: String, who: String = "", voice: String = "", dur: float = 0.0) -> void:
	## Say a line (with an optional voice clip) and wait for it.
	if dur <= 0.0:
		dur = 1.6 + text.length() * 0.055
	Game.say(text, who, dur)
	if voice != "":
		Snd.voice(voice)
	await get_tree().create_timer(dur, false).timeout


func _spawn_player() -> void:
	if player == null or not is_instance_valid(player):
		player = Player.new()
		player.name = "Tesu"
		world.add_child(player)
		player.died.connect(_on_player_died)


func _clear_world() -> void:
	if region and is_instance_valid(region):
		region.queue_free()
	region = null
	Game.level = null
	rig.zone_stack.clear()
	rig.cine = false
	rig.orbit = 0.0
	rig.tilt = 0.0
	rig.x_min = -INF
	rig.x_max = INF
	hud.hide_boss()
	hud.clear_subs()
	post.letterbox_target = 0.0
	post.heat_target = 0.0
	post.moths = 0.0
	post.desat = 0.0
	post.burn = 0.0
	Engine.time_scale = 1.0


func _clear_ui() -> void:
	for c in ui.get_children():
		c.queue_free()
	_menu = null
	_pause = null


# ------------------------------------------------------------- title
func show_title() -> void:
	state = "title"
	_clear_world()
	_clear_ui()
	if player:
		player.visible = false
		player.frozen = true
	var cs := CurtainSet.new()
	cs.mode = "title"
	cs.info = {"id": "title"}
	world.add_child(cs)
	Game.level = cs
	region = cs
	cs.build()
	rig.target = null
	rig.cinematic(Vector3(3.5, 1.6, 6.5), Vector3(0, 1.9, -2.0), 0.0, 38.0)
	var tw := create_tween().set_loops()
	tw.tween_property(rig, "cine_pos", Vector3(-2.5, 1.9, 5.8), 24.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(rig, "cine_pos", Vector3(3.5, 1.6, 6.5), 24.0).set_trans(Tween.TRANS_SINE)
	Snd.music("title")
	Snd.ambience("amb_wind")
	post.fade_to(0.0, 3.0)
	post.indigo_target = 0.2
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	_menu = root
	var v := VBoxContainer.new()
	v.anchor_left = 0.06
	v.anchor_top = 0.16
	v.anchor_right = 0.5
	v.anchor_bottom = 0.92
	v.add_theme_constant_override("separation", 6)
	root.add_child(v)
	v.add_child(Menus.label("द्वार", 150, Color(0.92, 0.6, 0.38), Hud.font_deva(), HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(Menus.label("D W A A R", 52, Color(0.92, 0.88, 0.8), Hud.font_serif(), HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(Menus.label("panchdwar · the five doors", 30, Color(0.6, 0.64, 0.95), Hud.font_italic(), HORIZONTAL_ALIGNMENT_LEFT))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 30)
	v.add_child(sp)
	v.add_child(Menus.label("Five doors. One veil. A village that gave away a girl.", 30, Color(0.8, 0.76, 0.7), Hud.font_italic(), HORIZONTAL_ALIGNMENT_LEFT))
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 50)
	v.add_child(sp2)
	var first: Button = null
	if Game.has_save():
		first = Menus.button("Continue", 46, func() -> void: _begin(true))
		first.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(first)
	var b := Menus.button("Begin", 46, func() -> void: _begin(false))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(b)
	if first == null:
		first = b
	var c := Menus.button("How Tesu moves", 34, _show_controls)
	c.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(c)
	var q := Menus.button("Leave", 34, func() -> void: get_tree().quit())
	q.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(q)
	var note := Menus.label("Ghatiya's faith, gods and rites are invented. The giving of a child is the story's horror: a wrong the village chooses.", 20, Color(0.55, 0.52, 0.5), Hud.font_italic(), HORIZONTAL_ALIGNMENT_RIGHT)
	note.anchor_left = 0.55
	note.anchor_right = 0.96
	note.anchor_top = 0.92
	note.anchor_bottom = 0.98
	root.add_child(note)
	first.call_deferred("grab_focus")


func _show_controls() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Menus.panel_bg(0.88))
	p.anchor_left = 0.52
	p.anchor_right = 0.95
	p.anchor_top = 0.14
	p.anchor_bottom = 0.86
	_menu.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var rows := [
		["A / D", "run", "S", "creep quietly"], ["Space", "jump", "W / S", "climb rings, ropes, walls"],
		["Left mouse / J", "paddle (3-hit)", "Right mouse / K", "aim the sling, release to loose"],
		["Q", "block · parry on time", "Shift", "roll"],
		["E", "set a lamp: checkpoint + watcher", "F", "untie, read, answer, talk"],
		["1 2 3", "Shut · Open · Break", "H", "close your doors: eyes, ears, breath"],
		["R", "pour water for the Thirsty", "Esc", "pause"],
	]
	v.add_child(Menus.label("How Tesu moves", 44, Color(1.0, 0.72, 0.4)))
	for r in rows:
		var h := HBoxContainer.new()
		for i in 4:
			var l := Menus.label(r[i], 24, Color(1.0, 0.8, 0.55) if i % 2 == 0 else Color(0.85, 0.82, 0.76), Hud.font_serif(), HORIZONTAL_ALIGNMENT_LEFT)
			l.custom_minimum_size = Vector2(170 if i % 2 == 0 else 210, 0)
			h.add_child(l)
		v.add_child(h)
	v.add_child(Menus.label("Gamepad: stick moves, A jump, X paddle, RT + right stick aims, B roll, LB block, RB lamp, Y interact, d-pad words, L3 close doors.", 22, Color(0.7, 0.68, 0.64), Hud.font_italic()))
	v.add_child(Menus.label("Every death costs a sense, and your twin gets it.", 26, Color(0.62, 0.66, 0.95), Hud.font_italic()))
	var ok := Menus.button("Close", 32, func() -> void: p.queue_free())
	v.add_child(ok)
	ok.grab_focus()


func _begin(cont: bool) -> void:
	if busy:
		return
	busy = true
	await post.fade_to(1.0, 1.4).finished
	_clear_ui()
	if cont and Game.load_game():
		busy = false
		start_region(Game.region)
	else:
		Game.new_game()
		busy = false
		start_region(0)


# ------------------------------------------------------------- regions
func start_region(i: int, mode: String = "enter") -> void:
	busy = true
	state = "play"
	_clear_world()
	_clear_ui()
	await get_tree().process_frame
	var info: Dictionary = Game.REGIONS[i]
	var r: Region = load(info["script"]).new()
	r.info = info
	r.index = i
	r.rig = rig
	r.name = info["id"]
	world.add_child(r)
	region = r
	Game.level = r
	if mode == "enter":
		Game.enter_region(i)
	else:
		Game.hp = Game.max_hp()
		Game.hp_changed.emit()
	r.build()
	_spawn_player()
	player.visible = true
	var pos: Vector3 = Game.checkpoint if Game.checkpoint != Vector3.INF else r.spawn
	player.respawn_at(pos)
	player.facing = 1
	rig.target = player
	rig.set_base(r.get_meta("cam_dist", 9.0), r.get_meta("cam_height", 1.9), r.get_meta("cam_fov", 42.0), r.get_meta("cam_pitch", -6.0))
	rig.snap()
	Snd.music(r.music)
	Snd.ambience(r.ambience)
	post.indigo_target = Game.light_level() * 0.6 if r.underground else Game.light_level() * 0.3
	if mode == "enter" and not r.get_meta("no_card", false):
		hud.title_card(info)
	busy = false
	r.begin()
	post.fade_to(0.0, 1.4)


func next_region() -> void:
	if busy:
		return
	busy = true
	player.set_cutscene(true)
	await post.fade_to(1.0, 1.6).finished
	busy = false
	if Game.region + 1 < Game.REGIONS.size():
		start_region(Game.region + 1)


func goto_region(i: int) -> void:
	busy = true
	await post.fade_to(1.0, 1.4).finished
	busy = false
	start_region(i)


# ------------------------------------------------------------- death
func _on_player_died() -> void:
	if region and is_instance_valid(region) and region.on_player_died():
		return
	if busy:
		return
	busy = true
	Game.deaths += 1
	await wait(1.6)
	await post.fade_to(1.0, 1.2, Color(0.02, 0.02, 0.06)).finished
	busy = false
	curtain_visit(false)


func curtain_visit(first: bool) -> void:
	## Tesu dies and wakes in front of the curtain. One door per death.
	busy = true
	state = "curtain"
	_clear_world()
	_clear_ui()
	await get_tree().process_frame
	var cs := CurtainSet.new()
	cs.mode = "first" if first else "death"
	cs.info = {"id": "curtain_visit"}
	world.add_child(cs)
	region = cs
	Game.level = cs
	cs.build()
	_spawn_player()
	player.respawn_at(Vector3(0, 0.05, 1.6))
	player.facing = 1
	player.puppet.rotation_degrees.y = 180
	player.set_cutscene(true)
	player.puppet.anim("kneel")
	rig.target = null
	rig.cinematic(Vector3(1.8, 1.2, 5.5), Vector3(0, 1.8, -2.0), 0.0, 40.0)
	rig.cinematic(Vector3(0.6, 1.5, 3.6), Vector3(0, 1.9, -2.0), 6.0, 36.0)
	Snd.music("veil")
	Snd.ambience("amb_wind")
	post.indigo_target = 0.4
	post.letterbox_target = 1.0
	post.fade_to(0.0, 2.0)
	busy = false
	await wait(1.2)
	if Game.hold() == 0 and Game.deaths <= 1:
		await line("A woman's voice comes through the cloth, patient and very close.", "", "", 3.4)
		await line("Give me a door, little potter. And I will carry you back.", "mother", "mother_offer", 4.5)
		await line("Every time.", "mother", "mother_every", 2.4)
	else:
		Snd.voice("mother_which")
		await line(["Which door?", "Again, little potter.", "Another door.", "You came back to me."][Game.deaths % 4], "mother", "", 2.6)
	if Game.hold() == 4:
		await line("One door left. The last thing she ever takes.", "", "", 3.2)
	_door_choice(Game.hold() > 0 or Game.deaths > 1)


func _door_choice(can_refuse: bool) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	_menu = root
	var v := VBoxContainer.new()
	v.anchor_left = 0.05
	v.anchor_right = 0.95
	v.anchor_top = 0.45
	v.anchor_bottom = 0.98
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	var desc := Menus.label("", 26, Color(0.88, 0.84, 0.76), Hud.font_italic())
	desc.custom_minimum_size = Vector2(0, 110)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 22)
	var first: Control = null
	for d in Game.DOORS:
		if not Game.has(d):
			continue
		var card := Menus.door_card(d, func() -> void: _give(d))
		var info: Dictionary = Game.DOOR_INFO[d]
		card.focus_entered.connect(func() -> void:
			desc.text = "Tesu loses: %s\nBindu gains: %s\nThe Mother keeps: %s" % [info["loses"], info["gains"], info["keeps"]])
		h.add_child(card)
		if first == null:
			first = card
	v.add_child(desc)
	v.add_child(h)
	if can_refuse:
		var rb := Menus.button("Refuse.  Wake at the region's start with every door, and lose what you gathered there.", 28, _refuse)
		v.add_child(rb)
	elif Game.hold() == 0:
		var rb2 := Menus.button("Refuse.  Wake at the Mouth again.", 28, _refuse)
		v.add_child(rb2)
	if first:
		first.call_deferred("grab_focus")
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 1.2)


func _give(door: String) -> void:
	if busy:
		return
	busy = true
	_clear_ui()
	var cs: CurtainSet = region as CurtainSet
	Game.give(door)
	Snd.sfx("door_give", null, 0, 0.0)
	Snd.voice("mother_kept")
	Fx.flash(Color(0.45, 0.5, 1.0, 0.5), 1.4)
	Fx.shake(0.4)
	if player:
		Fx.indigo_dust(player.global_position + Vector3(0, 1.4, 0), 60)
	if cs:
		cs.update_hold(2.5)
		rig.cinematic(Vector3(0.1, 1.9, 2.4), Vector3(0, 2.0, -2.0), 2.5, 30.0)
	await line("Kept.", "mother", "", 2.0)
	var info: Dictionary = Game.DOOR_INFO[door]
	await line(info["loses"], "", "", 3.4)
	if Game.hold() >= 5:
		busy = false
		play_ending("raakh")
		return
	Snd.voice(info["bindu"])
	await line(info["bindu_text"], "bindu", "", 3.2)
	await post.fade_to(1.0, 1.6, Color(0.02, 0.02, 0.06)).finished
	busy = false
	_return_from_curtain(false)


func _refuse() -> void:
	if busy:
		return
	busy = true
	_clear_ui()
	Snd.voice("mother_refuse")
	await line("Then go back. Empty handed.", "mother", "", 3.0)
	Game.refuse_penalty()
	await post.fade_to(1.0, 1.4).finished
	busy = false
	_return_from_curtain(true)


func _return_from_curtain(refused: bool) -> void:
	var r: int = Game.region
	if Game.flags.get("first_curtain_pending", false):
		# the first death at the Mouth: from the curtain, down into the dark
		Game.flags["first_curtain_pending"] = false
		start_region(3)
		return
	start_region(r, "respawn")
	if refused:
		Game.show_hint("You wake with every door. Everything you gathered here is gone.")


func respawn_at_lamp() -> void:
	_close_pause()
	start_region(Game.region, "respawn")


# ------------------------------------------------------------- questions
func ask_question(question: String, answers: Array, cb: Callable, kaki_hint: String = "") -> void:
	## The Askers ask one question each. With no mouth, press a handprint and Bindu answers.
	player.set_cutscene(true)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Menus.panel_bg(0.85))
	p.anchor_left = 0.25
	p.anchor_right = 0.75
	p.anchor_top = 0.42
	p.anchor_bottom = 0.9
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(Menus.label(question, 34, Color(0.75, 0.68, 0.95), Hud.font_italic()))
	if kaki_hint != "" and Game.flags.get("kaki_taught", false):
		v.add_child(Menus.label("Kaki said: " + kaki_hint, 22, Color(0.95, 0.72, 0.4, 0.8), Hud.font_italic()))
	var first: Button = null
	for i in answers.size():
		var txt: String = answers[i]
		if not Game.has("mouth"):
			txt = "✋  " + txt + "   (Bindu says it)"
		var b := Menus.button(txt, 30, func() -> void:
			root.queue_free()
			if not Game.has("mouth"):
				Snd.sfx("tap", null, 0)
				await wait(1.4)
			player.set_cutscene(false)
			cb.call(i))
		v.add_child(b)
		if first == null:
			first = b
	first.call_deferred("grab_focus")


# ------------------------------------------------------------- choice (generic)
func choose(title: String, options: Array, cb: Callable) -> void:
	## options: Array of [label, enabled]
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	var v := VBoxContainer.new()
	v.anchor_left = 0.2
	v.anchor_right = 0.8
	v.anchor_top = 0.5
	v.anchor_bottom = 0.95
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	root.add_child(v)
	v.add_child(Menus.label(title, 34, Color(0.92, 0.86, 0.78), Hud.font_italic()))
	var first: Button = null
	for i in options.size():
		var o: Array = options[i]
		var b := Menus.button(o[0], 32, func() -> void:
			root.queue_free()
			cb.call(i))
		b.disabled = not o[1]
		if not o[1]:
			b.add_theme_color_override("font_disabled_color", Color(0.4, 0.38, 0.36))
		v.add_child(b)
		if first == null and o[1]:
			first = b
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 1.0)
	if first:
		first.call_deferred("grab_focus")


# ------------------------------------------------------------- pause
func toggle_pause() -> void:
	if get_tree().paused:
		_close_pause()
		return
	get_tree().paused = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	_pause = root
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var v := VBoxContainer.new()
	v.anchor_left = 0.35
	v.anchor_right = 0.65
	v.anchor_top = 0.25
	v.anchor_bottom = 0.85
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	root.add_child(v)
	v.add_child(Menus.label("the shut prayer", 30, Color(0.6, 0.64, 0.95), Hud.font_italic()))
	var info: Dictionary = Game.REGIONS[Game.region]
	v.add_child(Menus.label("%s · %s" % [info["num"], info["name"]], 44, Color(0.92, 0.88, 0.8)))
	v.add_child(Menus.label("doors given: %d   ·   deaths: %d   ·   knots untied: %d" % [Game.hold(), Game.deaths, Game.untied], 24, Color(0.7, 0.66, 0.6)))
	var r := Menus.button("Resume", 38, _close_pause)
	v.add_child(r)
	v.add_child(Menus.button("Return to the last lamp", 32, respawn_at_lamp))
	var mus := HSlider.new()
	mus.min_value = -30
	mus.max_value = 6
	mus.value = Snd.music_volume
	mus.custom_minimum_size = Vector2(300, 30)
	mus.value_changed.connect(func(x: float) -> void:
		Snd.music_volume = x
		Snd._apply_doors())
	v.add_child(Menus.label("music", 22, Color(0.7, 0.66, 0.6)))
	v.add_child(mus)
	var sfx := HSlider.new()
	sfx.min_value = -30
	sfx.max_value = 6
	sfx.value = Snd.sfx_volume
	sfx.custom_minimum_size = Vector2(300, 30)
	sfx.value_changed.connect(func(x: float) -> void:
		Snd.sfx_volume = x
		Snd._apply_doors())
	v.add_child(Menus.label("sound", 22, Color(0.7, 0.66, 0.6)))
	v.add_child(sfx)
	v.add_child(Menus.button("Fullscreen", 30, func() -> void:
		var m := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)))
	v.add_child(Menus.button("Leave to the field", 30, func() -> void:
		_close_pause()
		Game.save_game()
		busy = true
		await post.fade_to(1.0, 1.0).finished
		busy = false
		show_title()))
	r.grab_focus()


func _close_pause() -> void:
	get_tree().paused = false
	if _pause and is_instance_valid(_pause):
		_pause.queue_free()
	_pause = null


# ------------------------------------------------------------- endings
func play_ending(name: String) -> void:
	busy = true
	state = "ending"
	_clear_world()
	_clear_ui()
	await get_tree().process_frame
	_spawn_player()
	var e: Region = load("res://src/core/endings.gd").new()
	e.set("ending", name)
	e.info = {"id": "ending_" + name}
	e.rig = rig
	world.add_child(e)
	region = e
	Game.level = e
	e.build()
	busy = false
	e.begin()


func credits(ending_name: String, ending_tr: String, text: String) -> void:
	_clear_ui()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.012, 0.02, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var v := VBoxContainer.new()
	v.anchor_left = 0.2
	v.anchor_right = 0.8
	v.anchor_top = 0.15
	v.anchor_bottom = 0.9
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	v.add_child(Menus.label(ending_name, 110, Color(0.92, 0.6, 0.38)))
	v.add_child(Menus.label(ending_tr, 40, Color(0.62, 0.66, 0.95), Hud.font_italic()))
	v.add_child(Menus.label(text, 30, Color(0.85, 0.82, 0.76), Hud.font_italic()))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 40)
	v.add_child(sp)
	var mins := int(Game.play_time / 60.0)
	v.add_child(Menus.label("doors given: %d   ·   deaths: %d   ·   refusals: %d   ·   knots untied: %d   ·   %d minutes" % [Game.hold(), Game.deaths, Game.refusals, Game.untied, mins], 24, Color(0.65, 0.62, 0.58)))
	v.add_child(Menus.label("DWAAR  ·  panchdwar  ·  the five doors", 26, Color(0.75, 0.7, 0.62)))
	v.add_child(Menus.label("Every sound, texture and shape in this game was generated from nothing: clay-pot drums, bells, a clay whistle, a drone. Type: Cormorant Garamond, Tiro Devanagari Hindi, Kalam (SIL Open Font License).", 20, Color(0.5, 0.48, 0.46), Hud.font_italic()))
	var b := Menus.button("Back to the field", 34, func() -> void:
		Game.erase_save()
		show_title())
	v.add_child(b)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 3.0)
	b.call_deferred("grab_focus")
