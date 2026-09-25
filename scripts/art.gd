extends RefCounted
## Placeholder shapes for the grey-box prototype. Swap these for real art later.
## Every function takes the CanvasItem to draw on, so call them from _draw().


static func fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


static func ellipse(center: Vector2, rx: float, ry: float, n: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


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


static func mushroom(ci: CanvasItem, pos: Vector2, s: float, cap: Color, a: float = 1.0, glow: bool = false) -> void:
	if glow:
		ci.draw_circle(pos + Vector2(0, -s * 0.2), s * 0.8, fade(cap, 0.25 * a))
	ci.draw_rect(Rect2(pos.x - s * 0.13, pos.y - s * 0.3, s * 0.26, s * 0.55), fade(Color("efe3c8"), a))
	var pts := PackedVector2Array()
	for i in 13:
		var ang := PI + PI * i / 12.0
		pts.append(pos + Vector2(cos(ang) * s * 0.55, sin(ang) * s * 0.5 - s * 0.25))
	ci.draw_colored_polygon(pts, fade(cap, a))
	var dot := fade(Color(1, 1, 1, 0.75), a)
	ci.draw_circle(pos + Vector2(-s * 0.2, -s * 0.45), s * 0.07, dot)
	ci.draw_circle(pos + Vector2(s * 0.15, -s * 0.55), s * 0.06, dot)
	ci.draw_circle(pos + Vector2(s * 0.3, -s * 0.35), s * 0.05, dot)


static func bottle(ci: CanvasItem, pos: Vector2, s: float, color: Color, a: float = 1.0) -> void:
	ci.draw_circle(pos + Vector2(0, s * 0.1), s * 0.5, fade(color, 0.18 * a))
	ci.draw_rect(Rect2(pos.x - s * 0.09, pos.y - s * 0.42, s * 0.18, s * 0.28), fade(Color("d8e6e6"), a))
	ci.draw_rect(Rect2(pos.x - s * 0.11, pos.y - s * 0.5, s * 0.22, s * 0.1), fade(Color("8a6242"), a))
	ci.draw_circle(pos + Vector2(0, s * 0.12), s * 0.3, fade(color, a))
	ci.draw_circle(pos + Vector2(-s * 0.1, s * 0.03), s * 0.07, fade(Color.WHITE, 0.6 * a))


static func creature(ci: CanvasItem, pos: Vector2, s: float, a: float = 1.0) -> void:
	var body := fade(Color("2a2240"), a)
	ci.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-s * 0.45, -s * 0.2), pos + Vector2(-s * 0.3, -s * 0.75), pos + Vector2(-s * 0.08, -s * 0.4)]), body)
	ci.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(s * 0.08, -s * 0.4), pos + Vector2(s * 0.3, -s * 0.75), pos + Vector2(s * 0.45, -s * 0.2)]), body)
	ci.draw_circle(pos, s * 0.5, body)
	var eye := fade(Color("ffd66b"), a)
	ci.draw_circle(pos + Vector2(-s * 0.17, -s * 0.08), s * 0.1, eye)
	ci.draw_circle(pos + Vector2(s * 0.17, -s * 0.08), s * 0.1, eye)


static func hut(ci: CanvasItem, pos: Vector2, s: float) -> void:
	ci.draw_circle(pos + Vector2(0, -s * 0.1), s * 0.95, Color(0.82, 0.62, 0.38, 0.12))
	ci.draw_rect(Rect2(pos.x - s * 0.5, pos.y - s * 0.4, s, s * 0.7), Color("6b4f3a"))
	ci.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-s * 0.65, -s * 0.35), pos + Vector2(0, -s * 1.0), pos + Vector2(s * 0.65, -s * 0.35)]), Color("3e2f2a"))
	ci.draw_rect(Rect2(pos.x - s * 0.12, pos.y - s * 0.05, s * 0.24, s * 0.35), Color("f0b35a"))
	ci.draw_circle(pos + Vector2(-s * 0.3, -s * 0.15), s * 0.09, Color("ffd27a"))
	ci.draw_circle(pos + Vector2(s * 0.3, -s * 0.15), s * 0.09, Color("ffd27a"))
