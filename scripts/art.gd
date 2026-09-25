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
	ci.draw_colored_polygon(ellipse(pos, rx, ry, 20), Color(0, 0, 0, 0.28 * a))


static func ingredient(ci: CanvasItem, id: String, pos: Vector2, s: float, a: float = 1.0) -> void:
	match id:
		"puffcap":
			mushroom(ci, pos, s, Color("b58fd6"), a, false)
		"moonglow":
			mushroom(ci, pos, s, Color("9ff0f0"), a, true)
		"honeyroot":
			var c := fade(Color("e0a441"), a)
			ci.draw_line(pos + Vector2(0, s * 0.3), pos + Vector2(s * 0.12, s * 0.45), fade(Color("8a6242"), a), s * 0.06)
			ci.draw_circle(pos + Vector2(0, s * 0.1), s * 0.28, c)
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-s * 0.25, 0), pos + Vector2(0, -s * 0.45), pos + Vector2(s * 0.25, 0)]), c)
			ci.draw_circle(pos + Vector2(-s * 0.08, 0), s * 0.07, fade(Color(1, 1, 1, 0.6), a))
		"emberleaf":
			var c := fade(Color("d9623b"), a)
			ci.draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0, -s * 0.5), pos + Vector2(s * 0.3, -s * 0.1), pos + Vector2(s * 0.18, s * 0.3),
				pos + Vector2(0, s * 0.42), pos + Vector2(-s * 0.18, s * 0.3), pos + Vector2(-s * 0.3, -s * 0.1)]), c)
			ci.draw_line(pos + Vector2(0, -s * 0.4), pos + Vector2(0, s * 0.5), fade(Color("ffd08a"), a), s * 0.04)
		"dewmoss":
			var c := fade(Color("6fae8a"), a)
			ci.draw_circle(pos + Vector2(-s * 0.2, s * 0.1), s * 0.22, c)
			ci.draw_circle(pos + Vector2(s * 0.18, s * 0.12), s * 0.2, c)
			ci.draw_circle(pos + Vector2(0, -s * 0.12), s * 0.24, c)
			ci.draw_circle(pos + Vector2(s * 0.08, -s * 0.2), s * 0.08, fade(Color("d8f3ff"), a))


## Toadstool with a shaded stem, gills, a shaded dome, a highlight and spots.
## pos is where the stem meets the ground.
static func mushroom(ci: CanvasItem, pos: Vector2, s: float, cap: Color, a: float = 1.0, glow_on: bool = false) -> void:
	var line_w := maxf(1.2, s * 0.035)
	if glow_on:
		glow(ci, pos + Vector2(0, -s * 0.35), s * 1.1, fade(cap, 0.45 * a))
	shadow(ci, pos + Vector2(0, s * 0.24), s * 0.34, s * 0.08, a)

	var stem := PackedVector2Array([pos + Vector2(-s * 0.14, s * 0.25), pos + Vector2(-s * 0.10, -s * 0.28),
		pos + Vector2(s * 0.10, -s * 0.28), pos + Vector2(s * 0.15, s * 0.25)])
	ci.draw_colored_polygon(stem, fade(Color("efe3c8"), a))
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(s * 0.03, s * 0.25), pos + Vector2(s * 0.03, -s * 0.28),
		pos + Vector2(s * 0.10, -s * 0.28), pos + Vector2(s * 0.15, s * 0.25)]), fade(Color("cdbb96"), a))
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

	var dot := fade(Color(1, 0.98, 0.92, 0.9), a)
	ci.draw_circle(pos + Vector2(-s * 0.3, -s * 0.42), s * 0.07, dot)
	ci.draw_circle(pos + Vector2(s * 0.05, -s * 0.64), s * 0.06, dot)
	ci.draw_circle(pos + Vector2(s * 0.32, -s * 0.42), s * 0.08, dot)
	ci.draw_circle(pos + Vector2(-s * 0.02, -s * 0.42), s * 0.045, dot)
	outline(ci, dome, fade(INK, 0.6 * a), line_w)


## Round flask with a cork, liquid up to a fill line, bubbles and a glass shine.
static func bottle(ci: CanvasItem, pos: Vector2, s: float, color: Color, a: float = 1.0) -> void:
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


## Mischief creature: pear body, ears, belly, stepping feet, blinking eyes.
## t drives the walk cycle; pass the same t each frame for smooth steps.
static func creature(ci: CanvasItem, pos: Vector2, s: float, a: float = 1.0, t: float = 0.0, blink: bool = false) -> void:
	var body := fade(Color("2a2240"), a)
	var dark := fade(Color("150f22"), a)
	var line_w := maxf(1.5, s * 0.05)
	var step := sin(t * 14.0)
	shadow(ci, pos + Vector2(0, s * 0.5), s * 0.42, s * 0.1, a)
	ci.draw_colored_polygon(ellipse(pos + Vector2(-s * 0.2, s * 0.42 + minf(0.0, step) * s * 0.08), s * 0.13, s * 0.08, 12), dark)
	ci.draw_colored_polygon(ellipse(pos + Vector2(s * 0.2, s * 0.42 + minf(0.0, -step) * s * 0.08), s * 0.13, s * 0.08, 12), dark)

	for side in [-1.0, 1.0]:
		var ear := PackedVector2Array([pos + Vector2(side * s * 0.42, -s * 0.15), pos + Vector2(side * s * 0.34, -s * 0.8),
			pos + Vector2(side * s * 0.08, -s * 0.38)])
		ci.draw_colored_polygon(ear, body)
		outline(ci, ear, dark, line_w)
		ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(side * s * 0.34, -s * 0.28), pos + Vector2(side * s * 0.32, -s * 0.62),
			pos + Vector2(side * s * 0.18, -s * 0.38)]), fade(Color("5b4580"), a))

	var bp := ellipse(pos, s * 0.48, s * 0.5, 24)
	ci.draw_colored_polygon(bp, body)
	ci.draw_colored_polygon(ellipse(pos + Vector2(0, s * 0.17), s * 0.28, s * 0.24, 16), fade(Color("3b2f58"), a))
	outline(ci, bp, dark, line_w)

	for side in [-1.0, 1.0]:
		var e := pos + Vector2(side * s * 0.17, -s * 0.1)
		if blink:
			ci.draw_line(e + Vector2(-s * 0.1, 0), e + Vector2(s * 0.1, 0), fade(Color("ffd66b"), a), line_w, true)
		else:
			ci.draw_circle(e, s * 0.12, fade(Color("ffd66b"), a))
			ci.draw_circle(e + Vector2(0, s * 0.02), s * 0.05, dark)
			ci.draw_circle(e + Vector2(-s * 0.04, -s * 0.04), s * 0.025, fade(Color.WHITE, a))
	ci.draw_arc(pos + Vector2(0, s * 0.06), s * 0.08, 0.3, PI - 0.3, 8, dark, maxf(1.0, s * 0.03), true)


static func hut_chimney(pos: Vector2, s: float) -> Vector2:
	return pos + Vector2(s * 0.29, -s * 0.98)


static func hut_windows(pos: Vector2, s: float) -> Array:
	return [pos + Vector2(-s * 0.3, -s * 0.15), pos + Vector2(s * 0.3, -s * 0.15)]


static func hut_cauldron(pos: Vector2, s: float) -> Vector2:
	return pos + Vector2(s * 0.66, s * 0.12)


## Witch's hut: stone footing, plank walls, shingled roof, chimney, arched
## glowing door, round windows, a roof mushroom and a cauldron outside.
static func hut(ci: CanvasItem, pos: Vector2, s: float, t: float = 0.0) -> void:
	var ink := fade(INK, 0.8)
	var line_w := maxf(1.5, s * 0.015)
	shadow(ci, pos + Vector2(0, s * 0.33), s * 0.75, s * 0.12)

	var ch := hut_chimney(pos, s)
	var chimney := Rect2(ch.x - s * 0.07, ch.y, s * 0.14, s * 0.3)
	ci.draw_rect(chimney, Color("6a6470"))
	ci.draw_rect(Rect2(chimney.position + Vector2(-s * 0.015, -s * 0.04), Vector2(s * 0.17, s * 0.05)), Color("4d4853"))
	ci.draw_rect(chimney, ink, false, line_w)

	ci.draw_rect(Rect2(pos.x - s * 0.55, pos.y + s * 0.18, s * 1.1, s * 0.14), Color("55505c"))
	for i in 8:
		var sx := pos.x - s * 0.5 + i * s * 0.143
		ci.draw_colored_polygon(ellipse(Vector2(sx, pos.y + s * 0.25), s * 0.07, s * 0.05, 10),
			Color("6e6878") if i % 2 == 0 else Color("625c6c"))

	var walls := Rect2(pos.x - s * 0.5, pos.y - s * 0.4, s, s * 0.6)
	ci.draw_rect(walls, Color("6b4f3a"))
	for i in range(1, 10):
		var px := walls.position.x + i * s * 0.1
		ci.draw_line(Vector2(px, walls.position.y), Vector2(px, walls.end.y), Color("56402f"), line_w)
	ci.draw_rect(Rect2(walls.position.x, walls.position.y, s * 0.06, walls.size.y), Color("3e2c22"))
	ci.draw_rect(Rect2(walls.end.x - s * 0.06, walls.position.y, s * 0.06, walls.size.y), Color("3e2c22"))
	ci.draw_rect(Rect2(walls.position.x, pos.y - s * 0.02, s, s * 0.04), Color("3e2c22"))
	ci.draw_rect(walls, ink, false, line_w)

	for w in hut_windows(pos, s):
		ci.draw_circle(w, s * 0.1, Color("ffd27a"))
		ci.draw_line(w + Vector2(-s * 0.1, 0), w + Vector2(s * 0.1, 0), Color("3e2c22"), line_w * 1.4)
		ci.draw_line(w + Vector2(0, -s * 0.1), w + Vector2(0, s * 0.1), Color("3e2c22"), line_w * 1.4)
		ci.draw_arc(w, s * 0.1, 0, TAU, 24, Color("3e2c22"), line_w * 2.0, true)

	var door_top := pos + Vector2(0, -s * 0.02)
	ci.draw_circle(door_top, s * 0.13, Color("3e2c22"))
	ci.draw_rect(Rect2(pos.x - s * 0.13, door_top.y, s * 0.26, s * 0.2), Color("3e2c22"))
	ci.draw_circle(door_top, s * 0.1, Color("f0b35a"))
	ci.draw_rect(Rect2(pos.x - s * 0.1, door_top.y, s * 0.2, s * 0.2), Color("f0b35a"))
	ci.draw_rect(Rect2(pos.x - s * 0.1, door_top.y + s * 0.1, s * 0.2, s * 0.1), Color("e09a45"))

	var roof := PackedVector2Array([pos + Vector2(-s * 0.72, -s * 0.34), pos + Vector2(0, -s * 1.02), pos + Vector2(s * 0.72, -s * 0.34)])
	ci.draw_colored_polygon(roof, Color("3e2f2a"))
	for row in 5:
		var y := -s * 0.4 - row * s * 0.12
		var half := s * 0.72 * (y + s * 1.02) / (s * 0.68)
		var x := -half + s * 0.07
		while x < half - s * 0.06:
			ci.draw_arc(pos + Vector2(x, y), s * 0.06, 0.1, PI - 0.1, 8, Color("2a201d"), line_w, true)
			x += s * 0.12
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -s * 1.02), pos + Vector2(s * 0.72, -s * 0.34),
		pos + Vector2(s * 0.5, -s * 0.34)]), Color(0, 0, 0, 0.18))
	outline(ci, roof, ink, line_w * 1.5)
	mushroom(ci, pos + Vector2(-s * 0.52, -s * 0.36), s * 0.22, Color("b58fd6"))

	var cc := hut_cauldron(pos, s)
	shadow(ci, cc + Vector2(0, s * 0.08), s * 0.12, s * 0.03)
	ci.draw_circle(cc, s * 0.09, Color("2f2b2a"))
	ci.draw_colored_polygon(ellipse(cc + Vector2(0, -s * 0.06), s * 0.1, s * 0.035, 16), Color("3d3837"))
	ci.draw_colored_polygon(ellipse(cc + Vector2(0, -s * 0.06), s * 0.08, s * 0.025, 16),
		Color("7fd67a").lightened(0.1 * sin(t * 3.0)))


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
