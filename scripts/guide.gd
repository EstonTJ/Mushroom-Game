extends Node2D
## Field Guide overlay: every mushroom in the game (found ones in full, locked
## ones as "?"), a page per mushroom with verified facts, edibility, where and
## when it grows and its dangerous lookalike, and "Did you know?" facts about
## the fungi kingdom. The game is paused while it is open (main.gd).

signal closed

const Art = preload("res://scripts/art.gd")

const PANEL := Rect2(16, 30, 688, 1220)
const CLOSE := Rect2(612, 46, 76, 64)
const BACK := Rect2(32, 46, 120, 64)
const FACT_BOX := Rect2(40, 1030, 640, 200)
const COLS := 3
const TILE := Vector2(206, 164)
const GRID_TOP := 176.0

var page := ""
var fact_index := 0
var t := 0.0
var panel_box: StyleBoxFlat
var tile_box: StyleBoxFlat
var button_box: StyleBoxFlat
var badge_box: StyleBoxFlat
var warn_box: StyleBoxFlat


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel_box = _box(Color("efe3c8"), Color("8a6242"), 26, 6)
	tile_box = _box(Color("e4d6b6"), Color("c8b48a"), 16, 2)
	button_box = _box(Color("7a5a3e"), Color("4a3424"), 12, 3)
	badge_box = _box(Color("4f8a44"), Color(0, 0, 0, 0.2), 14, 2)
	warn_box = _box(Color("f5d8c8"), Color("c8402a"), 14, 3)
	fact_index = randi() % maxi(1, Data.kingdom_facts.size())


func _box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b


func open(on_page: String = "") -> void:
	page = on_page
	visible = true
	t = 0.0


func tile_rect(i: int) -> Rect2:
	return Rect2(Vector2(40 + (i % COLS) * (TILE.x + 11), GRID_TOP + floori(float(i) / COLS) * (TILE.y + 8)), TILE)


func found_count() -> int:
	return Data.unlocked_mushrooms().size()


func tap(p: Vector2) -> void:
	if CLOSE.has_point(p):
		visible = false
		closed.emit()
		return
	if page != "":
		if BACK.has_point(p):
			page = ""
		return
	if FACT_BOX.has_point(p) and Data.kingdom_facts.size() > 0:
		fact_index = (fact_index + 1) % Data.kingdom_facts.size()
		return
	for i in Data.ingredient_order.size():
		if tile_rect(i).has_point(p):
			var id: String = Data.ingredient_order[i]
			if Data.is_unlocked(id):
				page = id
				t = 0.0
			return


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap(get_global_mouse_position())
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if visible:
		t += delta
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var rid := get_canvas_item()
	draw_rect(Rect2(0, 0, 720, 1280), Color(0.05, 0.03, 0.08, 0.7))
	panel_box.draw(rid, PANEL)
	button_box.draw(rid, CLOSE)
	draw_string(font, CLOSE.position + Vector2(0, 44), "X", HORIZONTAL_ALIGNMENT_CENTER, CLOSE.size.x, 30, Data.parchment)
	if page == "":
		_draw_grid(font, rid)
	else:
		_draw_page(font, rid, page)


func _draw_grid(font: Font, rid: RID) -> void:
	draw_string(font, Vector2(0, 96), "Field Guide", HORIZONTAL_ALIGNMENT_CENTER, 720, 40, Color("7a3a2a"))
	draw_string(font, Vector2(0, 138), "%d of %d mushrooms found" % [found_count(), Data.ingredient_order.size()],
		HORIZONTAL_ALIGNMENT_CENTER, 720, 20, Color("6a5a48"))
	for i in Data.ingredient_order.size():
		var id: String = Data.ingredient_order[i]
		var r := tile_rect(i)
		tile_box.draw(rid, r)
		if Data.is_unlocked(id):
			var info: Dictionary = Data.ingredients[id]
			Art.ingredient(self, id, r.position + Vector2(r.size.x / 2.0, 92), 84)
			draw_string(font, Vector2(r.position.x, r.end.y - 16), info["name"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Data.ink)
			var ed: String = info.get("edibility", "")
			if ed != "":
				draw_circle(r.position + Vector2(20, 20), 8, Data.edibility_color(ed))
		else:
			draw_string(font, Vector2(r.position.x, r.position.y + 96), "?", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 56,
				Color(0.4, 0.33, 0.25, 0.4))
			draw_string(font, Vector2(r.position.x, r.end.y - 16), "Night %d" % Data.unlock_night(id), HORIZONTAL_ALIGNMENT_CENTER,
				r.size.x, 15, Color(0.4, 0.33, 0.25, 0.6))
	if Data.kingdom_facts.size() > 0:
		tile_box.draw(rid, FACT_BOX)
		Art.sparkle(self, FACT_BOX.position + Vector2(34, 36), 11.0, Color("e0a030"))
		draw_string(font, FACT_BOX.position + Vector2(56, 44), "Did you know?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("7a3a2a"))
		draw_multiline_string(font, FACT_BOX.position + Vector2(28, 86), Data.kingdom_facts[fact_index], HORIZONTAL_ALIGNMENT_LEFT,
			FACT_BOX.size.x - 56, 22, 4, Data.ink)
		draw_string(font, Vector2(FACT_BOX.position.x, FACT_BOX.end.y - 14), "Tap for another fact", HORIZONTAL_ALIGNMENT_CENTER,
			FACT_BOX.size.x, 15, Color(0.4, 0.33, 0.25, 0.7))


func _draw_page(font: Font, rid: RID, id: String) -> void:
	var info: Dictionary = Data.ingredients[id]
	button_box.draw(rid, BACK)
	draw_string(font, BACK.position + Vector2(0, 42), "< Back", HORIZONTAL_ALIGNMENT_CENTER, BACK.size.x, 24, Data.parchment)

	var show := Vector2(360, 380)
	Art.glow(self, show + Vector2(0, -80), 170, Art.fade(Color(info["color"]).lightened(0.4), 0.35))
	draw_colored_polygon(Art.ellipse(show + Vector2(0, 36), 130, 30, 32), Color("7aa85a"))
	Art.ingredient(self, id, show + Vector2(0, 6 + sin(t * 2.0) * 3.0), 220)

	var y := 488.0
	draw_string(font, Vector2(0, y), info["name"], HORIZONTAL_ALIGNMENT_CENTER, 720, 38, Data.ink)
	draw_string(font, Vector2(0, y + 34), info["latin"], HORIZONTAL_ALIGNMENT_CENTER, 720, 21, Color("6a5a48"))

	var ed: String = info.get("edibility", "")
	if ed != "":
		var w := font.get_string_size(ed, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 36.0
		var badge := Rect2(360 - w / 2.0, y + 52, w, 38)
		badge_box.bg_color = Data.edibility_color(ed)
		badge_box.draw(rid, badge)
		draw_string(font, badge.position + Vector2(0, 27), ed, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 21, Color.WHITE)

	y += 128.0
	for row in [["Where", info.get("where", "")], ["When", info.get("season", "")], ["Grows", info.get("habitat", "")]]:
		if row[1] == "":
			continue
		draw_string(font, Vector2(56, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("7a3a2a"))
		draw_multiline_string(font, Vector2(150, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, 520, 20, 2, Data.ink)
		y += 30.0 if font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x < 520.0 else 56.0

	y += 16.0
	draw_line(Vector2(56, y), Vector2(664, y), Art.fade(Data.ink, 0.15), 2.0)
	y += 38.0
	var facts: Array = info.get("facts", [info.get("fact", "")])
	for f in facts:
		draw_circle(Vector2(64, y - 8), 5, Color("8a6242"))
		draw_multiline_string(font, Vector2(82, y), f, HORIZONTAL_ALIGNMENT_LEFT, 580, 21, 3, Data.ink)
		y += 30.0 * ceilf(font.get_string_size(f, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x / 580.0) + 14.0

	var look: String = info.get("lookalike", "")
	if look != "":
		var box := Rect2(44, y, 632, 96)
		warn_box.draw(rid, box)
		draw_string(font, box.position + Vector2(20, 32), "Dangerous lookalike", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("a8301e"))
		draw_multiline_string(font, box.position + Vector2(20, 60), look, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 40, 18, 2, Data.ink)

	draw_string(font, Vector2(0, PANEL.end.y - 28), "Real wild mushrooms can be deadly. Never eat one you find.", HORIZONTAL_ALIGNMENT_CENTER,
		720, 17, Color("b0413e"))
