class_name PostFX
extends CanvasLayer
## Drives the full-screen shader from the state of Tesu's doors.

var rect: ColorRect
var mat: ShaderMaterial
var hurt := 0.0
var flash := 0.0
var flash_col := Color.WHITE
var burn := 0.0
var letterbox := 0.0
var letterbox_target := 0.0
var fade := 0.0
var fade_color := Color.BLACK
var band := 0.0
var heat := 0.0
var heat_target := 0.0
var knock := 0.0
var chroma := 0.0
var indigo_target := 0.0
var moths := 0.0
var desat := 0.0
var smoke := 0.0
var _t := 0.0


func _ready() -> void:
	layer = 50
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = B.shader("post")
	rect.material = mat
	add_child(rect)
	Fx.flash_requested.connect(_on_flash)
	Fx.pulse_requested.connect(_on_pulse)


func _on_flash(c: Color, dur: float) -> void:
	flash_col = c
	flash = 1.0
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(self, "flash", 0.0, dur)


func _on_pulse(kind: String, amount: float) -> void:
	match kind:
		"hurt":
			hurt = max(hurt, amount)
			chroma = max(chroma, amount * 0.8)
		"bindu":
			chroma = max(chroma, amount * 0.5)
		"word":
			chroma = max(chroma, amount)
		"knock":
			knock = max(knock, amount)


func fade_to(v: float, dur: float, c: Color = Color.BLACK) -> Tween:
	fade_color = c
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(self, "fade", v, dur)
	return t


func _process(delta: float) -> void:
	var rd: float = delta / maxf(Engine.time_scale, 0.05)
	_t += rd
	var p: Player = Game.player as Player if Game.player and is_instance_valid(Game.player) else null
	var want_band := 1.0 if p and p.band_on else 0.0
	band = move_toward(band, want_band, rd * 3.0)
	hurt = move_toward(hurt, 0.0, rd * 1.4)
	chroma = move_toward(chroma, 0.0, rd * 2.0)
	knock = move_toward(knock, 0.0, rd * 0.8)
	letterbox = move_toward(letterbox, letterbox_target, rd * 1.5)
	heat = move_toward(heat, heat_target, rd)
	var low_hp := 0.0
	if Game.has("skin") and Game.hp <= 1 and Game.max_hp() > 1:
		low_hp = 0.35 + 0.15 * sin(_t * 6.0)
	var in_smoke: bool = Game.flags.get("in_smoke", false)
	smoke = move_toward(smoke, (0.55 if in_smoke else 0.0) * (0.4 if not Game.has("nose") else 1.0), rd * 1.5)
	mat.set_shader_parameter("time_s", _t)
	mat.set_shader_parameter("eye_lost", 0.0 if Game.has("eye") else 1.0)
	mat.set_shader_parameter("band", band)
	mat.set_shader_parameter("hurt", max(hurt, low_hp))
	mat.set_shader_parameter("burn", burn)
	mat.set_shader_parameter("indigo", indigo_target)
	mat.set_shader_parameter("letterbox", letterbox)
	mat.set_shader_parameter("heat", heat)
	mat.set_shader_parameter("knock", knock)
	mat.set_shader_parameter("chroma", chroma)
	mat.set_shader_parameter("moths", moths)
	mat.set_shader_parameter("desat", desat)
	mat.set_shader_parameter("smoke", smoke)
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("flash_color", flash_col)
	mat.set_shader_parameter("fade", fade)
	mat.set_shader_parameter("fade_color", fade_color)
