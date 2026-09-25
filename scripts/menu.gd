extends Node2D
## Game menu overlay (the game is paused while it's open): resume, open the
## Field Guide, replay any night already reached, or start over.

signal resumed
signal guide_requested
signal night_chosen(n: int)
signal restart_confirmed
signal title_requested
signal market_requested

const Art = preload("res://scripts/art.gd")

const PANEL := Rect2(16, 30, 688, 1220)
const CLOSE := Rect2(612, 46, 76, 64)
const BACK := Rect2(32, 46, 120, 64)
const MAIN_BUTTONS := ["Resume", "Field Guide", "Choose a night", "Market", "Title screen", "Start over"]
const COLS := 5
const TILE := Vector2(120, 104)
const GRID_TOP := 196.0
const YES := Rect2(120, 700, 220, 80)
const NO := Rect2(380, 700, 220, 80)

var page := "main"
var t := 0.0
var panel_box: StyleBoxFlat
var button_box: StyleBoxFlat
var tile_box: StyleBoxFlat
var danger_box: StyleBoxFlat


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel_box = _box(Color("efe3c8"), Color("8a6242"), 26, 6)
	button_box = _box(Color("7a5a3e"), Color("4a3424"), 18, 3)
	tile_box = _box(Color("e4d6b6"), Color("c8b48a"), 14, 2)
	danger_box = _box(Color("b0413e"), Color("7a2a26"), 18, 3)


func _box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b


func open() -> void:
	page = "main"
	visible = true
	t = 0.0


func main_button(i: int) -> Rect2:
	return Rect2(110, 300 + i * 104, 500, 86)


func tile_rect(n: int) -> Rect2:
	var i := n - 1
	return Rect2(Vector2(46 + (i % COLS) * (TILE.x + 6), GRID_TOP + floori(float(i) / COLS) * (TILE.y + 8)), TILE)


## Nights the player may choose: any up to the furthest they've reached.
func can_choose(n: int) -> bool:
	return n >= 1 and n <= maxi(Data.best_day, Data.day)


func tap(p: Vector2) -> void:
	match page:
		"main":
			if CLOSE.has_point(p):
				_close()
				return
			for i in MAIN_BUTTONS.size():
				if main_button(i).has_point(p):
					match MAIN_BUTTONS[i]:
						"Resume":
							_close()
						"Field Guide":
							visible = false
							guide_requested.emit()
						"Choose a night":
							page = "levels"
						"Market":
							visible = false
							market_requested.emit()
						"Title screen":
							visible = false
							title_requested.emit()
						"Start over":
							page = "confirm"
					return
		"levels":
			if BACK.has_point(p):
				page = "main"
				return
			if CLOSE.has_point(p):
				_close()
				return
			for n in range(1, Data.NIGHTS + 1):
				if tile_rect(n).has_point(p) and can_choose(n):
					visible = false
					night_chosen.emit(n)
					return
		"confirm":
			if YES.has_point(p):
				visible = false
				restart_confirmed.emit()
			elif NO.has_point(p):
				page = "main"


func _close() -> void:
	visible = false
	resumed.emit()


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
	draw_rect(Rect2(0, 0, 720, 1280), Color(0.05, 0.03, 0.08, 0.72))
	panel_box.draw(rid, PANEL)
	match page:
		"main":
			_draw_main(font, rid)
		"levels":
			_draw_levels(font, rid)
		"confirm":
			_draw_confirm(font, rid)


func _close_button(font: Font, rid: RID) -> void:
	button_box.draw(rid, CLOSE)
	draw_string(font, CLOSE.position + Vector2(0, 44), "X", HORIZONTAL_ALIGNMENT_CENTER, CLOSE.size.x, 30, Data.parchment)


func _draw_main(font: Font, rid: RID) -> void:
	_close_button(font, rid)
	Art.ingredient(self, "fly_agaric", Vector2(360, 190), 110)
	draw_string(font, Vector2(0, 280), "Mushroom Moon", HORIZONTAL_ALIGNMENT_CENTER, 720, 44, Color("7a3a2a"))
	for i in MAIN_BUTTONS.size():
		var r := main_button(i)
		(danger_box if i == MAIN_BUTTONS.size() - 1 else button_box).draw(rid, r)
		draw_string(font, r.position + Vector2(0, 56), MAIN_BUTTONS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, Data.parchment)
	draw_string(font, Vector2(0, 950), "Day %d  ·  furthest reached: night %d" % [Data.day, maxi(Data.best_day, Data.day)],
		HORIZONTAL_ALIGNMENT_CENTER, 720, 22, Color("6a5a48"))
	Art.coin(self, Vector2(290, 1010), 28)
	draw_string(font, Vector2(310, 1020), str(Data.coins), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Data.ink)
	Art.bone(self, Vector2(410, 1010), 36)
	draw_string(font, Vector2(436, 1020), str(Data.bones), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Data.ink)
	draw_string(font, Vector2(0, 1210), "Version " + Data.VERSION, HORIZONTAL_ALIGNMENT_CENTER, 720, 16, Color("8a7a60"))


func _draw_levels(font: Font, rid: RID) -> void:
	_close_button(font, rid)
	button_box.draw(rid, BACK)
	draw_string(font, BACK.position + Vector2(0, 42), "< Back", HORIZONTAL_ALIGNMENT_CENTER, BACK.size.x, 24, Data.parchment)
	draw_string(font, Vector2(0, 150), "Choose a night", HORIZONTAL_ALIGNMENT_CENTER, 720, 36, Color("7a3a2a"))
	for n in range(1, Data.NIGHTS + 1):
		var r := tile_rect(n)
		var open_night := can_choose(n)
		tile_box.bg_color = Color("e4d6b6") if open_night else Color(0.83, 0.78, 0.68, 0.5)
		tile_box.border_color = Color("e0a030") if n == Data.day else Color("c8b48a")
		tile_box.set_border_width_all(4 if n == Data.day else 2)
		tile_box.draw(rid, r)
		var col := Data.ink if open_night else Color(0.4, 0.33, 0.25, 0.4)
		draw_string(font, r.position + Vector2(0, 58), str(n), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 38, col)
		if Data.night_boss(n) != "":
			Art.crown(self, r.position + Vector2(r.size.x / 2.0, 90), 26, 1.0 if open_night else 0.35)
		elif not open_night:
			draw_string(font, r.position + Vector2(0, 92), "locked", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, col)
		if n == Data.day:
			draw_string(font, r.position + Vector2(0, 22), "now", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Color("b07a1a"))
	draw_multiline_string(font, Vector2(60, 1130), "Replay any night you've reached with your current bottles, coins, bones and upgrades. Leaving mid-day undoes today's progress.",
		HORIZONTAL_ALIGNMENT_CENTER, 600, 18, 3, Color("6a5a48"))


func _draw_confirm(font: Font, rid: RID) -> void:
	draw_string(font, Vector2(0, 470), "Start over?", HORIZONTAL_ALIGNMENT_CENTER, 720, 44, Color("7a3a2a"))
	draw_multiline_string(font, Vector2(80, 540), "This erases your saved game: nights, bottles, coins, bones, upgrades and discoveries. You'll begin again on night 1.",
		HORIZONTAL_ALIGNMENT_CENTER, 560, 24, 4, Data.ink)
	danger_box.draw(rid, YES)
	draw_string(font, YES.position + Vector2(0, 52), "Start over", HORIZONTAL_ALIGNMENT_CENTER, YES.size.x, 28, Color.WHITE)
	button_box.draw(rid, NO)
	draw_string(font, NO.position + Vector2(0, 52), "Cancel", HORIZONTAL_ALIGNMENT_CENTER, NO.size.x, 28, Data.parchment)
