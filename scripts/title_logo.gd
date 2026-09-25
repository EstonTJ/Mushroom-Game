extends RefCounted
## The "Mushroom Moon" wordmark, built from hand-drawn pixel letters so it
## matches the game's chunky outlined art. Glyphs are listed top to bottom and sit on a
## shared baseline, ROWS tall at most:
##   #  letter      c  mushroom cap      o  spot on a cap
## Lowercase letters are six rows tall; the capital M is taller, cap and all. The first "o" of "Moon" is
## the moon itself. Painted once into a Baked layer by title.gd.

const Art = preload("res://scripts/art.gd")

const ROWS := 11
const GLYPHS := {
	"M": ["...ccccc...", ".ccocccccc.", "cccccccoccc", ".##.....##.", ".###...###.", ".####.####.", ".##.###.##.", ".##..#..##.", ".##.....##.", ".##.....##.", ".##.....##."],
	"u": ["##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
	"s": [".####", "##...", ".###.", "...##", "...##", "####."],
	"h": ["##....", "##....", "##....", "#####.", "##..##", "##..##", "##..##", "##..##", "##..##"],
	"r": ["##.##", "####.", "##...", "##...", "##...", "##..."],
	"o": [".####.", "##..##", "##..##", "##..##", "##..##", ".####."],
	"m": ["#######.", "##.##.##", "##.##.##", "##.##.##", "##.##.##", "##.##.##"],
	"n": ["#####.", "##..##", "##..##", "##..##", "##..##", "##..##"],
}
## The moon-"o": a pixel disc a little larger than a lowercase letter.
const MOON_COLS := 8
const MOON_TOP := 3

## Letter colours run top to bottom, cream to warm gold.
const TOP := Color("fff3d6")
const BOTTOM := Color("f2c46e")
const CAP_TOP := Color("e38463")
const CAP_BOTTOM := Color("b9533f")
const SPOT := Color("fff3d6")
const OUTLINE := Color("2a1630")
const SHADOW := Color(0.07, 0.03, 0.12, 0.75)
const MOON_LIT := Color("fff4c4")
const MOON_SHADE := Color("e9d28f")
const CRATER := Color("d6bd78")

## Layout on the 720-wide screen: each word's top edge and pixel size.
const LINE1_TOP := 44.0
const LINE1_PX := 10.0
const LINE2_TOP := 168.0
const LINE2_PX := 16.0
const GAP_COLS := 1


static func _width(glyph: Array) -> int:
	var w := 0
	for row in glyph:
		w = maxi(w, (row as String).length())
	return w


## Columns in a word, with "@" standing for the moon.
static func word_cols(word: String) -> int:
	var cols := 0
	for ch in word:
		cols += MOON_COLS if ch == "@" else _width(GLYPHS[ch])
	return cols + GAP_COLS * (word.length() - 1)


static func word_left(word: String, px: float) -> float:
	return roundf((720.0 - word_cols(word) * px) / 2.0)


## Centre of the moon-"o" on screen (for its glow and for keeping stars off it).
static func moon_center() -> Vector2:
	var left := word_left("M@on", LINE2_PX) + (_width(GLYPHS["M"]) + GAP_COLS) * LINE2_PX
	return Vector2(left + MOON_COLS * LINE2_PX / 2.0, LINE2_TOP + (MOON_TOP + (ROWS - MOON_TOP) / 2.0) * LINE2_PX)


static func paint(ci: CanvasItem) -> void:
	var moon := moon_center()
	Art.glow(ci, moon, 210, Color(1.0, 0.9, 0.62, 0.5))
	Art.glow(ci, Vector2(360, LINE1_TOP + 50), 300, Color(0.62, 0.45, 0.85, 0.12))
	_word(ci, "Mushroom", LINE1_TOP, LINE1_PX)
	_word(ci, "M@on", LINE2_TOP, LINE2_PX)


## Collects a word's cells as [col, row, kind] and draws them in three passes:
## drop shadow, outline, then fill, so neighbouring letters share one outline.
static func _word(ci: CanvasItem, word: String, top: float, px: float) -> void:
	var cells := []
	var col := 0
	for ch in word:
		if ch == "@":
			cells.append_array(_moon_cells(col))
			col += MOON_COLS + GAP_COLS
			continue
		var glyph: Array = GLYPHS[ch]
		var drop_rows := ROWS - glyph.size()
		for r in glyph.size():
			var row: String = glyph[r]
			for c in row.length():
				if row[c] != ".":
					cells.append([col + c, drop_rows + r, row[c]])
		col += _width(glyph) + GAP_COLS
	var origin := Vector2(word_left(word, px), top)
	var edge := roundf(px * 0.4)
	var drop := roundf(px * 0.55)
	for cell in cells:
		ci.draw_rect(Rect2(_cell(origin, cell, px).position + Vector2(0, drop), Vector2(px, px)).grow(edge), SHADOW)
	for cell in cells:
		ci.draw_rect(_cell(origin, cell, px).grow(edge), OUTLINE)
	for cell in cells:
		var r := _cell(origin, cell, px)
		var k := float(cell[1]) / (ROWS - 1)
		match cell[2]:
			"#":
				ci.draw_rect(r, TOP.lerp(BOTTOM, k))
			"c":
				ci.draw_rect(r, CAP_TOP.lerp(CAP_BOTTOM, clampf(k * 4.0, 0.0, 1.0)))
			"o":
				ci.draw_rect(r, SPOT)
			"L":
				ci.draw_rect(r, MOON_LIT.lerp(MOON_SHADE, k))
			"C":
				ci.draw_rect(r, CRATER)
	# A one-pixel shine along the top of each lettered cell row that has open sky above.
	var filled := {}
	for cell in cells:
		filled[Vector2i(cell[0], cell[1])] = true
	for cell in cells:
		if cell[2] == "#" and not filled.has(Vector2i(cell[0], cell[1] - 1)):
			var r := _cell(origin, cell, px)
			ci.draw_rect(Rect2(r.position, Vector2(px, roundf(px * 0.22))), Color(1, 1, 1, 0.55))


static func _cell(origin: Vector2, cell: Array, px: float) -> Rect2:
	return Rect2(origin + Vector2(cell[0], cell[1]) * px, Vector2(px, px))


## A pixel disc with a few craters, MOON_COLS wide, from row MOON_TOP down.
static func _moon_cells(left: int) -> Array:
	var cells := []
	var size := ROWS - MOON_TOP
	var c0 := (MOON_COLS - 1) / 2.0
	var r0 := (size - 1) / 2.0
	var craters := [Vector2i(2, 2), Vector2i(5, 4), Vector2i(4, 5), Vector2i(2, 5)]
	for r in size:
		for c in MOON_COLS:
			if pow((c - c0) / (MOON_COLS / 2.0), 2) + pow((r - r0) / (size / 2.0), 2) <= 1.0:
				cells.append([left + c, MOON_TOP + r, "C" if craters.has(Vector2i(c, r)) else "L"])
	return cells
