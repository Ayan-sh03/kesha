extends Node
## Sound. All music comes from inside the world; giving the ear door
## removes the score itself. Buses: Music, Amb, SFX, Voice.

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const VOICE_DIR := "res://assets/audio/voice/"

var _cache := {}
var _music: Array[AudioStreamPlayer] = []
var _cur := 0
var _music_name := ""
var _amb: AudioStreamPlayer
var _amb_name := ""
var _duck := 0.0
var music_volume := 0.0
var sfx_volume := 0.0

var _lp_music: AudioEffectLowPassFilter
var _lp_sfx: AudioEffectLowPassFilter
var _lp_amb: AudioEffectLowPassFilter
var _reverb: AudioEffectReverb
var _band := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80
		add_child(p)
		_music.append(p)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Amb"
	add_child(_amb)
	Game.doors_changed.connect(_apply_doors)
	_apply_doors()


func _bus(name: String) -> int:
	var i := AudioServer.get_bus_index(name)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")
	return i


func _setup_buses() -> void:
	var m := _bus("Music")
	var a := _bus("Amb")
	var s := _bus("SFX")
	_bus("Voice")
	_lp_music = AudioEffectLowPassFilter.new()
	_lp_music.cutoff_hz = 20000
	AudioServer.add_bus_effect(m, _lp_music)
	_lp_amb = AudioEffectLowPassFilter.new()
	_lp_amb.cutoff_hz = 20000
	AudioServer.add_bus_effect(a, _lp_amb)
	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.4
	_reverb.wet = 0.12
	_reverb.dry = 1.0
	AudioServer.add_bus_effect(s, _reverb)
	_lp_sfx = AudioEffectLowPassFilter.new()
	_lp_sfx.cutoff_hz = 20000
	AudioServer.add_bus_effect(s, _lp_sfx)
	var lim := AudioEffectHardLimiter.new()
	AudioServer.add_bus_effect(0, lim)


func set_space(room: float, wet: float) -> void:
	## Regions set the room: caves ring, the village is dry.
	_reverb.room_size = room
	_reverb.wet = wet


func _apply_doors() -> void:
	var deaf := not Game.has("ear")
	var m := AudioServer.get_bus_index("Music")
	var s := AudioServer.get_bus_index("SFX")
	var a := AudioServer.get_bus_index("Amb")
	# The score goes dull: muffled, far, almost gone.
	_lp_music.cutoff_hz = 320.0 if deaf else 20000.0
	_lp_sfx.cutoff_hz = 260.0 if deaf else 20000.0
	_lp_amb.cutoff_hz = 220.0 if deaf else 20000.0
	AudioServer.set_bus_volume_db(m, (-17.0 if deaf else 0.0) + music_volume)
	AudioServer.set_bus_volume_db(s, (-24.0 if deaf else 0.0) + sfx_volume)
	AudioServer.set_bus_volume_db(a, -26.0 if deaf else 0.0)


func set_band(on: bool) -> void:
	## Shut prayer: ears stopped with fingers.
	if _band == on:
		return
	_band = on
	if not Game.has("ear"):
		return
	var t := create_tween().set_parallel()
	var to := 500.0 if on else 20000.0
	t.tween_method(func(v: float) -> void: _lp_sfx.cutoff_hz = v, _lp_sfx.cutoff_hz, to, 0.3)
	t.tween_method(func(v: float) -> void: _lp_music.cutoff_hz = v, _lp_music.cutoff_hz, to * 1.5, 0.3)
	t.tween_method(func(v: float) -> void: _lp_amb.cutoff_hz = v, _lp_amb.cutoff_hz, to, 0.3)


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return null
	var s: AudioStream = load(path)
	_cache[path] = s
	return s


# ------------------------------------------------------------- music
func music(name: String, fade: float = 2.5) -> void:
	if name == _music_name:
		return
	_music_name = name
	var old := _music[_cur]
	_cur = 1 - _cur
	var p := _music[_cur]
	var t := create_tween().set_parallel()
	t.tween_property(old, "volume_db", -80.0, fade).set_trans(Tween.TRANS_SINE)
	t.chain().tween_callback(old.stop)
	if name == "":
		return
	var s := _load(MUSIC_DIR + name + ".ogg")
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	p.stream = s
	p.volume_db = -40.0
	p.play()
	var t2 := create_tween()
	t2.tween_property(p, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE)


func music_name() -> String:
	return _music_name


func ambience(name: String, vol: float = -6.0) -> void:
	if name == _amb_name:
		return
	_amb_name = name
	if name == "":
		var t := create_tween()
		t.tween_property(_amb, "volume_db", -80.0, 2.0)
		t.tween_callback(_amb.stop)
		return
	var s := _load(SFX_DIR + name + ".ogg")
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_amb.stream = s
	_amb.volume_db = -40
	_amb.play()
	create_tween().tween_property(_amb, "volume_db", vol, 2.0)


# ------------------------------------------------------------- one-shots
func sfx(name: String, pos: Variant = null, vol: float = 0.0, pitch_var: float = 0.08, bus: String = "SFX") -> Node:
	var s := _load(SFX_DIR + name + ".ogg")
	if s == null:
		s = _load(VOICE_DIR + name + ".ogg")
	if s == null:
		return null
	var pitch := 1.0 + randf_range(-pitch_var, pitch_var)
	if pos is Vector3 and Game.level != null and is_instance_valid(Game.level):
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = s
		p3.bus = bus
		p3.volume_db = vol
		p3.pitch_scale = pitch
		p3.unit_size = 10.0
		p3.max_db = 3.0
		p3.max_distance = 70.0
		p3.attenuation_filter_cutoff_hz = 9000
		p3.attenuation_filter_db = -12
		Game.level.add_child(p3)
		p3.global_position = pos
		p3.play()
		p3.finished.connect(p3.queue_free)
		return p3
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.volume_db = vol
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func voice(name: String, vol: float = 0.0) -> Node:
	var s := _load(VOICE_DIR + name + ".ogg")
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = "Voice"
	p.volume_db = vol
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func step(surface: String, pos: Vector3, loud: float = 1.0) -> void:
	var n := "step_dust"
	match surface:
		"water": n = "step_water"
		"silt", "mud": n = "step_silt"
	sfx("%s%d" % [n, randi() % 4], pos, linear_to_db(clamp(loud, 0.05, 1.5)) - 4.0, 0.12)
