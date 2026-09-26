extends Node2D
## Dawn after a won night: how the night went (creatures scared off, hut
## hearts left, coins and bones earned, any boss beaten), a peek at the
## coming night, and a choice: visit the market or start the next day.
## main.gd sets `stats` (Data.last_night) before adding it.

signal market_pressed
signal next_pressed

const Art = preload("res://scripts/art.gd")
const Baked = preload("res://scripts/baked.gd")

const CARD := Rect2(40, 632, 640, 450)
const MARKET_BTN := Rect2(40, 1120, 300, 110)
const NEXT_BTN := Rect2(360, 1120, 320, 110)

var stats := {}
var t := 0.0
var scene: Baked
var card_box: StyleBoxFlat
var next_box: StyleBoxFlat
var market_box: StyleBoxFlat


func _ready() -> void:
	card_box = _box(Color("efe3c8"), Color("8a6242"), 26, 5)
	next_box = _box(Color("e8a53e"), Color("3a200e"), 22, 4)
	market_box = _box(Color("7a5a3e"), Color("4a3424"), 22, 4)
	scene = Baked.new(_paint_scene)
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


func tap(p: Vector2) -> void:
	if MARKET_BTN.has_point(p):
		market_pressed.emit()
	elif NEXT_BTN.has_point(p):
		next_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap(get_global_mouse_position())


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Sunrise over the hills, with the hut showing any damage from the night.
func _paint_scene(ci: CanvasItem) -> void:
	var top := Color("f3b27a")
	var mid := Color("f7d9a0")
	var low := Color("a8c890")
	ci.draw_polygon(PackedVector2Array([Vector2(0, 110), Vector2(720, 110), Vector2(720, 520), Vector2(0, 520)]),
		PackedColorArray([Color("8a78b8"), Color("8a78b8"), top, top]))
	ci.draw_polygon(PackedVector2Array([Vector2(0, 520), Vector2(720, 520), Vector2(720, 640), Vector2(0, 640)]),
		PackedColorArray([top, top, mid, mid]))
	var sun := Vector2(530, 500)
	Art.glow(ci, sun, 260, Color(1.0, 0.85, 0.5, 0.55))
	ci.draw_circle(sun, 70, Color("ffe8a8"))
	for h in [[Color("7aa06a"), 520.0, 0.4], [Color("5f8a58"), 560.0, 2.1]]:
		var pts := PackedVector2Array([Vector2(0, 1280)])
		for k in 25:
			var x := k * 30.0
			pts.append(Vector2(x, h[1] + sin(x * 0.012 + h[2]) * 26.0))
		pts.append(Vector2(720, 1280))
		ci.draw_colored_polygon(pts, h[0])
	ci.draw_rect(Rect2(0, 640, 720, 640), low.darkened(0.35))
	var hp := int(stats.get("hp", Data.HUT_HP))
	Art.hut(ci, Vector2(190, 590), 160.0, 0.0, clampi(Data.HUT_HP - hp, 0, Data.HUT_HP - 1))
	ci.draw_rect(Rect2(0, 640, 720, 640), Color(0.12, 0.1, 0.14, 0.45))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var rid := get_canvas_item()
	var night := int(stats.get("night", Data.day - 1))
	var bob := sin(t * 1.6) * 3.0
	draw_string_outline(font, Vector2(0, 196 + bob), "Night %d survived!" % night, HORIZONTAL_ALIGNMENT_CENTER, 720, 52, 12,
		Color("3a1e30"))
	draw_string(font, Vector2(0, 196 + bob), "Night %d survived!" % night, HORIZONTAL_ALIGNMENT_CENTER, 720, 52, Color("fff3d6"))
	draw_string_outline(font, Vector2(0, 240), "The sun comes up over the hut.", HORIZONTAL_ALIGNMENT_CENTER, 720, 24, 6,
		Color(0.2, 0.1, 0.2, 0.6))
	draw_string(font, Vector2(0, 240), "The sun comes up over the hut.", HORIZONTAL_ALIGNMENT_CENTER, 720, 24, Color("fff3d6"))

	card_box.draw(rid, CARD)
	var x0 := CARD.position.x + 40.0
	var row := CARD.position.y + 70.0
	var gap := 78.0
	# Creatures scared off.
	var repelled := int(stats.get("repelled", 0))
	var total := int(stats.get("total", repelled))
	Art.creature(self, "mischief", Vector2(x0 + 22, row + 8), 34.0, 1.0, t)
	_row(font, row, "Creatures scared off", "%d / %d" % [repelled, total])
	row += gap
	# Hut hearts.
	var hp := int(stats.get("hp", Data.HUT_HP))
	Art.heart(self, Vector2(x0 + 22, row - 8), 30, Color("d8445a"))
	draw_string(font, Vector2(x0 + 62, row), "Hut", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Data.ink)
	for i in Data.HUT_HP:
		Art.heart(self, Vector2(CARD.end.x - 60 - (Data.HUT_HP - 1 - i) * 40, row - 8), 26,
			Color("d8445a") if i < hp else Color(0.5, 0.42, 0.36, 0.35))
	row += gap
	# Coins and bones.
	Art.coin(self, Vector2(x0 + 22, row - 8), 32)
	_row(font, row, "Coins earned", "+%d  (you have %d)" % [int(stats.get("coins", 0)), Data.coins])
	row += gap
	Art.bone(self, Vector2(x0 + 22, row - 8), 40)
	_row(font, row, "Bones collected", "+%d  (you have %d)" % [int(stats.get("bones", 0)), Data.bones])
	row += gap
	# A beaten boss, or what's coming tonight.
	var boss := str(stats.get("boss", ""))
	if boss != "":
		Art.crown(self, Vector2(x0 + 22, row - 6), 32)
		_row(font, row, "Boss beaten", str(Data.creatures[boss]["name"]))
		if int(stats.get("reishi", 0)) > 0:
			Art.reishi(self, Vector2(CARD.position.x + 120, row + 44), 40)
			draw_string(font, Vector2(CARD.position.x + 146, row + 50), "It dropped a reishi! (you have %d)" % Data.reishi,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("a8401e"))
	else:
		var next_boss := Data.night_boss(Data.day)
		Art.glow(self, Vector2(x0 + 22, row - 8), 26, Color(0.6, 0.5, 1.0, 0.6))
		draw_circle(Vector2(x0 + 22, row - 8), 12, Color("fff2bf"))
		_row(font, row, "Tonight (night %d)" % Data.day, "%d creatures%s" % [Data.night_count(Data.day), " + a boss!" if next_boss != "" else ""])

	market_box.draw(rid, MARKET_BTN)
	draw_string(font, MARKET_BTN.position + Vector2(0, 50), "Visit the", HORIZONTAL_ALIGNMENT_CENTER, MARKET_BTN.size.x, 24, Data.parchment)
	draw_string(font, MARKET_BTN.position + Vector2(0, 84), "Market", HORIZONTAL_ALIGNMENT_CENTER, MARKET_BTN.size.x, 32, Color.WHITE)
	Art.glow(self, NEXT_BTN.get_center(), NEXT_BTN.size.x * 0.6, Color(1.0, 0.72, 0.3, 0.12 + 0.05 * sin(t * 2.0)))
	next_box.draw(rid, NEXT_BTN)
	draw_string(font, NEXT_BTN.position + Vector2(0, 50), "Start", HORIZONTAL_ALIGNMENT_CENTER, NEXT_BTN.size.x, 24, Color("5a3010"))
	draw_string(font, NEXT_BTN.position + Vector2(0, 84), "Day %d" % Data.day, HORIZONTAL_ALIGNMENT_CENTER, NEXT_BTN.size.x, 32,
		Color("2e1808"))


func _row(font: Font, y: float, label: String, value: String) -> void:
	draw_string(font, Vector2(CARD.position.x + 102, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Data.ink)
	draw_string(font, Vector2(CARD.position.x, y), value, HORIZONTAL_ALIGNMENT_RIGHT, CARD.size.x - 40, 26, Color("7a3a2a"))
