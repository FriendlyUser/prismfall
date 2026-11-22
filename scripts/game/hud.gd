extends Control
## In-run HUD: XP bar, shields, bombs, timer/boss bar, score and banners - all custom drawn.

var run
var _t := 0.0
var _boss_trail := 1.0      # delayed white "damage taken" bar
var _xp_shown := 0.0
var _hp_last := -1
var _hp_shake := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(dt: float) -> void:
	_t += dt
	if run and run.player:
		if _hp_last >= 0 and run.player.hp < _hp_last:
			_hp_shake = 0.5
		_hp_last = run.player.hp
	_hp_shake = maxf(0.0, _hp_shake - dt)
	queue_redraw()


## Angled glass panel behind HUD clusters.
func _panel(r: Rect2, accent: Color) -> void:
	var cut := 10.0
	var pts := PackedVector2Array([r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y - cut),
		Vector2(r.end.x - cut, r.end.y), Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y + cut)])
	draw_colored_polygon(pts, Color(0.01, 0.02, 0.06, 0.55))
	draw_polyline(Art.closed(pts), Color(accent, 0.35), 1.2, true)
	draw_line(r.position + Vector2(cut, 0), r.position + Vector2(cut + 40, 0), Color(accent, 0.9), 2.0)


func _draw() -> void:
	if run == null or run.player == null:
		return
	var sz := size
	var p = run.player
	var f: Font = Art.font_ui
	var ft: Font = Art.font_title
	var accent: Color = run.L.grid
	var ins: Vector4 = Game.safe_insets(get_viewport())
	var lx := 18.0 + ins.x
	var ty := ins.y
	var tex := Art.atlas

	# ---- XP bar (top, full width) with glowing head
	var need: float = run.xp_need
	var frac := clampf(run.xp / need, 0.0, 1.0)
	_xp_shown = lerpf(_xp_shown, frac, 0.2) if frac >= _xp_shown else frac
	draw_rect(Rect2(0, ty, sz.x, 8), Color(0.0, 0.02, 0.06, 0.85))
	var fill_w := sz.x * _xp_shown
	draw_rect(Rect2(0, ty, fill_w, 8), Color(0.2, 0.9, 0.6))
	draw_rect(Rect2(0, ty, fill_w, 3), Color(0.8, 1.0, 0.9, 0.85))
	for k in 12:
		var x := fmod(_t * 120.0 + k * 97.0, maxf(fill_w, 1.0))
		draw_rect(Rect2(x, ty + 1, 10, 6), Color(1, 1, 1, 0.18))
	draw_texture_rect_region(tex, Rect2(fill_w - 40, ty - 36, 80, 80), Art.R_ORB_GLOW, Color(0.4, 1.0, 0.7, 0.9))

	# ---- left cluster: level, shields, bombs, graze
	_panel(Rect2(lx - 8, ty + 16, maxf(220.0, p.max_hp * 30 + 90), 132), Color(0.4, 1.0, 0.75))
	Art.neon_text(self, ft, Vector2(lx, ty + 44), "LV %d" % run.plevel, 24, Color(0.5, 1.0, 0.75), -1, HORIZONTAL_ALIGNMENT_LEFT, 1.5)
	var shake := Vector2(randf_range(-3, 3), randf_range(-2, 2)) * _hp_shake * 2.0
	for i in p.max_hp:
		var c := Vector2(lx + 12 + i * 30, ty + 72) + shake
		var hex := Art.xform(Art.shapes["hex"], c, PI / 6.0, 11.0)
		if i < p.hp:
			var pulse := 0.85 + 0.15 * sin(_t * 4.0 + i)
			Art.fan(self, hex, c, Color(0.6, 1.0, 1.0, 0.75 * pulse), Color(0.05, 0.35, 0.55, 0.6))
			draw_polyline(Art.closed(hex), Color(0.6, 1.0, 1.0), 2.0, true)
			draw_circle(c, 3.0, Color(1, 1, 1), true, -1.0, true)
		else:
			draw_polyline(Art.closed(hex), Color(0.5, 0.2, 0.3, 0.8), 1.5, true)
	draw_string(f, Vector2(lx + 6 + p.max_hp * 30 + 6, ty + 78), "SHIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.85, 1.0, 0.7))
	for i in p.bombs:
		var c := Vector2(lx + 12 + i * 28, ty + 104)
		var star := Art.xform(Art.shapes["star"], c, -PI * 0.5, 11.0)
		Art.fan(self, star, c, Color(1.0, 0.9, 0.5, 0.8), Color(0.6, 0.3, 0.05, 0.6))
		draw_polyline(Art.closed(star), Art.GOLD, 2.0, true)
	var mx := lx + maxi(p.bombs, 1) * 28 + 10
	draw_string(f, Vector2(mx, ty + 110), "BOMB", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.5, 0.7))
	draw_rect(Rect2(lx, ty + 122, 140, 5), Color(0.1, 0.06, 0.02, 0.8))
	draw_rect(Rect2(lx, ty + 122, 140 * p.bomb_meter, 5), Art.GOLD)
	if p.bomb_meter > 0.0:
		draw_texture_rect_region(tex, Rect2(lx + 140 * p.bomb_meter - 12, ty + 112, 24, 24), Art.R_SPARKLE, Color(1, 0.9, 0.5, 0.9))
	draw_string(f, Vector2(lx, ty + 142), "GRAZE %d" % run.grazes, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.5, 0.75))

	# ---- top centre: boss bar or timer
	var cx := sz.x * 0.5
	if run.boss_e != null and not run.boss_e.dead and run.boss_e.spawn <= 0.0:
		var b = run.boss_e
		var spec: Dictionary = b.brain.spec
		var bw := minf(640.0, sz.x - 520.0)
		var bx := cx - bw * 0.5
		var hpf: float = clampf(b.hp / b.max_hp, 0.0, 1.0)
		_boss_trail = maxf(hpf, _boss_trail - get_process_delta_time() * 0.25) if _boss_trail > hpf else hpf
		var bc: Color = spec.color
		_panel(Rect2(bx - 16, ty + 14, bw + 32, 82), bc)
		Art.neon_text(self, ft, Vector2(bx, ty + 40), String(spec.name), 22, bc.lightened(0.3), bw, HORIZONTAL_ALIGNMENT_CENTER, 2.0)
		draw_rect(Rect2(bx - 2, ty + 50, bw + 4, 16), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(bx, ty + 52, bw * _boss_trail, 12), Color(1, 1, 1, 0.85))
		draw_rect(Rect2(bx, ty + 52, bw * hpf, 12), bc)
		draw_rect(Rect2(bx, ty + 52, bw * hpf, 4), Color(1, 1, 1, 0.55))
		draw_texture_rect_region(tex, Rect2(bx + bw * hpf - 30, ty + 28, 60, 60), Art.R_ORB_GLOW, Color(bc, 0.9))
		for ph: Dictionary in spec.phases:
			var at: float = ph.at
			if at < 1.0:
				draw_line(Vector2(bx + bw * at, ty + 46), Vector2(bx + bw * at, ty + 70), Color(1, 1, 1, 0.9), 2.0)
		draw_rect(Rect2(bx - 2, ty + 50, bw + 4, 16), Color(bc, 0.8), false, 1.5)
		var phases: int = b.brain.phase_count()
		draw_string(f, Vector2(bx, ty + 86), "PHASE %d / %d     %s" % [b.brain.phase + 1, phases, String(spec.title).to_upper()],
			HORIZONTAL_ALIGNMENT_CENTER, bw, 12, Color(1, 1, 1, 0.7))
	else:
		var remain := maxf(0.0, float(run.L.duration) - run.time)
		var urgent: bool = remain < 10.0 and run.state == "play"
		var tcol := Color(1, 0.4, 0.45) if urgent and int(_t * 4.0) % 2 == 0 else Color(1, 1, 1)
		_panel(Rect2(cx - 160, ty + 14, 320, 78), accent)
		var tstr := "%02d:%02d" % [int(remain) / 60, int(remain) % 60]
		Art.neon_text(self, ft, Vector2(cx - 150, ty + 50), tstr, 34, tcol, 300, HORIZONTAL_ALIGNMENT_CENTER, 2.0)
		draw_string(f, Vector2(cx - 200, ty + 70), "%s  |  %s" % [run.L.sector, run.L.name], HORIZONTAL_ALIGNMENT_CENTER, 400, 13, Color(accent, 0.9))
		var pw := 260.0
		var prog := clampf(run.time / float(run.L.duration), 0.0, 1.0)
		draw_rect(Rect2(cx - pw * 0.5, ty + 80, pw, 3), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(cx - pw * 0.5, ty + 80, pw * prog, 3), accent)
		var skull := Vector2(cx + pw * 0.5 + 10, ty + 81)
		draw_colored_polygon(Art.xform(Art.shapes["star"], skull, _t, 6.0), Color(1.0, 0.3, 0.4, 0.6 + 0.4 * sin(_t * 6.0)))

	# ---- score (right)
	var rx := sz.x - 24 - ins.z
	_panel(Rect2(rx - 250, ty + 14, 262, 62), Color(1, 1, 1))
	Art.neon_text(self, ft, Vector2(rx - 300, ty + 46), "%08d" % run.score, 26, Color(1, 1, 1), 300, HORIZONTAL_ALIGNMENT_RIGHT, 1.5)
	draw_string(f, Vector2(rx - 300, ty + 66), "KILLS %d   SHARDS +%d" % [run.kills, run.shards_preview()], HORIZONTAL_ALIGNMENT_RIGHT, 300, 13, Color(0.8, 0.9, 1.0, 0.75))
	var y := ty + 96.0
	for u: Dictionary in DB.UPGRADES:
		var l: int = p.level_of(u.id)
		if l <= 0:
			continue
		var uc: Color = u.color
		draw_string(f, Vector2(rx - 300, y), String(u.name), HORIZONTAL_ALIGNMENT_RIGHT, 256, 11, Color(uc, 0.8))
		for k in l:
			draw_rect(Rect2(rx - 38 + k * 7, y - 8, 5, 8), Color(uc, 0.9))
		y += 15

	# ---- controls hint
	if run.time < 10.0 and run.state == "play" and not Game.show_touch_controls():
		var a := clampf(10.0 - run.time, 0.0, 1.0)
		draw_string(f, Vector2(0, sz.y - 26 - ins.w), "WASD / ARROWS move     SHIFT focus (precise + hitbox)     SPACE bomb     ESC pause",
			HORIZONTAL_ALIGNMENT_CENTER, sz.x, 15, Color(0.8, 0.95, 1.0, 0.8 * a))

	if Game.debug.has("fps"):
		draw_string(f, Vector2(18, sz.y - 50), "FPS %d  bullets %d  enemies %d" % [Engine.get_frames_per_second(), run.bullets.count, run.enemies.list.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 0))

	# ---- banner
	if run.banner_t > 0.0:
		var a := clampf(run.banner_t, 0.0, 1.0)
		var by := sz.y * 0.34
		var bh := 110.0
		var bar_c: Color = run.banner_color
		var open := clampf((3.5 - run.banner_t) * 6.0, 0.0, 1.0) if run.banner_t > 2.0 else 1.0
		draw_rect(Rect2(0, by - bh * 0.5 * open, sz.x, bh * open), Color(0, 0, 0, 0.5 * a))
		draw_rect(Rect2(0, by - bh * 0.5 * open, sz.x, 2), Color(bar_c, a))
		draw_rect(Rect2(0, by + bh * 0.5 * open - 2, sz.x, 2), Color(bar_c, a))
		draw_texture_rect_region(tex, Rect2(cx - 500, by - 30, 1000, 60), Art.R_FLARE, Color(bar_c, 0.35 * a))
		if run.banner_warn:
			for k in 14:
				var sx := fmod(k * 120.0 + _t * 200.0, sz.x + 120.0) - 60.0
				draw_colored_polygon(PackedVector2Array([Vector2(sx, by - bh * 0.5), Vector2(sx + 30, by - bh * 0.5), Vector2(sx + 10, by - bh * 0.5 + 10), Vector2(sx - 20, by - bh * 0.5 + 10)]), Color(bar_c, 0.5 * a))
		var shake2 := Vector2(randf_range(-2, 2), 0) if run.banner_warn else Vector2.ZERO
		Art.neon_text(self, ft, Vector2(0, by + 10) + shake2, run.banner, 46, Color(bar_c.lightened(0.4), a), sz.x, HORIZONTAL_ALIGNMENT_CENTER, 3.0)
		draw_string(f, Vector2(0, by + 40), run.banner_sub, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 16, Color(1, 1, 1, 0.85 * a))
