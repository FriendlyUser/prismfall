extends Control
## On-screen touch controls (Android / mobile web):
## floating joystick on the left half, BOMB + FOCUS buttons bottom-right, PAUSE top-right.
## Multitouch: each finger is tracked by its index.

var run
var move := Vector2.ZERO        # analog move vector, length 0..1
var focus := false              # toggled by the FOCUS button
var _bomb_queued := false

var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _btn_fingers := {}          # finger index -> button name
var _t := 0.0
var _pressed_flash := {}        # button -> remaining flash time

const STICK_R := 78.0
const DEADZONE := 0.12


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = Game.show_touch_controls()
	Game.settings_changed.connect(func() -> void: visible = Game.show_touch_controls())


func consume_bomb() -> bool:
	var b := _bomb_queued
	_bomb_queued = false
	return b


func _buttons() -> Dictionary:
	var sz := size
	var ins: Vector4 = Game.safe_insets(get_viewport())
	var right := sz.x - 24.0 - ins.z
	var bottom := sz.y - 24.0 - ins.w
	return {
		"bomb": [Vector2(right - 70.0, bottom - 70.0), 62.0],
		"focus": [Vector2(right - 190.0, bottom - 40.0), 46.0],
		"pause": [Vector2(48.0 + ins.x, 190.0 + ins.y), 28.0],
	}


func _input(event: InputEvent) -> void:
	if not visible or run == null or run.modal != "":
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var p := _to_canvas(e.position)
		if e.pressed:
			var hit := _button_at(p)
			if hit != "":
				_btn_fingers[e.index] = hit
				_press(hit)
			elif p.x < size.x * 0.5 and _stick_finger < 0:
				_stick_finger = e.index
				_stick_origin = p
				_stick_pos = p
			get_viewport().set_input_as_handled()
		else:
			if e.index == _stick_finger:
				_stick_finger = -1
				move = Vector2.ZERO
			_btn_fingers.erase(e.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_finger:
			_stick_pos = _to_canvas(d.position)
			var v := (_stick_pos - _stick_origin) / STICK_R
			if v.length() > 1.0:
				# drag the base along so the stick never "runs out"
				_stick_origin = _stick_pos - v.normalized() * STICK_R
				v = v.normalized()
			move = v if v.length() > DEADZONE else Vector2.ZERO
			get_viewport().set_input_as_handled()


func _to_canvas(p: Vector2) -> Vector2:
	# touch positions arrive in viewport coordinates already when stretch mode is canvas_items
	return get_global_transform_with_canvas().affine_inverse() * p


func _button_at(p: Vector2) -> String:
	var bs := _buttons()
	for k: String in bs:
		var b: Array = bs[k]
		if p.distance_to(b[0]) < float(b[1]) * 1.15:
			return k
	return ""


func _press(name: String) -> void:
	_pressed_flash[name] = 0.18
	match name:
		"bomb":
			_bomb_queued = true
		"focus":
			focus = not focus
			Sfx.play("ui", -8.0)
		"pause":
			run.request_pause()


func _process(dt: float) -> void:
	_t += dt
	for k: String in _pressed_flash.keys():
		_pressed_flash[k] = float(_pressed_flash[k]) - dt
		if _pressed_flash[k] <= 0.0:
			_pressed_flash.erase(k)
	if run != null and run.modal != "":
		_stick_finger = -1
		move = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if run == null or run.modal != "":
		return
	var f: Font = Art.font_ui
	# joystick
	if _stick_finger >= 0:
		draw_circle(_stick_origin, STICK_R, Color(0.05, 0.1, 0.2, 0.35), true, -1.0, true)
		draw_arc(_stick_origin, STICK_R, 0, TAU, 48, Color(0.4, 0.9, 1.0, 0.6), 2.5, true)
		var knob := _stick_origin + move * STICK_R
		draw_circle(knob, 30.0, Color(0.4, 0.9, 1.0, 0.35), true, -1.0, true)
		draw_arc(knob, 30.0, 0, TAU, 32, Color(0.7, 1.0, 1.0, 0.9), 2.0, true)
	else:
		var hint := Vector2(150.0, size.y - 150.0)
		draw_arc(hint, STICK_R * 0.8, 0, TAU, 48, Color(0.4, 0.9, 1.0, 0.18 + 0.08 * sin(_t * 3.0)), 2.0, true)
		draw_string(f, hint + Vector2(-60, 6), "DRAG TO MOVE", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.7, 0.9, 1.0, 0.35))
	# buttons
	var bs := _buttons()
	for k: String in bs:
		var b: Array = bs[k]
		var c: Vector2 = b[0]
		var r: float = b[1]
		var col := Art.GOLD if k == "bomb" else (Art.MAGENTA if k == "focus" else Art.CYAN)
		var on := (k == "focus" and focus) or _pressed_flash.has(k)
		draw_circle(c, r, Color(col.r * 0.25, col.g * 0.25, col.b * 0.3, 0.55 if on else 0.32), true, -1.0, true)
		draw_arc(c, r, 0, TAU, 48, Color(col, 0.95 if on else 0.6), 3.0 if on else 2.0, true)
		match k:
			"bomb":
				var star := Art.xform(Art.shapes["star"], c + Vector2(0, -8), -PI * 0.5, 16.0)
				draw_polyline(Art.closed(star), col, 2.0, true)
				draw_string(f, c + Vector2(-40, 28), "BOMB x%d" % int(run.player.bombs), HORIZONTAL_ALIGNMENT_CENTER, 80, 13, col)
			"focus":
				draw_arc(c, 10.0, 0, TAU, 20, col, 2.0, true)
				draw_circle(c, 3.5, Color(1, 1, 1), true, -1.0, true)
				draw_string(f, c + Vector2(-40, 30), "FOCUS", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, col)
			"pause":
				draw_rect(Rect2(c + Vector2(-8, -10), Vector2(5, 20)), col)
				draw_rect(Rect2(c + Vector2(3, -10), Vector2(5, 20)), col)
