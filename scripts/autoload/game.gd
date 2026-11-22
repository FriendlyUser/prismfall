extends Node
## Persistent meta-progression, save/load, input map and run configuration.

const SAVE_PATH := "user://prismfall_save.json"

var shards := 0
var meta := {}            # shop id -> purchased level
var unlocked := 1         # number of sectors unlocked
var best := {}            # "0".."2" -> {"score": int, "cleared": bool}
var level_index := 0
var debug := {}           # URL / cmdline flags used for testing
var post_mat: ShaderMaterial
var main: Node
var touch_active := false   # becomes true on first touch (or forced via settings)
var settings := {
	"quality": 2,        # 0 low, 1 medium, 2 high
	"music": 0.7,
	"sfx": 0.85,
	"shake": 1.0,
	"touch": 0,          # 0 auto, 1 always, 2 never
}

signal settings_changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_mobile():
		settings.quality = 1
		touch_active = true
	_setup_input()
	_setup_buses()
	load_save()
	_read_debug()
	if debug.has("unlock"):
		unlocked = DB.LEVELS.size()
	if debug.has("quality"):
		settings.quality = int(debug.quality)
	if debug.has("touch"):
		touch_active = true
	apply_settings()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not touch_active and int(settings.touch) != 2:
		touch_active = true
		settings_changed.emit()


func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func show_touch_controls() -> bool:
	var mode := int(settings.touch)
	return mode == 1 or (mode == 0 and touch_active)


# ---------------------------------------------------------------- settings
func setting(key: String) -> Variant:
	return settings.get(key)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_game()
	settings_changed.emit()


func apply_settings() -> void:
	var mb := AudioServer.get_bus_index("Music")
	var sb := AudioServer.get_bus_index("SFX")
	if mb >= 0:
		AudioServer.set_bus_volume_db(mb, linear_to_db(maxf(float(settings.music), 0.0001)))
	if sb >= 0:
		AudioServer.set_bus_volume_db(sb, linear_to_db(maxf(float(settings.sfx), 0.0001)))
	if post_mat:
		post_mat.set_shader_parameter("quality", int(settings.quality))


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")


## Safe-area insets (notches, rounded corners) in canvas coordinates: left, top, right, bottom.
func safe_insets(vp: Viewport) -> Vector4:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or safe.size.x <= 0 or not is_mobile():
		return Vector4.ZERO
	var canvas := vp.get_visible_rect().size
	var k := canvas.x / float(win.x)
	return Vector4(safe.position.x * k, safe.position.y * k,
		maxf(0.0, win.x - safe.end.x) * k, maxf(0.0, win.y - safe.end.y) * k)


# ---------------------------------------------------------------- meta / shop
func meta_level(id: String) -> int:
	return int(meta.get(id, 0))


func shop_cost(item: Dictionary) -> int:
	var lvl := meta_level(item.id)
	var costs: Array = item.cost
	if lvl >= costs.size():
		return -1
	return int(costs[lvl])


func buy(item: Dictionary) -> bool:
	var c := shop_cost(item)
	if c < 0 or shards < c:
		return false
	shards -= c
	meta[item.id] = meta_level(item.id) + 1
	save_game()
	return true


func record_result(level_i: int, score: int, cleared: bool) -> void:
	var key := str(level_i)
	var b: Dictionary = best.get(key, {"score": 0, "cleared": false})
	b.score = maxi(int(b.score), score)
	b.cleared = bool(b.cleared) or cleared
	best[key] = b
	if cleared and level_i + 1 >= unlocked and level_i + 1 < DB.LEVELS.size():
		unlocked = level_i + 2
	save_game()


# ---------------------------------------------------------------- save / load
func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"shards": shards, "meta": meta, "unlocked": unlocked, "best": best, "settings": settings}))


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		shards = int(d.get("shards", 0))
		meta = d.get("meta", {})
		unlocked = clampi(int(d.get("unlocked", 1)), 1, DB.LEVELS.size())
		best = d.get("best", {})
		var s: Variant = d.get("settings")
		if s is Dictionary:
			for k: String in s:
				if settings.has(k):
					settings[k] = s[k]


func reset_progress() -> void:
	shards = 0
	meta = {}
	unlocked = 1
	best = {}
	save_game()


# ---------------------------------------------------------------- input
func _setup_input() -> void:
	_add("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add("focus", [KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add("bomb", [KEY_SPACE, KEY_X], [JOY_BUTTON_A, JOY_BUTTON_B])
	_add("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])


func _add(action: String, keys: Array, buttons: Array, axis := -1, axis_dir := 0.0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k: int in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b: int in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)
	if axis >= 0:
		var m := InputEventJoypadMotion.new()
		m.axis = axis
		m.axis_value = axis_dir
		InputMap.action_add_event(action, m)


# ---------------------------------------------------------------- debug flags
func _read_debug() -> void:
	var query := ""
	if OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("window.location.search", true)
		if v is String:
			query = v
	for arg in OS.get_cmdline_user_args():
		query += "&" + arg.trim_prefix("--")
	for part in query.trim_prefix("?").split("&", false):
		var kv := part.split("=")
		debug[kv[0]] = kv[1] if kv.size() > 1 else "1"
