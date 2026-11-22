extends Node2D
## One sector run: owns the simulation order, spawner, boss flow, camera/juice and run UI.

const ARENA := Rect2(-1400, -1400, 2800, 2800)
const PlayerScript := preload("res://scripts/game/player.gd")
const EnemiesScript := preload("res://scripts/game/enemies.gd")
const BulletsScript := preload("res://scripts/game/bullets.gd")
const ShotsScript := preload("res://scripts/game/shots.gd")
const GemsScript := preload("res://scripts/game/gems.gd")
const FxScript := preload("res://scripts/game/fx.gd")
const ArenaScript := preload("res://scripts/game/arena.gd")
const HudScript := preload("res://scripts/game/hud.gd")
const TouchScript := preload("res://scripts/ui/touch_controls.gd")

var L: Dictionary
var level_i := 0
var time := 0.0
var state := "play"          # play, warn, boss, win, dead, done
var state_t := 0.0
var score := 0
var kills := 0
var grazes := 0
var xp := 0.0
var plevel := 1
var xp_need := 8.0
var pending_levels := 0
var god := false

var banner := ""
var banner_sub := ""
var banner_t := 0.0
var banner_color := Color(0.4, 0.9, 1.0)
var banner_warn := false

var spawn_timers: Array[float] = []
var events_done := {}
var boss_e = null
var waves: Array = []          # background ripples [pos, age, strength]
var trauma := 0.0
var aberr := 0.0
var flash := 0.0
var flash_col := Color.WHITE
var _hitstop := 0.0
var _boom_t := 0.0
var _result_shown := false
var _light_flash := 0.0
var _light_flash_pos := Vector2.ZERO
var _light_flash_col := Color.WHITE
var touch = null

var bg_mat: ShaderMaterial
var world: Node2D
var cam: Camera2D
var player
var enemies
var bullets
var shots
var gems
var fx
var arena_node
var hud
var ui: CanvasLayer
var modal := ""                # "", levelup, pause, results
var modal_root: Control
var _choices: Array = []
var _cards_ready := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level_i = Game.level_index
	L = DB.LEVELS[level_i]
	god = Game.debug.has("god")
	_build_world()
	for w: Dictionary in L.waves:
		spawn_timers.append(1.0)
	if Game.debug.has("t"):
		time = float(Game.debug.t)
	if Game.debug.has("lv"):
		for k in int(Game.debug.lv):
			_auto_upgrade()
	show_banner(String(L.sector), String(L.name), L.grid, 3.0)
	Sfx.play_music(float(L.music_pitch), -10.0)


func _build_world() -> void:
	# background
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = load("res://shaders/background.gdshader")
	bg_mat.set_shader_parameter("col_a", L.bg_a)
	bg_mat.set_shader_parameter("col_b", L.bg_b)
	bg_mat.set_shader_parameter("col_c", L.bg_c)
	bg_mat.set_shader_parameter("grid_col", L.grid)
	bg_mat.set_shader_parameter("arena", Vector4(ARENA.position.x, ARENA.position.y, ARENA.size.x, ARENA.size.y))
	bg_mat.set_shader_parameter("detail", int(Game.setting("quality")))
	if L.has("planet"):
		bg_mat.set_shader_parameter("planet", L.planet)
		bg_mat.set_shader_parameter("planet_col", L.planet_col)
		bg_mat.set_shader_parameter("planet_rim", L.planet_rim)
		bg_mat.set_shader_parameter("planet_rings", float(L.get("rings", 0.0)))
	bg.material = bg_mat
	bg_layer.add_child(bg)
	if Game.debug.has("nobg"):
		bg.visible = false

	world = Node2D.new()
	add_child(world)
	arena_node = ArenaScript.new()
	arena_node.rect = ARENA
	arena_node.color = L.grid
	world.add_child(arena_node)

	fx = FxScript.new()
	gems = GemsScript.new()
	bullets = BulletsScript.new()
	shots = ShotsScript.new()
	enemies = EnemiesScript.new()
	player = PlayerScript.new()

	world.add_child(gems)
	world.add_child(enemies)
	world.add_child(shots)
	world.add_child(player)
	world.add_child(bullets)
	world.add_child(fx)

	bullets.fx = fx
	bullets.gems = gems
	bullets.speed_mult = L.bullet_speed
	bullets.bounds = ARENA.grow(60)
	shots.enemies = enemies
	shots.fx = fx
	enemies.bullets = bullets
	enemies.fx = fx
	enemies.run = self
	enemies.level = L
	enemies.arena = ARENA
	enemies.died.connect(_on_enemy_died)
	player.run = self
	player.apply_meta()
	player.position = Vector2.ZERO

	cam = Camera2D.new()
	world.add_child(cam)
	cam.make_current()

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 50
	add_child(hud_layer)
	hud = HudScript.new()
	hud.run = self
	hud_layer.add_child(hud)
	touch = TouchScript.new()
	touch.run = self
	hud_layer.add_child(touch)

	ui = CanvasLayer.new()
	ui.layer = 60
	add_child(ui)


# ---------------------------------------------------------------- main loop
func _process(raw_dt: float) -> void:
	_update_post(raw_dt)
	if get_tree().paused:
		_modal_input()
		return
	if Input.is_action_just_pressed("pause") and modal == "" and state != "done":
		_open_pause()
		return
	if _hitstop > 0.0:
		_hitstop -= raw_dt
		_update_camera(raw_dt)
		return
	var dt := minf(raw_dt, 1.0 / 30.0) * (0.35 if state == "dead" else 1.0)
	if Game.debug.has("sim"):
		# test-only: several fixed substeps per frame (for throttled playtest browsers)
		for k in int(Game.debug.sim):
			if get_tree().paused or _hitstop > 0.0:
				break
			_tick(1.0 / 60.0, raw_dt)
		return
	_tick(dt, raw_dt)


func _tick(dt: float, raw_dt: float) -> void:
	if Game.debug.has("trace") and Engine.get_process_frames() % 120 == 0:
		print("t=%.1f state=%s enemies=%d bullets=%d lv=%d hp=%d boss=%s fps=%d" % [time, state, enemies.list.size(), bullets.count, plevel, player.hp,
			"-" if boss_e == null else "%d/%d ph%d" % [boss_e.hp, boss_e.max_hp, boss_e.brain.phase], Engine.get_frames_per_second()])
	state_t += dt
	banner_t = maxf(0.0, banner_t - dt)

	if state in ["play", "warn", "boss"]:
		time += dt
	var _p0 := Time.get_ticks_usec()
	player.step(dt)
	var _p1 := Time.get_ticks_usec()
	_spawner(dt)
	_boss_flow(dt)
	enemies.hp_mult = float(L.hp_mult) * (1.0 + clampf(time / float(L.duration), 0.0, 1.2) * 1.4)
	var _p2 := Time.get_ticks_usec()
	enemies.step(dt, player.position)
	var _p3 := Time.get_ticks_usec()
	shots.step(dt)
	var _p4 := Time.get_ticks_usec()

	var can_hit: bool = player.alive and player.invuln <= 0.0 and not god and state != "win"
	var r: Vector2i = bullets.step(dt, player.position, PlayerScript.HIT_R, PlayerScript.GRAZE_R, can_hit)
	if r.y > 0 and player.alive:
		_on_graze(r.y)
	if r.x == 1:
		_player_hit()
	elif can_hit and enemies.contact(player.position, PlayerScript.BODY_R):
		_player_hit()

	var touch_bomb: bool = touch != null and touch.consume_bomb()
	if player.alive and (Input.is_action_just_pressed("bomb") or touch_bomb):
		_use_bomb()

	var got: Vector2i = gems.step(dt, player.position, player.magnet)
	if not player.alive:
		got = Vector2i.ZERO
	if got.x > 0:
		_gain_xp(got.x * player.xp_mult)
		Sfx.play("pickup", -14.0, 0.15, 1.0 + minf(plevel * 0.02, 0.4))
	if got.y > 0:
		score += got.y * 10
	var _p5 := Time.get_ticks_usec()
	fx.step(dt)
	var _p6 := Time.get_ticks_usec()
	_update_camera(dt)
	_update_waves(dt)
	var _p7 := Time.get_ticks_usec()
	if Game.debug.has("prof") and Engine.get_process_frames() % 20 == 0:
		print("prof player=%d spawn=%d enemies=%d shots=%d bullets+gems=%d fx=%d cam=%d frame_dt=%.3f" % [_p1 - _p0, _p2 - _p1, _p3 - _p2, _p4 - _p3, _p5 - _p4, _p6 - _p5, _p7 - _p6, raw_dt])

	if pending_levels > 0 and modal == "" and player.alive and state != "win":
		_open_levelup()


func _update_camera(dt: float) -> void:
	var want_zoom := 0.86 if (state == "boss" or state == "win") else 1.0
	if get_viewport_rect().size.y < 600.0:
		want_zoom *= 0.92   # small/phone screens see a bit more of the arena
	var z := lerpf(cam.zoom.x, want_zoom, minf(1.0, dt * 1.5))
	cam.zoom = Vector2(z, z)
	var half := get_viewport_rect().size * 0.5 / z
	var target: Vector2 = player.position + player.velocity * 0.12
	cam.position = cam.position.lerp(target, minf(1.0, dt * 7.0))
	var lim := ARENA.grow(180)
	cam.position.x = clampf(cam.position.x, lim.position.x + half.x, lim.end.x - half.x)
	cam.position.y = clampf(cam.position.y, lim.position.y + half.y, lim.end.y - half.y)
	trauma = maxf(0.0, trauma - dt * 1.6)
	var sh := trauma * trauma * 22.0 * float(Game.setting("shake"))
	cam.offset = Vector2(randf_range(-sh, sh), randf_range(-sh, sh))
	var view := Rect2(cam.position - half, half * 2.0)
	bullets.view = view
	shots.view = view
	enemies.view = view
	gems.view = view
	fx.view = view
	bg_mat.set_shader_parameter("cam_pos", cam.position + cam.offset)
	bg_mat.set_shader_parameter("view_size", half * 2.0)
	_update_lights(dt)


func _update_lights(dt: float) -> void:
	_light_flash = maxf(0.0, _light_flash - dt * 2.5)
	var ls: Array[Vector4] = []
	var lc: Array[Vector4] = []
	var pc := Color(0.35, 0.85, 1.0)
	ls.append(Vector4(player.position.x, player.position.y, 230.0, 0.55 if player.alive else 0.0))
	lc.append(Vector4(pc.r, pc.g, pc.b, 1.0))
	if boss_e != null and not boss_e.dead:
		var bc: Color = boss_e.color
		ls.append(Vector4(boss_e.pos.x, boss_e.pos.y, 420.0, 0.4 + 0.12 * sin(time * 4.0)))
		lc.append(Vector4(bc.r, bc.g, bc.b, 1.0))
	else:
		ls.append(Vector4.ZERO)
		lc.append(Vector4.ZERO)
	ls.append(Vector4(_light_flash_pos.x, _light_flash_pos.y, 700.0, _light_flash * 1.6))
	lc.append(Vector4(_light_flash_col.r, _light_flash_col.g, _light_flash_col.b, 1.0))
	ls.append(Vector4.ZERO)
	lc.append(Vector4.ZERO)
	bg_mat.set_shader_parameter("lights", ls)
	bg_mat.set_shader_parameter("light_cols", lc)


func light_flash(p: Vector2, c: Color, strength := 1.0) -> void:
	_light_flash = maxf(_light_flash, strength)
	_light_flash_pos = p
	_light_flash_col = c

func _update_waves(dt: float) -> void:
	var arr: Array[Vector4] = []
	for w: Array in waves:
		w[1] += dt
	waves = waves.filter(func(w: Array) -> bool: return w[1] < 1.2)
	for i in 8:
		if i < waves.size():
			var w: Array = waves[i]
			var p: Vector2 = w[0]
			arr.append(Vector4(p.x, p.y, w[1], w[2]))
		else:
			arr.append(Vector4(0, 0, 0, 0))
	bg_mat.set_shader_parameter("waves", arr)
	bg_mat.set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)


func _update_post(dt: float) -> void:
	aberr = maxf(0.0, aberr - dt * 2.5)
	flash = maxf(0.0, flash - dt * 2.2)
	if Game.post_mat:
		Game.post_mat.set_shader_parameter("aberration", 0.0009 + aberr * 0.01)
		Game.post_mat.set_shader_parameter("flash", flash)
		Game.post_mat.set_shader_parameter("flash_col", flash_col)


func add_wave(p: Vector2, strength := 1.0) -> void:
	waves.append([p, 0.0, strength])
	if waves.size() > 8:
		waves.pop_front()


func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func show_banner(text: String, sub: String, color: Color, dur := 2.5, warn := false) -> void:
	banner = text
	banner_sub = sub
	banner_color = color
	banner_t = dur
	banner_warn = warn


# ---------------------------------------------------------------- spawning
func _spawner(dt: float) -> void:
	if state != "play":
		return
	var prog := clampf(time / float(L.duration), 0.0, 1.0)
	var cap := 240
	var waves_data: Array = L.waves
	for i in waves_data.size():
		var w: Dictionary = waves_data[i]
		if time < float(w.from):
			continue
		spawn_timers[i] -= dt
		if spawn_timers[i] > 0.0:
			continue
		spawn_timers[i] = float(w.every) * lerpf(1.0, 0.5, prog)
		if enemies.list.size() >= cap:
			continue
		var n := int(w.count)
		if w.get("cluster", false):
			var c := _spawn_point()
			for k in n:
				enemies.spawn(String(w.kind), c + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
		else:
			for k in n:
				enemies.spawn(String(w.kind), _spawn_point())
	var evs: Array = L.events
	for j in evs.size():
		var ev: Dictionary = evs[j]
		if events_done.has(j) or time < float(ev.t):
			continue
		events_done[j] = true
		var count := int(ev.ring)
		var radius := 520.0
		for k in count:
			var p: Vector2 = player.position + Vector2.from_angle(TAU * k / count) * radius
			p = p.clamp(ARENA.position + Vector2(40, 40), ARENA.end - Vector2(40, 40))
			enemies.spawn(String(ev.kind), p)
		show_banner("ENCIRCLEMENT", "%d %s incoming" % [count, String(DB.ENEMIES[ev.kind].name).to_upper() + "S"], Color(1.0, 0.4, 0.5), 1.6)


func _spawn_point() -> Vector2:
	for attempt in 6:
		var p: Vector2 = player.position + Vector2.from_angle(randf() * TAU) * randf_range(640.0, 780.0)
		if ARENA.grow(-40).has_point(p):
			return p
	var q: Vector2 = player.position + Vector2.from_angle(randf() * TAU) * 700.0
	return q.clamp(ARENA.position + Vector2(40, 40), ARENA.end - Vector2(40, 40))


# ---------------------------------------------------------------- boss flow
func _boss_flow(dt: float) -> void:
	match state:
		"play":
			if time >= float(L.duration):
				state = "warn"
				state_t = 0.0
				var spec: Dictionary = DB.BOSSES[L.boss]
				show_banner("WARNING", "%s  -  %s" % [spec.name, spec.title], Color(1.0, 0.25, 0.3), 3.2, true)
				Sfx.play("warn", -4.0, 0.0)
				flash_col = Color(1.0, 0.1, 0.2)
				flash = 0.25
		"warn":
			if state_t >= 3.0:
				state = "boss"
				state_t = 0.0
				var p: Vector2 = player.position + Vector2(0, -330)
				p = p.clamp(ARENA.position + Vector2(120, 120), ARENA.end - Vector2(120, 120))
				boss_e = enemies.spawn_boss(String(L.boss), p)
				shake(0.6)
				add_wave(p, 2.0)
				Sfx.set_music_pitch(float(L.music_pitch) + 0.08)
		"win":
			_boom_t -= dt
			if state_t < 2.2 and _boom_t <= 0.0 and boss_e != null:
				_boom_t = 0.11
				var bp: Vector2 = boss_e.pos + Vector2(randf_range(-70, 70), randf_range(-70, 70))
				fx.explosion(bp, Art.BULLET_COLORS[randi() % 8], 1.3)
				light_flash(bp, Art.BULLET_COLORS[randi() % 8], 0.8)
				shake(0.2)
				Sfx.play("kill", -6.0, 0.2)
			if state_t >= 3.2 and not _result_shown:
				_finish(true)
		"dead":
			if state_t >= 1.4 and not _result_shown:
				_finish(false)


func on_boss_phase(e, phase: int) -> void:
	var n: int = bullets.clear_all()
	score += n * 5
	fx.explosion(e.pos, e.color, 2.0)
	fx.flare(e.pos, 700.0, Color(1, 1, 1), 0.6)
	light_flash(e.pos, Color(1, 1, 1), 1.2)
	fx.ring(e.pos, 600.0, Color(1, 1, 1), 0.8, 6.0)
	add_wave(e.pos, 2.5)
	shake(0.7)
	flash_col = Color(1, 1, 1)
	flash = 0.35
	aberr = 1.0
	_hitstop = 0.12
	Sfx.play("phase", -4.0, 0.0)
	var phases: int = e.brain.phase_count()
	show_banner("PHASE %d" % (phase + 1), "BREAK!  +%d" % (n * 5) if phase + 1 < phases else "FINAL PHASE", e.color, 1.8)


# ---------------------------------------------------------------- events
func _on_enemy_died(e) -> void:
	kills += 1
	score += int(e.score)
	if e.is_boss:
		state = "win"
		state_t = 0.0
		_boom_t = 0.0
		var n: int = bullets.clear_all()
		score += n * 10
		enemies.clear_non_boss(false)
		fx.explosion(e.pos, e.color, 3.0, enemies.hull(e))
		fx.flare(e.pos, 1400.0, Color(1, 1, 1), 1.0)
		light_flash(e.pos, Color(1, 1, 1), 2.0)
		fx.ring(e.pos, 1200.0, Color(1, 1, 1), 1.2, 10.0)
		add_wave(e.pos, 4.0)
		shake(1.0)
		flash_col = Color(1, 1, 1)
		flash = 0.8
		aberr = 1.5
		_hitstop = 0.25
		gems.vacuum = true
		for k in 40:
			gems.add(e.pos + Vector2(randf_range(-60, 60), randf_range(-60, 60)), 6, 0)
		Sfx.play("boom", 0.0, 0.0)
		show_banner("SECTOR CLEARED", "%s destroyed" % e.brain.spec.name, Art.GOLD, 3.0)
		return
	fx.explosion(e.pos, e.color, 0.8 if e.radius < 18 else 1.2, enemies.hull(e))
	if e.radius >= 18:
		light_flash(e.pos, e.color, 0.5)
	add_wave(e.pos, 0.25 if e.radius < 18 else 0.6)
	gems.add(e.pos, int(e.xp), 0)
	shake(0.05)
	Sfx.play("kill", -15.0, 0.2)


func _on_graze(n: int) -> void:
	grazes += n
	score += n * 20
	var gl: int = player.level_of("graze")
	player.bomb_meter += n * 0.018 * (1.0 + 0.6 * gl)
	if gl > 0:
		_gain_xp(n * 0.4 * gl)
	if player.bomb_meter >= 1.0:
		player.bomb_meter = 0.0
		if player.bombs < 6:
			player.bombs += 1
			fx.text(player.position + Vector2(0, -40), "+BOMB", Art.GOLD, 22, 1.2)
	Sfx.play("graze", -16.0, 0.2)


func _player_hit() -> void:
	player.hp -= 1
	player.invuln = 2.2
	bullets.erase_circle(player.position, 230.0)
	fx.explosion(player.position, Color(1.0, 0.3, 0.4), 1.4)
	light_flash(player.position, Color(1.0, 0.2, 0.3), 1.2)
	fx.ring(player.position, 230.0, Color(1.0, 0.3, 0.4), 0.5, 6.0)
	add_wave(player.position, 1.6)
	shake(0.8)
	aberr = 1.3
	flash_col = Color(1.0, 0.1, 0.2)
	flash = 0.3
	_hitstop = 0.1
	Sfx.play("hurt", -2.0, 0.05)
	if player.hp <= 0:
		player.alive = false
		state = "dead"
		state_t = 0.0
		fx.explosion(player.position, Art.CYAN, 3.0)
		fx.explosion(player.position, Art.MAGENTA, 2.0)
		add_wave(player.position, 3.5)
		shake(1.0)
		Sfx.play("boom", 0.0, 0.0)
		show_banner("SIGNAL LOST", "", Color(1.0, 0.3, 0.4), 3.0)


func _use_bomb() -> void:
	if player.bombs <= 0 or state in ["win", "dead"]:
		return
	player.bombs -= 1
	player.invuln = maxf(player.invuln, 2.2)
	var n: int = bullets.clear_all()
	score += n * 5
	var boss_dmg := -1.0
	if boss_e != null:
		boss_dmg = float(boss_e.max_hp) * 0.025
	enemies.damage_radius(player.position, 750.0, 70.0 * player.dmg_mult, boss_dmg)
	fx.ring(player.position, 900.0, Color(1.0, 0.85, 0.4), 0.9, 12.0)
	fx.ring(player.position, 600.0, Color(0.4, 0.9, 1.0), 0.7, 6.0)
	fx.burst(player.position, 80, Art.GOLD, 900.0, 8.0, 0.9)
	fx.flare(player.position, 900.0, Color(1.0, 0.9, 0.6), 0.6)
	light_flash(player.position, Color(1.0, 0.85, 0.4), 2.0)
	add_wave(player.position, 4.0)
	shake(0.8)
	flash_col = Color(1.0, 0.9, 0.6)
	flash = 0.55
	aberr = 1.0
	Sfx.play("bomb", -1.0, 0.0)


func _gain_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_need:
		xp -= xp_need
		plevel += 1
		xp_need = DB.xp_needed(plevel)
		pending_levels += 1


func shards_preview() -> int:
	return int(kills / 8.0 + time / 5.0 + score / 4000.0)


# ---------------------------------------------------------------- platform hooks
func on_back() -> void:
	# Android back: pause / resume, or leave results to the menu
	if modal == "pause":
		_close_modal()
	elif modal == "" and state != "done":
		_open_pause()
	elif modal == "results":
		Game.main.show_menu()


func on_focus_lost() -> void:
	if modal == "" and state != "done":
		_open_pause()


func request_pause() -> void:
	if modal == "" and state != "done":
		_open_pause()


# ---------------------------------------------------------------- level up
func _roll_choices() -> Array:
	var pool: Array = []
	for u: Dictionary in DB.UPGRADES:
		if player.level_of(u.id) < int(u.max):
			pool.append(u)
	pool.shuffle()
	return pool.slice(0, 3)


func _auto_upgrade() -> void:
	var c := _roll_choices()
	if c.size() > 0:
		player.apply_upgrade(String(c[0].id))


func _open_levelup() -> void:
	_choices = _roll_choices()
	if Game.debug.has("autopick") and not _choices.is_empty():
		player.apply_upgrade(String(_choices[0].id))
		pending_levels -= 1
		return
	if _choices.is_empty():
		pending_levels = 0
		player.hp = mini(player.hp + 1, player.max_hp)
		return
	modal = "levelup"
	get_tree().paused = true
	Sfx.play("levelup", -6.0, 0.0)
	_cards_ready = 0.45
	modal_root = _overlay(0.55)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 26)
	modal_root.add_child(v)
	var title := Art.label("LEVEL UP", 52, Color(0.5, 1.0, 0.75), Art.font_title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Art.label("CHOOSE AN UPGRADE   [1] [2] [3]", 16, Color(0.8, 0.9, 1.0, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 24)
	v.add_child(h)
	var first: Button = null
	for i in _choices.size():
		var u: Dictionary = _choices[i]
		var card := _upgrade_card(u, i)
		h.add_child(card)
		if first == null:
			first = card
	_center(v)
	first.grab_focus()


func _upgrade_card(u: Dictionary, i: int) -> Button:
	var c: Color = u.color
	var b := Art.button("", c)
	b.custom_minimum_size = Vector2(270, 300)
	b.disabled = true
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 20)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	var key := Art.label("[%d]" % (i + 1), 14, Color(c, 0.7))
	v.add_child(key)
	var icon := _UpgradeIcon.new()
	icon.color = c
	icon.id = String(u.id)
	icon.custom_minimum_size = Vector2(0, 80)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)
	var name_l := Art.label(String(u.name), 22, c.lightened(0.3), Art.font_head)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var cur: int = player.level_of(u.id)
	var lvl := Art.label("NEW" if cur == 0 else "LV %d  >  %d" % [cur, cur + 1], 14, Color(1, 1, 1, 0.7))
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lvl)
	var d := Art.label(String(u.desc), 16, Color(0.85, 0.92, 1.0))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size = Vector2(220, 0)
	v.add_child(d)
	b.pressed.connect(_choose.bind(i))
	return b


func _choose(i: int) -> void:
	if modal != "levelup" or _cards_ready > 0.0 or i >= _choices.size():
		return
	var u: Dictionary = _choices[i]
	player.apply_upgrade(String(u.id))
	pending_levels -= 1
	fx.ring(player.position, 160.0, u.color, 0.5, 5.0)
	_close_modal()
	if pending_levels > 0:
		_open_levelup()


# ---------------------------------------------------------------- pause / results
func _open_pause() -> void:
	modal = "pause"
	get_tree().paused = true
	modal_root = _overlay(0.6)
	var v := _menu_box("PAUSED", Art.CYAN)
	var b1 := Art.button("RESUME")
	b1.pressed.connect(_close_modal)
	v.add_child(b1)
	var b2 := Art.button("RESTART SECTOR")
	b2.pressed.connect(func() -> void: Game.main.start_run(level_i))
	v.add_child(b2)
	var b3 := Art.button("ABANDON TO MENU", Color(1.0, 0.4, 0.5))
	b3.pressed.connect(func() -> void: Game.main.show_menu())
	v.add_child(b3)
	_center(v)
	b1.grab_focus()


func _finish(victory: bool) -> void:
	_result_shown = true
	state = "done"
	var earned := shards_preview() + (150 * (level_i + 1) if victory else 0)
	Game.shards += earned
	Game.record_result(level_i, score, victory)
	modal = "results"
	modal_root = _overlay(0.55)
	var v := _menu_box("SECTOR CLEARED" if victory else "SIGNAL LOST", Art.GOLD if victory else Color(1.0, 0.35, 0.45))
	var lines := [
		["SCORE", "%d" % score],
		["TIME", "%d:%02d" % [int(time) / 60, int(time) % 60]],
		["KILLS", "%d" % kills],
		["GRAZES", "%d" % grazes],
		["LEVEL", "%d" % plevel],
		["SHARDS EARNED", "+%d" % earned],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 6)
	for ln: Array in lines:
		grid.add_child(Art.label(String(ln[0]), 18, Color(0.7, 0.85, 1.0, 0.8)))
		var val := Art.label(String(ln[1]), 18, Art.GOLD if String(ln[0]).begins_with("SHARDS") else Color(1, 1, 1))
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
	v.add_child(grid)
	var first: Button = null
	if victory and level_i + 1 < DB.LEVELS.size():
		var nb := Art.button("NEXT SECTOR  >", Art.GOLD)
		nb.pressed.connect(func() -> void: Game.main.start_run(level_i + 1))
		v.add_child(nb)
		first = nb
	elif victory:
		var fin := Art.label("ALL SECTORS CLEARED - THE SIGNAL IS FREE", 16, Art.GOLD)
		fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(fin)
	var rb := Art.button("RETRY SECTOR")
	rb.pressed.connect(func() -> void: Game.main.start_run(level_i))
	v.add_child(rb)
	var mb := Art.button("ARMORY / MENU", Color(0.8, 0.5, 1.0))
	mb.pressed.connect(func() -> void: Game.main.show_menu())
	v.add_child(mb)
	if first == null:
		first = rb
	_center(v)
	first.grab_focus()


func _menu_box(title: String, color: Color) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(380, 0)
	modal_root.add_child(v)
	var t := Art.label(title, 48, color, Art.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	v.add_child(spacer)
	return v


func _overlay(alpha: float) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.theme = Art.theme
	ui.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.03, alpha)
	root.add_child(dim)
	return root


func _center(c: Control) -> void:
	# centre a container once its size is known
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.reset_size()
	c.position = (get_viewport_rect().size - c.get_combined_minimum_size()) * 0.5
	c.resized.connect(func() -> void:
		if is_instance_valid(c):
			c.position = (get_viewport_rect().size - c.size) * 0.5)


func _close_modal() -> void:
	if modal_root:
		modal_root.queue_free()
		modal_root = null
	modal = ""
	get_tree().paused = false


func _modal_input() -> void:
	if modal == "levelup":
		if _cards_ready > 0.0:
			_cards_ready -= get_process_delta_time()
			if _cards_ready <= 0.0:
				_set_cards_enabled()
			return
		for i in 3:
			if Input.is_physical_key_pressed(KEY_1 + i):
				_choose(i)
				return
	elif modal == "pause":
		if Input.is_action_just_pressed("pause"):
			_close_modal()


func _set_cards_enabled() -> void:
	if modal_root == null:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	for b in modal_root.find_children("*", "Button", true, false):
		(b as Button).disabled = false
	if focus_owner == null:
		var bs := modal_root.find_children("*", "Button", true, false)
		if bs.size() > 0:
			(bs[0] as Button).grab_focus()


## Small procedural icon for each upgrade card.
class _UpgradeIcon extends Control:
	var color := Color.WHITE
	var id := ""
	var t := 0.0

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		draw_texture_rect(Art.glow, Rect2(c - Vector2(50, 50), Vector2(100, 100)), false, Color(color, 0.45))
		match id:
			"split":
				for k in 3:
					var a := -PI * 0.5 + (k - 1) * 0.35
					draw_line(c + Vector2.from_angle(a) * 8, c + Vector2.from_angle(a) * 34, color, 3.0, true)
			"orbit":
				draw_arc(c, 26, 0, TAU, 32, Color(color, 0.5), 1.5, true)
				for k in 3:
					var p := c + Vector2.from_angle(t * 3.0 + TAU * k / 3.0) * 26
					draw_circle(p, 5, color, true, -1.0, true)
			"nova":
				var r := fmod(t * 30.0, 34.0)
				draw_arc(c, r, 0, TAU, 32, Color(color, 1.0 - r / 34.0), 3.0, true)
				draw_arc(c, 10, 0, TAU, 24, color, 2.0, true)
			"seeker":
				for k in 3:
					var p := c + Vector2(sin(t * 2.0 + k * 2.0) * 22, -20 + k * 18)
					draw_line(p, p + Vector2(12, -6), color, 3.0, true)
			_:
				var pts := Art.xform(Art.shapes["star"] if id in ["power", "rate"] else Art.shapes["hex"], c, t, 28)
				draw_polyline(Art.closed(pts), color, 2.5, true)
				draw_circle(c, 6, Color(1, 1, 1), true, -1.0, true)
