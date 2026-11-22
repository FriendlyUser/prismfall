extends Node
## Procedural art kit: glow textures, palettes, fonts and neon UI styles.

const BULLET_COLORS: Array[Color] = [
	Color(1.0, 0.25, 0.6),   # 0 pink
	Color(1.0, 0.55, 0.15),  # 1 orange
	Color(0.7, 0.35, 1.0),   # 2 violet
	Color(0.25, 0.85, 1.0),  # 3 cyan
	Color(1.0, 0.9, 0.3),    # 4 yellow
	Color(0.3, 1.0, 0.55),   # 5 green
	Color(1.0, 0.18, 0.18),  # 6 red
	Color(0.95, 0.95, 1.0),  # 7 white
]
const CYAN := Color(0.35, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.3, 0.85)
const GOLD := Color(1.0, 0.85, 0.35)
const TEXT := Color(0.85, 0.95, 1.0)

# Sprite atlas regions (512x256 atlas baked by tools/bake_gfx.tscn into res://assets/gfx/atlas.png)
const ATLAS_PATH := "res://assets/gfx/atlas.png"
const R_ORB_GLOW := Rect2(0, 0, 128, 128)
const R_ORB_CORE := Rect2(128, 0, 64, 64)
const R_RING := Rect2(128, 64, 64, 64)
const R_RICE_GLOW := Rect2(192, 0, 192, 96)
const R_RICE_CORE := Rect2(192, 96, 96, 48)
const R_STAR := Rect2(384, 0, 128, 128)
const R_SOFT := Rect2(0, 128, 128, 128)
const R_FLARE := Rect2(128, 128, 256, 32)
const R_SPARKLE := Rect2(384, 128, 128, 128)

var atlas: Texture2D
var glow: Texture2D
var core: Texture2D
var ring_tex: Texture2D
var soft: Texture2D
var flare: Texture2D
var sparkle: Texture2D
var font: Font
var font_title: FontVariation
var font_ui: FontVariation
var font_head: FontVariation
var theme: Theme
var shapes := {}


func _ready() -> void:
	if ResourceLoader.exists(ATLAS_PATH):
		atlas = load(ATLAS_PATH)
	else:
		atlas = ImageTexture.create_from_image(build_atlas_image())
	glow = _region(R_ORB_GLOW)
	core = _region(R_ORB_CORE)
	ring_tex = _region(R_RING)
	soft = _region(R_SOFT)
	flare = _region(R_FLARE)
	sparkle = _region(R_SPARKLE)
	font = ThemeDB.fallback_font
	font_title = FontVariation.new()
	font_title.base_font = font
	font_title.spacing_glyph = 10
	font_title.variation_embolden = 0.9
	font_ui = FontVariation.new()
	font_ui.base_font = font
	font_ui.spacing_glyph = 2
	font_ui.variation_embolden = 0.35
	font_head = FontVariation.new()
	font_head.base_font = font
	font_head.spacing_glyph = 3
	font_head.variation_embolden = 0.9
	_build_shapes()
	_build_theme()


func _region(r: Rect2) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = atlas
	t.region = r
	return t


# ---------------------------------------------------------------- atlas generation
## Rasterises every sprite into one white+alpha atlas (used offline by tools/bake_gfx.gd).
func build_atlas_image() -> Image:
	var img := Image.create(512, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	_paint(img, R_ORB_GLOW, _f_orb_glow)
	_paint(img, R_ORB_CORE, _f_orb_core)
	_paint(img, R_RING, _f_ring)
	_paint(img, R_RICE_GLOW, _f_rice_glow)
	_paint(img, R_RICE_CORE, _f_rice_core)
	_paint(img, R_STAR, _f_star)
	_paint(img, R_SOFT, _f_soft)
	_paint(img, R_FLARE, _f_flare)
	_paint(img, R_SPARKLE, _f_sparkle)
	return img


func _paint(img: Image, r: Rect2, f: Callable) -> void:
	var w := int(r.size.x)
	var h := int(r.size.y)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h * 2.0 - 1.0
			var a: float = clampf(f.call(u, v), 0.0, 1.0)
			img.set_pixel(int(r.position.x) + x, int(r.position.y) + y, Color(1, 1, 1, a))


func _f_orb_glow(u: float, v: float) -> float:
	var d := sqrt(u * u + v * v)
	return pow(maxf(0.0, 1.0 - d), 2.2) * 0.85 + exp(-d * d * 28.0) * 0.4


func _f_orb_core(u: float, v: float) -> float:
	var d := sqrt(u * u + v * v)
	return smoothstep(0.82, 0.62, d)


func _f_ring(u: float, v: float) -> float:
	var d := sqrt(u * u + v * v)
	return smoothstep(0.1, 0.0, absf(d - 0.72)) + exp(-pow((d - 0.72) / 0.22, 2.0)) * 0.35


func _f_rice_glow(u: float, v: float) -> float:
	var d := sqrt(u * u + v * v)
	return pow(maxf(0.0, 1.0 - d), 2.0) * 0.9


func _f_rice_core(u: float, v: float) -> float:
	# pointed capsule: narrower towards the tips
	var d := sqrt(u * u + pow(v * (1.0 + 0.6 * absf(u)), 2.0))
	return smoothstep(0.86, 0.66, d)


func _f_star(u: float, v: float) -> float:
	var d := sqrt(u * u + v * v)
	var th := atan2(v, u)
	var edge := 0.42 + 0.5 * pow(0.5 + 0.5 * cos(5.0 * th), 2.5)
	return smoothstep(edge, edge - 0.09, d) + exp(-d * d * 6.0) * 0.25


func _f_soft(u: float, v: float) -> float:
	var d := sqrt(u * u + v * v)
	return exp(-d * d * 3.5) * maxf(0.0, 1.0 - d)


func _f_flare(u: float, v: float) -> float:
	return exp(-v * v * 14.0) * pow(maxf(0.0, 1.0 - absf(u)), 2.4) + exp(-(u * u * 30.0 + v * v * 8.0)) * 0.5


func _f_sparkle(u: float, v: float) -> float:
	var d := sqrt(u * u + v * v)
	var cross := maxf(exp(-absf(u) * 16.0) * exp(-v * v * 1.5), exp(-absf(v) * 16.0) * exp(-u * u * 1.5))
	return cross * maxf(0.0, 1.0 - d) + exp(-d * d * 22.0)


func _star(points: int, inner: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points * 2:
		var r := 1.0 if i % 2 == 0 else inner
		out.append(Vector2.from_angle(TAU * i / (points * 2)) * r)
	return out


func _poly(n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		out.append(Vector2.from_angle(TAU * i / n))
	return out


func _build_shapes() -> void:
	shapes["diamond"] = PackedVector2Array([Vector2(1.2, 0), Vector2(0, 0.75), Vector2(-0.9, 0), Vector2(0, -0.75)])
	shapes["arrow"] = PackedVector2Array([Vector2(1.2, 0), Vector2(-0.8, 0.75), Vector2(-0.35, 0), Vector2(-0.8, -0.75)])
	shapes["hex"] = _poly(6)
	shapes["star"] = _star(5, 0.45)
	shapes["shuriken"] = PackedVector2Array([
		Vector2(1, 0), Vector2(0.25, 0.25), Vector2(0, 1), Vector2(-0.25, 0.25),
		Vector2(-1, 0), Vector2(-0.25, -0.25), Vector2(0, -1), Vector2(0.25, -0.25)])
	shapes["ship"] = PackedVector2Array([
		Vector2(1.3, 0), Vector2(-0.2, 0.55), Vector2(-0.9, 1.0), Vector2(-0.55, 0.0),
		Vector2(-0.9, -1.0), Vector2(-0.2, -0.55)])


func xform(shape: PackedVector2Array, pos: Vector2, rot: float, scale: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(shape.size())
	var c := cos(rot) * scale
	var s := sin(rot) * scale
	for i in shape.size():
		var p := shape[i]
		out[i] = pos + Vector2(p.x * c - p.y * s, p.x * s + p.y * c)
	return out


## Gradient fill: triangle fan from a bright centre to darker edges (radial shading).
func fan(ci: CanvasItem, pts: PackedVector2Array, center: Vector2, inner: Color, edge: Color) -> void:
	var n := pts.size()
	var cols := PackedColorArray([inner, edge, edge])
	var empty := PackedVector2Array()
	for i in n:
		ci.draw_primitive(PackedVector2Array([center, pts[i], pts[(i + 1) % n]]), cols, empty)


## Neon outline: a wide translucent under-stroke plus a crisp bright line.
func neon_line(ci: CanvasItem, pts: PackedVector2Array, c: Color, width := 2.4) -> void:
	var cl := closed(pts)
	ci.draw_polyline(cl, Color(c, 0.22), width * 3.2, true)
	ci.draw_polyline(cl, c, width, true)


func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


# ---------------------------------------------------------------- UI
func box(bg: Color, border: Color, bw := 2, glow_size := 0, radius := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(border, 0.45)
	s.shadow_size = glow_size
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = font_ui
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", TEXT)


func button(text: String, accent := CYAN, font_size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", font_ui)
	b.add_theme_font_size_override("font_size", font_size)
	style_button(b, accent)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func() -> void: Sfx.play("ui", -12.0))
	b.pressed.connect(func() -> void: Sfx.play("select", -6.0))
	return b


func style_button(b: Button, accent: Color) -> void:
	var dark := Color(0.025, 0.035, 0.09, 0.88)
	var hot := Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.3, 0.96)
	b.add_theme_stylebox_override("normal", box(dark, Color(accent, 0.5), 2, 0))
	b.add_theme_stylebox_override("hover", box(hot, accent, 2, 14))
	b.add_theme_stylebox_override("focus", box(hot, accent, 2, 14))
	b.add_theme_stylebox_override("pressed", box(Color(accent, 0.45), Color.WHITE, 2, 18))
	b.add_theme_stylebox_override("disabled", box(Color(0.02, 0.02, 0.05, 0.7), Color(0.3, 0.32, 0.4, 0.5), 2, 0))
	b.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.58))


func label(text: String, size := 18, color := TEXT, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", f if f else font_ui)
	l.add_theme_color_override("font_shadow_color", Color(color, 0.22 if size < 24 else 0.4))
	l.add_theme_constant_override("shadow_outline_size", 3 if size < 24 else 10)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Draws text with a neon chromatic glow on any CanvasItem.
func neon_text(ci: CanvasItem, f: Font, pos: Vector2, text: String, size: int, color: Color, width := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT, split := 2.0) -> void:
	if split > 0.0:
		ci.draw_string(f, pos + Vector2(-split, 0), text, align, width, size, Color(1.0, 0.2, 0.6, 0.55 * color.a))
		ci.draw_string(f, pos + Vector2(split, 0), text, align, width, size, Color(0.2, 0.8, 1.0, 0.55 * color.a))
	ci.draw_string_outline(f, pos, text, align, width, size, 6, Color(color, 0.18 * color.a))
	ci.draw_string(f, pos, text, align, width, size, color)
