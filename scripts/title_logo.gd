extends RefCounted
## The "Mushroom Moon" wordmark, lettered by hand as thick round-ended pen
## strokes: warm cream with a gold lower edge, a dark plum outline and a
## drop shadow. The M of "Mushroom" wears a spotted mushroom cap; the first
## "o" of "Moon" is the moon, about the size of the "o" beside it.
## Painted once into a Baked layer by title.gd.
##
## Letters are measured in units: x-height X, capital height CAP, stroke
## width W. y is 0 on the baseline and negative upward.

const Art = preload("res://scripts/art.gd")

const X := 5.0
const CAP := 7.6
const W := 1.7
const H := W / 2.0
const GAP := 0.9
## Outline thickness and shadow drop, in units.
const EDGE := 0.42
const DROP := 0.5
const MOON_D := 5.4

const FILL := Color("fff1d2")
const RIM := Color("eeb85c")
const CAP_FILL := Color("dc7658")
const CAP_RIM := Color("a9462f")
const SPOT := Color("fff1d2")
const OUTLINE := Color("2a1630")
const SHADOW := Color(0.07, 0.03, 0.12, 0.75)
const MOON_LIT := Color("fff2bf")
const MOON_SHADE := Color("efd084")
const CRATER := Color(0.8, 0.66, 0.4, 0.5)

## Where each line sits on the 720-wide screen: baseline and unit size.
const LINE1_BASE := 172.0
const LINE1_UNIT := 12.4
const LINE2_BASE := 338.0
const LINE2_UNIT := 17.0


static func _arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, n: int = 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## A letter's width and its strokes (each a list of points along the pen's path).
static func glyph(ch: String) -> Array:
	match ch:
		"M", "N":
			var w := 7.4
			return [w, [PackedVector2Array([Vector2(H, -H), Vector2(H, -CAP + H), Vector2(w / 2.0, -CAP * 0.36),
				Vector2(w - H, -CAP + H), Vector2(w - H, -H)])]]
		"u":
			var w := 4.6
			var rx := w / 2.0 - H
			var bowl := PackedVector2Array([Vector2(H, -X + H)])
			bowl.append_array(_arc(Vector2(w / 2.0, -H - rx), rx, rx, PI, 0.0))
			bowl.append(Vector2(w - H, -X + H))
			return [w, [bowl, PackedVector2Array([Vector2(w - H, -X + H), Vector2(w - H, -H)])]]
		"n", "h":
			var w := 4.6
			var rx := w / 2.0 - H
			var top := -CAP if ch == "h" else -X
			var arch := _arc(Vector2(w / 2.0, -X + H + rx), rx, rx, PI, TAU)
			arch.append(Vector2(w - H, -H))
			return [w, [PackedVector2Array([Vector2(H, -H), Vector2(H, top + H)]), arch]]
		"m":
			var w := 7.2
			var r := (w - 2.0 * H) / 4.0
			var cy := -X + H + r
			var arches := _arc(Vector2(H + r, cy), r, r, PI, TAU, 12)
			arches.append(Vector2(H + 2.0 * r, -H))
			var second := _arc(Vector2(H + 3.0 * r, cy), r, r, PI, TAU, 12)
			second.append(Vector2(w - H, -H))
			return [w, [PackedVector2Array([Vector2(H, -H), Vector2(H, -X + H)]), arches, second]]
		"r":
			var w := 3.8
			var rx := 1.5
			return [w, [PackedVector2Array([Vector2(H, -H), Vector2(H, -X + H)]),
				_arc(Vector2(H + rx, -X + H + rx), rx, rx, PI, PI * 1.72, 10)]]
		"o":
			var w := 4.8
			return [w, [_arc(Vector2(w / 2.0, -X / 2.0), w / 2.0 - H, X / 2.0 - H, 0.0, TAU, 28)]]
		"s":
			var w := 4.3
			var rx := w / 2.0 - H
			var a := (X - 2.0 * H) / 4.0
			var pts := _arc(Vector2(w / 2.0, -X + H + a), rx, a, PI * 1.85, PI * 0.5, 16)
			pts.append_array(_arc(Vector2(w / 2.0, -H - a), rx, a, PI * 1.5, PI * 2.85, 16))
			return [w, [pts]]
		"@":
			return [MOON_D, []]
	return [0.0, []]


static func word_width(word: String) -> float:
	var w := 0.0
	for ch in word:
		w += float(glyph(ch)[0])
	return w + GAP * (word.length() - 1)


## Screen position of the word's left end on its baseline.
static func word_origin(word: String, base: float, unit: float) -> Vector2:
	return Vector2(roundf((720.0 - word_width(word) * unit) / 2.0), base)


static func moon_center() -> Vector2:
	var o := word_origin("N@on", LINE2_BASE, LINE2_UNIT)
	var left := float(glyph("N")[0]) + GAP
	return o + Vector2(left + MOON_D / 2.0, -MOON_D / 2.0) * LINE2_UNIT


static func paint(ci: CanvasItem) -> void:
	Art.glow(ci, moon_center(), 190, Color(1.0, 0.9, 0.62, 0.5))
	Art.glow(ci, Vector2(360, LINE1_BASE - 50), 300, Color(0.62, 0.45, 0.85, 0.12))
	_word(ci, "Mushroom", LINE1_BASE, LINE1_UNIT)
	_word(ci, "N@on", LINE2_BASE, LINE2_UNIT)


## Draws a word in passes (shadow, outline, gold rim, cream face) so
## touching strokes share one outline.
static func _word(ci: CanvasItem, word: String, base: float, u: float) -> void:
	var strokes := []
	var x := 0.0
	var cap_left := -1.0
	var moon_left := -1.0
	for ch in word:
		var g := glyph(ch)
		for s in g[1]:
			var pts := PackedVector2Array()
			for p in s:
				pts.append(Vector2(x, 0) + p)
			strokes.append(pts)
		if ch == "M":
			cap_left = x
		if ch == "@":
			moon_left = x
		x += float(g[0]) + GAP
	var o := word_origin(word, base, u)
	var drop := Vector2(0, DROP * u)
	var passes := [[drop, (W + EDGE * 2.0) * u, SHADOW, EDGE], [Vector2.ZERO, (W + EDGE * 2.0) * u, OUTLINE, EDGE],
		[Vector2.ZERO, W * u, RIM, 0.0], [Vector2(0, -0.16 * u), (W - 0.34) * u, FILL, -0.17]]
	for pass_i in passes.size():
		var ps: Array = passes[pass_i]
		var shift: Vector2 = ps[0]
		var width: float = ps[1]
		var col: Color = ps[2]
		for s in strokes:
			_stroke(ci, s, o + shift, u, width, col)
		if cap_left >= 0.0:
			_cap(ci, o + shift + Vector2(cap_left, 0) * u, u, ps[3], pass_i)
		if moon_left >= 0.0 and pass_i < 2:
			ci.draw_circle(o + shift + Vector2(moon_left + MOON_D / 2.0, -MOON_D / 2.0) * u, (MOON_D / 2.0 + EDGE) * u, col)
	if moon_left >= 0.0:
		_moon(ci, moon_center(), MOON_D / 2.0 * u)


## One pen stroke: a line through the points with a round dot at every
## point, so ends and corners come out round.
static func _stroke(ci: CanvasItem, pts: PackedVector2Array, o: Vector2, u: float, width: float, col: Color) -> void:
	var screen := PackedVector2Array()
	for p in pts:
		screen.append(o + p * u)
	# Separate segments (no mitred joins, which spike at sharp corners).
	for i in screen.size() - 1:
		ci.draw_line(screen[i], screen[i + 1], col, width, true)
	for p in screen:
		ci.draw_circle(p, width / 2.0, col)


## The mushroom cap over the M of "Mushroom": a dome with a slightly curved
## underside and three spots. grow widens it for the shadow and outline.
static func _cap(ci: CanvasItem, left: Vector2, u: float, grow: float, pass_i: int) -> void:
	var w := float(glyph("M")[0])
	var c := left + Vector2(w / 2.0, -CAP + 0.9) * u
	var rx := (w / 2.0 + 0.9 + grow) * u
	var ry := (2.9 + grow) * u
	var pts := _arc(c, rx, ry, PI, TAU, 24)
	# The underside: a gentle curve from rim to rim, rounded at both ends.
	var under := (0.35 + grow) * u
	for i in range(1, 16):
		var t := float(i) / 16.0
		pts.append(c + Vector2(rx * cos(t * PI), under * sin(t * PI)))
	var col: Color
	match pass_i:
		0:
			col = SHADOW
		1:
			col = OUTLINE
		2:
			col = CAP_RIM
		_:
			col = CAP_FILL
	if pass_i == 3:
		# The face sits a little higher than the rim, leaving a darker underside.
		pts = _arc(c + Vector2(0, -0.12 * u), rx - 0.1 * u, ry - 0.3 * u, PI, TAU, 24)
		pts.append(c + Vector2(0, 0.05 * u))
	ci.draw_colored_polygon(pts, col)
	if pass_i == 3:
		for spot in [[Vector2(-1.9, -1.2), 0.5], [Vector2(0.9, -2.0), 0.38], [Vector2(2.6, -0.7), 0.3]]:
			ci.draw_circle(c + spot[0] * u, spot[1] * u, SPOT)


## A smooth full moon: lit face, a shaded lower edge and a few craters.
static func _moon(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, MOON_SHADE)
	ci.draw_circle(c + Vector2(-r * 0.07, -r * 0.09), r * 0.9, MOON_LIT)
	for crater in [[Vector2(-0.35, -0.3), 0.2], [Vector2(0.3, 0.1), 0.15], [Vector2(-0.1, 0.42), 0.12], [Vector2(0.38, -0.4), 0.08]]:
		ci.draw_circle(c + crater[0] * r, crater[1] * r, CRATER)
	ci.draw_circle(c + Vector2(-r * 0.42, -r * 0.45), r * 0.12, Color(1, 1, 1, 0.45))
