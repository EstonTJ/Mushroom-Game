extends Node2D
## Day phase 2: drag two ingredients into the cauldron, then stir in circles.
## A known pair makes a bottle (and discovers the recipe); anything else is sludge.

const Art = preload("res://scripts/art.gd")

const POT := Vector2(360, 700)
const STIR_TURNS := 3.0
const SLOT_W := 144.0
const EMPTY_BTN := Rect2(560, 928, 140, 44)

var pot: Array[String] = []
var dragging := ""
var stirring := false
var last_angle := 0.0
var stir_total := 0.0
var swirl := 0.0
var popups := []
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	for p in popups:
		p["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.8)
	queue_redraw()


## Puts anything left in the cauldron back on the shelf.
func return_pot() -> void:
	for id in pot:
		Data.inventory[id] += 1
	pot.clear()
	stir_total = 0.0


func _unhandled_input(event: InputEvent) -> void:
	var p := get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(p)
		else:
			_on_release(p)
	elif event is InputEventMouseMotion and stirring:
		_on_stir(p)


func _on_press(p: Vector2) -> void:
	if EMPTY_BTN.has_point(p) and not pot.is_empty():
		return_pot()
		return
	if p.y > 140.0 and p.y < 330.0:
		var i := int(p.x / SLOT_W)
		if i >= 0 and i < 5:
			var id: String = Data.ingredient_order[i]
			if Data.inventory[id] > 0 and pot.size() < 2:
				dragging = id
		return
	if pot.size() == 2 and p.distance_to(POT) < 240.0:
		stirring = true
		last_angle = (p - POT).angle()


func _on_release(p: Vector2) -> void:
	if dragging != "":
		if p.distance_to(POT) < 200.0 and pot.size() < 2:
			Data.inventory[dragging] -= 1
			pot.append(dragging)
		dragging = ""
	stirring = false


func _on_stir(p: Vector2) -> void:
	if not stirring or pot.size() < 2 or p.distance_to(POT) < 30.0:
		return
	var a := (p - POT).angle()
	var d := wrapf(a - last_angle, -PI, PI)
	last_angle = a
	stir_total += absf(d)
	swirl += d
	if stir_total >= TAU * STIR_TURNS:
		_finish_brew()


func _finish_brew() -> void:
	stirring = false
	var id: String = Data.recipe_for(pot[0], pot[1])
	pot.clear()
	stir_total = 0.0
	if id == "":
		_popup("Murky sludge... try another mix", Color("5a4a3a"))
		return
	var info: Dictionary = Data.potions[id]
	Data.bottles[id] += 1
	if not Data.discovered.has(id):
		Data.discovered[id] = true
		_popup("New recipe: %s!" % info["name"], info["color"].darkened(0.3))
	else:
		_popup("+1 %s" % info["name"], info["color"].darkened(0.3))


func _popup(text: String, color: Color) -> void:
	popups.clear()
	popups.append({"text": text, "t": 0.0, "color": color})


func _liquid_color() -> Color:
	var base := Color("4b6b5a")
	if pot.is_empty():
		return base
	var c := Color(0, 0, 0, 0)
	for id in pot:
		c += Data.ingredients[id]["color"]
	return base.lerp(c / float(pot.size()), 0.6)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 720, 1280), Color("e9dfc9"))

	# Ingredient shelf
	for i in 5:
		var id: String = Data.ingredient_order[i]
		var n: int = Data.inventory[id] - (1 if dragging == id else 0)
		var x := SLOT_W * i
		draw_rect(Rect2(x + 8, 140, SLOT_W - 16, 190), Color(1, 1, 1, 0.35))
		Art.ingredient(self, id, Vector2(x + SLOT_W / 2, 215), 80, 1.0 if n > 0 else 0.3)
		draw_string(font, Vector2(x, 285), Data.ingredients[id]["name"], HORIZONTAL_ALIGNMENT_CENTER, SLOT_W, 20, Data.ink)
		draw_string(font, Vector2(x, 318), "x%d" % n, HORIZONTAL_ALIGNMENT_CENTER, SLOT_W, 26, Data.ink)
	draw_rect(Rect2(0, 330, 720, 16), Color("7a5a3e"))

	# Cauldron: fire, legs, body, rim, liquid
	for k in 5:
		var h := 50.0 + 14.0 * sin(t * 9.0 + k * 1.7)
		var fx := 270.0 + k * 45.0
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 22, 925), Vector2(fx, 925 - h), Vector2(fx + 22, 925)]),
			Color("f08a3c") if k % 2 == 0 else Color("f5c04a"))
	draw_rect(Rect2(245, 820, 24, 100), Color("2f2b2a"))
	draw_rect(Rect2(451, 820, 24, 100), Color("2f2b2a"))
	draw_circle(POT + Vector2(0, 30), 170, Color("2f2b2a"))
	draw_colored_polygon(Art.ellipse(POT + Vector2(0, -110), 185, 55), Color("3d3837"))
	var liquid := _liquid_color()
	draw_colored_polygon(Art.ellipse(POT + Vector2(0, -106), 160, 42), liquid)
	for k in 6:
		var ang := swirl + t * 0.6 + k * TAU / 6.0
		draw_circle(POT + Vector2(cos(ang) * 120, -106 + sin(ang) * 30), 7, liquid.lightened(0.35))
	for k in pot.size():
		var bob := sin(t * 2.5 + k) * 5.0
		Art.ingredient(self, pot[k], POT + Vector2(-60 + 120 * k, -125 + bob), 70)

	# Stir meter
	if pot.size() == 2:
		var progress := clampf(stir_total / (TAU * STIR_TURNS), 0.0, 1.0)
		draw_arc(POT, 215, 0, TAU, 64, Color(0, 0, 0, 0.1), 12)
		if progress > 0.0:
			draw_arc(POT, 215, -PI / 2, -PI / 2 + TAU * progress, 64, Data.lantern, 12)

	var tip := "Drag an ingredient into the cauldron."
	if pot.size() == 1:
		tip = "Add one more ingredient."
	elif pot.size() == 2:
		tip = "Stir! Circle your finger around the pot."
	draw_string(font, Vector2(20, 960), tip, HORIZONTAL_ALIGNMENT_LEFT, 530, 22, Data.ink)
	if not pot.is_empty():
		draw_rect(EMPTY_BTN, Color("7a5a3e"))
		draw_string(font, EMPTY_BTN.position + Vector2(0, 30), "Empty pot", HORIZONTAL_ALIGNMENT_CENTER,
			EMPTY_BTN.size.x, 20, Data.parchment)

	# Recipe book
	draw_rect(Rect2(0, 985, 720, 295), Color("d9cdb3"))
	draw_string(font, Vector2(20, 1020), "Recipe book", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Data.ink)
	for i in 4:
		var id: String = Data.potion_order[i]
		var info: Dictionary = Data.potions[id]
		var cell := Rect2(20 + (i % 2) * 350, 1035 + floori(i / 2.0) * 118, 330, 106)
		draw_rect(cell, Color(1, 1, 1, 0.4))
		var known: bool = Data.discovered.has(id)
		Art.bottle(self, cell.position + Vector2(48, 58), 70, info["color"] if known else Color("999999"))
		var name_text: String = info["name"] if known else "???"
		var recipe_text := "Not yet discovered"
		if known:
			var r: Array = info["recipe"]
			recipe_text = "%s + %s" % [Data.ingredients[r[0]]["name"], Data.ingredients[r[1]]["name"]]
		draw_string(font, cell.position + Vector2(95, 36), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Data.ink)
		draw_string(font, cell.position + Vector2(95, 66), recipe_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Data.ink)
		draw_string(font, cell.position + Vector2(95, 94), "%d bottled" % Data.bottles[id], HORIZONTAL_ALIGNMENT_LEFT,
			-1, 18, Data.moss)

	# Brew results
	for p in popups:
		var pt: float = p["t"]
		draw_string(font, Vector2(0, 470 - pt * 30), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 720, 34,
			Art.fade(p["color"], clampf(1.8 - pt, 0.0, 1.0)))

	# Ingredient being dragged
	if dragging != "":
		Art.ingredient(self, dragging, get_global_mouse_position(), 90)
