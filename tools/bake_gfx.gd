extends Node
## Offline tool (run headless): bakes the sprite atlas and rasterises the SVG emblem into
## every icon / splash image needed for Android, the web build and store listings.
##   res://assets/gfx/atlas.png
##   res://assets/icons/*.png, res://icon.svg

const C := Vector2(256, 280)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/gfx"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons"))
	Art.build_atlas_image().save_png("res://assets/gfx/atlas.png")

	var full := _svg(512, 512, _defs() + _background(512, true) + _emblem())
	_save_svg_text("res://icon.svg", full)
	_raster(full, 512, "res://assets/icons/icon_512.png")
	_raster(full, 192, "res://assets/icons/icon_192.png")
	_raster(full, 180, "res://assets/icons/icon_180.png")
	_raster(full, 144, "res://assets/icons/icon_144.png")
	# Android adaptive icon: 432x432 layers, artwork kept inside the central 66% safe zone
	var fg := _svg(432, 432, _defs() + "<g transform=\"translate(72,60) scale(0.5625)\">" + _emblem() + "</g>")
	_raster(fg, 432, "res://assets/icons/adaptive_fg_432.png")
	var bg := _svg(432, 432, _defs() + "<g transform=\"scale(0.84375)\">" + _background(512, true) + "</g>")
	_raster(bg, 432, "res://assets/icons/adaptive_bg_432.png")
	var mono := _svg(432, 432, "<g transform=\"translate(72,60) scale(0.5625)\">" + _ship_poly("#ffffff", "none", 0) + "</g>")
	_raster(mono, 432, "res://assets/icons/adaptive_mono_432.png")
	# boot splash (centred emblem on the clear colour)
	var splash := _svg(1024, 576, _defs() + "<g transform=\"translate(320,40) scale(0.75)\">" + _emblem() + "</g>")
	_raster(splash, 1024, "res://assets/icons/splash.png")
	print("baked gfx + icons")
	get_tree().quit()


func _svg(w: int, h: int, body: String) -> String:
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">%s</svg>" % [w, h, w, h, body]


func _raster(svg: String, width: int, path: String) -> void:
	var img := Image.new()
	var base_w := float(svg.get_slice("width=\"", 1).get_slice("\"", 0))
	var err := img.load_svg_from_string(svg, width / base_w)
	if err != OK:
		push_error("SVG raster failed for %s" % path)
		return
	img.save_png(path)


func _save_svg_text(path: String, svg: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(svg)


func _defs() -> String:
	return """<defs>
<radialGradient id="bg" cx="50%" cy="42%" r="72%"><stop offset="0" stop-color="#2b1366"/><stop offset="0.5" stop-color="#0c0728"/><stop offset="1" stop-color="#030210"/></radialGradient>
<radialGradient id="glow" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#4fe8ff" stop-opacity="0.75"/><stop offset="0.45" stop-color="#3a7bff" stop-opacity="0.25"/><stop offset="1" stop-color="#3a7bff" stop-opacity="0"/></radialGradient>
<linearGradient id="hull" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e6fdff"/><stop offset="0.35" stop-color="#4fc3ea"/><stop offset="1" stop-color="#081c3a"/></linearGradient>
<radialGradient id="bp"><stop offset="0" stop-color="#ffffff"/><stop offset="0.4" stop-color="#ffffff"/><stop offset="0.55" stop-color="#ff3d9a"/><stop offset="1" stop-color="#ff3d9a" stop-opacity="0"/></radialGradient>
<radialGradient id="by"><stop offset="0" stop-color="#ffffff"/><stop offset="0.4" stop-color="#ffffff"/><stop offset="0.55" stop-color="#ffd84d"/><stop offset="1" stop-color="#ffd84d" stop-opacity="0"/></radialGradient>
<radialGradient id="bv"><stop offset="0" stop-color="#ffffff"/><stop offset="0.4" stop-color="#ffffff"/><stop offset="0.55" stop-color="#a55bff"/><stop offset="1" stop-color="#a55bff" stop-opacity="0"/></radialGradient>
</defs>"""


func _background(s: int, grid: bool) -> String:
	var out := "<rect width=\"%d\" height=\"%d\" fill=\"url(#bg)\"/>" % [s, s]
	if grid:
		for k in range(1, 8):
			var p := k * s / 8
			out += "<line x1=\"%d\" y1=\"0\" x2=\"%d\" y2=\"%d\" stroke=\"#3a6bff\" stroke-opacity=\"0.18\" stroke-width=\"2\"/>" % [p, p, s]
			out += "<line x1=\"0\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"#3a6bff\" stroke-opacity=\"0.18\" stroke-width=\"2\"/>" % [p, s, p]
	return out


func _ship_points(scale: float) -> String:
	var pts := [Vector2(1.3, 0), Vector2(-0.2, 0.55), Vector2(-0.9, 1.0), Vector2(-0.55, 0.0), Vector2(-0.9, -1.0), Vector2(-0.2, -0.55)]
	var out := ""
	for p: Vector2 in pts:
		var q := C + Vector2(p.y, -p.x) * scale
		out += "%.1f,%.1f " % [q.x, q.y]
	return out


func _ship_poly(fill: String, stroke: String, width: int) -> String:
	return "<polygon points=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%d\" stroke-linejoin=\"round\"/>" % [_ship_points(150.0), fill, stroke, width]


func _emblem() -> String:
	var out := "<circle cx=\"256\" cy=\"270\" r=\"235\" fill=\"url(#glow)\"/>"
	# orbiting bullet ring
	out += "<circle cx=\"256\" cy=\"270\" r=\"205\" fill=\"none\" stroke=\"#ff4fd8\" stroke-opacity=\"0.55\" stroke-width=\"4\" stroke-dasharray=\"30 22\"/>"
	var grads := ["bp", "by", "bv"]
	for k in 9:
		var a := TAU * k / 9.0 - 0.3
		var p := Vector2(256, 270) + Vector2.from_angle(a) * 205.0
		out += "<circle cx=\"%.1f\" cy=\"%.1f\" r=\"22\" fill=\"url(#%s)\"/>" % [p.x, p.y, grads[k % 3]]
	out += "<polygon points=\"%s\" fill=\"none\" stroke=\"#4fe8ff\" stroke-opacity=\"0.35\" stroke-width=\"30\" stroke-linejoin=\"round\"/>" % _ship_points(150.0)
	out += _ship_poly("url(#hull)", "#7ff6ff", 10)
	out += "<polygon points=\"%s\" fill=\"none\" stroke=\"#ff4fd8\" stroke-width=\"8\" stroke-linejoin=\"round\"/>" % _ship_points(78.0)
	out += "<circle cx=\"256\" cy=\"232\" r=\"16\" fill=\"#ffffff\"/>"
	return out
