extends Control
## Title screen, sector select, armory (meta shop) and help - with an animated neon attract mode.

var bg_mat: ShaderMaterial
var decor: Control
var content: VBoxContainer
var shards_label: Label
var _t := 0.0
var _floaters: Array = []
var _page := "main"
var _k := 0.0   # 0 = title page layout, 1 = compact sub-page layout


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Art.theme
	var L: Dictionary = DB.LEVELS[clampi(Game.unlocked - 1, 0, DB.LEVELS.size() - 1)]
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = load("res://shaders/background.gdshader")
	bg_mat.set_shader_parameter("col_a", L.bg_a)
	bg_mat.set_shader_parameter("col_b", L.bg_b)
	bg_mat.set_shader_parameter("col_c", L.bg_c)
	bg_mat.set_shader_parameter("grid_col", L.grid)
	bg_mat.set_shader_parameter("grid_strength", 0.55)
	bg_mat.set_shader_parameter("arena", Vector4(-100000, -100000, 200000, 200000))
	bg_mat.set_shader_parameter("detail", int(Game.setting("quality")))
	bg_mat.set_shader_parameter("planet", Vector3(400.0, 170.0, 210.0))
	bg_mat.set_shader_parameter("planet_col", L.get("planet_col", Color(0.3, 0.4, 0.9)))
	bg_mat.set_shader_parameter("planet_rim", L.get("planet_rim", Color(0.4, 0.9, 1.0)))
	bg_mat.set_shader_parameter("planet_rings", 1.0)
	bg.material = bg_mat
	add_child(bg)

	decor = Control.new()
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	decor.material = m
	add_child(decor)
	decor.draw.connect(_draw_decor)

	for i in 26:
		var kinds := DB.ENEMIES.keys()
		var k: String = kinds[i % kinds.size()]
		_floaters.append({"kind": k, "p": Vector2(randf() * 1600, randf() * 900), "v": Vector2.from_angle(randf() * TAU) * randf_range(10, 35),
			"rot": randf() * TAU, "spin": randf_range(-1, 1), "s": randf_range(10, 22)})

	shards_label = Art.label("", 20, Art.GOLD)
	shards_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	shards_label.offset_left = -300
	shards_label.offset_right = -24
	shards_label.offset_top = 18
	shards_label.offset_bottom = 50
	shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(shards_label)

	content = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	add_child(content)

	var credit := Art.label("PRISMFALL  |  original Godot 4 bullet-heaven  |  procedural art & audio", 12, Color(0.7, 0.8, 1.0, 0.45))
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	credit.offset_top = -34
	credit.offset_bottom = -10
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(credit)

	Sfx.play_music(0.92, -12.0)
	_show_main()


func _process(dt: float) -> void:
	_t += dt
	bg_mat.set_shader_parameter("cam_pos", Vector2(_t * 22.0, _t * -14.0))
	bg_mat.set_shader_parameter("view_size", size)
	bg_mat.set_shader_parameter("time_s", _t)
	for f: Dictionary in _floaters:
		f.p += f.v * dt
		f.rot += f.spin * dt
		f.p = Vector2(fposmod(f.p.x, size.x + 100), fposmod(f.p.y, size.y + 100))
	shards_label.text = "SHARDS  %d" % Game.shards
	_k = lerpf(_k, 0.0 if _page == "main" else 1.0, minf(1.0, dt * 10.0))
	var cy := maxf(250.0, (size.y - content.size.y) * 0.5 + 90.0) if _page == "main" else maxf(110.0, (size.y - content.size.y) * 0.5 + 20.0)
	content.position = Vector2((size.x - content.size.x) * 0.5, cy)
	decor.queue_redraw()
	if Input.is_action_just_pressed("pause") and _page != "main":
		_show_main()


func on_back() -> void:
	if _page != "main":
		_show_main()
	else:
		Game.main.quit_game()


# ---------------------------------------------------------------- settings
func _show_settings() -> void:
	_page = "settings"
	_clear()
	content.add_child(_title("SETTINGS"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	var q_names := ["LOW", "MEDIUM", "HIGH"]
	var first := _cycle_row(grid, "GRAPHICS", "quality", q_names)
	_slider_row(grid, "MUSIC", "music")
	_slider_row(grid, "SOUND FX", "sfx")
	_cycle_row(grid, "SCREEN SHAKE", "shake", ["OFF", "LOW", "FULL"], [0.0, 0.5, 1.0])
	_cycle_row(grid, "TOUCH CONTROLS", "touch", ["AUTO", "ALWAYS", "NEVER"])
	var note := Art.label("Graphics LOW disables bloom & grain - use it on older phones.", 13, Color(0.8, 0.9, 1.0, 0.6))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)
	var reset := Art.button("RESET PROGRESS", Color(1.0, 0.35, 0.4), 16)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(func() -> void:
		if reset.text == "RESET PROGRESS":
			reset.text = "PRESS AGAIN TO CONFIRM"
		else:
			Game.reset_progress()
			reset.text = "PROGRESS RESET")
	content.add_child(reset)
	content.add_child(_back())
	first.call_deferred("grab_focus")


func _cycle_row(grid: GridContainer, label_text: String, key: String, names: Array, values: Array = []) -> Button:
	grid.add_child(Art.label(label_text, 18, Art.TEXT, Art.font_head))
	var b := Art.button("", Art.CYAN, 18)
	b.custom_minimum_size = Vector2(220, 44)
	var idx_of := func() -> int:
		var cur: Variant = Game.setting(key)
		if values.is_empty():
			return int(cur)
		for i in values.size():
			if is_equal_approx(float(values[i]), float(cur)):
				return i
		return values.size() - 1
	b.text = String(names[idx_of.call()])
	b.pressed.connect(func() -> void:
		var i: int = (idx_of.call() + 1) % names.size()
		Game.set_setting(key, i if values.is_empty() else values[i])
		b.text = String(names[i])
		if key == "quality":
			bg_mat.set_shader_parameter("detail", i))
	grid.add_child(b)
	return b


func _slider_row(grid: GridContainer, label_text: String, key: String) -> void:
	grid.add_child(Art.label(label_text, 18, Art.TEXT, Art.font_head))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(Game.setting(key))
	sl.custom_minimum_size = Vector2(220, 36)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.add_theme_stylebox_override("slider", Art.box(Color(0.05, 0.08, 0.15), Color(Art.CYAN, 0.5), 1, 0, 3))
	sl.add_theme_stylebox_override("grabber_area", Art.box(Color(Art.CYAN, 0.6), Art.CYAN, 1, 6, 3))
	sl.add_theme_stylebox_override("grabber_area_highlight", Art.box(Color(Art.CYAN, 0.9), Color.WHITE, 1, 10, 3))
	sl.value_changed.connect(func(v: float) -> void:
		Game.settings[key] = v
		Game.apply_settings())
	sl.drag_ended.connect(func(_c: bool) -> void:
		Game.set_setting(key, sl.value)
		Sfx.play("pickup", -6.0, 0.0))
	grid.add_child(sl)


func _clear() -> void:
	for c in content.get_children():
		c.queue_free()
	content.size = Vector2.ZERO


# ---------------------------------------------------------------- pages
func _show_main() -> void:
	_page = "main"
	_clear()
	var play := Art.button("LAUNCH", Art.CYAN, 26)
	play.custom_minimum_size = Vector2(340, 58)
	play.pressed.connect(_show_levels)
	content.add_child(play)
	var shop := Art.button("ARMORY", Art.GOLD, 22)
	shop.pressed.connect(_show_shop)
	content.add_child(shop)
	var help := Art.button("HOW TO PLAY", Art.MAGENTA, 22)
	help.pressed.connect(_show_help)
	content.add_child(help)
	var opts := Art.button("SETTINGS", Color(0.6, 0.7, 0.95), 22)
	opts.pressed.connect(_show_settings)
	content.add_child(opts)
	if not OS.has_feature("web"):
		var quit := Art.button("QUIT", Color(1.0, 0.4, 0.5), 18)
		quit.pressed.connect(func() -> void: Game.main.quit_game())
		content.add_child(quit)
	play.call_deferred("grab_focus")


func _show_levels() -> void:
	_page = "levels"
	_clear()
	content.add_child(_title("SELECT SECTOR"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	content.add_child(h)
	var first: Button = null
	for i in DB.LEVELS.size():
		var L: Dictionary = DB.LEVELS[i]
		var locked := i >= Game.unlocked
		var c: Color = L.grid
		var b := Art.button("", c)
		b.custom_minimum_size = Vector2(300, 250)
		b.disabled = locked
		var m := MarginContainer.new()
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, 18)
		b.add_child(m)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 8)
		m.add_child(v)
		v.add_child(Art.label(String(L.sector), 14, Color(c, 0.8)))
		v.add_child(Art.label(String(L.name), 22, c.lightened(0.35) if not locked else Color(0.5, 0.5, 0.6), Art.font_head))
		var d := Art.label("LOCKED\nClear the previous sector to unlock." if locked else String(L.desc), 14, Color(0.85, 0.9, 1.0, 0.85))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(250, 0)
		v.add_child(d)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(spacer)
		var boss: Dictionary = DB.BOSSES[L.boss]
		var bst: Dictionary = Game.best.get(str(i), {})
		var info := "BOSS  %s\nSURVIVE  %d:%02d" % [boss.name, int(L.duration) / 60, int(L.duration) % 60]
		if not bst.is_empty():
			info += "\nBEST  %d%s" % [int(bst.score), "   CLEARED" if bst.cleared else ""]
		v.add_child(Art.label(info, 13, Color(1, 1, 1, 0.65) if not locked else Color(0.5, 0.5, 0.6, 0.6)))
		b.pressed.connect(func() -> void: Game.main.start_run(i))
		h.add_child(b)
		if not locked:
			first = b
	content.add_child(_back())
	if first:
		first.call_deferred("grab_focus")


func _show_shop() -> void:
	_page = "shop"
	_clear()
	content.add_child(_title("ARMORY"))
	var sub := Art.label("Permanent upgrades. Earn shards from every run.", 14, Color(0.8, 0.9, 1.0, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	var first: Button = null
	for item: Dictionary in DB.SHOP:
		var lvl := Game.meta_level(item.id)
		var max_l: int = (item.cost as Array).size()
		var left := VBoxContainer.new()
		left.add_theme_constant_override("separation", 0)
		left.custom_minimum_size = Vector2(300, 0)
		left.add_child(Art.label(String(item.name), 18, Color(0.85, 0.95, 1.0), Art.font_head))
		left.add_child(Art.label(String(item.desc), 13, Color(0.8, 0.85, 1.0, 0.65)))
		grid.add_child(left)
		var pl := HBoxContainer.new()
		pl.add_theme_constant_override("separation", 6)
		pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pl.custom_minimum_size = Vector2(110, 0)
		for k in max_l:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(14, 14)
			pip.add_theme_stylebox_override("panel", Art.box(Art.CYAN if k < lvl else Color(0.05, 0.08, 0.15), Color(Art.CYAN, 0.8), 1, 6 if k < lvl else 0, 3))
			pl.add_child(pip)
		grid.add_child(pl)
		var cost := Game.shop_cost(item)
		var b := Art.button("MAXED" if cost < 0 else "BUY  %d" % cost, Art.GOLD, 16)
		b.custom_minimum_size = Vector2(150, 40)
		b.disabled = cost < 0 or Game.shards < cost
		b.pressed.connect(func() -> void:
			if Game.buy(item):
				Sfx.play("levelup", -8.0, 0.0)
				_show_shop())
		grid.add_child(b)
		if first == null and not b.disabled:
			first = b
	var back := _back()
	content.add_child(back)
	(first if first else back).call_deferred("grab_focus")


func _show_help() -> void:
	_page = "help"
	_clear()
	content.add_child(_title("HOW TO PLAY"))
	var txt := Art.label(
		"Your prism ship fires automatically at the nearest enemy.\n" +
		"Your only job: DODGE. Only the white dot at the ship's centre can be hit.\n\n" +
		"MOVE  WASD / Arrows / Left stick\n" +
		"FOCUS  Shift / RB  - slow precise movement, tighter + stronger shots\n" +
		"BOMB  Space / X / A  - wipes all bullets, damages everything, brief invulnerability\n" +
		"PAUSE  Esc / P / Start\n\n" +
		"GRAZE bullets (pass close without touching) to charge new bombs.\n" +
		"Collect XP gems to level up and draft upgrades.\n" +
		"Survive the sector timer, then destroy the boss to unlock the next sector.",
		16, Color(0.85, 0.93, 1.0))
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(txt)
	var back := _back()
	content.add_child(back)
	back.call_deferred("grab_focus")


func _title(t: String) -> Label:
	var l := Art.label(t, 34, Color(1, 1, 1), Art.font_title)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _back() -> Button:
	var b := Art.button("BACK", Color(0.6, 0.7, 0.9), 18)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(200, 44)
	b.pressed.connect(_show_main)
	return b


# ---------------------------------------------------------------- attract-mode decor
func _draw_decor() -> void:
	var sz := size
	var c := Vector2(sz.x * 0.5, lerpf(150.0, 52.0, _k))
	var tex := Art.atlas
	var centre := Vector2(sz.x * 0.5, sz.y * 0.5 + 40)
	# hyperspace warp intro: star streaks rushing outward, fading over the first 1.6 s
	var warp := clampf(1.0 - _t / 1.6, 0.0, 1.0)
	if warp > 0.0:
		for k in 120:
			var h := fmod(k * 0.6180339 * 7.0, 1.0)
			var a := TAU * fmod(k * 0.6180339, 1.0)
			var d := fmod(h * 900.0 + _t * 1400.0, 900.0)
			var dir := Vector2.from_angle(a)
			var p0 := centre + dir * d
			decor.draw_line(p0, p0 + dir * (40.0 + d * 0.35) * warp, Color(0.7, 0.9, 1.0, warp * clampf(d / 200.0, 0.0, 1.0)), 2.0)
		decor.draw_texture_rect_region(tex, Rect2(centre - Vector2(300, 300), Vector2(600, 600)), Art.R_SOFT, Color(0.6, 0.8, 1.0, warp * 0.8))
	# floating enemy silhouettes
	for f: Dictionary in _floaters:
		var d: Dictionary = DB.ENEMIES[f.kind]
		var col: Color = d.color
		var pts := Art.xform(Art.shapes[d.shape], f.p - Vector2(50, 50), f.rot, f.s)
		decor.draw_polyline(Art.closed(pts), Color(col, 0.35), 1.5, true)
	# bullet flower behind the title (rice bullets aligned to travel)
	for k in 108:
		var arm := k % 6
		var i := k / 6
		var r := fmod(_t * 70.0 + i * 40.0, 720.0)
		var sgn := 1.0 if arm % 2 == 0 else -1.0
		var a := _t * 0.35 + arm * TAU / 6.0 + r * 0.0045 * sgn
		var p := centre + Vector2.from_angle(a) * r
		var col: Color = Art.BULLET_COLORS[[0, 3, 2][arm % 3]]
		var fade := clampf(r / 120.0, 0.0, 1.0) * clampf((720.0 - r) / 200.0, 0.0, 1.0)
		var heading := a + atan(r * 0.0045 * sgn)
		decor.draw_set_transform(p, heading)
		decor.draw_texture_rect_region(tex, Rect2(-26, -13, 52, 26), Art.R_RICE_GLOW, Color(col, 0.85 * fade))
		decor.draw_texture_rect_region(tex, Rect2(-10, -5, 20, 10), Art.R_RICE_CORE, Color(1, 1, 1, 0.95 * fade))
	decor.draw_set_transform(Vector2.ZERO)
	# title with light sweep
	decor.draw_texture_rect_region(tex, Rect2(c - Vector2(460, 130), Vector2(920, 260)), Art.R_ORB_GLOW, Color(0.2, 0.5, 1.0, 0.35))
	decor.draw_texture_rect_region(tex, Rect2(c - Vector2(520, 20) + Vector2(0, 22), Vector2(1040, 40)), Art.R_FLARE, Color(0.5, 0.8, 1.0, 0.45 * (1.0 - _k)))
	var title_size := int(lerpf(92.0 if sz.x > 900 else 60.0, 44.0, _k))
	var wob := sin(_t * 1.3) * 2.0 * (1.0 - _k * 0.6)
	var title := "PRISMFALL"
	var tw := Art.font_title.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var x0 := (sz.x - tw) * 0.5
	var sweep := fmod(_t * 0.45, 1.6) - 0.3        # 0..1 across the word, then a pause
	var x := x0
	for ch_i in title.length():
		var ch := title[ch_i]
		var cw := Art.font_title.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x + 10.0
		var u := (x + cw * 0.5 - x0) / tw
		var shine := clampf(1.0 - absf(u - sweep) * 7.0, 0.0, 1.0)
		var bob := sin(_t * 2.2 + ch_i * 0.6) * 3.0 * (1.0 - _k)
		var base := Vector2(x, c.y + 30 + bob)
		decor.draw_string(Art.font_title, base + Vector2(-6 + wob, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(1.0, 0.2, 0.6, 0.75))
		decor.draw_string(Art.font_title, base + Vector2(6 - wob, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.2, 0.8, 1.0, 0.75))
		decor.draw_string(Art.font_title, base, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.85, 0.95, 1.0).lerp(Color(1, 1, 1), shine))
		if shine > 0.3:
			decor.draw_texture_rect_region(tex, Rect2(base + Vector2(cw * 0.5 - 40, -title_size * 0.4 - 40), Vector2(80, 80)), Art.R_SPARKLE, Color(1, 1, 1, shine))
		x += cw
	var lw := 300.0 + sin(_t * 2.0) * 20.0
	var a2 := 1.0 - _k
	decor.draw_line(Vector2(c.x - lw, c.y + 52), Vector2(c.x + lw, c.y + 52), Color(0.4, 0.9, 1.0, 0.8 * a2), 2.0)
	decor.draw_string(Art.font_ui, Vector2(0, c.y + 82), "N E O N   B U L L E T   H E A V E N", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 18, Color(1.0, 0.5, 0.85, 0.9 * a2))
	# hero ship with engine flame
	if _k > 0.5:
		return
	var sp := Vector2(c.x + sin(_t * 0.8) * 30.0, sz.y - 80 + cos(_t * 1.1) * 8.0)
	decor.draw_texture_rect_region(tex, Rect2(sp - Vector2(45, 45), Vector2(90, 90)), Art.R_ORB_GLOW, Color(0.2, 0.8, 1.0, 0.7))
	var fl := 16.0 + sin(_t * 40.0) * 4.0
	decor.draw_texture_rect_region(tex, Rect2(sp + Vector2(-fl * 0.5, 16), Vector2(fl, fl * 2.4)), Art.R_RICE_GLOW, Color(1.0, 0.4, 0.85, 0.85))
	var ship := Art.xform(Art.shapes["ship"], sp, -PI * 0.5, 18.0)
	Art.fan(decor, ship, sp, Color(0.25, 0.55, 0.8, 0.9), Color(0.02, 0.05, 0.12, 0.9))
	Art.neon_line(decor, ship, Art.CYAN, 2.4)