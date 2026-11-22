extends Node2D
## Glowing arena boundary with animated corner brackets.

var rect := Rect2(-1400, -1400, 2800, 2800)
var color := Color(0.3, 0.7, 1.0)
var _t := 0.0


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _draw() -> void:
	var pulse := 0.6 + 0.4 * sin(_t * 2.0)
	draw_rect(rect.grow(6), Color(color, 0.08 * pulse), false, 24.0)
	draw_rect(rect.grow(2), Color(color, 0.25 * pulse), false, 8.0)
	draw_rect(rect, Color(color.lightened(0.4), 0.9), false, 2.5)
	var L := 140.0
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var cp: Vector2 = corner
		var sx := -1.0 if cp.x > rect.get_center().x else 1.0
		var sy := -1.0 if cp.y > rect.get_center().y else 1.0
		draw_line(cp, cp + Vector2(L * sx, 0), Color(1, 1, 1, 0.9), 5.0)
		draw_line(cp, cp + Vector2(0, L * sy), Color(1, 1, 1, 0.9), 5.0)
	# travelling energy pulses along the border
	var per := rect.size.x * 2 + rect.size.y * 2
	for k in 6:
		var d := fmod(_t * 380.0 + k * per / 6.0, per)
		var p := _perimeter_point(d)
		draw_texture_rect_region(Art.atlas, Rect2(p - Vector2(40, 40), Vector2(80, 80)), Art.R_ORB_GLOW, Color(color, 0.9))
		draw_texture_rect_region(Art.atlas, Rect2(p - Vector2(70, 10), Vector2(140, 20)), Art.R_FLARE, Color(color, 0.6))


func _perimeter_point(d: float) -> Vector2:
	var w := rect.size.x
	var h := rect.size.y
	if d < w:
		return rect.position + Vector2(d, 0)
	d -= w
	if d < h:
		return Vector2(rect.end.x, rect.position.y + d)
	d -= h
	if d < w:
		return Vector2(rect.end.x - d, rect.end.y)
	d -= w
	return Vector2(rect.position.x, rect.end.y - d)
