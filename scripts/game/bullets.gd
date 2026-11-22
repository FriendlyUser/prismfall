extends Node2D
## Enemy bullet pool. Data-oriented packed arrays, drawn from one atlas in additive batches.
## Shapes: 0 orb, 1 rice (oriented along travel), 2 star (spinning).

const MAX := 2600
const ORB := 0
const RICE := 1
const STAR := 2

var pos := PackedVector2Array()
var ang := PackedFloat32Array()
var spd := PackedFloat32Array()
var acc := PackedFloat32Array()
var crv := PackedFloat32Array()
var rad := PackedFloat32Array()
var col := PackedInt32Array()
var age := PackedFloat32Array()
var grazed := PackedByteArray()
var shp := PackedByteArray()
var count := 0

var bounds := Rect2(-1500, -1500, 3000, 3000)
var view := Rect2()
var speed_mult := 1.0
var fx
var gems


func _ready() -> void:
	pos.resize(MAX); ang.resize(MAX); spd.resize(MAX); acc.resize(MAX); crv.resize(MAX)
	rad.resize(MAX); col.resize(MAX); age.resize(MAX); grazed.resize(MAX); shp.resize(MAX)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func spawn(p: Vector2, a: float, s: float, r := 6.0, c := 0, accel := 0.0, curve := 0.0, shape := ORB) -> void:
	if count >= MAX:
		return
	var i := count
	pos[i] = p
	ang[i] = a
	spd[i] = s * speed_mult
	acc[i] = accel * speed_mult
	crv[i] = curve
	rad[i] = r
	col[i] = c
	age[i] = 0.0
	grazed[i] = 0
	shp[i] = shape
	count += 1


func ring(p: Vector2, n: int, s: float, offset := 0.0, r := 6.0, c := 0, accel := 0.0, curve := 0.0, shape := ORB) -> void:
	for k in n:
		spawn(p, offset + TAU * k / n, s, r, c, accel, curve, shape)


func fan(p: Vector2, a: float, n: int, spread: float, s: float, r := 6.0, c := 0, accel := 0.0, shape := RICE) -> void:
	if n <= 1:
		spawn(p, a, s, r, c, accel, 0.0, shape)
		return
	for k in n:
		spawn(p, a - spread * 0.5 + spread * k / (n - 1), s, r, c, accel, 0.0, shape)


func _remove(i: int) -> void:
	count -= 1
	if i == count:
		return
	pos[i] = pos[count]; ang[i] = ang[count]; spd[i] = spd[count]; acc[i] = acc[count]
	crv[i] = crv[count]; rad[i] = rad[count]; col[i] = col[count]; age[i] = age[count]
	grazed[i] = grazed[count]; shp[i] = shp[count]


## Moves bullets. Returns Vector2i(hit, new_grazes).
func step(dt: float, ppos: Vector2, hit_r: float, graze_r: float, can_hit: bool) -> Vector2i:
	var hit := 0
	var grazes := 0
	var i := 0
	var far := 1500.0 * 1500.0
	while i < count:
		var a := ang[i] + crv[i] * dt
		ang[i] = a
		var s := clampf(spd[i] + acc[i] * dt, 30.0, 900.0)
		spd[i] = s
		var p := pos[i] + Vector2(cos(a), sin(a)) * (s * dt)
		pos[i] = p
		age[i] += dt
		var d2 := p.distance_squared_to(ppos)
		if age[i] > 16.0 or d2 > far or not bounds.has_point(p):
			_remove(i)
			continue
		# rice bullets have a slimmer hit circle than their visual length
		var r := rad[i] * (0.55 if shp[i] == RICE else 0.62) + hit_r
		if can_hit and d2 < r * r and age[i] > 0.05:
			hit = 1
			if fx:
				fx.burst(p, 6, Art.BULLET_COLORS[col[i]], 200.0, 4.0, 0.3)
			_remove(i)
			continue
		if grazed[i] == 0:
			var gr := rad[i] + graze_r
			if d2 < gr * gr:
				grazed[i] = 1
				grazes += 1
				if fx:
					fx.spark(p.lerp(ppos, 0.5), Color(1, 1, 1))
		i += 1
	queue_redraw()
	return Vector2i(hit, grazes)


## Removes bullets inside a circle; returns how many were erased.
func erase_circle(p: Vector2, r: float, to_score := false) -> int:
	var n := 0
	var i := 0
	while i < count:
		var rr := r + rad[i]
		if pos[i].distance_squared_to(p) < rr * rr:
			if fx:
				fx.pop(pos[i], Art.BULLET_COLORS[col[i]])
			if to_score and gems:
				gems.add(pos[i], 1, 1)
			_remove(i)
			n += 1
		else:
			i += 1
	return n


## Converts every bullet into a score spark (bombs, boss phase breaks).
func clear_all() -> int:
	var n := count
	for i in count:
		if fx and i % 2 == 0:
			fx.pop(pos[i], Art.BULLET_COLORS[col[i]])
		if gems and i % 3 == 0:
			gems.add(pos[i], 1, 1)
	count = 0
	queue_redraw()
	return n


func _draw() -> void:
	var v := view.grow(40.0)
	var tex := Art.atlas
	var colors := Art.BULLET_COLORS
	var white := Color(1, 1, 1, 0.95)
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.012)
	# ---- orbs (no transform)
	for i in count:
		if shp[i] != ORB:
			continue
		var p := pos[i]
		if not v.has_point(p):
			continue
		var c: Color = colors[col[i]]
		var r := rad[i]
		var pop := 1.0 + maxf(0.0, 0.12 - age[i]) * 8.0          # spawn flash
		var g := r * 3.1 * pop
		draw_texture_rect_region(tex, Rect2(p.x - g, p.y - g, g * 2.0, g * 2.0), Art.R_ORB_GLOW, Color(c, 0.8))
		var rr := r * 1.25
		draw_texture_rect_region(tex, Rect2(p.x - rr, p.y - rr, rr * 2.0, rr * 2.0), Art.R_ORB_CORE, c)
		if r >= 9.0:
			var ro := r * 1.7
			draw_texture_rect_region(tex, Rect2(p.x - ro, p.y - ro, ro * 2.0, ro * 2.0), Art.R_RING, Color(c.lightened(0.3), 0.9))
		var rc := r * 0.72 * pulse
		draw_texture_rect_region(tex, Rect2(p.x - rc, p.y - rc, rc * 2.0, rc * 2.0), Art.R_ORB_CORE, white)
	# ---- rice + stars (rotated)
	for i in count:
		var s := shp[i]
		if s == ORB:
			continue
		var p := pos[i]
		if not v.has_point(p):
			continue
		var c: Color = colors[col[i]]
		var r := rad[i]
		var pop := 1.0 + maxf(0.0, 0.12 - age[i]) * 8.0
		if s == RICE:
			draw_set_transform(p, ang[i])
			var gl := r * 4.2 * pop
			draw_texture_rect_region(tex, Rect2(-gl, -gl * 0.5, gl * 2.0, gl), Art.R_RICE_GLOW, Color(c, 0.85))
			var cl := r * 1.9
			draw_texture_rect_region(tex, Rect2(-cl, -cl * 0.5, cl * 2.0, cl), Art.R_RICE_CORE, c)
			var wl := r * 1.35
			draw_texture_rect_region(tex, Rect2(-wl, -wl * 0.42, wl * 2.0, wl * 0.84), Art.R_RICE_CORE, white)
		else:
			draw_set_transform(p, age[i] * 5.0 + i)
			var g := r * 3.0 * pop
			draw_texture_rect_region(tex, Rect2(-g, -g, g * 2.0, g * 2.0), Art.R_ORB_GLOW, Color(c, 0.7))
			var sr := r * 1.9
			draw_texture_rect_region(tex, Rect2(-sr, -sr, sr * 2.0, sr * 2.0), Art.R_STAR, c)
			var rc := r * 0.6
			draw_texture_rect_region(tex, Rect2(-rc, -rc, rc * 2.0, rc * 2.0), Art.R_ORB_CORE, white)
	draw_set_transform(Vector2.ZERO)
