extends Node
## Creature sprite cache (autoload "Sprites"). Each creature kind's walk cycle
## is painted once into a strip of FRAMES images; after that a creature costs
## one textured quad per frame instead of dozens of vector shapes, which is what
## keeps busy nights smooth in a phone browser. Until a strip is ready (one frame
## after it's first asked for), callers fall back to drawing the vector art.

const Art = preload("res://scripts/art.gd")

const FRAMES := 8
## One walk step is sin(t * 14): a full cycle is TAU / 14 seconds.
const CYCLE := TAU / 14.0
## Cell size relative to the creature's size, and where its feet sit in the cell.
const CELL_SCALE := 2.4
const ANCHOR := Vector2(0.5, 0.64)

var _strips := {}


class Strip extends Node2D:
	var kind := ""
	var size := 40.0
	var cell := 96

	func _draw() -> void:
		for i in FRAMES:
			var t: float = CYCLE * i / FRAMES
			var at := Vector2(cell * (i + ANCHOR.x), cell * ANCHOR.y)
			Art.creature(self, kind, at, size, 1.0, t, false)


func _cell_for(size: float) -> int:
	return int(ceil(size * CELL_SCALE))


## Ask for a kind's strip at a given size; builds it the first time.
func request(kind: String, size: float) -> void:
	var key := "%s@%d" % [kind, int(size)]
	if _strips.has(key):
		return
	var cell := _cell_for(size)
	var vp := SubViewport.new()
	vp.size = Vector2i(cell * FRAMES, cell)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var strip := Strip.new()
	strip.kind = kind
	strip.size = size
	strip.cell = cell
	vp.add_child(strip)
	add_child(vp)
	_strips[key] = {"viewport": vp, "cell": cell, "frames_waited": 0}


func _process(_delta: float) -> void:
	for key in _strips:
		var s: Dictionary = _strips[key]
		if s["frames_waited"] < 3:
			s["frames_waited"] += 1


## Draws the creature from the cache. Returns false if its strip isn't ready
## yet (the caller should draw the vector art instead).
func draw(ci: CanvasItem, kind: String, pos: Vector2, size: float, a: float, t: float) -> bool:
	var key := "%s@%d" % [kind, int(size)]
	if not _strips.has(key):
		request(kind, size)
		return false
	var s: Dictionary = _strips[key]
	if s["frames_waited"] < 2:
		return false
	var cell: int = s["cell"]
	var frame := posmod(int(floor(t / CYCLE * FRAMES)), FRAMES)
	var region := Rect2(cell * frame, 0, cell, cell)
	var dest := Rect2(pos - Vector2(cell * ANCHOR.x, cell * ANCHOR.y), Vector2(cell, cell))
	ci.draw_texture_rect_region(s["viewport"].get_texture(), dest, region, Color(1, 1, 1, a))
	return true
