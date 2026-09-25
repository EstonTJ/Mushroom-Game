extends Node2D
## Title screen, shown every time the game opens: Continue (if there's a
## save), New game, Choose a night, Field Guide. The moonlit scene behind is
## painted once (Baked); only the stars, fireflies and buttons animate.

signal continue_pressed
signal new_game_pressed
signal choose_pressed
signal guide_pressed
signal market_pressed

const Art = preload("res://scripts/art.gd")
const Baked = preload("res://scripts/baked.gd")
const Logo = preload("res://scripts/title_logo.gd")

## The first button (Continue, or New game on a fresh start) is the big one;
## the rest sit two to a row beneath it.
const PRIMARY := Rect2(100, 894, 520, 100)
const GRID_TOP := 1018.0
const GRID_W := 254.0
const GRID_H := 80.0
const GRID_GAP := 12.0
const YES := Rect2(120, 760, 220, 84)
const NO := Rect2(380, 760, 220, 84)
## Where the hut stands, and how big it is.
const HUT_POS := Vector2(360, 830)
const HUT_SIZE := 245.0

## Set by main.gd before adding: whether a save exists, its day and screen,
## the furthest night, and a note about how the last session ended.
var has_save := false
var save_day := 1
var best_day := 1
var note := ""

var page := "main"
var t := 0.0
var stars := []
var fireflies := []
var scene: Baked
## The pixel-lettered title, painted once and bobbed gently as a whole.
var logo: Baked
var moon := Logo.moon_center()


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 70:
		stars.append({"pos": Vector2(rng.randf_range(0, 720), rng.randf_range(0, 620)), "ph": rng.randf() * TAU,
			"r": rng.randf_range(1.0, 2.4)})
	for i in 14:
		fireflies.append({"pos": Vector2(rng.randf_range(40, 680), rng.randf_range(760, 1240)), "ph": rng.randf() * TAU})
	scene = Baked.new(_paint_scene)
	# Children draw over their parent; the backdrop has to sit behind the title.
	scene.z_index = -1
	add_child(scene)
	logo = Baked.new(Logo.paint, Vector2i(720, 400))
	add_child(logo)


## The buttons on the title, top to bottom.
func buttons() -> Array:
	var list := []
	if has_save:
		list.append("continue")
	list.append("new")
	if has_save:
		list.append("choose")
		list.append("market")
	list.append("guide")
	return list


func button_rect(i: int) -> Rect2:
	if i == 0:
		return PRIMARY
	var n := buttons().size() - 1
	var k := i - 1
	var y := GRID_TOP + floori(k / 2.0) * (GRID_H + GRID_GAP)
	# A button alone on its row spans the full width.
	if k == n - 1 and n % 2 == 1:
		return Rect2(PRIMARY.position.x, y, PRIMARY.size.x, GRID_H)
	return Rect2(PRIMARY.position.x + (k % 2) * (GRID_W + GRID_GAP), y, GRID_W, GRID_H)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap(get_global_mouse_position())


func tap(p: Vector2) -> void:
	if page == "confirm":
		if YES.has_point(p):
			new_game_pressed.emit()
		elif NO.has_point(p):
			page = "main"
		return
	var list := buttons()
	for i in list.size():
		if button_rect(i).has_point(p):
			match list[i]:
				"continue":
					continue_pressed.emit()
				"new":
					if has_save:
						page = "confirm"
					else:
						new_game_pressed.emit()
				"choose":
					choose_pressed.emit()
				"guide":
					guide_pressed.emit()
				"market":
					market_pressed.emit()
			return


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Baked backdrop: night sky, a large pale moon behind the title, hills,
## pines, the hut and its glowing mushrooms.
func _paint_scene(ci: CanvasItem) -> void:
	var top := Color("100e28")
	var mid := Color("2a2152")
	var low := Color("141c22")
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, 760), Vector2(0, 760)]),
		PackedColorArray([top, top, mid, mid]))
	ci.draw_polygon(PackedVector2Array([Vector2(0, 760), Vector2(720, 760), Vector2(720, 1280), Vector2(0, 1280)]),
		PackedColorArray([mid, mid, low, low]))
	# Moonlight spilling from the moon in the title.
	Art.glow(ci, moon, 420, Color(1.0, 0.92, 0.75, 0.16))
	var hills := [[Color("221f40"), 670.0, 0.0], [Color("1a282c"), 730.0, 1.7]]
	for h in hills:
		var pts := PackedVector2Array([Vector2(0, 1280)])
		for k in 25:
			var x := k * 30.0
			pts.append(Vector2(x, h[1] + sin(x * 0.01 + h[2]) * 34.0 + sin(x * 0.027 + h[2]) * 14.0))
		pts.append(Vector2(720, 1280))
		ci.draw_colored_polygon(pts, h[0])
	for k in 10:
		var tx := 20.0 + k * 78.0
		if absf(tx - 360.0) < 140.0:
			continue
		var ty := 720.0 + sin(tx * 0.01) * 30.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 28, ty + 34), Vector2(tx, ty - 80 - (k % 3) * 22), Vector2(tx + 28, ty + 34)]),
			Color("10181f"))
	# Warm lamplight pooling round the hut, then the hut itself.
	Art.glow(ci, HUT_POS + Vector2(0, -90), 300, Color(0.95, 0.66, 0.32, 0.26))
	Art.shadow(ci, HUT_POS + Vector2(0, 8), 190, 26, 1.2)
	Art.hut(ci, HUT_POS, HUT_SIZE, 0.0, 0)
	for m in [["ghost_fungus", Vector2(112, 838), 74.0], ["fly_agaric", Vector2(184, 850), 60.0], ["amethyst_deceiver", Vector2(560, 848), 58.0],
			["ghost_fungus", Vector2(628, 834), 64.0], ["chanterelle", Vector2(52, 860), 44.0], ["puffball", Vector2(680, 862), 40.0]]:
		if m[0] == "ghost_fungus":
			Art.glow(ci, m[1] + Vector2(0, -22), 100, Color(0.55, 1.0, 0.7, 0.3))
		elif m[0] == "amethyst_deceiver":
			Art.glow(ci, m[1] + Vector2(0, -24), 70, Color(0.7, 0.5, 1.0, 0.22))
		Art.ingredient(ci, m[0], m[1], m[2])
	# The ground fades to a dark footing for the buttons.
	var clear := Color(0.05, 0.04, 0.09, 0.0)
	var shade := Color(0.05, 0.04, 0.09, 0.78)
	ci.draw_polygon(PackedVector2Array([Vector2(0, 850), Vector2(720, 850), Vector2(720, 930), Vector2(0, 930)]),
		PackedColorArray([clear, clear, shade, shade]))
	ci.draw_rect(Rect2(0, 930, 720, 350), shade)


## A chunky frame with notched corners, a lit top edge and a shaded bottom,
## so the buttons match the outlined storybook art.
func _frame(r: Rect2, fill: Color, edge: Color, lit: Color, shade: Color, notch: float = 8.0, shadow := true) -> void:
	if shadow:
		_notched(Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.45), notch)
	_notched(r, edge, notch)
	var inner := r.grow(-4)
	_notched(inner, fill, notch - 3)
	draw_rect(Rect2(inner.position.x + notch, inner.position.y, inner.size.x - notch * 2, 4), lit)
	draw_rect(Rect2(inner.position.x + notch, inner.end.y - 6, inner.size.x - notch * 2, 6), shade)


func _notched(r: Rect2, c: Color, n: float) -> void:
	draw_rect(Rect2(r.position.x + n, r.position.y, r.size.x - n * 2, r.size.y), c)
	draw_rect(Rect2(r.position.x, r.position.y + n, r.size.x, r.size.y - n * 2), c)
	draw_rect(Rect2(r.position.x + n / 2.0, r.position.y + n / 2.0, r.size.x - n, r.size.y - n), c)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for s in stars:
		if s["pos"].distance_to(moon) < 90.0 or (s["pos"].y > 40 and s["pos"].y < 350 and absf(s["pos"].x - 360) < 330):
			continue
		var tw := 0.35 + 0.65 * absf(sin(t * 1.3 + s["ph"]))
		draw_circle(s["pos"], s["r"], Color(1, 1, 0.9, 0.8 * tw))

	# Lamplight in the windows and the ghost fungi breathe gently.
	var breathe := 0.5 + 0.5 * sin(t * 1.4)
	for w in Art.hut_windows(HUT_POS, HUT_SIZE):
		Art.glow(self, w, 46, Color(1.0, 0.75, 0.35, 0.16 + 0.1 * breathe))
	for g in [Vector2(112, 816), Vector2(628, 814)]:
		Art.glow(self, g, 56, Color(0.6, 1.0, 0.75, 0.1 + 0.08 * (1.0 - breathe)))
	for f in fireflies:
		var pos: Vector2 = f["pos"] + Vector2(sin(t * 0.7 + f["ph"]) * 30.0, cos(t * 0.5 + f["ph"]) * 16.0)
		var blink := 0.5 + 0.5 * sin(t * 3.0 + f["ph"])
		Art.glow(self, pos, 14, Color(0.8, 1.0, 0.5, 0.45 * blink))

	logo.position.y = round(sin(t * 1.2) * 3.0)
	# A few spores drift up past the title.
	for k in 4:
		var life := fposmod(t * 0.12 + k * 0.25, 1.0)
		var sx: float = [150.0, 610.0, 96.0, 560.0][k] + sin(t * 0.8 + k * 2.0) * 10.0
		var sy := 330.0 - life * 260.0
		var a := sin(life * PI) * 0.8
		draw_rect(Rect2(round(sx), round(sy), 6, 6), Color(0.85, 1.0, 0.75, a))

	# Subtitle on a dark ribbon so it reads over the moonlit sky.
	var ribbon := Rect2(36, 372, 648, 46)
	_frame(ribbon, Color(0.1, 0.07, 0.16, 0.82), Color(0.36, 0.28, 0.45, 0.9), Color(1, 1, 1, 0.06), Color(0, 0, 0, 0.2), 6.0, false)
	draw_string(font, Vector2(0, 403), "Forage by day  ·  Brew your defenses  ·  Protect the hut by night", HORIZONTAL_ALIGNMENT_CENTER,
		720, 20, Color("e8f2dc"))

	if page == "confirm":
		_frame(Rect2(40, 600, 640, 280), Color(0.1, 0.07, 0.15, 0.96), Color("5a4670"), Color(1, 1, 1, 0.06), Color(0, 0, 0, 0.25), 12.0)
		draw_string(font, Vector2(0, 666), "Start a new game?", HORIZONTAL_ALIGNMENT_CENTER, 720, 34, Color("ffd890"))
		draw_string(font, Vector2(0, 716), "Your saved game (day %d) will be erased." % save_day, HORIZONTAL_ALIGNMENT_CENTER, 720, 22,
			Data.parchment)
		_frame(YES, Color("b0413e"), Color("4a1a18"), Color(1, 0.7, 0.6, 0.35), Color(0, 0, 0, 0.2))
		draw_string(font, YES.position + Vector2(0, 54), "New game", HORIZONTAL_ALIGNMENT_CENTER, YES.size.x, 28, Color.WHITE)
		_frame(NO, Color("3a2d4c"), Color("1a1224"), Color(1, 1, 1, 0.12), Color(0, 0, 0, 0.2))
		draw_string(font, NO.position + Vector2(0, 54), "Cancel", HORIZONTAL_ALIGNMENT_CENTER, NO.size.x, 28, Data.parchment)
	else:
		var list := buttons()
		for i in list.size():
			var r := button_rect(i)
			var label: String = {"continue": "Continue  ·  Day %d" % save_day, "new": "New game", "choose": "Choose a night",
				"guide": "Field Guide", "market": "Market"}[list[i]]
			if i == 0:
				Art.glow(self, r.get_center(), r.size.x * 0.62, Color(1.0, 0.72, 0.3, 0.14 + 0.06 * breathe))
				_frame(r, Color("e8a53e"), Color("3a200e"), Color("ffe0a0"), Color("b8742a"), 10.0)
				draw_string(font, r.position + Vector2(0, 66), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, Color("2e1808"))
			else:
				_frame(r, Color(0.2, 0.15, 0.27, 0.92), Color("0e0a16"), Color(0.55, 0.77, 0.76, 0.35), Color(0, 0, 0, 0.25))
				draw_string(font, r.position + Vector2(0, 51), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 25, Color("e6dcc8"))

	if note != "":
		draw_string_outline(font, Vector2(20, 1236), note, HORIZONTAL_ALIGNMENT_LEFT, 560, 16, 5, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(20, 1236), note, HORIZONTAL_ALIGNMENT_LEFT, 560, 16, Color("ffb08a"))
	if Data.dev:
		_frame(Rect2(20, 20, 150, 50), Color("c0392b"), Color("3a0e0a"), Color(1, 0.7, 0.6, 0.35), Color(0, 0, 0, 0.2), 6.0)
		draw_string(font, Vector2(20, 55), "DEV BUILD", HORIZONTAL_ALIGNMENT_CENTER, 150, 22, Color.WHITE)
	draw_string(font, Vector2(500, 1262), "Version " + Data.version_label(), HORIZONTAL_ALIGNMENT_RIGHT, 200, 16, Color(1, 1, 1, 0.5))
