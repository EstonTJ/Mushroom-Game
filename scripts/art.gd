extends RefCounted
## Drawn-in-code art. Every function takes the CanvasItem to draw on, so call
## them from _draw(). Swap for real sprites later without touching game logic.

const INK := Color("1c1526")

static var _soft: GradientTexture2D


static func fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


static func ellipse(center: Vector2, rx: float, ry: float, n: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


static func outline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	if pts.size() < 2:
		return
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, color, width, true)


## A soft round falloff, used for glows, light pools, smoke and clouds.
static func soft_texture() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(0.5, 0.0)
		_soft.width = 128
		_soft.height = 128
	return _soft


static func glow(ci: CanvasItem, pos: Vector2, r: float, color: Color) -> void:
	ci.draw_texture_rect(soft_texture(), Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, color)


static func shadow(ci: CanvasItem, pos: Vector2, rx: float, ry: float, a: float = 1.0) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	ci.draw_colored_polygon(ellipse(pos, rx, ry, 20), Color(0, 0, 0, 0.28 * a))


## Draws a mushroom ingredient by id (a key of Data.ingredients). pos is the
## ground point (stem base sits just below it); s is the overall size.
static func ingredient(ci: CanvasItem, id: String, pos: Vector2, s: float, a: float = 1.0) -> void:
	if s < 2.0 or a <= 0.0:
		return
	match id:
		"puffball":
			_puffball(ci, pos, s, a)
		"fly_agaric":
			_fly_agaric(ci, pos, s, a)
		"chanterelle":
			_chanterelle(ci, pos, s, a)
		"ghost_fungus":
			_ghost_fungus(ci, pos, s, a)
		"shaggy_ink_cap":
			_ink_cap(ci, pos, s, a)
		"scarlet_elf_cup":
			_elf_cup(ci, pos, s, a)
		"turkey_tail":
			_turkey_tail(ci, pos, s, a)
		"amethyst_deceiver":
			mushroom(ci, pos, s * 0.92, Color("8a4fc8"), a, false, false, Color("a878d8"))
			ci.draw_line(pos + Vector2(-s * 0.04, s * 0.2), pos + Vector2(-s * 0.03, -s * 0.2), fade(Color("7a48b0"), a), 1.2, true)
			ci.draw_line(pos + Vector2(s * 0.05, s * 0.2), pos + Vector2(s * 0.04, -s * 0.2), fade(Color("7a48b0"), a), 1.2, true)
		"morel":
			_morel(ci, pos, s, a)
		"chicken_of_the_woods":
			_chicken(ci, pos, s, a)
		"indigo_milk_cap":
			_milk_cap(ci, pos, s, a)
		"porcini":
			_porcini(ci, pos, s, a)
		"parasol":
			_parasol(ci, pos, s, a)
		"lions_mane":
			_lions_mane(ci, pos, s, a)
		"bleeding_tooth":
			_bleeding_tooth(ci, pos, s, a)
		_:
			mushroom(ci, pos, s, Color("b58fd6"), a)


static func _stem(ci: CanvasItem, pos: Vector2, s: float, a: float, top_y: float, w_top: float, w_bot: float, color: Color) -> void:
	var pts := PackedVector2Array([pos + Vector2(-w_bot, s * 0.25), pos + Vector2(-w_top, top_y), pos + Vector2(w_top, top_y),
		pos + Vector2(w_bot, s * 0.25)])
	ci.draw_colored_polygon(pts, fade(color, a))
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(w_bot * 0.25, s * 0.25), pos + Vector2(w_top * 0.25, top_y),
		pos + Vector2(w_top, top_y), pos + Vector2(w_bot, s * 0.25)]), fade(color.darkened(0.15), a))
	outline(ci, pts, fade(INK, 0.55 * a), maxf(1.2, s * 0.03))


static func _puffball(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	var cream := Color("efe6cf")
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.36, s * 0.08, a)
	_stem(ci, pos, s, a, s * 0.02, s * 0.12, s * 0.18, Color("e0d4b4"))
	var c := pos + Vector2(0, -s * 0.22)
	var ball := ellipse(c, s * 0.4, s * 0.36, 28)
	ci.draw_colored_polygon(ball, fade(cream, a))
	ci.draw_colored_polygon(ellipse(c + Vector2(s * 0.08, s * 0.08), s * 0.28, s * 0.24, 20), fade(Color("ddd0ae"), 0.7 * a))
	ci.draw_colored_polygon(ellipse(c + Vector2(-s * 0.13, -s * 0.13), s * 0.14, s * 0.09, 14), fade(Color.WHITE, 0.7 * a))
	for k in 16:
		var p := Vector2(sin(k * 12.9898) * 0.3, sin(k * 78.233) * 0.27)
		ci.draw_circle(c + p * s, s * 0.022, fade(Color("c8b890"), a))
	ci.draw_colored_polygon(ellipse(c + Vector2(0, -s * 0.3), s * 0.06, s * 0.025, 10), fade(Color("7a6a4a"), a))
	ci.draw_circle(c + Vector2(-s * 0.02, -s * 0.42), s * 0.035, fade(Color("a89878"), 0.5 * a))
	ci.draw_circle(c + Vector2(s * 0.05, -s * 0.5), s * 0.025, fade(Color("a89878"), 0.35 * a))
	outline(ci, ball, fade(INK, 0.55 * a), maxf(1.2, s * 0.03))


static func _fly_agaric(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	ci.draw_colored_polygon(ellipse(pos + Vector2(0, s * 0.2), s * 0.19, s * 0.09, 14), fade(Color("f5efe0"), a))
	mushroom(ci, pos, s, Color("d8322a"), a)
	var dot := fade(Color(1, 0.98, 0.92), a)
	for p in [Vector2(-0.14, -0.6), Vector2(0.2, -0.58), Vector2(-0.4, -0.3), Vector2(0.42, -0.3), Vector2(0.12, -0.36)]:
		ci.draw_circle(pos + p * s, s * 0.045, dot)
	ci.draw_colored_polygon(ellipse(pos + Vector2(0, -s * 0.12), s * 0.17, s * 0.045, 14), fade(Color("f5efe0"), a))
	outline(ci, ellipse(pos + Vector2(0, -s * 0.12), s * 0.17, s * 0.045, 14), fade(INK, 0.4 * a), 1.0)


static func _chanterelle(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	var gold := Color("f0b23a")
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.3, s * 0.07, a)
	var body := PackedVector2Array([pos + Vector2(-s * 0.1, s * 0.25), pos + Vector2(-s * 0.13, s * 0.02), pos + Vector2(-s * 0.28, -s * 0.24),
		pos + Vector2(-s * 0.5, -s * 0.42), pos + Vector2(s * 0.5, -s * 0.42), pos + Vector2(s * 0.28, -s * 0.24),
		pos + Vector2(s * 0.13, s * 0.02), pos + Vector2(s * 0.1, s * 0.25)])
	ci.draw_colored_polygon(body, fade(gold, a))
	for k in 7:
		var x := -0.4 + k * 0.133
		ci.draw_line(pos + Vector2(x * 0.25 * s, s * 0.05), pos + Vector2(x * s, -s * 0.4), fade(Color("d8902a"), a), maxf(1.0, s * 0.025), true)
	outline(ci, body, fade(INK, 0.55 * a), maxf(1.2, s * 0.03))
	var lip := PackedVector2Array()
	for i in 28:
		var ang := TAU * i / 28.0
		var w := 1.0 + 0.07 * sin(ang * 6.0)
		lip.append(pos + Vector2(0, -s * 0.44) + Vector2(cos(ang) * s * 0.52 * w, sin(ang) * s * 0.13 * w))
	ci.draw_colored_polygon(lip, fade(gold.lightened(0.1), a))
	ci.draw_colored_polygon(ellipse(pos + Vector2(0, -s * 0.45), s * 0.3, s * 0.07, 18), fade(Color("c8861a"), a))
	outline(ci, lip, fade(INK, 0.55 * a), maxf(1.2, s * 0.03))


static func _fan(ci: CanvasItem, base: Vector2, r: float, a0: float, a1: float, color: Color, a: float) -> PackedVector2Array:
	var pts := PackedVector2Array([base])
	for i in 13:
		var ang := lerpf(a0, a1, i / 12.0)
		pts.append(base + Vector2.from_angle(ang) * r * (1.0 + 0.05 * sin(ang * 9.0)))
	ci.draw_colored_polygon(pts, fade(color, a))
	return pts


static func _ghost_fungus(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	glow(ci, pos + Vector2(0, -s * 0.3), s * 1.1, Color(0.55, 1.0, 0.65, 0.45 * a))
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.34, s * 0.07, a)
	for f in [[Vector2(-0.16, 0.2), 0.42, PI * 1.05, PI * 1.6], [Vector2(0.14, 0.22), 0.46, PI * 1.4, PI * 1.95], [Vector2(0.0, 0.25), 0.5, PI * 1.2, PI * 1.8]]:
		var base: Vector2 = pos + f[0] * s
		var pts := _fan(ci, base, s * f[1], f[2], f[3], Color("c8f5d8"), a)
		for k in range(2, 12, 2):
			ci.draw_line(base, pts[k], fade(Color("9ad8b0"), a), 1.0, true)
		outline(ci, pts, fade(Color("2a4a38"), 0.6 * a), maxf(1.2, s * 0.03))


static func _ink_cap(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.24, s * 0.06, a)
	_stem(ci, pos, s, a, s * 0.0, s * 0.06, s * 0.08, Color("f5f2ea"))
	var cap := PackedVector2Array([pos + Vector2(-s * 0.22, s * 0.04)])
	for i in 15:
		var ang := PI + PI * i / 14.0
		cap.append(pos + Vector2(cos(ang) * s * 0.22, -s * 0.55 + sin(ang) * s * 0.28))
	cap.append(pos + Vector2(s * 0.22, s * 0.04))
	ci.draw_colored_polygon(cap, fade(Color("f2efe8"), a))
	ci.draw_colored_polygon(ellipse(pos + Vector2(0, -s * 0.78), s * 0.12, s * 0.06, 12), fade(Color("d8c8a8"), a))
	for row in 5:
		for col in 3:
			var p := pos + Vector2((-0.12 + col * 0.12 + (row % 2) * 0.06) * s, (-0.6 + row * 0.13) * s)
			ci.draw_polyline(PackedVector2Array([p + Vector2(-s * 0.035, -s * 0.03), p, p + Vector2(s * 0.035, -s * 0.03)]),
				fade(Color("b8a888"), a), maxf(1.0, s * 0.02), true)
	ci.draw_rect(Rect2(pos.x - s * 0.22, pos.y - s * 0.02, s * 0.44, s * 0.06), fade(Color("2a2a30"), a))
	for x in [-0.15, 0.02, 0.14]:
		ci.draw_colored_polygon(ellipse(pos + Vector2(x * s, s * 0.08), s * 0.025, s * 0.045, 8), fade(Color("2a2a30"), a))
	outline(ci, cap, fade(INK, 0.55 * a), maxf(1.2, s * 0.03))


static func _elf_cup(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.46, s * 0.07, a)
	ci.draw_line(pos + Vector2(-s * 0.48, s * 0.2), pos + Vector2(s * 0.48, s * 0.1), fade(Color("6a4a30"), a), s * 0.08, true)
	for m in [Vector2(-0.3, 0.14), Vector2(0.05, 0.14), Vector2(0.36, 0.09)]:
		ci.draw_circle(pos + m * s, s * 0.06, fade(Color("6f9a4a"), a))
	for cup in [[Vector2(-0.24, 0.04), 0.26], [Vector2(0.34, 0.06), 0.2], [Vector2(0.08, -0.04), 0.34]]:
		var c: Vector2 = pos + cup[0] * s
		var r: float = cup[1] * s
		var bowl := PackedVector2Array()
		for i in 13:
			var ang := PI * i / 12.0
			bowl.append(c + Vector2(cos(ang) * r, sin(ang) * r * 0.8 - r * 0.3))
		ci.draw_colored_polygon(bowl, fade(Color("e86a78"), a))
		ci.draw_colored_polygon(ellipse(c + Vector2(0, -r * 0.3), r, r * 0.36, 18), fade(Color("e0283a"), a))
		ci.draw_colored_polygon(ellipse(c + Vector2(0, -r * 0.26), r * 0.6, r * 0.2, 14), fade(Color("a8182a"), a))
		outline(ci, ellipse(c + Vector2(0, -r * 0.3), r, r * 0.36, 18), fade(INK, 0.55 * a), maxf(1.0, s * 0.025))


static func _turkey_tail(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.44, s * 0.07, a)
	ci.draw_rect(Rect2(pos.x - s * 0.12, pos.y + s * 0.02, s * 0.24, s * 0.22), fade(Color("5a4030"), a))
	var bands := [Color("e8dcc0"), Color("8a6a4a"), Color("5a6a80"), Color("c8a878"), Color("6a4a32"), Color("a8845c")]
	for fan in [[Vector2(0.18, 0.1), 0.34], [Vector2(-0.06, 0.06), 0.5]]:
		var base: Vector2 = pos + fan[0] * s
		var r: float = fan[1] * s
		var outer := PackedVector2Array()
		for k in bands.size():
			var pts := _fan(ci, base, r * (1.0 - k * 0.15), PI * 1.08, PI * 1.92, bands[k], a)
			if k == 0:
				outer = pts
		outline(ci, outer, fade(INK, 0.55 * a), maxf(1.2, s * 0.03))


static func _morel(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.26, s * 0.06, a)
	_stem(ci, pos, s, a, -s * 0.18, s * 0.13, s * 0.16, Color("efe3c8"))
	var c := pos + Vector2(0, -s * 0.46)
	var cap := ellipse(c, s * 0.26, s * 0.36, 24)
	ci.draw_colored_polygon(cap, fade(Color("c8a068"), a))
	for row in 6:
		for col in 4:
			var p := Vector2((-0.15 + col * 0.1 + (row % 2) * 0.05), (-0.27 + row * 0.1))
			if (p / Vector2(0.24, 0.33)).length() < 0.9:
				ci.draw_colored_polygon(ellipse(c + p * s, s * 0.035, s * 0.03, 8), fade(Color("6a4a2a"), a))
	outline(ci, cap, fade(INK, 0.55 * a), maxf(1.2, s * 0.03))


static func _chicken(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.44, s * 0.07, a)
	var bark := Rect2(pos.x - s * 0.44, pos.y - s * 0.78, s * 0.2, s * 1.03)
	ci.draw_rect(bark, fade(Color("5a4030"), a))
	ci.draw_line(Vector2(bark.position.x + s * 0.07, bark.position.y), Vector2(bark.position.x + s * 0.08, bark.end.y), fade(Color("3e2c20"), a), 2.0)
	ci.draw_line(Vector2(bark.position.x + s * 0.14, bark.position.y), Vector2(bark.position.x + s * 0.13, bark.end.y), fade(Color("3e2c20"), a), 2.0)
	for shelf in [[-0.56, 0.5], [-0.28, 0.62], [0.02, 0.46]]:
		var base := Vector2(bark.end.x - s * 0.02, pos.y + float(shelf[0]) * s)
		var r: float = float(shelf[1]) * s
		var pts := _fan(ci, base, r, -0.85, 0.75, Color("f5902a"), a)
		var rim := PackedVector2Array()
		for i in range(1, pts.size()):
			rim.append(base + (pts[i] - base) * 0.88)
		ci.draw_polyline(rim, fade(Color("f5d23a"), a), maxf(2.0, s * 0.06), true)
		ci.draw_colored_polygon(ellipse(base + Vector2(r * 0.35, -r * 0.2), r * 0.18, r * 0.07, 10), fade(Color("ffb860"), 0.8 * a))
		outline(ci, pts, fade(INK, 0.55 * a), maxf(1.2, s * 0.03))


static func _milk_cap(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.34, s * 0.07, a)
	_stem(ci, pos, s, a, -s * 0.28, s * 0.1, s * 0.13, Color("8aa0d8"))
	var cap := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		cap.append(pos + Vector2(cos(ang) * s * 0.55, -s * 0.28 + sin(ang) * s * 0.3))
	ci.draw_colored_polygon(cap, fade(Color("4a6ad0"), a))
	for k in 3:
		var r := 0.45 - k * 0.13
		ci.draw_arc(pos + Vector2(0, -s * 0.28), s * r, PI * 1.1, PI * 1.9, 12, fade(Color("2e48a8"), a), maxf(1.0, s * 0.025), true)
	ci.draw_colored_polygon(ellipse(pos + Vector2(0, -s * 0.52), s * 0.16, s * 0.04, 12), fade(Color("2e48a8"), a))
	outline(ci, cap, fade(INK, 0.55 * a), maxf(1.2, s * 0.03))
	var drop := pos + Vector2(s * 0.46, -s * 0.18)
	ci.draw_circle(drop, s * 0.05, fade(Color("6a8ae0"), a))
	ci.draw_colored_polygon(PackedVector2Array([drop + Vector2(-s * 0.045, -s * 0.01), drop + Vector2(0, -s * 0.09),
		drop + Vector2(s * 0.045, -s * 0.01)]), fade(Color("6a8ae0"), a))


static func _porcini(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.4, s * 0.08, a)
	var stem := PackedVector2Array([pos + Vector2(-s * 0.18, s * 0.25), pos + Vector2(-s * 0.26, s * 0.02), pos + Vector2(-s * 0.16, -s * 0.24),
		pos + Vector2(s * 0.16, -s * 0.24), pos + Vector2(s * 0.26, s * 0.02), pos + Vector2(s * 0.18, s * 0.25)])
	ci.draw_colored_polygon(stem, fade(Color("efe3c8"), a))
	for k in 4:
		ci.draw_line(pos + Vector2(-s * 0.18, -s * 0.12 + k * s * 0.08), pos + Vector2(s * 0.18, -s * 0.16 + k * s * 0.08),
			fade(Color("d8c8a0"), a), 1.0, true)
	outline(ci, stem, fade(INK, 0.55 * a), maxf(1.2, s * 0.03))
	ci.draw_colored_polygon(ellipse(pos + Vector2(0, -s * 0.24), s * 0.48, s * 0.08, 20), fade(Color("e8d8a0"), a))
	var cap := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		cap.append(pos + Vector2(cos(ang) * s * 0.52, -s * 0.26 + sin(ang) * s * 0.46))
	ci.draw_colored_polygon(cap, fade(Color("8a5a32"), a))
	ci.draw_colored_polygon(ellipse(pos + Vector2(-s * 0.16, -s * 0.56), s * 0.16, s * 0.07, 12), fade(Color("b88a5a"), 0.8 * a))
	outline(ci, cap, fade(INK, 0.6 * a), maxf(1.2, s * 0.035))


static func _parasol(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.24, s * 0.06, a)
	_stem(ci, pos, s, a, -s * 0.55, s * 0.05, s * 0.08, Color("e8dcc0"))
	for k in 5:
		var y := s * (0.12 - k * 0.12)
		ci.draw_polyline(PackedVector2Array([pos + Vector2(-s * 0.05, y), pos + Vector2(0, y + s * 0.03), pos + Vector2(s * 0.05, y)]),
			fade(Color("8a6a48"), a), maxf(1.0, s * 0.02), true)
	ci.draw_colored_polygon(ellipse(pos + Vector2(0, -s * 0.3), s * 0.11, s * 0.035, 12), fade(Color("f5efe0"), a))
	var cap := PackedVector2Array([pos + Vector2(-s * 0.58, -s * 0.5), pos + Vector2(-s * 0.3, -s * 0.66), pos + Vector2(0, -s * 0.76),
		pos + Vector2(s * 0.3, -s * 0.66), pos + Vector2(s * 0.58, -s * 0.5), pos + Vector2(0, -s * 0.54)])
	ci.draw_colored_polygon(cap, fade(Color("d8c098"), a))
	for p in [Vector2(-0.34, -0.58), Vector2(-0.16, -0.64), Vector2(0.16, -0.64), Vector2(0.34, -0.58), Vector2(-0.45, -0.53),
			Vector2(0.45, -0.53), Vector2(0.0, -0.62)]:
		ci.draw_colored_polygon(ellipse(pos + p * s, s * 0.04, s * 0.02, 8), fade(Color("8a6a48"), a))
	ci.draw_colored_polygon(ellipse(pos + Vector2(0, -s * 0.74), s * 0.09, s * 0.04, 10), fade(Color("6a4a30"), a))
	outline(ci, cap, fade(INK, 0.55 * a), maxf(1.2, s * 0.03))


static func _lions_mane(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.4, s * 0.07, a)
	var c := pos + Vector2(0, -s * 0.36)
	ci.draw_colored_polygon(ellipse(c, s * 0.4, s * 0.3, 24), fade(Color("f5efe0"), a))
	for k in 24:
		var x := -0.38 + k * 0.033
		var top := c + Vector2(x * s, -s * 0.05 + absf(x) * s * 0.3)
		var length := s * (0.3 + 0.12 * sin(k * 2.7))
		var tip := top + Vector2(sin(k * 1.3) * s * 0.03, length)
		ci.draw_line(top, tip, fade(Color("e0d8c0") if k % 2 == 0 else Color("fffaf0"), a), maxf(1.5, s * 0.035), true)
	ci.draw_colored_polygon(ellipse(c + Vector2(-s * 0.12, -s * 0.12), s * 0.14, s * 0.07, 12), fade(Color.WHITE, 0.6 * a))
	outline(ci, ellipse(c, s * 0.4, s * 0.3, 24), fade(INK, 0.35 * a), maxf(1.0, s * 0.025))


static func _bleeding_tooth(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.36, s * 0.07, a)
	_stem(ci, pos, s, a, -s * 0.12, s * 0.12, s * 0.16, Color("b88a7a"))
	var cap := PackedVector2Array()
	for i in 22:
		var ang := PI + PI * i / 21.0
		var w := 1.0 + 0.08 * sin(ang * 7.0)
		cap.append(pos + Vector2(cos(ang) * s * 0.5 * w, -s * 0.14 + sin(ang) * s * 0.4 * w))
	ci.draw_colored_polygon(cap, fade(Color("f2e4e0"), a))
	ci.draw_colored_polygon(ellipse(pos + Vector2(s * 0.12, -s * 0.3), s * 0.26, s * 0.14, 14), fade(Color("e8c8c8"), 0.6 * a))
	for p in [Vector2(-0.22, -0.34), Vector2(0.05, -0.44), Vector2(0.26, -0.3), Vector2(-0.05, -0.24), Vector2(0.18, -0.46)]:
		var d: Vector2 = pos + p * s
		ci.draw_circle(d, s * 0.055, fade(Color("c82838"), a))
		ci.draw_circle(d + Vector2(-s * 0.018, -s * 0.018), s * 0.018, fade(Color.WHITE, 0.8 * a))
	outline(ci, cap, fade(INK, 0.55 * a), maxf(1.2, s * 0.03))


## Toadstool with a shaded stem, gills, a shaded dome, a highlight and spots.
## pos is where the stem meets the ground.
static func mushroom(ci: CanvasItem, pos: Vector2, s: float, cap: Color, a: float = 1.0, glow_on: bool = false,
		spots: bool = true, stem_color: Color = Color("efe3c8")) -> void:
	var line_w := maxf(1.2, s * 0.035)
	if glow_on:
		glow(ci, pos + Vector2(0, -s * 0.35), s * 1.1, fade(cap, 0.45 * a))
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.34, s * 0.08, a)

	var stem := PackedVector2Array([pos + Vector2(-s * 0.14, s * 0.25), pos + Vector2(-s * 0.10, -s * 0.28),
		pos + Vector2(s * 0.10, -s * 0.28), pos + Vector2(s * 0.15, s * 0.25)])
	ci.draw_colored_polygon(stem, fade(stem_color, a))
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(s * 0.03, s * 0.25), pos + Vector2(s * 0.03, -s * 0.28),
		pos + Vector2(s * 0.10, -s * 0.28), pos + Vector2(s * 0.15, s * 0.25)]), fade(stem_color.darkened(0.15), a))
	outline(ci, stem, fade(INK, 0.55 * a), line_w)

	ci.draw_colored_polygon(ellipse(pos + Vector2(0, -s * 0.27), s * 0.5, s * 0.09, 20), fade(cap.darkened(0.45), a))
	var dome := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		dome.append(pos + Vector2(cos(ang) * s * 0.58, sin(ang) * s * 0.52 - s * 0.27))
	ci.draw_colored_polygon(dome, fade(cap, a))
	var shade := PackedVector2Array()
	for i in 9:
		var ang := PI * 1.6 + PI * 0.4 * i / 8.0
		shade.append(pos + Vector2(cos(ang) * s * 0.58, sin(ang) * s * 0.52 - s * 0.27))
	shade.append(pos + Vector2(s * 0.25, -s * 0.27))
	ci.draw_colored_polygon(shade, fade(cap.darkened(0.18), a))
	ci.draw_colored_polygon(ellipse(pos + Vector2(-s * 0.2, -s * 0.58), s * 0.16, s * 0.08, 14), fade(cap.lightened(0.45), 0.8 * a))

	var dot := fade(Color(1, 0.98, 0.92, 0.9), a if spots else 0.0)
	ci.draw_circle(pos + Vector2(-s * 0.3, -s * 0.42), s * 0.07, dot)
	ci.draw_circle(pos + Vector2(s * 0.05, -s * 0.64), s * 0.06, dot)
	ci.draw_circle(pos + Vector2(s * 0.32, -s * 0.42), s * 0.08, dot)
	ci.draw_circle(pos + Vector2(-s * 0.02, -s * 0.42), s * 0.045, dot)
	outline(ci, dome, fade(INK, 0.6 * a), line_w)


## Round flask with a cork, liquid up to a fill line, bubbles and a glass shine.
static func bottle(ci: CanvasItem, pos: Vector2, s: float, color: Color, a: float = 1.0) -> void:
	if s < 2.0 or a <= 0.0:
		return
	var ink := fade(INK, 0.7 * a)
	var line_w := maxf(1.2, s * 0.035)
	var glass := fade(Color(0.82, 0.92, 0.95, 0.35), a)
	var c := pos + Vector2(0, s * 0.14)
	var r := s * 0.3
	shadow(ci, pos + Vector2(0, s * 0.44), s * 0.26, s * 0.07, a)

	ci.draw_circle(c, r, glass)
	var level := c.y - r * 0.15
	var theta := asin(clampf((c.y - level) / r, -1.0, 1.0))
	var liquid := PackedVector2Array()
	for i in 17:
		var ang := lerpf(-theta, PI + theta, i / 16.0)
		liquid.append(c + Vector2(cos(ang), sin(ang)) * r * 0.9)
	ci.draw_colored_polygon(liquid, fade(color, a))
	ci.draw_line(liquid[0], liquid[16], fade(color.lightened(0.4), a), line_w, true)
	ci.draw_circle(c + Vector2(-r * 0.25, r * 0.35), r * 0.1, fade(color.lightened(0.5), 0.8 * a))
	ci.draw_circle(c + Vector2(r * 0.22, r * 0.18), r * 0.07, fade(color.lightened(0.5), 0.8 * a))
	ci.draw_arc(c, r * 0.72, PI * 1.1, PI * 1.45, 8, fade(Color.WHITE, 0.75 * a), maxf(1.5, s * 0.05), true)
	ci.draw_arc(c, r, 0, TAU, 32, ink, line_w, true)

	var neck := Rect2(pos.x - s * 0.09, pos.y - s * 0.38, s * 0.18, s * 0.24)
	ci.draw_rect(neck, glass)
	ci.draw_line(neck.position, neck.position + Vector2(0, neck.size.y), ink, line_w, true)
	ci.draw_line(neck.position + Vector2(neck.size.x, 0), neck.end, ink, line_w, true)
	var cork := Rect2(pos.x - s * 0.12, pos.y - s * 0.5, s * 0.24, s * 0.14)
	ci.draw_rect(cork, fade(Color("9a6b45"), a))
	ci.draw_rect(Rect2(cork.position, Vector2(cork.size.x, cork.size.y * 0.35)), fade(Color("b98a5e"), a))
	ci.draw_rect(cork, ink, false, line_w)


## Night creatures. kind is a key of Data.creatures. pos is where the creature
## stands; s is its size. t drives walk cycles and flapping (pass the same t
## every frame for smooth animation).
static func creature(ci: CanvasItem, kind: String, pos: Vector2, s: float, a: float = 1.0, t: float = 0.0, blink: bool = false) -> void:
	if s < 2.0 or a <= 0.0:
		return
	match kind:
		"scuttler":
			_scuttler(ci, pos, s, a, t, blink)
		"stumpling":
			_stumpling(ci, pos, s, a, t, blink)
		"moth":
			_moth(ci, pos, s, a, t, blink)
		_:
			_mischief(ci, pos, s, a, t, blink)


## Where each creature's eyes are, so a light layer can make them glow.
static func creature_eyes(kind: String, pos: Vector2, s: float, t: float) -> Array:
	match kind:
		"scuttler":
			return [pos + Vector2(-s * 0.07, -s * 0.37), pos + Vector2(s * 0.07, -s * 0.37)]
		"stumpling":
			return [pos + Vector2(-s * 0.14, -s * 0.08), pos + Vector2(s * 0.14, -s * 0.08)]
		"moth":
			var c := pos + Vector2(0, moth_lift(s, t))
			return [c + Vector2(-s * 0.05, -s * 0.3), c + Vector2(s * 0.05, -s * 0.3)]
		_:
			return [pos + Vector2(-s * 0.09, -s * 0.3), pos + Vector2(s * 0.09, -s * 0.3)]


static func moth_lift(s: float, t: float) -> float:
	return -s * 0.6 + sin(t * 4.0) * s * 0.08


static func _eyes(ci: CanvasItem, pts: Array, r: float, color: Color, blink: bool, a: float, line_w: float) -> void:
	for e in pts:
		if blink:
			ci.draw_line(e + Vector2(-r * 1.4, 0), e + Vector2(r * 1.4, 0), fade(color, a), line_w, true)
		else:
			ci.draw_circle(e, r, fade(color, a))
			ci.draw_circle(e + Vector2(-r * 0.35, -r * 0.35), r * 0.35, fade(Color.WHITE, 0.9 * a))


## Hooded prankster: pointed floppy hood, swaying cloak hem, glowing eyes in a
## dark face, little arms and feet.
static func _mischief(ci: CanvasItem, pos: Vector2, s: float, a: float, t: float, blink: bool) -> void:
	var cloak := fade(Color("2a2240"), a)
	var shade := fade(Color("1a1430"), a)
	var trim := fade(Color("5b4a86"), a)
	var line_w := maxf(1.5, s * 0.05)
	var step := sin(t * 14.0)
	shadow(ci, pos + Vector2(0, s * 0.5), s * 0.44, s * 0.1, a)
	for side in [-1.0, 1.0]:
		var lift := maxf(0.0, step * side) * s * 0.08
		ci.draw_colored_polygon(ellipse(pos + Vector2(side * s * 0.18, s * 0.47 - lift), s * 0.13, s * 0.07, 12), shade)
	for side in [-1.0, 1.0]:
		ci.draw_circle(pos + Vector2(side * s * 0.47, s * 0.02 - step * side * s * 0.06), s * 0.1, shade)

	var hem := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		hem.append(pos + Vector2(s * (0.52 - 1.04 * u), s * (0.44 + 0.05 * sin(t * 8.0 + u * 9.0))))
	var body := PackedVector2Array([pos + Vector2(s * 0.32, -s * 1.0), pos + Vector2(s * 0.24, -s * 0.72),
		pos + Vector2(s * 0.3, -s * 0.42), pos + Vector2(s * 0.42, s * 0.05), pos + Vector2(s * 0.52, s * 0.38)])
	body.append_array(hem)
	body.append_array(PackedVector2Array([pos + Vector2(-s * 0.52, s * 0.38), pos + Vector2(-s * 0.42, s * 0.05),
		pos + Vector2(-s * 0.3, -s * 0.42), pos + Vector2(-s * 0.18, -s * 0.78), pos + Vector2(s * 0.05, -s * 0.93)]))
	ci.draw_colored_polygon(body, cloak)
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(s * 0.24, -s * 0.72), pos + Vector2(s * 0.3, -s * 0.42),
		pos + Vector2(s * 0.42, s * 0.05), pos + Vector2(s * 0.52, s * 0.4), pos + Vector2(s * 0.3, s * 0.42),
		pos + Vector2(s * 0.2, 0.0), pos + Vector2(s * 0.14, -s * 0.5)]), fade(shade, 0.7))
	outline(ci, body, fade(INK, 0.9 * a), line_w)
	var trim_line := PackedVector2Array()
	for p in hem:
		trim_line.append(p + Vector2(0, -s * 0.05))
	ci.draw_polyline(trim_line, trim, line_w * 1.2, true)
	ci.draw_line(pos + Vector2(-s * 0.22, s * 0.12), pos + Vector2(-s * 0.08, s * 0.2), trim, line_w * 0.8, true)
	ci.draw_line(pos + Vector2(-s * 0.18, s * 0.2), pos + Vector2(-s * 0.12, s * 0.1), trim, line_w * 0.8, true)

	var face := pos + Vector2(0, -s * 0.3)
	ci.draw_colored_polygon(ellipse(face, s * 0.2, s * 0.17, 20), fade(Color("0d0a14"), a))
	_eyes(ci, creature_eyes("mischief", pos, s, t), s * 0.055, Color("ffd66b"), blink, a, line_w)


## Beetle-spider: violet shell with a sheen, six scuttling legs, antennae.
static func _scuttler(ci: CanvasItem, pos: Vector2, s: float, a: float, t: float, blink: bool) -> void:
	var shell := fade(Color("2e2448"), a)
	var dark := fade(Color("140f20"), a)
	var line_w := maxf(1.5, s * 0.06)
	shadow(ci, pos + Vector2(0, s * 0.32), s * 0.58, s * 0.14, a)
	for side in [-1.0, 1.0]:
		for j in 3:
			var ph := sin(t * 30.0 + j * 2.1 + side)
			var base := pos + Vector2(side * s * 0.22, (j - 1) * s * 0.18)
			var knee := pos + Vector2(side * s * 0.56, (j - 1) * s * 0.22 - s * 0.14 + ph * s * 0.06)
			var foot := pos + Vector2(side * s * 0.74, (j - 1) * s * 0.3 + s * 0.08 - ph * s * 0.06)
			ci.draw_polyline(PackedVector2Array([base, knee, foot]), dark, line_w, true)
	var body := ellipse(pos, s * 0.38, s * 0.32, 24)
	ci.draw_colored_polygon(body, shell)
	ci.draw_colored_polygon(ellipse(pos + Vector2(s * 0.12, s * 0.08), s * 0.2, s * 0.18, 16), fade(Color("221a38"), a))
	ci.draw_line(pos + Vector2(0, -s * 0.3), pos + Vector2(0, s * 0.31), dark, maxf(1.0, s * 0.04), true)
	ci.draw_arc(pos + Vector2(-s * 0.08, -s * 0.04), s * 0.22, PI * 1.05, PI * 1.55, 8, fade(Color("8a78c8"), 0.85 * a), line_w, true)
	ci.draw_circle(pos + Vector2(-s * 0.18, s * 0.1), s * 0.05, fade(Color("5b4a86"), a))
	ci.draw_circle(pos + Vector2(s * 0.16, -s * 0.12), s * 0.04, fade(Color("5b4a86"), a))
	outline(ci, body, dark, line_w)
	var head := pos + Vector2(0, -s * 0.34)
	for side in [-1.0, 1.0]:
		ci.draw_polyline(PackedVector2Array([head + Vector2(side * s * 0.06, -s * 0.08), head + Vector2(side * s * 0.16, -s * 0.3),
			head + Vector2(side * s * 0.26, -s * 0.28 + sin(t * 9.0 + side) * s * 0.04)]), dark, maxf(1.0, s * 0.035), true)
	ci.draw_circle(head, s * 0.17, dark)
	_eyes(ci, creature_eyes("scuttler", pos, s, t), s * 0.055, Color("ffb04a"), blink, a, line_w)


## Walking tree stump: bark with grooves, a cut top with rings, moss and a
## tiny toadstool, root legs, twig arms and a grumpy face.
static func _stumpling(ci: CanvasItem, pos: Vector2, s: float, a: float, t: float, blink: bool) -> void:
	var bark := fade(Color("5a4030"), a)
	var bark_dark := fade(Color("3e2c20"), a)
	var line_w := maxf(1.5, s * 0.035)
	var step := sin(t * 7.0)
	shadow(ci, pos + Vector2(0, s * 0.47), s * 0.52, s * 0.11, a)
	for side in [-1.0, 1.0]:
		var lift := maxf(0.0, step * side) * s * 0.06
		ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(side * s * 0.1, s * 0.3), pos + Vector2(side * s * 0.34, s * 0.3),
			pos + Vector2(side * s * 0.4, s * 0.47 - lift), pos + Vector2(side * s * 0.08, s * 0.47 - lift)]), bark_dark)
	for side in [-1.0, 1.0]:
		var sh := pos + Vector2(side * s * 0.42, -s * 0.05)
		var hand := sh + Vector2(side * s * 0.28, -s * 0.12 + step * side * s * 0.05)
		ci.draw_line(sh, hand, bark_dark, maxf(2.0, s * 0.07), true)
		ci.draw_line(hand, hand + Vector2(side * s * 0.08, -s * 0.1), bark_dark, maxf(1.5, s * 0.04), true)
		leaf(ci, hand + Vector2(side * s * 0.03, -s * 0.14), s * 0.09, side * 0.6, fade(Color("7a9a4a"), a))

	var body := PackedVector2Array([pos + Vector2(-s * 0.4, -s * 0.36), pos + Vector2(s * 0.4, -s * 0.36),
		pos + Vector2(s * 0.47, s * 0.34), pos + Vector2(-s * 0.47, s * 0.34)])
	ci.draw_colored_polygon(body, bark)
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(s * 0.18, -s * 0.36), pos + Vector2(s * 0.4, -s * 0.36),
		pos + Vector2(s * 0.47, s * 0.34), pos + Vector2(s * 0.22, s * 0.34)]), fade(bark_dark, 0.45))
	for k in 5:
		var x := -0.3 + k * 0.15
		ci.draw_line(pos + Vector2(x * s, -s * 0.3), pos + Vector2(x * 1.12 * s, s * 0.3), bark_dark, line_w, true)
	outline(ci, body, fade(INK, 0.9 * a), line_w * 1.4)

	var top := pos + Vector2(0, -s * 0.36)
	ci.draw_colored_polygon(ellipse(top, s * 0.4, s * 0.12, 24), fade(Color("c8a070"), a))
	outline(ci, ellipse(top, s * 0.26, s * 0.08, 20), fade(Color("9a7448"), a), 1.5)
	outline(ci, ellipse(top, s * 0.12, s * 0.04, 12), fade(Color("9a7448"), a), 1.5)
	outline(ci, ellipse(top, s * 0.4, s * 0.12, 24), bark_dark, line_w)
	ci.draw_colored_polygon(ellipse(top + Vector2(-s * 0.22, s * 0.03), s * 0.16, s * 0.06, 12), fade(Color("6f9a4a"), a))
	_fly_agaric(ci, top + Vector2(s * 0.18, -s * 0.01), s * 0.24, a)

	var face := pos + Vector2(0, -s * 0.08)
	for side in [-1.0, 1.0]:
		ci.draw_colored_polygon(ellipse(face + Vector2(side * s * 0.14, 0), s * 0.09, s * 0.07, 12), fade(Color("1a120c"), a))
		ci.draw_line(face + Vector2(side * s * 0.25, -s * 0.12), face + Vector2(side * s * 0.05, -s * 0.06), bark_dark, maxf(2.0, s * 0.05), true)
	_eyes(ci, creature_eyes("stumpling", pos, s, t), s * 0.045, Color("ffb04a"), blink, a, line_w)
	ci.draw_polyline(PackedVector2Array([face + Vector2(-s * 0.1, s * 0.15), face + Vector2(-s * 0.03, s * 0.12),
		face + Vector2(s * 0.03, s * 0.16), face + Vector2(s * 0.1, s * 0.13)]), fade(Color("1a120c"), a), line_w, true)


## Dusk moth: hovers above its shadow, big flapping wings with eyespots,
## fuzzy striped body, feathery antennae.
static func _moth(ci: CanvasItem, pos: Vector2, s: float, a: float, t: float, blink: bool) -> void:
	var c := pos + Vector2(0, moth_lift(s, t))
	var flap := 0.45 + 0.55 * absf(sin(t * 14.0))
	var ink := fade(INK, 0.85 * a)
	var line_w := maxf(1.2, s * 0.03)
	shadow(ci, pos + Vector2(0, s * 0.45), s * 0.36 * flap + 4.0, s * 0.08, 0.7 * a)
	for side in [-1.0, 1.0]:
		var lw := c + Vector2(side * s * 0.24 * flap, s * 0.16)
		var lower := ellipse(lw, s * 0.22 * flap + 1.0, s * 0.18, 18)
		ci.draw_colored_polygon(lower, fade(Color("45385a"), a))
		outline(ci, lower, ink, line_w)
		var uw := c + Vector2(side * s * 0.36 * flap, -s * 0.12)
		var upper := ellipse(uw, s * 0.36 * flap + 1.0, s * 0.26, 22)
		ci.draw_colored_polygon(upper, fade(Color("5a4a6a"), a))
		ci.draw_colored_polygon(ellipse(uw + Vector2(side * s * 0.12 * flap, -s * 0.04), s * 0.2 * flap + 1.0, s * 0.14, 16),
			fade(Color("6a5a7e"), a))
		outline(ci, upper, ink, line_w)
		ci.draw_circle(uw + Vector2(side * s * 0.1 * flap, 0), s * 0.09, fade(Color("d8b0f0"), a))
		ci.draw_circle(uw + Vector2(side * s * 0.1 * flap, 0), s * 0.045, fade(Color("2a2240"), a))
	ci.draw_colored_polygon(ellipse(c + Vector2(0, s * 0.05), s * 0.12, s * 0.3, 16), fade(Color("3a2e44"), a))
	for k in 3:
		var y := s * (-0.02 + k * 0.11)
		ci.draw_line(c + Vector2(-s * 0.1, y), c + Vector2(s * 0.1, y), fade(Color("6a5a7e"), a), line_w * 1.5, true)
	var head := c + Vector2(0, -s * 0.28)
	for side in [-1.0, 1.0]:
		var base := head + Vector2(side * s * 0.04, -s * 0.08)
		var tip := head + Vector2(side * s * 0.22, -s * 0.32)
		ci.draw_line(base, tip, ink, line_w, true)
		for k in range(1, 5):
			var at := base.lerp(tip, k / 5.0)
			ci.draw_line(at, at + Vector2(side * s * 0.05, s * 0.03), ink, 1.0, true)
	ci.draw_circle(head, s * 0.11, fade(Color("3a2e44"), a))
	_eyes(ci, creature_eyes("moth", pos, s, t), s * 0.04, Color("ffd66b"), blink, a, line_w)


## Storybook witch's cottage. pos is the middle of the doorstep; s is the size.
## broken (0 = whole, up to Data.HUT_HP - 1) adds damage in stages:
## 1 cracked plaster, missing shingles, a loose shutter;
## 2 a cracked window, the door hanging open, rubble, the lantern askew;
## 3 a roof hole with rafters, a broken chimney, exposed bricks (and smoke);
## 4 a boarded window, a sagging porch, soot, the lantern out.
static func hut(ci: CanvasItem, pos: Vector2, s: float, t: float = 0.0, broken: int = 0) -> void:
	var line := Color("2a1a22")
	var lw := maxf(2.0, s * 0.014)
	var timber := Color("4a3226")
	var hole := Color("140c10")
	var P := func(x: float, y: float) -> Vector2: return pos + Vector2(x, y) * s

	shadow(ci, pos + Vector2(0.02, 0.36) * s, s * 0.9, s * 0.14)

	# Firewood stack and a mushroom cluster at the base.
	for row in 3:
		for k in 3 - row:
			var lp: Vector2 = P.call(-0.8 + k * 0.085 + row * 0.042, 0.24 - row * 0.075)
			ci.draw_circle(lp, s * 0.042, Color("6a4a30"))
			ci.draw_circle(lp, s * 0.03, Color("c8a070"))
			ci.draw_arc(lp, s * 0.015, 0, TAU, 8, Color("9a7448"), 1.0, true)

	# Crooked stone chimney, behind the roof.
	var ch := PackedVector2Array([P.call(0.42, -0.58), P.call(0.57, -0.58), P.call(0.6, -0.97), P.call(0.45, -1.0)])
	if broken >= 3:
		ch = PackedVector2Array([P.call(0.42, -0.58), P.call(0.57, -0.58), P.call(0.585, -0.86), P.call(0.54, -0.82),
			P.call(0.5, -0.9), P.call(0.44, -0.86)])
	ci.draw_colored_polygon(ch, Color("6e6674"))
	for k in 5:
		var y := -0.64 - k * 0.07
		if broken >= 3 and y < -0.84:
			break
		ci.draw_rect(Rect2(P.call(0.44 + (k % 2) * 0.05, y), Vector2(s * 0.06, s * 0.05)), Color("7e7684"))
	if broken < 3:
		ci.draw_colored_polygon(PackedVector2Array([P.call(0.43, -1.02), P.call(0.62, -0.99), P.call(0.62, -0.95), P.call(0.43, -0.98)]),
			Color("4d4853"))
	outline(ci, ch, line, lw)

	# Stone foundation, each stone drawn.
	ci.draw_rect(Rect2(P.call(-0.58, 0.14), Vector2(1.16, 0.2) * s), Color("4a4450"))
	for row in 2:
		var x := -0.58 + row * 0.06
		var k := 0
		while x < 0.56:
			var w := 0.11 + 0.03 * sin(k * 2.7 + row)
			var c: Vector2 = P.call(x + w * 0.5, 0.19 + row * 0.09)
			ci.draw_colored_polygon(ellipse(c, s * w * 0.48, s * 0.042, 10), Color("7a7488") if (k + row) % 2 == 0 else Color("6a6478"))
			ci.draw_colored_polygon(ellipse(c + Vector2(-s * 0.015, -s * 0.015), s * w * 0.25, s * 0.015, 8), Color(1, 1, 1, 0.12))
			x += w
			k += 1

	# Plaster walls, darker up under the eaves, with timber framing.
	var wall := PackedVector2Array([P.call(-0.53, -0.38), P.call(0.51, -0.4), P.call(0.55, 0.16), P.call(-0.57, 0.16)])
	var shade_top := Color("a8906c")
	var lit_bottom := Color("ecdcbc")
	ci.draw_polygon(wall, PackedColorArray([shade_top, shade_top, lit_bottom, lit_bottom]))
	if broken >= 3:
		var bricks := Rect2(P.call(0.3, -0.02), Vector2(0.16, 0.12) * s)
		ci.draw_rect(bricks, Color("8a4a3a"))
		for r in 3:
			ci.draw_line(bricks.position + Vector2(0, r * s * 0.04), bricks.position + Vector2(bricks.size.x, r * s * 0.04), Color("5a2e24"), 1.0)
	var beams := [[Vector2(-0.53, -0.38), Vector2(-0.57, 0.16)], [Vector2(0.51, -0.4), Vector2(0.55, 0.16)],
		[Vector2(-0.55, 0.03), Vector2(0.54, 0.03)], [Vector2(-0.55, -0.02), Vector2(-0.42, -0.36)],
		[Vector2(0.53, -0.02), Vector2(0.41, -0.37)], [Vector2(-0.14, -0.39), Vector2(-0.15, 0.16)],
		[Vector2(0.14, -0.39), Vector2(0.15, 0.16)]]
	for b in beams:
		ci.draw_line(P.call(b[0].x, b[0].y), P.call(b[1].x, b[1].y), timber, s * 0.045, true)
	outline(ci, wall, line, lw)

	# Ivy climbing the left corner.
	var ivy := PackedVector2Array()
	for k in 11:
		ivy.append(P.call(-0.5 + sin(k * 1.4) * 0.03, 0.14 - k * 0.055))
	ci.draw_polyline(ivy, Color("2f5a30"), lw, true)
	for k in range(1, 11):
		var side := 1.0 if k % 2 == 0 else -1.0
		leaf(ci, ivy[k] + Vector2(side * s * 0.03, 0), s * 0.035, side * 0.9, Color("4f8a44") if k % 3 else Color("6aa05a"))

	# Arched windows with warm light, bottle silhouettes, shutters and flower boxes.
	var wins := hut_windows(pos, s)
	for i in wins.size():
		var w: Vector2 = wins[i]
		var ww := s * 0.1
		var arch := PackedVector2Array([w + Vector2(-ww, s * 0.1)])
		for j in 11:
			var ang := PI + PI * j / 10.0
			arch.append(w + Vector2(cos(ang) * ww, sin(ang) * ww - s * 0.02))
		arch.append(w + Vector2(ww, s * 0.1))
		if i == 1 and broken >= 4:
			ci.draw_colored_polygon(arch, hole)
			for k in 3:
				var yb := -0.08 + k * 0.07
				ci.draw_line(w + Vector2(-ww * 1.3, s * yb), w + Vector2(ww * 1.3, s * (yb + 0.03)), Color("8a6242"), s * 0.035, true)
		else:
			var cracked := i == 0 and broken >= 2
			ci.draw_colored_polygon(arch, Color("f0b85a") if not cracked else Color("b88a40"))
			ci.draw_circle(w + Vector2(0, s * 0.01), ww * 0.7, Color("ffe6a0") if not cracked else Color("d8b060"))
			for k in 3:
				var bx := -0.06 + k * 0.06
				var bottle := w + Vector2(s * bx, s * 0.08)
				ci.draw_rect(Rect2(bottle + Vector2(-s * 0.012, -s * 0.05), Vector2(s * 0.024, s * 0.05)), Color(0.3, 0.18, 0.12, 0.7))
				ci.draw_circle(bottle + Vector2(0, -s * 0.015), s * 0.018, Color(0.3, 0.18, 0.12, 0.7))
			ci.draw_line(w + Vector2(0, -ww - s * 0.02), w + Vector2(0, s * 0.1), timber, lw * 1.3)
			ci.draw_line(w + Vector2(-ww, s * 0.02), w + Vector2(ww, s * 0.02), timber, lw * 1.3)
			if cracked:
				ci.draw_polyline(PackedVector2Array([w + Vector2(-ww * 0.8, -ww * 0.5), w + Vector2(-ww * 0.1, 0), w + Vector2(ww * 0.5, -ww * 0.9)]),
					hole, lw, true)
				ci.draw_polyline(PackedVector2Array([w + Vector2(-ww * 0.1, 0), w + Vector2(ww * 0.2, ww * 0.9)]), hole, lw, true)
		ci.draw_polyline(arch, timber, lw * 2.2, true)
		ci.draw_line(arch[0], arch[arch.size() - 1], timber, lw * 2.2, true)
		var box := Rect2(w + Vector2(-ww * 1.25, s * 0.1), Vector2(ww * 2.5, s * 0.05))
		ci.draw_rect(box, Color("7a5236"))
		ci.draw_rect(box, line, false, 1.0)
		for k in 5:
			var fp := box.position + Vector2(s * 0.02 + k * s * 0.04, -s * 0.005)
			ci.draw_circle(fp, s * 0.016, [Color("f5a8c8"), Color("ffe07a"), Color("c8b0f0"), Color("ff9a7a"), Color("f5a8c8")][k])
		ci.draw_line(box.position + Vector2(s * 0.02, s * 0.05), box.position + Vector2(s * 0.01, s * 0.1), Color("4f8a44"), 1.5, true)
		ci.draw_line(box.end + Vector2(-s * 0.03, 0), box.end + Vector2(-s * 0.02, s * 0.06), Color("4f8a44"), 1.5, true)
	# A shutter beside the left window (hanging loose once hit).
	var sh_top: Vector2 = wins[0] + Vector2(-s * 0.22, -s * 0.12)
	var shutter := PackedVector2Array([sh_top, sh_top + Vector2(s * 0.09, 0), sh_top + Vector2(s * 0.09, s * 0.22), sh_top + Vector2(0, s * 0.22)])
	if broken >= 1:
		var pivot := sh_top + Vector2(s * 0.09, 0)
		for k in shutter.size():
			shutter[k] = pivot + (shutter[k] - pivot).rotated(0.35)
	ci.draw_colored_polygon(shutter, Color("4a6a6a"))
	ci.draw_line((shutter[0] + shutter[3]) * 0.5, (shutter[1] + shutter[2]) * 0.5, Color("3a5454"), lw, true)
	outline(ci, shutter, line, lw * 0.8)

	# Arched plank door, light spilling from the gap, iron hinges.
	var door_c: Vector2 = P.call(0.0, -0.12)
	var dw := s * 0.12
	var door := PackedVector2Array([P.call(-0.12, 0.16)])
	for j in 11:
		var ang := PI + PI * j / 10.0
		door.append(door_c + Vector2(cos(ang) * dw, sin(ang) * dw))
	door.append(P.call(0.12, 0.16))
	ci.draw_colored_polygon(door, Color("ffd27a"))
	var panel := PackedVector2Array()
	var open := 0.35 if broken >= 2 else 0.12
	for p in door:
		var rel: Vector2 = p - P.call(-0.12, 0.0)
		panel.append(P.call(-0.12, 0.0) + Vector2(rel.x * (1.0 - open), rel.y))
	ci.draw_colored_polygon(panel, Color("6a4028"))
	for k in 3:
		var px := -0.12 + (k + 1) * 0.06 * (1.0 - open)
		ci.draw_line(P.call(px, -0.2), P.call(px, 0.16), Color("4a2c1c"), 1.5, true)
	for hy in [-0.1, 0.08]:
		ci.draw_line(P.call(-0.12, hy), P.call(-0.12 + 0.12 * (1.0 - open), hy), Color("2a2a30"), lw * 1.5, true)
	ci.draw_polyline(door, timber, lw * 2.2, true)

	# Little porch roof over the door, with its lantern.
	var sag := 0.05 if broken >= 4 else 0.0
	var porch := PackedVector2Array([P.call(-0.2, -0.24), P.call(0.0, -0.36), P.call(0.2, -0.24 + sag), P.call(0.2, -0.21 + sag), P.call(-0.2, -0.21)])
	ci.draw_colored_polygon(porch, Color("5a3a4a"))
	for k in 4:
		ci.draw_arc(P.call(-0.15 + k * 0.1, -0.23 + (sag if k == 3 else 0.0)), s * 0.05, 0.2, PI - 0.2, 8, Color("3a2230"), lw * 0.8, true)
	outline(ci, porch, line, lw)
	ci.draw_line(P.call(-0.19, -0.21), P.call(-0.14, -0.13), timber, lw * 1.5, true)
	ci.draw_line(P.call(0.19, -0.21 + sag), P.call(0.14, -0.13), timber, lw * 1.5, true)
	var lamp := hut_lamp(pos, s)
	var swing := 0.25 if broken >= 2 else 0.0
	var hook: Vector2 = P.call(0.2, -0.21 + sag)
	var lamp_at: Vector2 = hook + (lamp - hook).rotated(swing)
	ci.draw_line(hook, lamp_at + Vector2(0, -s * 0.03), Color("2a2a30"), 1.5, true)
	ci.draw_rect(Rect2(lamp_at + Vector2(-s * 0.025, -s * 0.03), Vector2(s * 0.05, s * 0.065)), Color("ffcf7a") if broken < 4 else Color("3a3028"))
	ci.draw_rect(Rect2(lamp_at + Vector2(-s * 0.025, -s * 0.03), Vector2(s * 0.05, s * 0.065)), line, false, 1.2)

	# Tall crooked roof with inward-curving sides and fish-scale shingles.
	var left := _curve(P.call(-0.82, -0.34), P.call(-0.2, -0.58), P.call(0.08, -1.22), 14)
	var right := _curve(P.call(0.08, -1.22), P.call(0.3, -0.62), P.call(0.82, -0.36), 14)
	var roof := PackedVector2Array()
	roof.append_array(left)
	roof.append_array(right)
	roof.append(P.call(0.8, -0.3))
	roof.append(P.call(-0.8, -0.28))
	ci.draw_colored_polygon(roof, Color("2e1c28"))
	var tiles := [Color("6a4458"), Color("5a3a4c"), Color("74506a")]
	var row := 0
	var y := -1.08
	while y < -0.3:
		var xl := _x_at(left, pos.y + y * s)
		var xr := _x_at(right, pos.y + y * s)
		var x := xl + s * 0.05 + (row % 2) * s * 0.055
		var k := 0
		while x < xr - s * 0.04:
			var c := Vector2(x, pos.y + y * s)
			var scale := PackedVector2Array([c + Vector2(-s * 0.056, -s * 0.03)])
			for j in 7:
				var ang := PI * j / 6.0
				scale.append(c + Vector2(-cos(ang) * s * 0.056, sin(ang) * s * 0.05))
			scale.append(c + Vector2(s * 0.056, -s * 0.03))
			ci.draw_colored_polygon(scale, tiles[(row + k) % tiles.size()])
			ci.draw_arc(c, s * 0.053, 0.25, PI - 0.25, 8, Color("2e1c28"), 1.2, true)
			x += s * 0.11
			k += 1
		y += 0.075
		row += 1
	var missing := [Vector2(-0.3, -0.5), Vector2(0.28, -0.6), Vector2(0.5, -0.42), Vector2(-0.05, -0.86), Vector2(-0.5, -0.38)]
	for k in mini(broken * 2, missing.size()):
		ci.draw_colored_polygon(ellipse(P.call(missing[k].x, missing[k].y), s * 0.06, s * 0.035, 10), Color("1e1218"))
	if broken >= 3:
		var hole_pts := PackedVector2Array([P.call(-0.22, -0.62), P.call(-0.05, -0.76), P.call(0.1, -0.66), P.call(0.04, -0.5), P.call(-0.16, -0.48)])
		if broken >= 4:
			hole_pts = PackedVector2Array([P.call(-0.32, -0.6), P.call(-0.05, -0.84), P.call(0.22, -0.68), P.call(0.14, -0.44), P.call(-0.26, -0.44)])
		ci.draw_colored_polygon(hole_pts, hole)
		for k in 3:
			var rx := -0.22 + k * 0.12
			ci.draw_line(P.call(rx, -0.46), P.call(rx + 0.1, -0.78), Color("5a3a26"), lw * 2.0, true)
		outline(ci, hole_pts, Color("1e1218"), lw)
	# Shade the right-hand slope, then the eave's underside and the outline.
	var shade := PackedVector2Array()
	shade.append_array(right)
	shade.append(P.call(0.8, -0.3))
	shade.append(P.call(0.1, -0.3))
	ci.draw_colored_polygon(shade, Color(0.05, 0.0, 0.08, 0.22))
	ci.draw_line(P.call(-0.8, -0.28), P.call(0.8, -0.3), Color("1e1218"), s * 0.03, true)
	outline(ci, roof, line, lw * 1.5)
	ci.draw_polyline(left.slice(8), Color(1, 0.85, 0.9, 0.25), lw, true)

	# Round dormer window on the roof.
	var dormer: Vector2 = P.call(0.04, -0.8)
	ci.draw_circle(dormer, s * 0.075, timber)
	ci.draw_circle(dormer, s * 0.055, Color("f0b85a") if broken < 4 else hole)
	ci.draw_line(dormer + Vector2(-s * 0.055, 0), dormer + Vector2(s * 0.055, 0), timber, lw, true)

	# Moon-and-star sign on the peak.
	var tip: Vector2 = P.call(0.08, -1.22)
	ci.draw_line(tip, tip + Vector2(0, -s * 0.12), Color("2a2a30"), lw, true)
	ci.draw_circle(tip + Vector2(0, -s * 0.17), s * 0.055, Color("f0d890"))
	ci.draw_circle(tip + Vector2(s * 0.025, -s * 0.185), s * 0.047, Color("2e1c28"))
	sparkle(ci, tip + Vector2(s * 0.08, -s * 0.2), s * 0.03, Color("f0d890"))


	# Damage on the walls, rubble and soot.
	if broken >= 1:
		ci.draw_polyline(PackedVector2Array([P.call(-0.36, -0.3), P.call(-0.32, -0.2), P.call(-0.38, -0.1), P.call(-0.33, 0.0)]),
			Color("5a4030"), lw * 1.2, true)
	if broken >= 2:
		ci.draw_polyline(PackedVector2Array([P.call(0.36, -0.36), P.call(0.3, -0.26), P.call(0.34, -0.16)]), Color("5a4030"), lw * 1.2, true)
		for k in 6:
			var rb: Vector2 = P.call(-0.45 + k * 0.18 + sin(k * 3.1) * 0.04, 0.4 + sin(k * 1.7) * 0.03)
			ci.draw_colored_polygon(PackedVector2Array([rb, rb + Vector2(s * 0.06, -s * 0.01), rb + Vector2(s * 0.05, s * 0.025), rb + Vector2(0, s * 0.02)]),
				Color("5a4030") if k % 2 == 0 else Color("5a3a4a"))
	if broken >= 4:
		for k in 3:
			glow(ci, P.call(-0.3 + k * 0.3, -0.28 + k * 0.04), s * 0.14, Color(0.05, 0.02, 0.02, 0.5))

	var cc := hut_cauldron(pos, s)
	shadow(ci, cc + Vector2(0, s * 0.08), s * 0.12, s * 0.03)
	ci.draw_circle(cc, s * 0.09, Color("2f2b2a"))
	ci.draw_colored_polygon(ellipse(cc + Vector2(0, -s * 0.06), s * 0.1, s * 0.035, 16), Color("3d3837"))
	ci.draw_colored_polygon(ellipse(cc + Vector2(0, -s * 0.06), s * 0.08, s * 0.025, 16),
		Color("7fd67a").lightened(0.1 * sin(t * 3.0)))
	_fly_agaric(ci, P.call(0.6, 0.31), s * 0.16, 1.0)
	ingredient(ci, "amethyst_deceiver", P.call(0.69, 0.33), s * 0.11)


## Points along a quadratic curve from a to b bending toward ctrl.
static func _curve(a: Vector2, ctrl: Vector2, b: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		pts.append(a.lerp(ctrl, u).lerp(ctrl.lerp(b, u), u))
	return pts


## The x of a curve at height y (the curve runs monotonically in y).
static func _x_at(pts: PackedVector2Array, y: float) -> float:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		if (y - a.y) * (y - b.y) <= 0.0 and a.y != b.y:
			return lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
	return pts[0].x


static func hut_chimney(pos: Vector2, s: float) -> Vector2:
	return pos + Vector2(0.52, -1.02) * s


static func hut_windows(pos: Vector2, s: float) -> Array:
	return [pos + Vector2(-0.33, -0.16) * s, pos + Vector2(0.33, -0.16) * s]


static func hut_cauldron(pos: Vector2, s: float) -> Vector2:
	return pos + Vector2(0.76, 0.14) * s


static func hut_lamp(pos: Vector2, s: float) -> Vector2:
	return pos + Vector2(0.2, -0.1) * s


## Where smoke rises from the roof hole once the hut is badly damaged.
static func hut_roof_hole(pos: Vector2, s: float) -> Vector2:
	return pos + Vector2(-0.06, -0.62) * s


static func hut_dormer(pos: Vector2, s: float) -> Vector2:
	return pos + Vector2(0.04, -0.8) * s


static func lantern_lamp(pos: Vector2, s: float) -> Vector2:
	return pos + Vector2(s * 0.24, -s * 0.8)


## Wooden post with a hanging lamp. pos is the foot of the post.
static func lantern(ci: CanvasItem, pos: Vector2, s: float) -> void:
	var wood := Color("3d2e2c")
	var ink := fade(INK, 0.8)
	shadow(ci, pos + Vector2(0, 2), s * 0.12, s * 0.04)
	ci.draw_rect(Rect2(pos.x - s * 0.04, pos.y - s, s * 0.08, s), wood)
	ci.draw_rect(Rect2(pos.x - s * 0.04, pos.y - s * 0.98, s * 0.3, s * 0.05), wood)
	var lamp := lantern_lamp(pos, s)
	ci.draw_line(lamp + Vector2(0, -s * 0.13), lamp + Vector2(0, -s * 0.2), wood, 2.0)
	var box := Rect2(lamp.x - s * 0.08, lamp.y - s * 0.1, s * 0.16, s * 0.2)
	ci.draw_rect(box, Color("ffcf7a"))
	ci.draw_rect(box, ink, false, 2.0)
	ci.draw_line(Vector2(lamp.x, box.position.y), Vector2(lamp.x, box.end.y), ink, 1.5)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(box.position.x - 3, box.position.y), Vector2(lamp.x, box.position.y - s * 0.08),
		Vector2(box.end.x + 3, box.position.y)]), wood)


static func crystal(ci: CanvasItem, pos: Vector2, s: float, color: Color, a: float = 1.0) -> void:
	var pts := PackedVector2Array([pos + Vector2(0, -s * 0.6), pos + Vector2(s * 0.22, -s * 0.1),
		pos + Vector2(0, s * 0.5), pos + Vector2(-s * 0.22, -s * 0.1)])
	shadow(ci, pos + Vector2(0, s * 0.5), s * 0.2, s * 0.06, a)
	ci.draw_colored_polygon(pts, fade(color, a))
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[2], pts[3]]), fade(color.lightened(0.35), a))
	outline(ci, pts, fade(INK, 0.6 * a), 1.5)


static func heart(ci: CanvasItem, pos: Vector2, s: float, color: Color) -> void:
	ci.draw_circle(pos + Vector2(-s * 0.25, -s * 0.1), s * 0.28, color)
	ci.draw_circle(pos + Vector2(s * 0.25, -s * 0.1), s * 0.28, color)
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-s * 0.52, 0.0), pos + Vector2(s * 0.52, 0.0),
		pos + Vector2(0, s * 0.52)]), color)


## Four-point twinkle star.
static func sparkle(ci: CanvasItem, pos: Vector2, s: float, color: Color) -> void:
	if s < 0.5:
		return
	var k := s * 0.25
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -s), pos + Vector2(k, -k), pos + Vector2(s, 0),
		pos + Vector2(k, k), pos + Vector2(0, s), pos + Vector2(-k, k), pos + Vector2(-s, 0), pos + Vector2(-k, -k)]), color)


## Small leaf, rotated by ang. Used for leaf litter and falling leaves.
static func leaf(ci: CanvasItem, pos: Vector2, s: float, ang: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for p in [Vector2(0, -s), Vector2(s * 0.45, -s * 0.2), Vector2(s * 0.3, s * 0.5), Vector2(0, s * 0.7),
			Vector2(-s * 0.3, s * 0.5), Vector2(-s * 0.45, -s * 0.2)]:
		pts.append(pos + p.rotated(ang))
	ci.draw_colored_polygon(pts, color)
	ci.draw_line(pos + Vector2(0, -s * 0.8).rotated(ang), pos + Vector2(0, s * 0.9).rotated(ang), color.darkened(0.3), 1.2, true)


## Cartoon monster bone: a shaft with two knobbly ends.
static func bone(ci: CanvasItem, pos: Vector2, s: float, a: float = 1.0, ang: float = -0.5) -> void:
	if s < 2.0 or a <= 0.0:
		return
	var ivory := fade(Color("efe6d0"), a)
	var shade := fade(Color("c8bca0"), a)
	var ink := fade(INK, 0.7 * a)
	var dir := Vector2.from_angle(ang)
	var side := dir.orthogonal()
	var half := s * 0.34
	var w := s * 0.12
	var shaft := PackedVector2Array([pos - dir * half + side * w, pos + dir * half + side * w, pos + dir * half - side * w, pos - dir * half - side * w])
	for end in [-1.0, 1.0]:
		var c: Vector2 = pos + dir * half * end
		ci.draw_circle(c + side * s * 0.12, s * 0.13, ink)
		ci.draw_circle(c - side * s * 0.12, s * 0.13, ink)
	ci.draw_colored_polygon(shaft, ink)
	for end in [-1.0, 1.0]:
		var c: Vector2 = pos + dir * half * end
		ci.draw_circle(c + side * s * 0.12, s * 0.11, ivory)
		ci.draw_circle(c - side * s * 0.12, s * 0.11, ivory)
	var inner := PackedVector2Array([pos - dir * half + side * (w - 2.0), pos + dir * half + side * (w - 2.0),
		pos + dir * half - side * (w - 2.0), pos - dir * half - side * (w - 2.0)])
	ci.draw_colored_polygon(inner, ivory)
	ci.draw_line(pos - dir * half * 0.7 - side * w * 0.4, pos + dir * half * 0.7 - side * w * 0.4, shade, maxf(1.0, s * 0.04), true)


## Gold coin with a rim and a shine.
static func coin(ci: CanvasItem, pos: Vector2, s: float, a: float = 1.0) -> void:
	if s < 2.0 or a <= 0.0:
		return
	ci.draw_circle(pos, s * 0.5, fade(Color("a8741a"), a))
	ci.draw_circle(pos, s * 0.42, fade(Color("f5c04a"), a))
	ci.draw_arc(pos, s * 0.3, 0, TAU, 20, fade(Color("d8962a"), a), maxf(1.0, s * 0.06), true)
	ci.draw_arc(pos, s * 0.36, PI * 1.1, PI * 1.5, 8, fade(Color.WHITE, 0.8 * a), maxf(1.0, s * 0.07), true)
