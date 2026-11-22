extends Node2D
## Player projectiles: prism bolts (kind 0) and homing seekers (kind 1).

const MAX := 600

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var dmg := PackedFloat32Array()
var pierce := PackedInt32Array()
var life := PackedFloat32Array()
var kind := PackedByteArray()
var last := PackedInt32Array()
var count := 0
var view := Rect2()
var enemies
var fx


func _ready() -> void:
	pos.resize(MAX); vel.resize(MAX); dmg.resize(MAX); pierce.resize(MAX)
	life.resize(MAX); kind.resize(MAX); last.resize(MAX)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func spawn(p: Vector2, v: Vector2, damage: float, pierce_n := 0, k := 0, lifetime := 1.0) -> void:
	if count >= MAX:
		return
	pos[count] = p
	vel[count] = v
	dmg[count] = damage
	pierce[count] = pierce_n
	life[count] = lifetime
	kind[count] = k
	last[count] = -1
	count += 1


func _remove(i: int) -> void:
	count -= 1
	pos[i] = pos[count]; vel[i] = vel[count]; dmg[i] = dmg[count]; pierce[i] = pierce[count]
	life[i] = life[count]; kind[i] = kind[count]; last[i] = last[count]


func step(dt: float) -> void:
	var i := 0
	while i < count:
		life[i] -= dt
		if life[i] <= 0.0:
			_remove(i)
			continue
		if kind[i] == 1:
			var t: Variant = enemies.nearest(pos[i], 700.0)
			if t != null:
				var want: Vector2 = (t.pos - pos[i]).normalized() * 560.0
				vel[i] = vel[i].lerp(want, minf(1.0, dt * 4.5))
			if randf() < 0.5:
				fx.particle(pos[i], -vel[i] * 0.1, Color(1.0, 0.35, 0.8, 0.7), 5.0, 0.25)
		pos[i] += vel[i] * dt
		var e: Variant = enemies.hit_circle(pos[i], 7.0 if kind[i] == 0 else 9.0, last[i])
		if e != null:
			enemies.damage(e, dmg[i], vel[i].normalized())
			fx.spark(pos[i], Color(0.6, 1.0, 1.0) if kind[i] == 0 else Color(1.0, 0.5, 0.9))
			last[i] = e.uid
			pierce[i] -= 1
			if pierce[i] < 0:
				_remove(i)
				continue
		i += 1
	queue_redraw()


func _draw() -> void:
	var v := view.grow(40)
	var tex := Art.atlas
	for i in count:
		var p := pos[i]
		if not v.has_point(p):
			continue
		var dir := vel[i].normalized()
		if kind[i] == 0:
			draw_set_transform(p - dir * 10.0, vel[i].angle())
			draw_texture_rect_region(tex, Rect2(-26, -8, 52, 16), Art.R_RICE_GLOW, Color(0.2, 0.75, 1.0, 0.65))
			draw_texture_rect_region(tex, Rect2(-14, -2.5, 28, 5), Art.R_RICE_CORE, Color(0.85, 1.0, 1.0, 0.95))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect_region(tex, Rect2(p.x - 16, p.y - 16, 32, 32), Art.R_ORB_GLOW, Color(1.0, 0.3, 0.8, 0.6))
			draw_set_transform(p, vel[i].angle())
			draw_texture_rect_region(tex, Rect2(-9, -3.5, 18, 7), Art.R_RICE_CORE, Color(1.0, 0.85, 0.95))
			draw_set_transform(Vector2.ZERO)