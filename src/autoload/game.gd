extends Node
## Global game state: the five doors, the Mother's hold, deaths, inventory,
## progression and saving. Everything that "remembers" lives here.

signal doors_changed
signal hp_changed
signal inventory_changed
signal noise(pos: Vector3, radius: float)
signal said(text: String, who: String, dur: float)
signal word_spoken(word: String, pos: Vector3, by_bindu: bool)
signal hint(text: String)

const DOORS := ["eye", "ear", "mouth", "nose", "skin"]
const DOOR_INFO := {
	"eye": {"name": "Eye", "hi": "आँख", "tr": "aankh",
		"loses": "His left eye. The left third of the world goes dark.",
		"gains": "Bindu's sight. She draws for him in chalk.",
		"keeps": "She looks out through every lamp-niche in Ghatiya.",
		"bindu": "bindu_see", "bindu_text": "I can see. I'll draw for you."},
	"ear": {"name": "Ear", "hi": "कान", "tr": "kaan",
		"loses": "Hearing. No footsteps, no warnings, no music.",
		"gains": "Bindu's hearing. Every sound near him draws as rings.",
		"keeps": "She hears every whisper at the curtain.",
		"bindu": "bindu_hear", "bindu_text": "I can hear you. I'll tap back."},
	"mouth": {"name": "Mouth", "hi": "मुँह", "tr": "munh",
		"loses": "Voice and taste. Kaki's three words are gone.",
		"gains": "Bindu's voice. Press a wet handprint and she speaks the word.",
		"keeps": "At night she talks through Kaki.",
		"bindu": "bindu_tesu", "bindu_text": "Tesu. Press your hand. I'll say it."},
	"nose": {"name": "Nose", "hi": "नाक", "tr": "naak",
		"loses": "Smell. Her clay trail is gone. Gas gives no warning.",
		"gains": "Bindu's breath. Smoke and gas can't hurt him.",
		"keeps": "Smoke rises from every cold kiln in the village.",
		"bindu": "bindu_here", "bindu_text": "Breathe. I'm breathing for you."},
	"skin": {"name": "Skin", "hi": "खाल", "tr": "khaal",
		"loses": "Touch and pain. No health, no flash when hit.",
		"gains": "Fired skin. Double health, hot floors are safe.",
		"keeps": "Her curtain burns at the hem. Fire can walk now.",
		"bindu": "bindu_here", "bindu_text": "I feel it for you. Every one."},
}

const REGIONS := [
	{"id": "dry_ghat", "num": "I", "name": "Dry Ghat", "tr": "sookha ghat", "sub": "prologue · the giving · night", "depth": "0 haath", "script": "res://src/regions/r01_dry_ghat.gd"},
	{"id": "ghatiya", "num": "II", "name": "Ghatiya", "tr": "the potters' lanes", "sub": "the hub", "depth": "0 haath", "script": "res://src/regions/r02_ghatiya.gd"},
	{"id": "curtain", "num": "III", "name": "The Curtain", "tr": "parda", "sub": "past the burning ground", "depth": "the field", "script": "res://src/regions/r03_curtain.gd"},
	{"id": "drowned", "num": "IV", "name": "Drowned Ghats", "tr": "dooba ghat", "sub": "an older town the river buried", "depth": "80 haath", "script": "res://src/regions/r04_drowned.gd"},
	{"id": "pits", "num": "V", "name": "Clay Pits", "tr": "khadaan", "sub": "where Ghatiya dug its clay", "depth": "200 haath", "script": "res://src/regions/r05_pits.gd"},
	{"id": "hall", "num": "VI", "name": "Hall of Given Things", "tr": "diya hua", "sub": "everything the village gave", "depth": "360 haath", "script": "res://src/regions/r06_hall.gd"},
	{"id": "knots", "num": "VII", "name": "Knot House", "tr": "gaanth-ghar", "sub": "Gaara's count", "depth": "500 haath", "script": "res://src/regions/r07_knots.gd"},
	{"id": "kiln", "num": "VIII", "name": "The Kiln", "tr": "aava", "sub": "where gifts are fired", "depth": "620 haath", "script": "res://src/regions/r08_kiln.gd"},
	{"id": "wheel", "num": "IX", "name": "The Wheel", "tr": "chaak", "sub": "Gaara's floor", "depth": "700 haath", "script": "res://src/regions/r09_wheel.gd"},
	{"id": "way_up", "num": "X", "name": "The Way Up", "tr": "upar", "sub": "the climb back", "depth": "700 → 0 haath", "script": "res://src/regions/r10_way_up.gd"},
]

const SAVE_PATH := "user://dwaar_save.json"

# --- doors
var given := {}            # door -> true when given to the Mother
var given_order: Array = []
var ever_given := false
var untied := 0            # knots untied (asking back: the one sin)
var wake := 0              # extra clay woken in the next region

# --- body
var hp := 5
var breath := 1.0
var pellets := 12
var lamps := 1
var water := 1.0
var leaking := false

# --- progress
var region := 0
var deaths := 0
var refusals := 0
var learned_name := false   # the First's name, read in the Hall
var bound := false          # the Knot-Keeper's knot pulled tight
var words_learned := false  # Kaki teaches the three words in Ghatiya
var route := ""             # rescue / kiln / veil / rain / ash
var mother_follows := false
var gathered := {"pellets": 0, "lamps": 0}
var checkpoint := Vector3.INF
var flags := {}
var play_time := 0.0
var autotest := false

# live references (set by Main / regions)
var main: Node = null
var player: Node = null
var level: Node = null
var camera: Camera3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


# ------------------------------------------------------------- doors
func has(door: String) -> bool:
	return not given.get(door, false)


func hold() -> int:
	return given_order.size()


func max_hp() -> int:
	return 10 if given.get("skin", false) else 5


func give(door: String) -> void:
	if given.get(door, false):
		return
	given[door] = true
	given_order.append(door)
	ever_given = true
	hp = max_hp()
	doors_changed.emit()
	hp_changed.emit()


func untie(door: String = "") -> String:
	## Take one sense back from Bindu. Asking is the one sin: more clay wakes.
	if given_order.is_empty():
		return ""
	var d: String = door if door != "" and given.get(door, false) else given_order[given_order.size() - 1]
	given.erase(d)
	given_order.erase(d)
	untied += 1
	wake += 1
	hp = min(hp, max_hp())
	doors_changed.emit()
	hp_changed.emit()
	return d


func is_watched(pos: Vector3) -> bool:
	## Clay moves only when nobody is looking: a set lamp, or Tesu's open
	## eyes facing it, on screen, and not on his blind side.
	for l in get_tree().get_nodes_in_group("watcher"):
		if l.has_method("watches") and l.watches(pos):
			return true
	if player == null or not is_instance_valid(player) or camera == null:
		return false
	if not player.eyes_open():
		return false
	var pp: Vector3 = player.global_position
	if (pos.x - pp.x) * player.facing < -1.2:
		return false
	if camera.is_position_behind(pos):
		return false
	var sp := camera.unproject_position(pos)
	var vs := get_viewport().get_visible_rect().size
	if sp.x < 0 or sp.x > vs.x or sp.y < -vs.y * 0.2 or sp.y > vs.y * 1.1:
		return false
	if not has("eye") and sp.x < vs.x / 3.0:
		return false
	return true


func light_level() -> float:
	## Below the river the Mother's light grows with every door.
	return float(hold()) / 5.0


# ------------------------------------------------------------- body
func hurt(amount: int) -> void:
	hp = max(0, hp - amount)
	hp_changed.emit()


func heal(amount: int) -> void:
	hp = min(max_hp(), hp + amount)
	hp_changed.emit()


func add_pellets(n: int) -> void:
	pellets += n
	gathered["pellets"] += max(n, 0)
	inventory_changed.emit()


func add_lamps(n: int) -> void:
	lamps += n
	gathered["lamps"] += max(n, 0)
	inventory_changed.emit()


func emit_noise(pos: Vector3, radius: float) -> void:
	noise.emit(pos, radius)


func say(text: String, who: String = "", dur: float = 0.0) -> void:
	said.emit(text, who, dur)


func show_hint(text: String) -> void:
	hint.emit(text)


# ------------------------------------------------------------- progress
func new_game() -> void:
	given = {}
	given_order = []
	ever_given = false
	untied = 0
	wake = 0
	hp = 5
	breath = 1.0
	pellets = 12
	lamps = 1
	water = 1.0
	leaking = false
	region = 0
	deaths = 0
	refusals = 0
	learned_name = false
	bound = false
	words_learned = false
	route = ""
	mother_follows = false
	gathered = {"pellets": 0, "lamps": 0}
	checkpoint = Vector3.INF
	flags = {}
	play_time = 0.0
	doors_changed.emit()
	hp_changed.emit()
	inventory_changed.emit()


func enter_region(i: int) -> void:
	region = i
	gathered = {"pellets": 0, "lamps": 0}
	checkpoint = Vector3.INF
	hp = max_hp()
	save_game()


func refuse_penalty() -> void:
	## Refusing the curtain: wake at the region start with doors intact,
	## but everything gathered in this region is lost.
	pellets = max(0, pellets - int(gathered["pellets"]))
	lamps = max(0, lamps - int(gathered["lamps"]))
	gathered = {"pellets": 0, "lamps": 0}
	checkpoint = Vector3.INF
	refusals += 1
	inventory_changed.emit()


func save_game() -> void:
	if autotest:
		return
	var d := {
		"given_order": given_order, "ever_given": ever_given, "untied": untied, "wake": wake,
		"pellets": pellets, "lamps": lamps, "region": region, "deaths": deaths,
		"refusals": refusals, "learned_name": learned_name, "bound": bound,
		"words_learned": words_learned, "flags": flags, "play_time": play_time,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	new_game()
	given_order = d.get("given_order", [])
	for g in given_order:
		given[g] = true
	ever_given = d.get("ever_given", false)
	untied = int(d.get("untied", 0))
	wake = int(d.get("wake", 0))
	pellets = int(d.get("pellets", 12))
	lamps = int(d.get("lamps", 1))
	region = int(d.get("region", 0))
	deaths = int(d.get("deaths", 0))
	refusals = int(d.get("refusals", 0))
	learned_name = d.get("learned_name", false)
	bound = d.get("bound", false)
	words_learned = d.get("words_learned", false)
	flags = d.get("flags", {})
	play_time = float(d.get("play_time", 0.0))
	hp = max_hp()
	doors_changed.emit()
	hp_changed.emit()
	inventory_changed.emit()
	return true


func erase_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ------------------------------------------------------------- input
func _setup_inputs() -> void:
	var keys := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE], "attack": [KEY_J], "aim": [KEY_K],
		"roll": [KEY_SHIFT], "block": [KEY_Q], "lamp": [KEY_E],
		"interact": [KEY_F], "word_shut": [KEY_1], "word_open": [KEY_2],
		"word_break": [KEY_3], "band": [KEY_H], "pour": [KEY_R],
		"pause": [KEY_ESCAPE, KEY_P], "skip": [KEY_ENTER, KEY_TAB],
	}
	var mouse := {"attack": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT}
	var pad := {
		"jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "roll": JOY_BUTTON_B,
		"interact": JOY_BUTTON_Y, "block": JOY_BUTTON_LEFT_SHOULDER,
		"lamp": JOY_BUTTON_RIGHT_SHOULDER, "pause": JOY_BUTTON_START,
		"band": JOY_BUTTON_LEFT_STICK, "pour": JOY_BUTTON_RIGHT_STICK,
		"word_shut": JOY_BUTTON_DPAD_LEFT, "word_open": JOY_BUTTON_DPAD_UP,
		"word_break": JOY_BUTTON_DPAD_RIGHT, "skip": JOY_BUTTON_BACK,
	}
	var axes := {
		"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
		"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0],
		"aim": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
		"aim_left": [JOY_AXIS_RIGHT_X, -1.0], "aim_right": [JOY_AXIS_RIGHT_X, 1.0],
		"aim_up": [JOY_AXIS_RIGHT_Y, -1.0], "aim_down": [JOY_AXIS_RIGHT_Y, 1.0],
	}
	var all := {}
	for k in keys:
		all[k] = true
	for k in axes:
		all[k] = true
	for action in all:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		for k in keys.get(action, []):
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		if mouse.has(action):
			var m := InputEventMouseButton.new()
			m.button_index = mouse[action]
			InputMap.action_add_event(action, m)
		if pad.has(action):
			var b := InputEventJoypadButton.new()
			b.button_index = pad[action]
			InputMap.action_add_event(action, b)
		if axes.has(action):
			var j := InputEventJoypadMotion.new()
			j.axis = axes[action][0]
			j.axis_value = axes[action][1]
			InputMap.action_add_event(action, j)
