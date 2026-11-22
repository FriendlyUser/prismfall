extends Node2D
## XP gems (kind 0) and score sparks (kind 1) with magnet pickup.

const MAX := 700

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var val := PackedInt32Array()
var kind := PackedByteArray()
var age := PackedFloat32Array()
var count := 0
var view := Rect2()
var vacuum := false


func _ready() -> void:
	pos.resize(MAX); vel.resize(MAX); val.resize(MAX); kind.resize(MAX); age.resize(MAX)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func add(p: Vector2, v: int, k := 0) -> void:
	if count >= MAX:
		if k == 0:
			# merge into a random existing gem instead of dropping XP
			var j := randi() % count
			val[j] += v
			kind[j] = 0
		return
	pos[count] = p
	vel[count] = Vector2.from_angle(randf() * TAU) * randf_range(40, 140)
	val[count] = v
	kind[count] = k
	age[count] = 0.0
	count += 1


## Returns Vector2i(xp, score_sparks) collected this frame.
func step(dt: float, ppos: Vector2, magnet: float) -> Vector2i:
	var xp := 0
	var sc := 0
	var i := 0
	var m2 := magnet * magnet
	while i < count:
		age[i] += dt
		var p := pos[i]
		var to := ppos - p
		var d2 := to.length_squared()
		var pulled := vacuum or kind[i] == 1 and age[i] > 0.35 or d2 < m2
		if pulled:
			var d := sqrt(d2) + 0.001
			var pull := 900.0 + age[i] * 200.0
			vel[i] = vel[i].lerp(to / d * pull, minf(1.0, dt * 6.0))
		else:
			vel[i] *= 1.0 - minf(1.0, dt * 4.0)
		p += vel[i] * dt
		pos[i] = p
		if d2 < 22.0 * 22.0:
			if kind[i] == 0:
				xp += val[i]
			else:
				sc += val[i]
			count -= 1
			pos[i] = pos[count]; vel[i] = vel[count]; val[i] = val[count]; kind[i] = kind[count]; age[i] = age[count]
			continue
		i += 1
	queue_redraw()
	return Vector2i(xp, sc)


func _draw() -> void:
	var v := view.grow(30)
	var tex := Art.atlas
	var t := Time.get_ticks_msec() * 0.004
	for i in count:
		var p := pos[i]
		if not v.has_point(p):
			continue
		if kind[i] == 1:
			draw_texture_rect_region(tex, Rect2(p.x - 7, p.y - 7, 14, 14), Art.R_ORB_GLOW, Color(1.0, 0.85, 0.3, 0.9))
			continue
		var vv := val[i]
		var c := Color(0.3, 1.0, 0.55) if vv < 3 else (Color(0.3, 0.8, 1.0) if vv < 6 else Color(1.0, 0.4, 0.9))
		var s := 5.0 + minf(vv, 12) * 0.6
		var moving := vel[i].length_squared() > 40000.0
		if moving:
			# comet tail while being magnetised
			draw_set_transform(p, vel[i].angle())
			draw_texture_rect_region(tex, Rect2(-s * 4.5, -s, s * 4.5, s * 2.0), Art.R_RICE_GLOW, Color(c, 0.5))
			draw_set_transform(Vector2.ZERO)
		draw_texture_rect_region(tex, Rect2(p.x - s * 2.6, p.y - s * 2.6, s * 5.2, s * 5.2), Art.R_ORB_GLOW, Color(c, 0.5))
		var rot := t + i
		var pts := Art.xform(Art.shapes["diamond"], p, rot, s)
		Art.fan(self, pts, p, Color(c.lightened(0.6), 0.9), Color(c, 0.25))
		draw_polyline(Art.closed(pts), c.lightened(0.4), 1.6, true)
		var tw := sin(t * 1.7 + i * 2.3)
		if tw > 0.85:
			var k := (tw - 0.85) / 0.15 * s * 2.2
			draw_texture_rect_region(tex, Rect2(p.x - k, p.y - k, k * 2.0, k * 2.0), Art.R_SPARKLE, Color(1, 1, 1, 0.9))