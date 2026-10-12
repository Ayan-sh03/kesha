class_name Hud
extends CanvasLayer
## Almost no HUD. Health is a crack running up a clay pot. Doors given are
## five little doors in a corner. Words are three marks. Every door given
## removes part of the HUD.

static var _fonts := {}

var canvas: HudCanvas
var overlay: CanvasLayer
var sub_box: VBoxContainer
var sub_label: RichTextLabel
var hint_label: Label
var prompt_label: Label
var card: Control
var boss_name := ""
var boss_hi := ""
var boss_frac := -1.0
var _sub_queue: Array = []
var _sub_t := 0.0
var _hint_t := 0.0
var _boss_vis := 0.0


static func font_serif() -> Font:
	if not _fonts.has("serif"):
		var f: FontFile = load("res://assets/fonts/CormorantGaramond.ttf")
		var deva: FontFile = load("res://assets/fonts/TiroDevanagariHindi-Regular.ttf")
		f.fallbacks = [deva]
		var v := FontVariation.new()
		v.base_font = f
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 560}
		_fonts["serif"] = v
	return _fonts["serif"]


static func font_italic() -> Font:
	if not _fonts.has("italic"):
		var f: FontFile = load("res://assets/fonts/CormorantGaramond-Italic.ttf")
		f.fallbacks = [load("res://assets/fonts/TiroDevanagariHindi-Regular.ttf")]
		_fonts["italic"] = f
	return _fonts["italic"]


static func font_chalk() -> Font:
	if not _fonts.has("chalk"):
		var f: FontFile = load("res://assets/fonts/Kalam-Regular.ttf")
		_fonts["chalk"] = f
	return _fonts["chalk"]


static func font_deva() -> Font:
	if not _fonts.has("deva"):
		_fonts["deva"] = load("res://assets/fonts/TiroDevanagariHindi-Regular.ttf")
	return _fonts["deva"]


const WHO := {
	"mother": [Color(0.66, 0.7, 1.0), "the veiled mother"],
	"bindu": [Color(0.96, 0.95, 0.88), "bindu"],
	"kaki": [Color(0.95, 0.72, 0.4), "kaki"],
	"gaara": [Color(0.9, 0.42, 0.28), "gaara"],
	"elder": [Color(0.78, 0.76, 0.72), "the elders"],
	"tesu": [Color(1.0, 0.6, 0.25), "tesu"],
	"baba": [Color(0.86, 0.84, 0.78), "baba"],
	"keeper": [Color(0.8, 0.7, 0.5), "the knot-keeper"],
	"asker": [Color(0.7, 0.62, 0.85), "a voice behind the cloth"],
	"first": [Color(0.85, 0.55, 0.4), "the first"],
	"": [Color(0.85, 0.82, 0.76), ""],
}


func _ready() -> void:
	layer = 20
	canvas = HudCanvas.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.hud = self
	add_child(canvas)
	overlay = CanvasLayer.new()
	overlay.layer = 60
	add_child(overlay)
	# subtitles
	sub_label = RichTextLabel.new()
	sub_label.bbcode_enabled = true
	sub_label.fit_content = true
	sub_label.scroll_active = false
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_label.anchor_left = 0.18
	sub_label.anchor_right = 0.82
	sub_label.anchor_top = 0.8
	sub_label.anchor_bottom = 0.95
	sub_label.add_theme_font_override("normal_font", font_serif())
	sub_label.add_theme_font_override("italics_font", font_italic())
	sub_label.add_theme_font_size_override("normal_font_size", 38)
	sub_label.add_theme_font_size_override("italics_font_size", 38)
	sub_label.add_theme_constant_override("outline_size", 10)
	sub_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	sub_label.modulate.a = 0.0
	overlay.add_child(sub_label)
	# hints
	hint_label = Label.new()
	hint_label.anchor_left = 0.2
	hint_label.anchor_right = 0.8
	hint_label.anchor_top = 0.07
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_override("font", font_italic())
	hint_label.add_theme_font_size_override("font_size", 32)
	hint_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
	hint_label.add_theme_constant_override("outline_size", 8)
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	hint_label.modulate.a = 0.0
	overlay.add_child(hint_label)
	# interact prompt
	prompt_label = Label.new()
	prompt_label.anchor_left = 0.3
	prompt_label.anchor_right = 0.7
	prompt_label.anchor_top = 0.72
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_override("font", font_serif())
	prompt_label.add_theme_font_size_override("font_size", 30)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.55))
	prompt_label.add_theme_constant_override("outline_size", 8)
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	overlay.add_child(prompt_label)
	Game.said.connect(_on_said)
	Game.hint.connect(_on_hint)


func _on_said(text: String, who: String, dur: float) -> void:
	if dur <= 0.0:
		dur = 2.0 + text.length() * 0.055
	_sub_queue.append([text, who, dur])


func _on_hint(text: String) -> void:
	hint_label.text = text
	_hint_t = 3.2 + text.length() * 0.03


func clear_subs() -> void:
	_sub_queue.clear()
	_sub_t = 0.0


func _process(delta: float) -> void:
	var rd: float = delta / maxf(Engine.time_scale, 0.05)
	# subtitles
	if _sub_t > 0.0:
		_sub_t -= rd
		if _sub_t <= 0.4:
			sub_label.modulate.a = clamp(_sub_t / 0.4, 0.0, 1.0)
	elif not _sub_queue.is_empty():
		var s: Array = _sub_queue.pop_front()
		var who: String = s[1]
		var info: Array = WHO.get(who, WHO[""])
		var c: Color = info[0]
		var name_str := ""
		if info[1] != "":
			name_str = "[font_size=24][color=#%s]%s[/color][/font_size]\n" % [c.darkened(0.15).to_html(false), String(info[1]).to_upper()]
		var body := "[color=#%s]%s[/color]" % [c.to_html(false), s[0]]
		if who == "bindu":
			body = "[font=res://assets/fonts/Kalam-Regular.ttf][color=#%s]%s[/color][/font]" % [c.to_html(false), s[0]]
		elif who == "":
			body = "[i]" + body + "[/i]"
		sub_label.text = "[center]" + name_str + body + "[/center]"
		sub_label.modulate.a = 1.0
		_sub_t = s[2]
	else:
		sub_label.modulate.a = 0.0
	# hint
	if _hint_t > 0.0:
		_hint_t -= rd
		hint_label.modulate.a = clamp(_hint_t, 0.0, 1.0)
	else:
		hint_label.modulate.a = 0.0
	# prompt
	var p: Player = Game.player as Player if Game.player and is_instance_valid(Game.player) else null
	if p and p.interact_target and p.control:
		var key := "F"
		prompt_label.text = "[%s]  %s" % [key, p.interact_target.get("prompt")]
	else:
		prompt_label.text = ""
	_boss_vis = move_toward(_boss_vis, 1.0 if boss_frac >= 0.0 else 0.0, rd * 2.0)
	canvas.queue_redraw()


func title_card(info: Dictionary) -> void:
	if card:
		card.queue_free()
	card = Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(card)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.anchor_left = 0.0
	v.anchor_right = 1.0
	v.anchor_top = 0.3
	v.anchor_bottom = 0.7
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	var lines := [
		["%s  ·  %s" % [info.get("num", ""), info.get("depth", "")], font_serif(), 30, Color(0.8, 0.55, 0.38)],
		[info.get("name", ""), font_serif(), 104, Color(0.95, 0.92, 0.86)],
		[info.get("tr", ""), font_italic(), 44, Color(0.62, 0.66, 0.95)],
		[String(info.get("sub", "")).to_upper(), font_serif(), 22, Color(0.7, 0.66, 0.6)],
	]
	for l in lines:
		var lab := Label.new()
		lab.text = l[0]
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_override("font", l[1])
		lab.add_theme_font_size_override("font_size", l[2])
		lab.add_theme_color_override("font_color", l[3])
		lab.add_theme_constant_override("outline_size", 12)
		lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		v.add_child(lab)
	card.modulate.a = 0.0
	var t := card.create_tween()
	t.tween_property(card, "modulate:a", 1.0, 1.4).set_delay(0.6)
	t.tween_interval(3.0)
	t.tween_property(card, "modulate:a", 0.0, 1.6)
	t.tween_callback(card.queue_free)


func show_boss(n: String, hi: String) -> void:
	boss_name = n
	boss_hi = hi
	boss_frac = 1.0


func set_boss(frac: float) -> void:
	boss_frac = frac


func hide_boss() -> void:
	boss_frac = -1.0


class HudCanvas:
	extends Control
	var hud: Hud
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta

	func _draw() -> void:
		if not Game.player or not is_instance_valid(Game.player) or not hud.visible:
			return
		var p: Player = Game.player
		if p.state == "cutscene" and not Game.flags.get("hud_in_cutscene", false):
			return
		var vs := get_viewport_rect().size
		_draw_pot(Vector2(110, vs.y - 150))
		_draw_inventory(Vector2(200, vs.y - 112))
		_draw_doors(Vector2(vs.x - 330, 70))
		_draw_words(Vector2(vs.x - 290, vs.y - 120))
		if p.band_on and Game.has("nose"):
			var a := Game.breath
			draw_arc(Vector2(vs.x * 0.5, vs.y * 0.5 - 140), 34, -PI * 0.5, -PI * 0.5 + TAU * a, 48, Color(0.9, 0.9, 0.95, 0.8), 5.0, true)
		if hud._boss_vis > 0.01:
			_draw_boss(vs)

	func _pot_points(c: Vector2, s: float) -> PackedVector2Array:
		var prof := [Vector2(0, 0), Vector2(0.55, 0.02), Vector2(0.95, 0.2), Vector2(1.08, 0.45), Vector2(1.0, 0.7), Vector2(0.7, 0.88), Vector2(0.42, 0.95), Vector2(0.4, 1.02), Vector2(0.52, 1.1), Vector2(0.5, 1.14)]
		var pts := PackedVector2Array()
		for v in prof:
			pts.append(c + Vector2(v.x, -v.y) * s)
		for i in range(prof.size() - 1, -1, -1):
			var v: Vector2 = prof[i]
			pts.append(c + Vector2(-v.x, -v.y) * s)
		return pts

	func _draw_pot(c: Vector2) -> void:
		if not Game.has("skin"):
			return  # touch given: no health at all
		var s := 62.0
		var pts := _pot_points(c, s)
		draw_colored_polygon(pts, Color(0.6, 0.27, 0.15, 0.92))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.25, 0.1, 0.05, 0.9), 3.0, true)
		# band of slip decoration
		draw_line(c + Vector2(-0.98, -0.45) * s, c + Vector2(0.98, -0.45) * s, Color(0.92, 0.85, 0.7, 0.6), 3.0)
		for i in 7:
			var x := -0.8 + i * 0.27
			draw_circle(c + Vector2(x, -0.55) * s, 3.0, Color(0.92, 0.85, 0.7, 0.6))
		# the crack runs up from the base as health goes
		var frac := 1.0 - float(Game.hp) / float(Game.max_hp())
		if frac > 0.0:
			var crack := PackedVector2Array()
			var rng := RandomNumberGenerator.new()
			rng.seed = 42
			var steps := 12
			for i in steps + 1:
				var y := float(i) / steps
				if y > frac * 1.1:
					break
				crack.append(c + Vector2(rng.randf_range(-0.25, 0.25) + sin(y * 9.0) * 0.15, -y) * s)
			if crack.size() > 1:
				draw_polyline(crack, Color(0.05, 0.02, 0.01, 1.0), 4.0, true)
				draw_polyline(crack, Color(1.0, 0.6, 0.3, 0.25 + 0.2 * sin(_t * 5.0)), 1.5, true)
		if Game.hp <= 0:
			draw_colored_polygon(pts, Color(0, 0, 0, 0.5))

	func _draw_inventory(o: Vector2) -> void:
		var f := Hud.font_serif()
		var col := Color(0.92, 0.88, 0.8, 0.9)
		# pellets
		draw_circle(o + Vector2(10, -6), 8, Color(0.7, 0.33, 0.2))
		draw_string(f, o + Vector2(26, 4), "%d" % Game.pellets, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
		# spare lamps
		var lo := o + Vector2(90, -2)
		draw_colored_polygon(PackedVector2Array([lo + Vector2(-12, -4), lo + Vector2(12, -4), lo + Vector2(6, 4), lo + Vector2(-6, 4)]), Color(0.7, 0.33, 0.2))
		draw_circle(lo + Vector2(6, -12), 4 + sin(_t * 12.0), Color(1.0, 0.7, 0.3))
		draw_string(f, o + Vector2(108, 4), "%d" % Game.lamps, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
		# water gourd
		var go := o + Vector2(170, -6)
		draw_circle(go, 11, Color(0.3, 0.25, 0.2, 0.8))
		draw_arc(go, 11, PI * 0.5 - PI * Game.water, PI * 0.5 + PI * Game.water, 24, Color(0.45, 0.65, 0.8, 0.95), 4.0, true)

	func _door_shape(o: Vector2, w: float, h: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		pts.append(o + Vector2(-w * 0.5, 0))
		for i in 13:
			var a := PI + PI * float(i) / 12.0
			pts.append(o + Vector2(cos(a) * w * 0.5, -h + w * 0.5 + sin(a) * w * 0.5))
		pts.append(o + Vector2(w * 0.5, 0))
		return pts

	func _draw_doors(o: Vector2) -> void:
		var f := Hud.font_deva()
		for i in 5:
			var d: String = Game.DOORS[i]
			var c := o + Vector2(i * 62, 70)
			var pts := _door_shape(c, 40, 62)
			var given: bool = not Game.has(d)
			if given:
				draw_colored_polygon(pts, Color(0.12, 0.17, 0.42, 0.95))
				draw_circle(c + Vector2(0, -30), 5, Color(0.8, 0.82, 0.95))
				draw_line(c + Vector2(-6, -36), c + Vector2(6, -24), Color(0.8, 0.82, 0.95), 2.0)
			else:
				draw_colored_polygon(pts, Color(0.08, 0.05, 0.04, 0.55))
				var glow := Color(1.0, 0.65, 0.3, 0.35 + 0.1 * sin(_t * 2.0 + i))
				draw_colored_polygon(_door_shape(c + Vector2(0, -4), 26, 50), glow)
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.75, 0.42, 0.25, 0.9), 2.5, true)
			var info: Dictionary = Game.DOOR_INFO[d]
			draw_string(f, c + Vector2(-28, 30), info["hi"], HORIZONTAL_ALIGNMENT_CENTER, 56, 20, Color(0.85, 0.8, 0.72, 0.8))

	func _draw_words(o: Vector2) -> void:
		if not Game.words_learned:
			return
		var p: Player = Game.player
		var f := Hud.font_deva()
		var glyphs := ["बंद", "खुल", "टूट"]
		var keys := ["shut", "open", "break"]
		for i in 3:
			var c := o + Vector2(i * 96, 0)
			var cd: float = p.word_cd[keys[i]] / Player.WORD_CD
			if Game.has("mouth"):
				var a := 0.9 - cd * 0.6
				draw_string(f, c + Vector2(-40, 10), glyphs[i], HORIZONTAL_ALIGNMENT_CENTER, 80, 40, Color(1.0, 0.82, 0.55, a))
			else:
				# handprints: Bindu says them for him
				var hc := Color(0.45, 0.25, 0.15, 0.9 - cd * 0.6)
				draw_circle(c + Vector2(0, 4), 13, hc)
				for k in 5:
					var ang := -PI * 0.5 + (k - 2) * 0.38
					draw_line(c + Vector2(0, 0), c + Vector2(cos(ang), sin(ang)) * 26, hc, 7.0, true)
			draw_string(Hud.font_serif(), c + Vector2(-20, 46), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Color(0.7, 0.66, 0.6, 0.6))

	func _draw_boss(vs: Vector2) -> void:
		var a := hud._boss_vis
		var w := vs.x * 0.42
		var o := Vector2(vs.x * 0.5 - w * 0.5, 64)
		draw_string(Hud.font_serif(), Vector2(0, o.y - 14), hud.boss_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 30, Color(0.92, 0.86, 0.76, a))
		draw_string(Hud.font_italic(), Vector2(0, o.y + 44), hud.boss_hi, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 26, Color(0.6, 0.62, 0.9, a * 0.9))
		draw_rect(Rect2(o, Vector2(w, 8)), Color(0.08, 0.05, 0.04, 0.7 * a))
		draw_rect(Rect2(o, Vector2(w * clamp(hud.boss_frac, 0.0, 1.0), 8)), Color(0.75, 0.33, 0.18, a))
		# cracks across the bar
		var n := int((1.0 - hud.boss_frac) * 10.0)
		for i in n:
			var x := o.x + w * (0.08 + 0.09 * i)
			draw_line(Vector2(x, o.y - 3), Vector2(x + 6, o.y + 11), Color(0.05, 0.02, 0.01, a), 2.0)
