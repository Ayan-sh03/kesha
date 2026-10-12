class_name Menus
extends RefCounted
## Styled UI pieces: buttons that read like lamplit text, door cards.


static func button(text: String, size: int = 40, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", Hud.font_serif())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.82, 0.78, 0.7))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.72, 0.4))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.72, 0.4))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.6))
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	if cb.is_valid():
		b.pressed.connect(cb)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.focus_entered.connect(func() -> void: Snd.sfx("ui_move", null, -10, 0.1))
	b.pressed.connect(func() -> void: Snd.sfx("ui_select", null, -6, 0.0))
	return b


static func label(text: String, size: int = 32, color: Color = Color(0.9, 0.86, 0.78), font: Font = null, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font if font else Hud.font_serif())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	return l


static func panel_bg(alpha: float = 0.75) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.025, 0.04, alpha)
	sb.border_color = Color(0.55, 0.3, 0.18, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	return sb


static func door_card(door: String, cb: Callable) -> Button:
	var info: Dictionary = Game.DOOR_INFO[door]
	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 300)
	b.focus_mode = Control.FOCUS_ALL
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.05, 0.08, 0.85)
	st.border_color = Color(0.55, 0.3, 0.18, 0.8)
	st.set_border_width_all(2)
	st.corner_radius_top_left = 95
	st.corner_radius_top_right = 95
	var hv: StyleBoxFlat = st.duplicate()
	hv.bg_color = Color(0.1, 0.13, 0.32, 0.95)
	hv.border_color = Color(0.65, 0.7, 1.0, 1.0)
	hv.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("focus", hv)
	b.add_theme_stylebox_override("pressed", hv)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var hi := label(info["hi"], 64, Color(0.95, 0.85, 0.7), Hud.font_deva())
	hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hi)
	var en := label(info["name"], 34, Color(0.9, 0.86, 0.78))
	en.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(en)
	var tr := label(info["tr"], 24, Color(0.6, 0.64, 0.95), Hud.font_italic())
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tr)
	b.pressed.connect(cb)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.focus_entered.connect(func() -> void: Snd.sfx("curtain", null, -14, 0.2))
	return b
