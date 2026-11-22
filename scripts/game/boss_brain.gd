extends RefCounted
## Boss controller: data-driven phases of bullet patterns (DB.BOSSES), movement and drawing.

var spec: Dictionary
var e        # Enemy
var mgr      # enemies manager
var phase := 0
var phase_t := 0.0
var invuln := 0.0
var timers: Array[float] = []
var angles: Array[float] = []
var fired: Array[int] = []
var move_t := 0.0
var anchor_angle := -PI * 0.5
var muzzle := 0.0


func _init(s: Dictionary, enemy, manager) -> void:
	spec = s
	e = enemy
	mgr = manager
	_enter_phase(0)


func phase_count() -> int:
	return (spec.phases as Array).size()


func _enter_phase(i: int) -> void:
	phase = i
	phase_t = 0.0
	timers.clear()
	angles.clear()
	fired.clear()
	for p: Dictionary in spec.phases[i].patterns:
		timers.append(float(p.get("delay", 0.6)))
		angles.append(randf() * TAU)
		fired.append(0)


func step(dt: float, ppos: Vector2) -> void:
	invuln = maxf(0.0, invuln - dt)
	muzzle = maxf(0.0, muzzle - dt)
	phase_t += dt
	move_t += dt
	# phase break
	var frac: float = e.hp / e.max_hp
	if phase + 1 < phase_count() and frac <= float(spec.phases[phase + 1].at):
		_enter_phase(phase + 1)
		invuln = 2.0
		mgr.run.on_boss_phase(e, phase)
		return
	# movement: hover on a slowly drifting anchor around the player
	anchor_angle += dt * 0.22
	var target: Vector2 = ppos + Vector2.from_angle(anchor_angle) * Vector2(330, 260)
	var want: Vector2 = (target - e.pos) * 1.1
	e.vel = e.vel.lerp(want.limit_length(150.0 + phase * 20.0), minf(1.0, dt * 2.0))
	e.rot += dt * float(spec.spin) * (1.0 + phase * 0.35)
	if invuln > 0.0:
		return
	var pats: Array = spec.phases[phase].patterns
	for i in pats.size():
		_run(i, pats[i], dt, ppos)


func _run(i: int, p: Dictionary, dt: float, ppos: Vector2) -> void:
	angles[i] += float(p.get("spin", 0.0)) * dt
	if p.has("cycle"):
		var cyc: Array = p.cycle
		if fmod(phase_t, float(cyc[0]) + float(cyc[1])) > float(cyc[0]):
			return
	timers[i] -= dt
	if timers[i] > 0.0:
		return
	timers[i] = maxf(timers[i] + float(p.every), 0.0)
	fired[i] += 1
	var B = mgr.bullets
	var origin: Vector2 = e.pos
	var aim: float = (ppos - origin).angle()
	var size: float = p.get("size", 7.0)
	var c: int = p.get("color", 0)
	var speed: float = p.get("speed", 150.0)
	var accel: float = p.get("accel", 0.0)
	var curve: float = p.get("curve", 0.0)
	# default bullet shapes per pattern type: 0 orb, 1 rice, 2 star
	var defaults := {"spiral": 1, "ring": 0, "flower": 0, "fan": 1, "stream": 1, "rain": 2, "layers": 0}
	var shape: int = p.get("shape", defaults.get(String(p.type), 0))
	match String(p.type):
		"spiral":
			var arms: int = p.arms
			for k in arms:
				B.spawn(origin, angles[i] + TAU * k / arms, speed, size, c, accel, curve, shape)
		"ring":
			var sign := -1.0 if p.get("alt", false) and fired[i] % 2 == 0 else 1.0
			B.ring(origin, int(p.n), speed, randf() * TAU, size, c, accel, curve * sign, shape)
		"flower":
			var off := randf() * TAU
			B.ring(origin, int(p.n), speed, off, size, c, accel, curve, shape)
			B.ring(origin, int(p.n), speed, off + PI / float(p.n), size, (c + 3) % 8, accel, -curve, shape)
		"fan":
			B.fan(origin, aim, int(p.n), float(p.spread), speed, size, c, accel, shape)
		"stream":
			var j: float = p.get("jitter", 0.05)
			B.spawn(origin, aim + randf_range(-j, j), speed, size, c, accel, 0.0, shape)
		"rain":
			for k in int(p.n):
				B.spawn(origin, randf() * TAU, speed * randf_range(0.55, 1.3), size, c, accel, 0.0, shape)
		"layers":
			var off2 := randf() * TAU
			for l in int(p.layers):
				B.ring(origin, int(p.n), speed + l * float(p.step), off2 + l * 0.08, size, (c + l * 2) % 8, 0.0, 0.0, shape)
		"summon":
			for k in int(p.n):
				var sp: Vector2 = origin + Vector2.from_angle(TAU * k / float(p.n)) * (e.radius + 50.0)
				mgr.spawn(String(p.kind), sp)
	muzzle = 0.12
	if String(p.type) != "stream" or fired[i] % 4 == 0:
		Sfx.play("eshot", -14.0, 0.1)


func draw(ci: CanvasItem) -> void:
	var frac: float = clampf(e.hp / e.max_hp, 0.0, 1.0)
	var c: Color = (spec.color as Color).lerp(Color(1.0, 0.25, 0.3), (1.0 - frac) * 0.45)
	var c2: Color = spec.color2
	var r: float = e.radius
	var pos: Vector2 = e.pos
	var t: float = e.t
	var pts: int = spec.points
	if e.spawn > 0.0:
		var k: float = e.spawn / 1.6
		for j in 3:
			ci.draw_arc(pos, r * (0.5 + k * 4.0 + j * 0.4), 0, TAU, 64, Color(c, (1.0 - k) * 0.7), 3.0, true)
		var star_in := _star_pts(pos, r * (1.0 - k), pts, e.rot + k * 6.0)
		ci.draw_polyline(Art.closed(star_in), Color(c, 1.0 - k), 2.0, true)
		return
	var fl: bool = e.flash > 0.0
	var empty := PackedVector2Array()
	# god rays
	var rays := 10
	for k in rays:
		var a: float = t * 0.25 + TAU * k / rays
		var rl: float = r * (3.2 + 0.8 * sin(t * 1.7 + k * 1.3))
		var w: float = 0.09
		ci.draw_primitive(PackedVector2Array([pos, pos + Vector2.from_angle(a - w) * rl, pos + Vector2.from_angle(a + w) * rl]),
			PackedColorArray([Color(c, 0.22), Color(c, 0.0), Color(c, 0.0)]), empty)
	# outer ticked ring + dashed ring
	ci.draw_arc(pos, r * 2.05, 0, TAU, 96, Color(c, 0.25), 1.5, true)
	for k in 36:
		var a: float = e.rot * 0.3 + TAU * k / 36.0
		var l: float = 6.0 if k % 3 == 0 else 3.0
		ci.draw_line(pos + Vector2.from_angle(a) * r * 2.05, pos + Vector2.from_angle(a) * (r * 2.05 - l), Color(c, 0.6), 1.5, true)
	for k in pts * 2:
		var a0: float = -e.rot * 0.6 + TAU * k / (pts * 2)
		ci.draw_arc(pos, r * 1.45, a0, a0 + TAU / (pts * 2) * 0.55, 8, Color(c2, 0.85), 2.5, true)
	# orbiting satellites
	var sats: int = 3 + phase
	for k in sats:
		var a: float = -t * (1.2 + phase * 0.3) + TAU * k / sats
		var sp: Vector2 = pos + Vector2.from_angle(a) * r * 1.75
		var dia := Art.xform(Art.shapes["diamond"], sp, a + PI * 0.5, 7.0)
		Art.fan(ci, dia, sp, Color(c2, 1.0), Color(c2.r * 0.2, c2.g * 0.2, c2.b * 0.3, 1.0))
		ci.draw_polyline(Art.closed(dia), c2.lightened(0.4), 1.5, true)
	# spiked star body with radial shading
	var star := _star_pts(pos, r, pts, e.rot)
	if fl:
		Art.fan(ci, star, pos, Color(1, 1, 1), Color(1, 1, 1, 0.8))
	else:
		Art.fan(ci, star, pos, Color(c.r * 0.7, c.g * 0.7, c.b * 0.75, 1.0), Color(c.r * 0.06, c.g * 0.06, c.b * 0.12, 0.98))
	Art.neon_line(ci, star, c.lightened(0.25), 3.0)
	# inner counter-rotating polygon
	var inner := PackedVector2Array()
	var ip: int = maxi(3, pts / 2)
	for k in ip:
		inner.append(pos + Vector2.from_angle(-e.rot * 1.7 + TAU * k / ip) * r * 0.55)
	Art.fan(ci, inner, pos, Color(c2, 0.55), Color(c2.r * 0.1, c2.g * 0.1, c2.b * 0.15, 0.9))
	ci.draw_polyline(Art.closed(inner), c2, 2.2, true)
	# pulsing core (swells with each volley)
	var pulse: float = 0.5 + 0.5 * sin(t * 5.0)
	var core_r: float = r * (0.2 + pulse * 0.05 + muzzle * 0.8)
	ci.draw_circle(pos, core_r * 1.5, Color(c2, 0.5), true, -1.0, true)
	ci.draw_circle(pos, core_r, Color(1, 1, 1), true, -1.0, true)
	ci.draw_arc(pos, r * 0.32, 0, TAU, 32, Color(c2, 0.9), 2.0, true)
	if invuln > 0.0:
		var a2: float = 0.35 + 0.25 * sin(t * 20.0)
		var hexr: float = r * 1.8
		for k in 6:
			var a0: float = t + TAU * k / 6.0
			ci.draw_arc(pos, hexr, a0, a0 + TAU / 6.0 * 0.8, 12, Color(1, 1, 1, a2), 4.0, true)


func _star_pts(pos: Vector2, r: float, pts: int, rot: float) -> PackedVector2Array:
	var star := PackedVector2Array()
	for k in pts * 2:
		var rr: float = r * (1.15 if k % 2 == 0 else 0.62) * (1.0 + 0.04 * sin(e.t * 6.0 + k))
		star.append(pos + Vector2.from_angle(rot + TAU * k / (pts * 2)) * rr)
	return star