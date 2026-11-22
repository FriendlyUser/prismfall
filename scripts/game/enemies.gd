extends Node2D
## Enemy manager: data-driven enemies (DB.ENEMIES) + bosses, spatial grid, AI, damage and drawing.

signal died(e: Enemy)

const BossBrain := preload("res://scripts/game/boss_brain.gd")
const CELL := 72.0


class Enemy:
	var uid := 0
	var kind := ""
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var hp := 1.0
	var max_hp := 1.0
	var radius := 12.0
	var speed := 80.0
	var color := Color.WHITE
	var flash := 0.0
	var t := 0.0
	var fire_t := 0.0
	var rot := 0.0
	var spin := 0.0
	var spawn := 0.7
	var dead := false
	var is_boss := false
	var brain = null
	var xp := 1
	var score := 10
	var orbit_cd := 0.0
	var shape: PackedVector2Array
	var fuse := -1.0


var list: Array[Enemy] = []
var grid := {}
var boss: Enemy = null
var bullets
var fx
var run
var level: Dictionary = {}
var hp_mult := 1.0
var arena := Rect2(-1400, -1400, 2800, 2800)
var view := Rect2()
var _uid := 0
var _glow_layer: Node2D


func _ready() -> void:
	_glow_layer = Node2D.new()
	_glow_layer.show_behind_parent = true
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer.material = m
	add_child(_glow_layer)
	_glow_layer.draw.connect(_draw_glow)


func spawn(kind: String, p: Vector2) -> Enemy:
	var d: Dictionary = DB.ENEMIES[kind]
	var e := Enemy.new()
	_uid += 1
	e.uid = _uid
	e.kind = kind
	e.pos = p
	e.hp = float(d.hp) * hp_mult
	e.max_hp = e.hp
	e.radius = d.radius
	e.speed = float(d.speed) * randf_range(0.9, 1.1)
	e.color = d.color
	e.xp = d.xp
	e.score = d.score
	e.shape = Art.shapes[d.shape]
	e.fire_t = randf_range(0.8, float(d.get("fire", 2.0)) + 0.8)
	e.spin = float(d.get("spin", 0.0)) * (1.0 if randf() < 0.5 else -1.0)
	e.rot = randf() * TAU
	list.append(e)
	return e


func spawn_boss(id: String, p: Vector2) -> Enemy:
	var spec: Dictionary = DB.BOSSES[id]
	var e := Enemy.new()
	_uid += 1
	e.uid = _uid
	e.kind = "boss"
	e.is_boss = true
	e.pos = p
	e.hp = spec.hp
	e.max_hp = e.hp
	e.radius = spec.radius
	e.color = spec.color
	e.xp = spec.xp
	e.score = spec.score
	e.spawn = 1.6
	e.brain = BossBrain.new(spec, e, self)
	list.append(e)
	boss = e
	return e


# ---------------------------------------------------------------- simulation
func step(dt: float, ppos: Vector2) -> void:
	_build_grid()
	var any_dead := false
	for e in list:
		if e.dead:
			any_dead = true
			continue
		e.t += dt
		e.flash = maxf(0.0, e.flash - dt)
		e.orbit_cd = maxf(0.0, e.orbit_cd - dt)
		if e.spawn > 0.0:
			e.spawn -= dt
			continue
		var to := ppos - e.pos
		var dist := to.length()
		var dir := to / maxf(dist, 0.001)
		match e.kind:
			"drone":
				_seek(e, dir, dt, 3.0)
				e.rot = e.vel.angle()
			"mite":
				_seek(e, dir.rotated(sin(e.t * 5.0 + e.uid) * 0.6), dt, 5.0)
				e.rot = e.vel.angle()
			"spitter":
				var want := dir
				if dist < 230.0:
					want = -dir
				elif dist < 360.0:
					want = dir.orthogonal() * (1.0 if e.uid % 2 == 0 else -1.0)
				_seek(e, want, dt, 2.0)
				e.rot += dt * 1.2
				e.fire_t -= dt
				if e.fire_t <= 0.0 and dist < 720.0:
					e.fire_t = float(DB.ENEMIES.spitter.fire) * randf_range(0.85, 1.15)
					var n: int = level.get("spitter_shots", 3)
					bullets.fan(e.pos, dir.angle(), n, 0.16 * (n - 1), 190.0, 7.0, 2)
					e.flash = 0.1
					Sfx.play("eshot", -16.0)
			"bloom":
				_seek(e, dir, dt, 3.0)
				e.rot += dt * 2.0
				if dist < 85.0 and e.fuse < 0.0:
					e.fuse = 0.55
				if e.fuse >= 0.0:
					e.fuse -= dt
					e.vel *= 0.85
					if e.fuse <= 0.0:
						kill(e)
						continue
			"spinner":
				_seek(e, dir, dt, 1.0)
				e.rot += e.spin * dt
				e.fire_t -= dt
				if e.fire_t <= 0.0 and dist < 800.0:
					e.fire_t = 0.17
					var arms: int = level.get("spinner_arms", 3)
					for k in arms:
						bullets.spawn(e.pos, e.rot + TAU * k / arms, 135.0, 6.0, 6, 0.0, 0.0, 1)
			"boss":
				e.brain.step(dt, ppos)
		if not e.is_boss:
			_separate(e)
		e.pos += e.vel * dt
		e.pos = e.pos.clamp(arena.position + Vector2(20, 20), arena.end - Vector2(20, 20))
	if any_dead:
		list = list.filter(func(x: Enemy) -> bool: return not x.dead)
	queue_redraw()
	_glow_layer.queue_redraw()


func _seek(e: Enemy, dir: Vector2, dt: float, turn: float) -> void:
	e.vel = e.vel.lerp(dir * e.speed, minf(1.0, dt * turn))


func _separate(e: Enemy) -> void:
	var key := Vector2i(floori(e.pos.x / CELL), floori(e.pos.y / CELL))
	var cell: Variant = grid.get(key)
	if cell == null:
		return
	for o: Enemy in cell:
		if o == e or o.is_boss:
			continue
		var d := e.pos - o.pos
		var rr := e.radius + o.radius
		var l2 := d.length_squared()
		if l2 < rr * rr and l2 > 0.01:
			var l := sqrt(l2)
			e.pos += d / l * (rr - l) * 0.35


func _build_grid() -> void:
	grid.clear()
	for e in list:
		if e.dead or e.is_boss:
			continue
		var key := Vector2i(floori(e.pos.x / CELL), floori(e.pos.y / CELL))
		var cell: Variant = grid.get(key)
		if cell == null:
			grid[key] = [e]
		else:
			cell.append(e)


# ---------------------------------------------------------------- queries
func nearest(p: Vector2, max_d: float) -> Enemy:
	var best: Enemy = null
	var bd := max_d * max_d
	for e in list:
		if e.dead or e.spawn > 0.0:
			continue
		var d := e.pos.distance_squared_to(p)
		if d < bd:
			bd = d
			best = e
	return best


func hit_circle(p: Vector2, r: float, exclude_uid := -1) -> Enemy:
	if boss and not boss.dead and boss.spawn <= 0.0 and boss.uid != exclude_uid:
		var rr := boss.radius + r
		if boss.pos.distance_squared_to(p) < rr * rr:
			return boss
	var cx := floori(p.x / CELL)
	var cy := floori(p.y / CELL)
	for y in range(cy - 1, cy + 2):
		for x in range(cx - 1, cx + 2):
			var cell: Variant = grid.get(Vector2i(x, y))
			if cell == null:
				continue
			for e: Enemy in cell:
				if e.dead or e.spawn > 0.0 or e.uid == exclude_uid:
					continue
				var rr := e.radius + r
				if e.pos.distance_squared_to(p) < rr * rr:
					return e
	return null


func contact(p: Vector2, r: float) -> bool:
	if boss and not boss.dead and boss.spawn <= 0.0:
		var br := boss.radius * 0.8 + r
		if boss.pos.distance_squared_to(p) < br * br:
			return true
	var cx := floori(p.x / CELL)
	var cy := floori(p.y / CELL)
	for y in range(cy - 1, cy + 2):
		for x in range(cx - 1, cx + 2):
			var cell: Variant = grid.get(Vector2i(x, y))
			if cell == null:
				continue
			for e: Enemy in cell:
				if e.dead or e.spawn > 0.0:
					continue
				var rr := e.radius * 0.75 + r
				if e.pos.distance_squared_to(p) < rr * rr:
					return true
	return false


# ---------------------------------------------------------------- damage
func damage(e: Enemy, amount: float, dir := Vector2.ZERO, show_number := true) -> void:
	if e.dead or e.spawn > 0.0:
		return
	if e.is_boss and e.brain.invuln > 0.0:
		return
	e.hp -= amount
	e.flash = 0.06
	if not e.is_boss:
		e.pos += dir * 3.0
	if show_number:
		fx.number(e.pos + Vector2(0, -e.radius), amount, Color(1, 1, 1, 0.9) if amount < 30 else Art.GOLD, 14 if amount < 30 else 18)
	if e.hp <= 0.0:
		kill(e)
	else:
		Sfx.play("hit", -20.0, 0.15)


func damage_radius(p: Vector2, r: float, amount: float, boss_amount := -1.0) -> void:
	for e in list:
		if e.dead or e.spawn > 0.0:
			continue
		var rr := r + e.radius
		if e.pos.distance_squared_to(p) < rr * rr:
			var a := amount if not e.is_boss or boss_amount < 0.0 else boss_amount
			damage(e, a, (e.pos - p).normalized() * 6.0)


func kill(e: Enemy) -> void:
	if e.dead:
		return
	e.dead = true
	if e.kind == "bloom" and e.spawn <= 0.0:
		var n: int = level.get("bloom_burst", 10)
		bullets.ring(e.pos, n, 150.0, randf() * TAU, 8.0, 4, 0.0, 0.0, 2)
		fx.ring(e.pos, 90.0, e.color, 0.4, 4.0)
	died.emit(e)


func clear_non_boss(give_xp: bool) -> void:
	for e in list:
		if not e.is_boss and not e.dead:
			e.dead = true
			if give_xp:
				died.emit(e)
			else:
				fx.explosion(e.pos, e.color, 0.6, hull(e))


# ---------------------------------------------------------------- drawing
## World-space outline of an enemy (used for debris shards on death).
func hull(e: Enemy) -> PackedVector2Array:
	if e.is_boss:
		return Art.xform(Art.shapes["star"], e.pos, e.rot, e.radius * 1.2)
	return Art.xform(e.shape, e.pos, e.rot, e.radius)


func _draw() -> void:
	var v := view.grow(80)
	var white := Color(1, 1, 1)
	for e in list:
		if e.dead or not v.has_point(e.pos):
			continue
		var c := e.color
		if e.is_boss:
			e.brain.draw(self)
			continue
		if e.spawn > 0.0:
			# warp-in telegraph: converging brackets + contracting ring
			var k := e.spawn / 0.7
			var a0 := k * 2.5
			for j in 4:
				var a := a0 + TAU * j / 4.0
				var d := e.radius * (1.2 + k * 4.0)
				draw_line(e.pos + Vector2.from_angle(a) * d, e.pos + Vector2.from_angle(a) * (d + e.radius), Color(c, 1.0 - k), 2.0, true)
			draw_arc(e.pos, e.radius * (1.0 + k * 2.5), 0, TAU, 32, Color(c, 0.8 * (1.0 - k)), 2.0, true)
			continue
		var r := e.radius * (1.0 + e.flash * 2.5)
		var pts := Art.xform(e.shape, e.pos, e.rot, r)
		var hot := e.fuse >= 0.0 and int(e.fuse * 20.0) % 2 == 0
		if e.flash > 0.0:
			Art.fan(self, pts, e.pos, white, Color(1, 1, 1, 0.75))
		else:
			Art.fan(self, pts, e.pos, Color(c.r * 0.6, c.g * 0.6, c.b * 0.65, 0.95), Color(c.r * 0.07, c.g * 0.07, c.b * 0.12, 0.95))
		Art.neon_line(self, pts, white if hot else c.lightened(0.2), 2.4)
		var inner := Art.xform(e.shape, e.pos, -e.rot * 1.5 + e.t * 2.0, r * 0.42)
		draw_polyline(Art.closed(inner), Color(c.lightened(0.6), 0.85), 1.4, true)
		draw_circle(e.pos, r * 0.15 * (1.0 + 0.25 * sin(e.t * 9.0)), Color(1, 1, 1, 0.95), true, -1.0, true)
		match e.kind:
			"spitter":
				# charge-up telegraph before each volley
				if e.fire_t < 0.45:
					var q := 1.0 - e.fire_t / 0.45
					draw_arc(e.pos, r * (2.2 - q * 1.0), 0, TAU, 28, Color(c.lightened(0.4), q), 2.0, true)
			"spinner":
				for j in 6:
					var a := -e.rot * 0.7 + TAU * j / 6.0
					draw_circle(e.pos + Vector2.from_angle(a) * r * 1.45, 2.2, Color(c.lightened(0.4), 0.9), true, -1.0, true)
		if (e.kind == "spinner" or e.kind == "spitter") and e.hp < e.max_hp:
			var w := e.radius * 2.0
			draw_rect(Rect2(e.pos + Vector2(-w * 0.5, e.radius + 9), Vector2(w, 3)), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(e.pos + Vector2(-w * 0.5, e.radius + 9), Vector2(w * e.hp / e.max_hp, 3)), c)


func _draw_glow() -> void:
	var v := view.grow(80)
	var tex := Art.atlas
	for e in list:
		if e.dead or not v.has_point(e.pos):
			continue
		var c := e.color
		if e.spawn > 0.0:
			var k := 1.0 - e.spawn / (1.6 if e.is_boss else 0.7)
			var g := e.radius * 3.0
			_glow_layer.draw_texture_rect_region(tex, Rect2(e.pos.x - g, e.pos.y - g, g * 2, g * 2), Art.R_SPARKLE, Color(c, k))
			continue
		var s := e.radius * (5.5 if e.is_boss else 3.4)
		if e.fuse >= 0.0:
			c = Color(1, 0.3, 0.2)
			s *= 1.6
		_glow_layer.draw_texture_rect_region(tex, Rect2(e.pos.x - s, e.pos.y - s, s * 2, s * 2), Art.R_ORB_GLOW, Color(c, 0.4))
		if e.kind == "drone" or e.kind == "mite":
			# thruster flame behind fast movers
			var back := e.pos - Vector2.from_angle(e.rot) * e.radius * 1.1
			var f := e.radius * (1.0 + 0.25 * sin(e.t * 30.0 + e.uid))
			_glow_layer.draw_texture_rect_region(tex, Rect2(back.x - f, back.y - f, f * 2, f * 2), Art.R_ORB_GLOW, Color(1.0, 0.6, 0.3, 0.6))
		if e.is_boss:
			var s2 := e.radius * 9.0
			_glow_layer.draw_texture_rect_region(tex, Rect2(e.pos.x - s2, e.pos.y - s2, s2 * 2, s2 * 2), Art.R_SOFT, Color(c, 0.25))