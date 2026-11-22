extends Node2D
## The prism ship: movement, focus mode, shields, bombs and all auto-weapons.

const HIT_R := 4.0
const GRAZE_R := 26.0
const BODY_R := 9.0

var run
var velocity := Vector2.ZERO
var facing := -PI * 0.5
var hp := 4
var max_hp := 4
var bombs := 2
var bomb_meter := 0.0
var invuln := 1.0
var focus := false
var alive := true

var dmg_mult := 1.0
var rate_mult := 1.0
var move_speed := 290.0
var magnet := 100.0
var xp_mult := 1.0
var pierce := 0
var lv := {}

var fire_cd := 0.0
var seeker_cd := 1.0
var nova_cd := 2.0
var orbit_angle := 0.0
var blades: PackedVector2Array = PackedVector2Array()
var trail: PackedVector2Array = PackedVector2Array()
var _trail_t := 0.0
var _exhaust_t := 0.0
var _t := 0.0
var _glow: Node2D


func _ready() -> void:
	_glow = Node2D.new()
	_glow.show_behind_parent = true
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	add_child(_glow)
	_glow.draw.connect(_draw_glow)


func apply_meta() -> void:
	max_hp = 4 + Game.meta_level("hp")
	hp = max_hp
	bombs = 2 + Game.meta_level("bomb")
	dmg_mult = 1.0 + 0.1 * Game.meta_level("dmg")
	move_speed = 290.0 * (1.0 + 0.06 * Game.meta_level("spd"))
	magnet = 100.0 * (1.0 + 0.25 * Game.meta_level("mag"))
	xp_mult = 1.0 + 0.1 * Game.meta_level("xp")


func level_of(id: String) -> int:
	return int(lv.get(id, 0))


func apply_upgrade(id: String) -> void:
	lv[id] = level_of(id) + 1
	match id:
		"power": dmg_mult += 0.25
		"rate": rate_mult += 0.18
		"speed": move_speed *= 1.10
		"magnet": magnet *= 1.5
		"aegis":
			max_hp += 1
			hp = max_hp
		"pierce": pierce += 1
		"nova": nova_cd = 0.5


func step(dt: float) -> void:
	_t += dt
	invuln = maxf(0.0, invuln - dt)
	if not alive:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	focus = Input.is_action_pressed("focus")
	var tc = run.touch
	if tc != null and tc.visible:
		if tc.move.length() > input.length():
			input = tc.move
		focus = focus or tc.focus
	var spd := move_speed * (0.42 if focus else 1.0)
	velocity = velocity.lerp(input * spd, minf(1.0, dt * 20.0))
	position += velocity * dt
	var a: Rect2 = run.ARENA
	position = position.clamp(a.position + Vector2(12, 12), a.end - Vector2(12, 12))
	_trail_t -= dt
	if _trail_t <= 0.0:
		_trail_t = 0.016
		trail.insert(0, position)
		if trail.size() > 18:
			trail.resize(18)
	_exhaust_t -= dt
	if _exhaust_t <= 0.0:
		_exhaust_t = 0.03 if Game.setting("quality") == 0 else 0.016
		var back := -Vector2.from_angle(facing)
		var side := back.orthogonal() * randf_range(-4.0, 4.0)
		run.fx.particle(position + back * 16.0 + side, back * randf_range(90.0, 160.0) + velocity * 0.4,
			Color(0.4, 0.85, 1.0, 0.7).lerp(Color(1.0, 0.35, 0.85, 0.7), randf()), randf_range(4.0, 7.0), randf_range(0.2, 0.35))
	_weapons(dt)
	queue_redraw()
	_glow.queue_redraw()


func _weapons(dt: float) -> void:
	var enemies = run.enemies
	# --- prism bolts (auto-aim + multishot)
	fire_cd -= dt
	if fire_cd <= 0.0:
		var target = enemies.nearest(position, 760.0)
		if target != null:
			fire_cd += 0.15 / rate_mult
			fire_cd = maxf(fire_cd, 0.0)
			facing = (target.pos - position).angle()
			var n := 1 + level_of("split")
			var spread := 0.06 if focus else 0.15
			var dmg := 9.0 * dmg_mult * (1.2 if focus else 1.0)
			for k in n:
				var ang := facing + (k - (n - 1) * 0.5) * spread
				run.shots.spawn(position + Vector2.from_angle(ang) * 16.0, Vector2.from_angle(ang) * 1000.0, dmg, pierce, 0, 0.8)
			run.fx.particle(position + Vector2.from_angle(facing) * 18.0, Vector2.ZERO, Color(0.6, 1.0, 1.0, 0.9), 11.0, 0.07, 2)
			Sfx.play("shot", -17.0, 0.08)
		else:
			fire_cd = 0.05
	# --- seekers
	var sl := level_of("seeker")
	if sl > 0:
		seeker_cd -= dt
		if seeker_cd <= 0.0:
			seeker_cd = 1.1 / rate_mult
			for k in sl:
				var ang := facing + PI + randf_range(-1.2, 1.2)
				run.shots.spawn(position, Vector2.from_angle(ang) * 380.0, 15.0 * dmg_mult, 0, 1, 2.2)
	# --- nova pulse
	var nl := level_of("nova")
	if nl > 0:
		nova_cd -= dt
		if nova_cd <= 0.0:
			nova_cd = maxf(1.4, 3.6 - 0.45 * nl)
			var r := 150.0 + 30.0 * nl
			enemies.damage_radius(position, r, (16.0 + 9.0 * nl) * dmg_mult)
			run.bullets.erase_circle(position, r * 0.75, true)
			run.fx.ring(position, r, Color(0.8, 0.5, 1.0), 0.45, 5.0)
			run.add_wave(position, 0.6)
			Sfx.play("nova", -10.0)
	# --- orbit shards
	var ol := level_of("orbit")
	blades.resize(ol)
	if ol > 0:
		orbit_angle += dt * (3.0 + ol * 0.25)
		var orad := 78.0 + ol * 4.0
		for k in ol:
			var bp := position + Vector2.from_angle(orbit_angle + TAU * k / ol) * orad
			blades[k] = bp
			var e = enemies.hit_circle(bp, 13.0)
			if e != null and e.orbit_cd <= 0.0:
				e.orbit_cd = 0.22
				enemies.damage(e, 11.0 * dmg_mult, (e.pos - position).normalized())
			run.bullets.erase_circle(bp, 14.0)


# ---------------------------------------------------------------- drawing
## Ship outline in local space with banking squash (the hull narrows on the side it rolls towards).
func _ship_pts(scale: float, bank: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := cos(facing)
	var s := sin(facing)
	for p: Vector2 in Art.shapes["ship"]:
		var q := Vector2(p.x, p.y * (1.0 - absf(bank) * 0.35) + bank * 0.12) * scale
		out.append(Vector2(q.x * c - q.y * s, q.x * s + q.y * c))
	return out


func _bank() -> float:
	var side := Vector2.from_angle(facing).orthogonal()
	return clampf(velocity.dot(side) / maxf(move_speed, 1.0), -1.0, 1.0)


func _draw() -> void:
	if not alive:
		return
	var blink := invuln > 0.0 and int(invuln * 16.0) % 2 == 0
	var body_a := 0.35 if blink else 1.0
	# engine ribbon trail
	if trail.size() > 2:
		var local := PackedVector2Array()
		var cols := PackedColorArray()
		for i in trail.size():
			local.append(trail[i] - position)
			var k := 1.0 - float(i) / trail.size()
			cols.append(Color(0.3, 0.9, 1.0, 0.0).lerp(Color(1.0, 0.35, 0.85, 0.0), 1.0 - k) + Color(0, 0, 0, k * 0.75 * body_a))
		draw_polyline_colors(local, cols, 6.0, true)
	# orbit blades
	for bp in blades:
		var lp := bp - position
		var tri := Art.xform(Art.shapes["arrow"], lp, orbit_angle * 2.0, 11.0)
		Art.fan(self, tri, lp, Color(0.6, 1.0, 0.8, 1.0), Color(0.05, 0.3, 0.15, 0.95))
		Art.neon_line(self, tri, Color(0.5, 1.0, 0.7), 1.8)
	# hull with radial shading + banking
	var bank := _bank()
	var c := Art.CYAN
	var ship := _ship_pts(15.0, bank)
	Art.fan(self, ship, Vector2.from_angle(facing) * 2.0, Color(0.25, 0.6, 0.85, body_a), Color(0.02, 0.06, 0.14, 0.95 * body_a))
	Art.neon_line(self, ship, Color(c, body_a), 2.4)
	var wing := _ship_pts(8.0, bank)
	draw_polyline(Art.closed(wing), Color(Art.MAGENTA, 0.95 * body_a), 1.6, true)
	# cockpit gem
	var nose := Vector2.from_angle(facing)
	var gem := Art.xform(Art.shapes["diamond"], nose * 5.0, facing, 4.5)
	Art.fan(self, gem, nose * 5.0, Color(1, 1, 1, body_a), Color(0.4, 0.9, 1.0, body_a))
	# invulnerability shield bubble
	if invuln > 0.0:
		var a := clampf(invuln, 0.0, 1.0) * 0.6
		for k in 6:
			var a0 := _t * 1.5 + TAU * k / 6.0
			draw_arc(Vector2.ZERO, 30.0, a0, a0 + TAU / 6.0 * 0.75, 10, Color(0.5, 0.95, 1.0, a), 2.0, true)
	# hitbox - always visible, emphasised while focusing
	if focus:
		draw_arc(Vector2.ZERO, GRAZE_R, _t * 2.0, _t * 2.0 + TAU * 0.8, 40, Color(1, 1, 1, 0.35), 1.5, true)
		draw_arc(Vector2.ZERO, HIT_R + 4.0, 0, TAU, 20, Color(1.0, 0.25, 0.4), 2.0, true)
	draw_circle(Vector2.ZERO, HIT_R, Color(1, 1, 1), true, -1.0, true)


func _draw_glow() -> void:
	if not alive:
		return
	var tex := Art.atlas
	_glow.draw_texture_rect_region(tex, Rect2(-50, -50, 100, 100), Art.R_ORB_GLOW, Color(0.2, 0.8, 1.0, 0.5))
	_glow.draw_texture_rect_region(tex, Rect2(-110, -110, 220, 220), Art.R_SOFT, Color(0.2, 0.6, 1.0, 0.18))
	var back := -Vector2.from_angle(facing)
	var f := 13.0 + sin(_t * 40.0) * 3.0 + velocity.length() * 0.025
	for k in 2:
		var side := Vector2.from_angle(facing).orthogonal() * (5.0 if k == 0 else -5.0)
		var fp := back * 13.0 + side
		_glow.draw_texture_rect_region(tex, Rect2(fp.x - f, fp.y - f, f * 2, f * 2), Art.R_ORB_GLOW, Color(1.0, 0.4, 0.8, 0.75))
	_glow.draw_set_transform(back * (18.0 + f * 0.6), facing)
	_glow.draw_texture_rect_region(tex, Rect2(-f * 1.6, -f * 0.35, f * 3.2, f * 0.7), Art.R_RICE_GLOW, Color(0.5, 0.8, 1.0, 0.8))
	_glow.draw_set_transform(Vector2.ZERO)
	for bp in blades:
		var lp := bp - position
		_glow.draw_texture_rect_region(tex, Rect2(lp.x - 24, lp.y - 24, 48, 48), Art.R_ORB_GLOW, Color(0.3, 1.0, 0.6, 0.55))
	if focus:
		_glow.draw_texture_rect_region(tex, Rect2(-16, -16, 32, 32), Art.R_SPARKLE, Color(1, 1, 1, 0.9))