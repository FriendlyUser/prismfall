extends Node2D
## Particles, debris shards, flares, shock rings and floating numbers - additive, one atlas.

const MAXP := 2400
const MAXS := 600

# particles
var p_pos := PackedVector2Array()
var p_vel := PackedVector2Array()
var p_life := PackedFloat32Array()
var p_max := PackedFloat32Array()
var p_size := PackedFloat32Array()
var p_col := PackedColorArray()
var p_kind := PackedByteArray()      # 0 glow puff, 1 streak, 2 sparkle, 3 soft smoke
var pc := 0
# debris shards (line segments that tumble)
var s_pos := PackedVector2Array()
var s_vel := PackedVector2Array()
var s_half := PackedVector2Array()
var s_rot := PackedFloat32Array()
var s_spin := PackedFloat32Array()
var s_life := PackedFloat32Array()
var s_max := PackedFloat32Array()
var s_col := PackedColorArray()
var sc := 0

var rings: Array = []    # [pos, radius, max_radius, life, max_life, color, width]
var flares: Array = []   # [pos, size, life, max_life, color]
var texts: Array = []    # [pos, text, life, color, size, max_life]
var view := Rect2()
var quality := 2


func _ready() -> void:
	p_pos.resize(MAXP); p_vel.resize(MAXP); p_life.resize(MAXP); p_max.resize(MAXP)
	p_size.resize(MAXP); p_col.resize(MAXP); p_kind.resize(MAXP)
	s_pos.resize(MAXS); s_vel.resize(MAXS); s_half.resize(MAXS); s_rot.resize(MAXS)
	s_spin.resize(MAXS); s_life.resize(MAXS); s_max.resize(MAXS); s_col.resize(MAXS)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	quality = int(Game.setting("quality"))


func particle(p: Vector2, v: Vector2, c: Color, size: float, life: float, kind := 0) -> void:
	if pc >= MAXP:
		return
	p_pos[pc] = p
	p_vel[pc] = v
	p_life[pc] = life
	p_max[pc] = life
	p_size[pc] = size
	p_col[pc] = c
	p_kind[pc] = kind
	pc += 1


func burst(p: Vector2, n: int, c: Color, speed := 300.0, size := 6.0, life := 0.6) -> void:
	if quality == 0:
		n = n / 2 + 1
	for k in n:
		var a := randf() * TAU
		var s := speed * randf_range(0.25, 1.0)
		particle(p, Vector2.from_angle(a) * s, c, size * randf_range(0.6, 1.2), life * randf_range(0.6, 1.1), 1 if k % 2 == 0 else 0)


## Hull debris: every edge of the polygon flies off and tumbles.
func shards(pts: PackedVector2Array, center: Vector2, c: Color, force := 220.0) -> void:
	var n := pts.size()
	for i in n:
		if sc >= MAXS:
			return
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var mid := (a + b) * 0.5
		var out := (mid - center).normalized()
		s_pos[sc] = mid
		s_vel[sc] = (out * randf_range(0.5, 1.0) + Vector2.from_angle(randf() * TAU) * 0.35) * force
		s_half[sc] = (b - a) * 0.5
		s_rot[sc] = 0.0
		s_spin[sc] = randf_range(-9.0, 9.0)
		var life := randf_range(0.45, 0.85)
		s_life[sc] = life
		s_max[sc] = life
		s_col[sc] = c
		sc += 1


func explosion(p: Vector2, c: Color, scale := 1.0, hull := PackedVector2Array()) -> void:
	burst(p, int(16 * scale), c, 380.0 * scale, 7.0, 0.7)
	burst(p, int(6 * scale), Color(1, 1, 1), 220.0 * scale, 8.0, 0.35)
	particle(p, Vector2.ZERO, c, 46.0 * scale, 0.28)
	particle(p, Vector2.ZERO, Color(1, 1, 1), 20.0 * scale, 0.12)
	if quality > 0:
		for k in int(3 * scale):
			particle(p + Vector2.from_angle(randf() * TAU) * 10.0 * scale, Vector2.from_angle(randf() * TAU) * 40.0,
				Color(c, 0.35), 30.0 * scale, randf_range(0.6, 1.0), 3)
	if hull.size() > 0:
		shards(hull, p, c.lightened(0.25), 240.0 * scale)
	ring(p, 70.0 * scale, c, 0.35, 3.0)
	if scale >= 1.2:
		flare(p, 260.0 * scale, c.lightened(0.4), 0.35)


func spark(p: Vector2, c: Color) -> void:
	for k in 2:
		particle(p, Vector2.from_angle(randf() * TAU) * randf_range(60, 180), c, 3.0, 0.25, 1)


## Bullet cancel pop: little sparkle + ring.
func pop(p: Vector2, c: Color) -> void:
	particle(p, Vector2.ZERO, c.lightened(0.4), 12.0, 0.25, 2)
	particle(p, Vector2.from_angle(randf() * TAU) * 90.0, c, 4.0, 0.3, 1)


func ring(p: Vector2, max_r: float, c: Color, life := 0.5, width := 4.0) -> void:
	rings.append([p, 0.0, max_r, life, life, c, width])


func flare(p: Vector2, size: float, c: Color, life := 0.4) -> void:
	flares.append([p, size, life, life, c])


func number(p: Vector2, val: float, c := Color(1, 1, 1), size := 16) -> void:
	if texts.size() > 60:
		return
	texts.append([p + Vector2(randf_range(-8, 8), -10), str(int(round(val))), 0.6, c, size, 0.6])


func text(p: Vector2, s: String, c: Color, size := 20, life := 1.0) -> void:
	texts.append([p, s, life, c, size, life])


func step(dt: float) -> void:
	var i := 0
	while i < pc:
		p_life[i] -= dt
		if p_life[i] <= 0.0:
			pc -= 1
			p_pos[i] = p_pos[pc]; p_vel[i] = p_vel[pc]; p_life[i] = p_life[pc]; p_max[i] = p_max[pc]
			p_size[i] = p_size[pc]; p_col[i] = p_col[pc]; p_kind[i] = p_kind[pc]
			continue
		p_pos[i] += p_vel[i] * dt
		p_vel[i] *= 1.0 - minf(1.0, dt * 3.0)
		i += 1
	i = 0
	while i < sc:
		s_life[i] -= dt
		if s_life[i] <= 0.0:
			sc -= 1
			s_pos[i] = s_pos[sc]; s_vel[i] = s_vel[sc]; s_half[i] = s_half[sc]; s_rot[i] = s_rot[sc]
			s_spin[i] = s_spin[sc]; s_life[i] = s_life[sc]; s_max[i] = s_max[sc]; s_col[i] = s_col[sc]
			continue
		s_pos[i] += s_vel[i] * dt
		s_vel[i] *= 1.0 - minf(1.0, dt * 2.2)
		s_rot[i] += s_spin[i] * dt
		i += 1
	for r: Array in rings:
		r[3] -= dt
		var t: float = 1.0 - float(r[3]) / float(r[4])
		r[1] = float(r[2]) * (1.0 - pow(1.0 - t, 3.0))
	rings = rings.filter(func(r: Array) -> bool: return r[3] > 0.0)
	for f: Array in flares:
		f[2] -= dt
	flares = flares.filter(func(f: Array) -> bool: return f[2] > 0.0)
	for tx: Array in texts:
		tx[2] -= dt
		tx[0] += Vector2(0, -40 * dt)
	texts = texts.filter(func(tx: Array) -> bool: return tx[2] > 0.0)
	queue_redraw()


func _draw() -> void:
	var v := view.grow(60)
	var tex := Art.atlas
	# smoke + puffs + sparkles (atlas quads, batched)
	for i in pc:
		var p := p_pos[i]
		if not v.has_point(p):
			continue
		var t := p_life[i] / p_max[i]
		var c := p_col[i]
		var k := p_kind[i]
		if k == 1:
			continue
		var s := p_size[i]
		var region := Art.R_ORB_GLOW
		if k == 0:
			s *= 0.4 + t * 0.8
			c.a *= t
		elif k == 2:
			region = Art.R_SPARKLE
			s *= 0.6 + (1.0 - t) * 0.8
			c.a *= t
		else:
			region = Art.R_SOFT
			s *= 1.0 + (1.0 - t) * 1.4
			c.a *= t * t
		draw_texture_rect_region(tex, Rect2(p.x - s, p.y - s, s * 2.0, s * 2.0), region, c)
	for f: Array in flares:
		var t: float = float(f[2]) / float(f[3])
		var p: Vector2 = f[0]
		var w: float = float(f[1]) * (0.6 + (1.0 - t) * 0.6)
		var c: Color = f[4]
		c.a = t
		draw_texture_rect_region(tex, Rect2(p.x - w, p.y - w * 0.07, w * 2.0, w * 0.14), Art.R_FLARE, c)
		draw_texture_rect_region(tex, Rect2(p.x - w * 0.35, p.y - w * 0.35, w * 0.7, w * 0.7), Art.R_SPARKLE, Color(1, 1, 1, t))
	# streak sparks (lines)
	for i in pc:
		if p_kind[i] != 1:
			continue
		var p := p_pos[i]
		if not v.has_point(p):
			continue
		var t := p_life[i] / p_max[i]
		var c := p_col[i]
		c.a *= t
		draw_line(p, p - p_vel[i] * 0.05, c, p_size[i] * 0.5 * (0.5 + t))
	# debris shards
	for i in sc:
		var p := s_pos[i]
		if not v.has_point(p):
			continue
		var t := s_life[i] / s_max[i]
		var h := s_half[i].rotated(s_rot[i]) * (0.4 + 0.6 * t)
		var c := s_col[i]
		c.a = t
		draw_line(p - h, p + h, c, 2.2)
	for r: Array in rings:
		var t: float = float(r[3]) / float(r[4])
		var c: Color = r[5]
		c.a = t
		draw_arc(r[0], r[1], 0, TAU, 64, c, float(r[6]) * (0.4 + t), true)
		c.a = t * 0.25
		draw_arc(r[0], r[1] * 0.96, 0, TAU, 64, c, float(r[6]) * 3.0, true)
	var f := Art.font_ui
	for tx: Array in texts:
		var c: Color = tx[3]
		var life: float = tx[2]
		var max_life: float = tx[5]
		c.a = clampf(life * 2.5, 0.0, 1.0)
		var age := max_life - life
		var size := int(float(tx[4]) * (1.0 + maxf(0.0, 0.12 - age) * 4.0))
		draw_string(f, tx[0] - Vector2(150, 0), tx[1], HORIZONTAL_ALIGNMENT_CENTER, 300, size, c)
