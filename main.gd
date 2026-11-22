extends Node
## Root: owns the global post-process + fade layers, swaps between menu and sector runs,
## and handles platform events (Android back button, app focus loss).

const MenuScript := preload("res://scripts/ui/menu.gd")
const RunScript := preload("res://scripts/game/run.gd")

var current: Node
var _fade: ColorRect
var _fade_tween: Tween
var _fps_label: Label
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.main = self
	get_tree().set_auto_accept_quit(true)
	var post_layer := CanvasLayer.new()
	post_layer.layer = 100
	add_child(post_layer)
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/post.gdshader")
	r.material = m
	post_layer.add_child(r)
	Game.post_mat = m
	Game.apply_settings()
	if Game.debug.has("nopost"):
		post_layer.visible = false
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 110
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.0, 0.0, 0.02, 1.0)
	fade_layer.add_child(_fade)
	if Game.debug.has("fps"):
		_fps_label = Label.new()
		_fps_label.position = Vector2(10, 690)
		fade_layer.add_child(_fps_label)
	if Game.debug.has("level"):
		_swap_now(RunScript.new(), clampi(int(Game.debug.level) - 1, 0, DB.LEVELS.size() - 1))
	else:
		_swap_now(MenuScript.new(), -1)
	_fade_out()


func _process(dt: float) -> void:
	_t += dt
	if Game.post_mat:
		Game.post_mat.set_shader_parameter("time_s", _t)
	if _fps_label:
		_fps_label.text = "FPS %d  frame %.1f ms  draw calls %d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button / gesture: pause in-game, step back in menus.
			if current and current.has_method("on_back"):
				current.on_back()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if current and current.has_method("on_focus_lost"):
				current.on_focus_lost()


func show_menu() -> void:
	_transition(func() -> void: _swap_now(MenuScript.new(), -1))


func start_run(i: int) -> void:
	_transition(func() -> void: _swap_now(RunScript.new(), i))


func quit_game() -> void:
	get_tree().quit()


func _transition(swap: Callable) -> void:
	if _fade_tween and _fade_tween.is_running():
		return
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 1.0, 0.22)
	_fade_tween.tween_callback(swap)
	_fade_tween.tween_callback(_fade_out)


func _fade_out() -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.35)


func _swap_now(n: Node, level_i: int) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if level_i >= 0:
		Game.level_index = level_i
	if current:
		current.queue_free()
	current = n
	add_child(n)
	move_child(n, 0)
