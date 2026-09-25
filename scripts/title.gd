extends Node2D
## Title screen, shown every time the game opens: Continue (if there's a
## save), New game, Choose a night, Field Guide. The moonlit scene behind is
## painted once (Baked); only the stars, fireflies and buttons animate.

signal continue_pressed
signal new_game_pressed
signal choose_pressed
signal guide_pressed

const Art = preload("res://scripts/art.gd")
const Baked = preload("res://scripts/baked.gd")

const BUTTON_W := 460.0
const BUTTON_H := 92.0
const FIRST_Y := 772.0
const GAP := 110.0
const YES := Rect2(120, 760, 220, 84)
const NO := Rect2(380, 760, 220, 84)

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
var button_box: StyleBoxFlat
var main_box: StyleBoxFlat
var danger_box: StyleBoxFlat


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 70:
		stars.append({"pos": Vector2(rng.randf_range(0, 720), rng.randf_range(0, 620)), "ph": rng.randf() * TAU,
			"r": rng.randf_range(1.0, 2.4)})
	for i in 14:
		fireflies.append({"pos": Vector2(rng.randf_range(40, 680), rng.randf_range(760, 1240)), "ph": rng.randf() * TAU})
	button_box = _box(Color(0.24, 0.18, 0.3, 0.85), Color(0.55, 0.77, 0.76, 0.6), 22, 3)
	main_box = _box(Color("4f8a44"), Color("2f5a30"), 22, 3)
	danger_box = _box(Color("b0413e"), Color("7a2a26"), 18, 3)
	scene = Baked.new(_paint_scene)
	# Children draw over their parent; the backdrop has to sit behind the title.
	scene.z_index = -1
	add_child(scene)


func _box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b


## The buttons on the title, top to bottom.
func buttons() -> Array:
	var list := []
	if has_save:
		list.append("continue")
	list.append("new")
	if has_save:
		list.append("choose")
	list.append("guide")
	return list


func button_rect(i: int) -> Rect2:
	return Rect2(360 - BUTTON_W / 2.0, FIRST_Y + i * GAP, BUTTON_W, BUTTON_H)


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
			return


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Baked backdrop: night sky, moon, hills, the hut and glowing mushrooms.
func _paint_scene(ci: CanvasItem) -> void:
	var top := Color("141230")
	var mid := Color("2e2458")
	var low := Color("1a2a2a")
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, 700), Vector2(0, 700)]),
		PackedColorArray([top, top, mid, mid]))
	ci.draw_polygon(PackedVector2Array([Vector2(0, 700), Vector2(720, 700), Vector2(720, 1280), Vector2(0, 1280)]),
		PackedColorArray([mid, mid, low, low]))
	var moon := Vector2(520, 230)
	Art.glow(ci, moon, 300, Color(1.0, 0.95, 0.8, 0.35))
	ci.draw_circle(moon, 96, Color("fff3d0"))
	for c in [[Vector2(-30, -20), 16.0], [Vector2(25, 30), 12.0], [Vector2(40, -35), 8.0]]:
		ci.draw_circle(moon + c[0], c[1], Color(0.9, 0.84, 0.7, 0.6))
	var hills := [[Color("22203e"), 560.0, 0.0], [Color("1b2a2e"), 610.0, 1.7]]
	for h in hills:
		var pts := PackedVector2Array([Vector2(0, 1280)])
		for k in 25:
			var x := k * 30.0
			pts.append(Vector2(x, h[1] + sin(x * 0.01 + h[2]) * 40.0 + sin(x * 0.027 + h[2]) * 16.0))
		pts.append(Vector2(720, 1280))
		ci.draw_colored_polygon(pts, h[0])
	for k in 10:
		var tx := 20.0 + k * 78.0
		var ty := 585.0 + sin(tx * 0.01) * 40.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 26, ty + 30), Vector2(tx, ty - 70 - (k % 3) * 20), Vector2(tx + 26, ty + 30)]),
			Color("121a22"))
	Art.glow(ci, Vector2(360, 640), 260, Color(0.82, 0.62, 0.38, 0.25))
	Art.hut(ci, Vector2(360, 690), 150.0, 0.0, 0)
	for m in [["ghost_fungus", Vector2(120, 690), 70.0], ["fly_agaric", Vector2(230, 700), 62.0], ["amethyst_deceiver", Vector2(520, 700), 56.0],
			["ghost_fungus", Vector2(610, 690), 60.0], ["chanterelle", Vector2(80, 720), 44.0], ["puffball", Vector2(650, 720), 40.0]]:
		if m[0] == "ghost_fungus":
			Art.glow(ci, m[1] + Vector2(0, -20), 90, Color(0.55, 1.0, 0.65, 0.35))
		Art.ingredient(ci, m[0], m[1], m[2])
	ci.draw_rect(Rect2(0, 730, 720, 550), Color(0.06, 0.05, 0.1, 0.55))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var rid := get_canvas_item()
	for s in stars:
		var tw := 0.35 + 0.65 * absf(sin(t * 1.3 + s["ph"]))
		draw_circle(s["pos"], s["r"], Color(1, 1, 0.9, 0.8 * tw))
	for f in fireflies:
		var pos: Vector2 = f["pos"] + Vector2(sin(t * 0.7 + f["ph"]) * 30.0, cos(t * 0.5 + f["ph"]) * 16.0)
		var blink := 0.5 + 0.5 * sin(t * 3.0 + f["ph"])
		Art.glow(self, pos, 14, Color(0.8, 1.0, 0.5, 0.5 * blink))

	var bob := sin(t * 1.2) * 4.0
	draw_string_outline(font, Vector2(0, 190 + bob), "Mushroom", HORIZONTAL_ALIGNMENT_CENTER, 720, 92, 14, Color(0.08, 0.04, 0.14, 0.85))
	draw_string(font, Vector2(0, 190 + bob), "Mushroom", HORIZONTAL_ALIGNMENT_CENTER, 720, 92, Color("f5e6c0"))
	draw_string_outline(font, Vector2(0, 290 + bob), "Moon", HORIZONTAL_ALIGNMENT_CENTER, 720, 110, 14, Color(0.08, 0.04, 0.14, 0.85))
	draw_string(font, Vector2(0, 290 + bob), "Moon", HORIZONTAL_ALIGNMENT_CENTER, 720, 110, Color("ffd890"))
	draw_string_outline(font, Vector2(0, 350), "Forage by day. Brew your defenses. Protect the hut by night.", HORIZONTAL_ALIGNMENT_CENTER,
		720, 21, 6, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(0, 350), "Forage by day. Brew your defenses. Protect the hut by night.", HORIZONTAL_ALIGNMENT_CENTER,
		720, 21, Color("c8f5e8"))

	if page == "confirm":
		draw_rect(Rect2(40, 600, 640, 280), Color(0.08, 0.06, 0.12, 0.9))
		draw_string(font, Vector2(0, 660), "Start a new game?", HORIZONTAL_ALIGNMENT_CENTER, 720, 34, Color("ffd890"))
		draw_string(font, Vector2(0, 710), "Your saved game (day %d) will be erased." % save_day, HORIZONTAL_ALIGNMENT_CENTER, 720, 22,
			Data.parchment)
		danger_box.draw(rid, YES)
		draw_string(font, YES.position + Vector2(0, 54), "New game", HORIZONTAL_ALIGNMENT_CENTER, YES.size.x, 28, Color.WHITE)
		button_box.draw(rid, NO)
		draw_string(font, NO.position + Vector2(0, 54), "Cancel", HORIZONTAL_ALIGNMENT_CENTER, NO.size.x, 28, Data.parchment)
	else:
		var list := buttons()
		for i in list.size():
			var r := button_rect(i)
			var label: String = {"continue": "Continue  ·  Day %d" % save_day, "new": "New game", "choose": "Choose a night",
				"guide": "Field Guide"}[list[i]]
			(main_box if i == 0 else button_box).draw(rid, r)
			draw_string(font, r.position + Vector2(0, 60), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 32, Color.WHITE)

	if note != "":
		draw_string_outline(font, Vector2(20, 1236), note, HORIZONTAL_ALIGNMENT_LEFT, 560, 16, 5, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(20, 1236), note, HORIZONTAL_ALIGNMENT_LEFT, 560, 16, Color("ffb08a"))
	draw_string(font, Vector2(500, 1262), "Version " + Data.VERSION, HORIZONTAL_ALIGNMENT_RIGHT, 200, 16, Color(1, 1, 1, 0.5))
