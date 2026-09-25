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


## Night creatures. kind is a key of Data.creatures. pos is where the creature
## stands; s is its size. t drives walk cycles and flapping (pass the same t
## every frame for smooth animation).
static func creature(ci: CanvasItem, kind: String, pos: Vector2, s: float, a: float = 1.0, t: float = 0.0, blink: bool = false) -> void:
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
	mushroom(ci, top + Vector2(s * 0.18, -s * 0.01), s * 0.24, Color("d9623b"), a)

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


## Four-point twinkle star.
static func sparkle(ci: CanvasItem, pos: Vector2, s: float, color: Color) -> void:
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
