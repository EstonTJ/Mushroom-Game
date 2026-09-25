extends Node2D
## Day phase 2: drag two ingredients into the cauldron, then stir in circles.
## A known pair makes a bottle (and discovers the recipe); anything else is sludge.
##
## Drawing is split into stacked layers like the night map: room -> light pools
## -> objects -> glows -> UI (recipe book, hints, flying bottles). The room is
## static and drawn once.

const Art = preload("res://scripts/art.gd")

const POT := Vector2(360, 700)
const STIR_TURNS := 3.0
const SLOT_W := 144.0
const EMPTY_BTN := Rect2(560, 928, 140, 44)
const FIRE := Vector2(360, 942)
const WINDOW := Vector2(72, 520)
const CANDLE := Vector2(652, 572)
const SURFACE := POT + Vector2(0, -106)
const BOOK_TOP := 985.0
const FLY_TIME := 0.9


## One drawing layer. It calls back into this script so all drawing stays here.
class Layer extends Node2D:
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


var pot: Array[String] = []
var dragging := ""
var stirring := false
var last_angle := -0.6
var stir_total := 0.0
var swirl := 0.0
var popups := []
var particles := []
var flyers := []
var cell_flash := {}
var murk := 0.0
var t := 0.0
var steam_timer := 0.0
var ember_timer := 0.0

var room_layer: Layer
var light_under: Layer
var objects: Layer
var light_over: Layer
var ui_layer: Layer
var jar_box: StyleBoxFlat
var book_box: StyleBoxFlat
var sign_box: StyleBoxFlat
var tip_box: StyleBoxFlat


func _ready() -> void:
	jar_box = _box(Color(0.85, 0.93, 1.0, 0.14), Color(0.9, 0.95, 1.0, 0.4), 18, 2)
	book_box = _box(Color("5a2f2a"), Color("3a1c19"), 18, 4)
	sign_box = _box(Color("7a5a3e"), Color("4a3424"), 10, 3)
	tip_box = _box(Color(0.08, 0.06, 0.06, 0.72), Color(1, 1, 1, 0.08), 12, 1)
	room_layer = _add_layer(_paint_room, false)
	light_under = _add_layer(_paint_light_under, true)
	objects = _add_layer(_paint_objects, false)
	light_over = _add_layer(_paint_light_over, true)
	ui_layer = _add_layer(_paint_ui, false)


func _add_layer(painter: Callable, additive: bool) -> Layer:
	var layer := Layer.new()
	layer.painter = painter
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		layer.material = m
	add_child(layer)
	return layer


func _box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b


func _process(delta: float) -> void:
	t += delta
	murk = maxf(0.0, murk - delta * 0.6)
	for p in popups:
		p["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.8)

	var still_flying := []
	for f in flyers:
		f["t"] += delta
		if f["t"] >= FLY_TIME:
			var i: int = Data.potion_order.find(f["id"])
			cell_flash[f["id"]] = 0.8
			_burst(_bottle_spot(i), Data.potions[f["id"]]["color"], 14, 140.0)
		else:
			_emit(_flyer_pos(f), Vector2(randf_range(-20, 20), randf_range(-20, 20)), 0.4, 2.5,
				Data.potions[f["id"]]["color"].lightened(0.3), "spark")
			still_flying.append(f)
	flyers = still_flying
	for k in cell_flash.keys():
		cell_flash[k] = maxf(0.0, cell_flash[k] - delta)

	_update_particles(delta)
	light_under.queue_redraw()
	objects.queue_redraw()
	light_over.queue_redraw()
	ui_layer.queue_redraw()


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
			_splash(Data.ingredients[dragging]["color"])
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
		murk = 1.0
		for i in 12:
			_emit(SURFACE + Vector2(randf_range(-110, 110), randf_range(-15, 15)),
				Vector2(randf_range(-25, 25), randf_range(-70, -30)), 1.6, 16.0, Color(0.35, 0.4, 0.3, 0.55), "smoke")
		_popup("Murky sludge... try another mix", Color("b8c4a0"))
		return
	var info: Dictionary = Data.potions[id]
	Data.bottles[id] += 1
	_burst(SURFACE, info["color"], 30, 260.0)
	flyers.append({"id": id, "t": 0.0})
	if not Data.discovered.has(id):
		Data.discovered[id] = true
		_popup("New recipe: %s!" % info["name"], info["color"].lightened(0.25))
	else:
		_popup("+1 %s" % info["name"], info["color"].lightened(0.25))


func _popup(text: String, color: Color) -> void:
	popups.clear()
	popups.append({"text": text, "t": 0.0, "color": color})


func _liquid_color() -> Color:
	var base := Color("4b6b5a")
	if not pot.is_empty():
		var c := Color(0, 0, 0, 0)
		for id in pot:
			c += Data.ingredients[id]["color"]
		base = base.lerp(c / float(pot.size()), 0.6)
	return base.lerp(Color("4a4a38"), murk)


# -------------------------------------------------------------- particles ---

func _emit(pos: Vector2, vel: Vector2, life: float, size: float, color: Color, kind: String) -> void:
	if particles.size() < 400:
		particles.append({"pos": pos, "vel": vel, "life": life, "max": life, "size": size, "color": color, "kind": kind})


func _burst(pos: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		_emit(pos, Vector2.from_angle(randf() * TAU) * randf_range(speed * 0.3, speed), randf_range(0.4, 0.9),
			randf_range(2.0, 4.5), color, "spark")


func _splash(color: Color) -> void:
	for i in 10:
		_emit(SURFACE + Vector2(randf_range(-30, 30), 0), Vector2(randf_range(-90, 90), randf_range(-200, -90)),
			0.6, 3.0, color, "drop")


func _update_particles(delta: float) -> void:
	steam_timer -= delta
	if steam_timer <= 0.0:
		steam_timer = 0.14 if stirring else 0.22
		_emit(SURFACE + Vector2(randf_range(-120, 120), randf_range(-15, 10)), Vector2(randf_range(-6, 6), randf_range(-45, -25)),
			2.2, 14.0, Color(1, 1, 1, 0.1).lerp(_liquid_color(), 0.3), "steam")
	ember_timer -= delta
	if ember_timer <= 0.0:
		ember_timer = 0.09
		_emit(FIRE + Vector2(randf_range(-80, 80), -10), Vector2(randf_range(-15, 15), randf_range(-90, -50)),
			randf_range(0.6, 1.2), 2.0, Color(1.0, 0.6, 0.2), "ember")

	for p in particles:
		p["life"] -= delta
		var v: Vector2 = p["vel"]
		match p["kind"]:
			"spark":
				v *= 0.92
			"drop":
				v.y += 520.0 * delta
			"steam", "smoke":
				v.x += sin(t * 2.0 + p["life"]) * 8.0 * delta
		p["vel"] = v
		p["pos"] += v * delta
	particles = particles.filter(func(p): return p["life"] > 0.0)


# ---------------------------------------------------------------- drawing ---

func _cell_rect(i: int) -> Rect2:
	return Rect2(20 + (i % 2) * 350, 1035 + floori(i / 2.0) * 118, 330, 106)


func _bottle_spot(i: int) -> Vector2:
	return _cell_rect(i).position + Vector2(48, 58)


func _flyer_pos(f: Dictionary) -> Vector2:
	var k: float = clampf(f["t"] / FLY_TIME, 0.0, 1.0)
	var from := SURFACE + Vector2(0, -20)
	var to := _bottle_spot(Data.potion_order.find(f["id"]))
	var ctrl := (from + to) * 0.5 + Vector2(120, -420)
	return from.lerp(ctrl, k).lerp(ctrl.lerp(to, k), k)


func _flicker(speed: float) -> float:
	return 0.88 + 0.12 * sin(t * speed) * sin(t * speed * 0.57 + 1.3)


func _paint_room(ci: CanvasItem) -> void:
	# Plank wall, darker toward the ceiling.
	var top := Color("2e211e")
	var bottom := Color("5a4034")
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, 880), Vector2(0, 880)]),
		PackedColorArray([top, top, bottom, bottom]))
	for i in 13:
		var x := 10.0 + i * 58.0
		ci.draw_line(Vector2(x, 110), Vector2(x, 880), Color(0, 0, 0, 0.28), 3.0)
		ci.draw_line(Vector2(x + 3, 110), Vector2(x + 3, 880), Color(1, 1, 1, 0.04), 2.0)
	for k in [Vector2(120, 420), Vector2(610, 720), Vector2(240, 800), Vector2(520, 400)]:
		ci.draw_colored_polygon(Art.ellipse(k, 9, 5, 12), Color(0, 0, 0, 0.3))

	_paint_window(ci)

	# Little wall shelf with books (the candle is drawn live, it flickers).
	ci.draw_rect(Rect2(592, 600, 124, 12), Color("6d5140"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(600, 612), Vector2(620, 612), Vector2(600, 636)]), Color("4a3424"))
	var book_cols := [Color("7a3b3b"), Color("3b5a7a"), Color("5a7a3b")]
	for b in 3:
		ci.draw_rect(Rect2(598 + b * 14, 548 + b * 4, 12, 52 - b * 4), book_cols[b])
		ci.draw_rect(Rect2(598 + b * 14, 556 + b * 4, 12, 3), Color(1, 0.9, 0.6, 0.5))

	# Hanging herb bundles.
	for h in [[112.0, 70.0, Color("7d9a5c")], [162.0, 92.0, Color("9a7a4c")], [560.0, 82.0, Color("8a6a9c")], [606.0, 64.0, Color("7d9a5c")]]:
		var x: float = h[0]
		var end := Vector2(x, 346.0 + h[1])
		var col: Color = h[2]
		ci.draw_line(Vector2(x, 346), end, Color("c8b48a"), 2.0, true)
		for k in 5:
			var ang := PI / 2.0 + (k - 2) * 0.28
			var tip := end + Vector2.from_angle(ang) * 46.0
			ci.draw_colored_polygon(PackedVector2Array([end + Vector2(-3, 0), tip, end + Vector2(3, 0)]), col.darkened(0.1 * k))
			ci.draw_line(end, tip, col.lightened(0.2), 1.5, true)
		ci.draw_rect(Rect2(x - 6, end.y - 4, 12, 7), Color("c8b48a"))

	# Stone floor.
	ci.draw_rect(Rect2(0, 880, 720, 110), Color("3a322f"))
	for row in 4:
		var y := 882.0 + row * 26.0
		var x := -35.0 * (row % 2)
		while x < 720.0:
			var w := 62.0 + 16.0 * absf(sin(x * 0.37 + row))
			var shade := 0.5 + 0.5 * sin(x * 1.3 + row * 2.1)
			ci.draw_rect(Rect2(x + 2, y + 2, w - 4, 22), Color("5a4f4a").lerp(Color("6b5f58"), shade))
			ci.draw_rect(Rect2(x + 2, y + 2, w - 4, 4), Color(1, 1, 1, 0.06))
			x += w
	ci.draw_polygon(PackedVector2Array([Vector2(0, 870), Vector2(720, 870), Vector2(720, 900), Vector2(0, 900)]),
		PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35)]))

	# Ingredient shelf.
	ci.draw_rect(Rect2(0, 326, 720, 22), Color("7a5a3e"))
	ci.draw_rect(Rect2(0, 326, 720, 4), Color("9a7a5a"))
	ci.draw_rect(Rect2(0, 348, 720, 8), Color(0, 0, 0, 0.3))
	for x in [30.0, 690.0]:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 10, 348), Vector2(x + 10, 348), Vector2(x - 10, 384)]), Color("4a3424"))


func _paint_window(ci: CanvasItem) -> void:
	ci.draw_circle(WINDOW, 58, Color("3e2c22"))
	ci.draw_circle(WINDOW, 48, Color("1b1a34"))
	ci.draw_circle(WINDOW + Vector2(0, 20), 40, Color("232448"))
	for s in [Vector2(-24, -18), Vector2(20, 8), Vector2(-8, 22), Vector2(28, -26), Vector2(-30, 10)]:
		ci.draw_circle(WINDOW + s, 1.6, Color(1, 1, 0.9, 0.8))
	ci.draw_circle(WINDOW + Vector2(14, -14), 14, Color("fff3d0"))
	ci.draw_circle(WINDOW + Vector2(20, -18), 11, Color("1b1a34"))
	ci.draw_line(WINDOW + Vector2(-48, 0), WINDOW + Vector2(48, 0), Color("3e2c22"), 6.0)
	ci.draw_line(WINDOW + Vector2(0, -48), WINDOW + Vector2(0, 48), Color("3e2c22"), 6.0)
	ci.draw_arc(WINDOW, 53, 0, TAU, 40, Color("5a4034"), 4.0, true)
	ci.draw_rect(Rect2(WINDOW.x - 58, WINDOW.y + 54, 116, 10), Color("5a4034"))


func _paint_light_under(ci: CanvasItem) -> void:
	var liquid := _liquid_color()
	Art.glow(ci, FIRE + Vector2(0, -30), 340, Color(1.0, 0.55, 0.2, 0.26 * _flicker(9.0)))
	Art.glow(ci, WINDOW, 120, Color(0.6, 0.7, 1.0, 0.12))
	Art.glow(ci, CANDLE + Vector2(0, -26), 130, Art.fade(Data.lantern, 0.3 * _flicker(13.0)))
	Art.glow(ci, SURFACE + Vector2(0, -40), 280, Art.fade(liquid, 0.14 + (0.08 if stirring else 0.0)))


func _paint_objects(ci: CanvasItem) -> void:
	var rid := ci.get_canvas_item()
	var font := ThemeDB.fallback_font
	for i in 5:
		_paint_jar(ci, rid, font, i)
	_paint_candle(ci)
	_paint_fire(ci)
	_paint_cauldron(ci)

	for p in particles:
		var kind: String = p["kind"]
		if kind == "steam" or kind == "smoke":
			var f: float = p["life"] / p["max"]
			var size: float = p["size"] * (1.0 + (1.0 - f) * 1.5)
			Art.glow(ci, p["pos"], size * 2.0, Art.fade(p["color"], f))
		elif kind == "drop":
			ci.draw_circle(p["pos"], p["size"], p["color"])

	if dragging != "":
		var m := get_global_mouse_position()
		Art.shadow(ci, m + Vector2(10, 50), 34, 9)
		Art.ingredient(ci, dragging, m, 92)


func _paint_jar(ci: CanvasItem, rid: RID, font: Font, i: int) -> void:
	var id: String = Data.ingredient_order[i]
	var n: int = Data.inventory[id] - (1 if dragging == id else 0)
	var cx := SLOT_W * i + SLOT_W / 2.0
	Art.shadow(ci, Vector2(cx, 326), 46, 6)
	var body := Rect2(cx - 46, 188, 92, 136)
	jar_box.draw(rid, body)
	Art.ingredient(ci, id, Vector2(cx, 258), 66, 1.0 if n > 0 else 0.25)
	ci.draw_line(Vector2(cx - 34, 204), Vector2(cx - 34, 270), Color(1, 1, 1, 0.28), 4.0, true)
	ci.draw_rect(Rect2(cx - 44, 184, 88, 10), Color("6a4a30"))
	ci.draw_rect(Rect2(cx - 38, 168, 76, 18), Color("8a6242"))
	ci.draw_rect(Rect2(cx - 38, 168, 76, 5), Color("a88058"))
	var tag := Rect2(cx - 28, 290, 56, 26)
	ci.draw_rect(tag, Color("efe3c8"))
	ci.draw_rect(tag, Color("8a6242"), false, 2.0)
	ci.draw_string(font, tag.position + Vector2(0, 20), "x%d" % n, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 19, Data.ink)
	ci.draw_string_outline(font, Vector2(SLOT_W * i, 160), Data.ingredients[id]["name"], HORIZONTAL_ALIGNMENT_CENTER,
		SLOT_W, 18, 4, Color(0, 0, 0, 0.5))
	ci.draw_string(font, Vector2(SLOT_W * i, 160), Data.ingredients[id]["name"], HORIZONTAL_ALIGNMENT_CENTER,
		SLOT_W, 18, Data.parchment)


func _paint_candle(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(CANDLE.x - 7, CANDLE.y, 14, 28), Color("efe3c8"))
	ci.draw_rect(Rect2(CANDLE.x - 7, CANDLE.y, 14, 4), Color("fff6e0"))
	ci.draw_line(CANDLE, CANDLE + Vector2(0, -5), Color("2b2233"), 1.5)
	var h := 16.0 * _flicker(15.0)
	var sway := sin(t * 5.0) * 1.5
	ci.draw_colored_polygon(PackedVector2Array([CANDLE + Vector2(-5, -4), CANDLE + Vector2(sway, -4 - h),
		CANDLE + Vector2(5, -4)]), Color("f5a53a"))
	ci.draw_colored_polygon(PackedVector2Array([CANDLE + Vector2(-2.5, -4), CANDLE + Vector2(sway * 0.5, -4 - h * 0.55),
		CANDLE + Vector2(2.5, -4)]), Color("fff0b0"))


func _log(ci: CanvasItem, a: Vector2, b: Vector2, w: float) -> void:
	var n := (b - a).normalized().orthogonal() * w * 0.5
	ci.draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), Color("5a3a26"))
	ci.draw_line(a + n * 0.4, b + n * 0.4, Color("7a5236"), 2.0, true)
	ci.draw_circle(b, w * 0.5, Color("8a6a4a"))
	ci.draw_arc(b, w * 0.28, 0, TAU, 12, Color("6a4a30"), 1.5, true)


func _paint_fire(ci: CanvasItem) -> void:
	_log(ci, FIRE + Vector2(-110, 8), FIRE + Vector2(95, -4), 18)
	_log(ci, FIRE + Vector2(100, 10), FIRE + Vector2(-85, -6), 16)
	var cols := [Color("e8541e"), Color("f59a2c"), Color("ffd35a")]
	for layer in 3:
		var hs: float = [1.0, 0.72, 0.45][layer]
		var w := 28.0 * (1.0 - layer * 0.22)
		for k in 7:
			var x := -90.0 + k * 30.0 + sin(t * 3.0 + k) * 4.0
			var h := (70.0 + 25.0 * sin(t * 9.0 + k * 1.7) + 12.0 * sin(t * 13.0 + k)) * hs
			var tip := x + sin(t * 7.0 + k) * 6.0
			ci.draw_colored_polygon(PackedVector2Array([FIRE + Vector2(x - w / 2.0, 0), FIRE + Vector2(x - w * 0.55, -h * 0.35),
				FIRE + Vector2(tip, -h), FIRE + Vector2(x + w * 0.55, -h * 0.35), FIRE + Vector2(x + w / 2.0, 0)]), cols[layer])
	for k in 7:
		var ang := PI * (0.08 + 0.84 * k / 6.0)
		var p := FIRE + Vector2(cos(ang) * 130.0, sin(ang) * 18.0 + 14.0)
		ci.draw_colored_polygon(Art.ellipse(p, 20, 11, 12), Color("5e534d"))
		ci.draw_colored_polygon(Art.ellipse(p + Vector2(-5, -4), 9, 4, 10), Color("7a6e66"))


func _paint_cauldron(ci: CanvasItem) -> void:
	var body_c := POT + Vector2(0, 40)
	var rx := 175.0
	var ry := 150.0
	var iron := Color("2a2629")
	var dark := Color("171416")

	for side in [-1.0, 1.0]:
		ci.draw_rect(Rect2(POT.x + side * 115.0 - 13.0, 850, 26, 78), dark)
		var ring := POT + Vector2(side * 190.0, -58)
		ci.draw_arc(ring, 24, 0, TAU, 24, dark, 9.0, true)
		ci.draw_arc(ring, 24, PI * 1.1, PI * 1.6, 8, Color("6a6470"), 2.5, true)

	# Body with a soft highlight toward the top-left and firelight on the right.
	ci.draw_colored_polygon(Art.ellipse(body_c, rx, ry, 48), iron)
	for k in range(1, 9):
		var f := k / 8.0
		ci.draw_colored_polygon(Art.ellipse(body_c + Vector2(-0.3 * f * rx, -0.26 * f * ry), rx * (1.0 - 0.62 * f), ry * (1.0 - 0.62 * f), 40),
			Art.fade(Color("6a6470"), 0.09))
	var bounce := PackedVector2Array()
	for k in 14:
		var ang := -0.2 + 1.5 * k / 13.0
		bounce.append(body_c + Vector2(cos(ang) * (rx - 4), sin(ang) * (ry - 4)))
	ci.draw_polyline(bounce, Color(1.0, 0.55, 0.25, 0.35 * _flicker(9.0)), 5.0, true)
	var band := PackedVector2Array()
	for k in 25:
		var ang := PI * k / 24.0
		band.append(POT + Vector2(cos(ang) * rx * 0.985, -52 + sin(ang) * 26.0))
	ci.draw_polyline(band, dark, 11.0, true)
	for k in range(2, 23, 3):
		ci.draw_circle(band[k], 4.0, Color("5a5460"))
	Art.outline(ci, Art.ellipse(body_c, rx, ry, 48), Art.fade(Color.BLACK, 0.5), 3.0)

	# Rim and liquid.
	ci.draw_colored_polygon(Art.ellipse(POT + Vector2(0, -110), 190, 56, 48), Color("3d3837"))
	var rim_front := PackedVector2Array()
	for k in 21:
		var ang := 0.25 + (PI - 0.5) * k / 20.0
		rim_front.append(POT + Vector2(0, -110) + Vector2(cos(ang) * 188.0, sin(ang) * 54.0))
	ci.draw_polyline(rim_front, Color("7a7480"), 3.0, true)
	ci.draw_colored_polygon(Art.ellipse(POT + Vector2(0, -108), 170, 46, 48), dark)
	var liquid := _liquid_color()
	ci.draw_colored_polygon(Art.ellipse(SURFACE, 160, 40, 48), liquid.darkened(0.25))
	ci.draw_colored_polygon(Art.ellipse(SURFACE + Vector2(0, 2), 150, 34, 48), liquid)
	for k in 3:
		var spiral := PackedVector2Array()
		var a0 := swirl + k * TAU / 3.0 + t * 0.4
		for j in 14:
			var u := j / 13.0
			var ang := a0 + u * 2.6
			var r := 0.18 + 0.72 * u
			spiral.append(SURFACE + Vector2(cos(ang) * 150.0 * r, sin(ang) * 34.0 * r + 2.0))
		ci.draw_polyline(spiral, Art.fade(liquid.lightened(0.35), 0.55), 3.0, true)
	for k in 7:
		var ph := fmod(t * (0.8 if not stirring else 1.6) + k * 0.143, 1.0)
		var bp := SURFACE + Vector2(sin(k * 12.9) * 110.0, sin(k * 7.3) * 20.0 + 2.0)
		if ph < 0.8:
			ci.draw_circle(bp, 3.0 + ph * 9.0, liquid.lightened(0.25))
			ci.draw_circle(bp + Vector2(-2, -2), 1.5 + ph * 2.0, Art.fade(Color.WHITE, 0.6))
		else:
			ci.draw_arc(bp, 12.0 + (ph - 0.8) * 30.0, 0, TAU, 14, Art.fade(liquid.lightened(0.4), (1.0 - ph) * 5.0), 2.0, true)

	for k in pot.size():
		var ang := swirl * 0.5 + k * PI + t * 0.25
		var bob := sin(t * 2.5 + k) * 4.0
		Art.ingredient(ci, pot[k], SURFACE + Vector2(cos(ang) * 75.0, sin(ang) * 16.0 - 14.0 + bob), 62)

	if pot.size() == 2:
		var a := last_angle
		var bowl := SURFACE + Vector2(cos(a) * 95.0, sin(a) * 22.0)
		var handle_end := bowl + Vector2(cos(a) * 40.0 + 30.0, -200.0)
		ci.draw_line(bowl, handle_end, Color("6a4a30"), 13.0, true)
		ci.draw_line(bowl + Vector2(-3, 0), handle_end + Vector2(-3, 0), Color("b88a5c"), 4.0, true)
		ci.draw_colored_polygon(Art.ellipse(bowl, 22, 10, 16), Color("7a5236"))

		var progress := clampf(stir_total / (TAU * STIR_TURNS), 0.0, 1.0)
		ci.draw_arc(POT, 215, 0, TAU, 72, Color(1, 1, 1, 0.1), 10.0, true)
		if progress > 0.0:
			ci.draw_arc(POT, 215, -PI / 2, -PI / 2 + TAU * progress, 72, Data.lantern, 10.0, true)
		for k in 3:
			var pip := POT + Vector2.from_angle(-PI / 2 + (k - 1) * 0.2) * 243.0
			var lit := progress * STIR_TURNS > k + 0.999
			ci.draw_circle(pip, 9, Data.lantern if lit else Color(1, 1, 1, 0.15))
			ci.draw_arc(pip, 9, 0, TAU, 16, Color(0, 0, 0, 0.5), 2.0, true)

	if dragging != "" and pot.size() < 2:
		var rim := Art.ellipse(POT + Vector2(0, -110), 196, 62, 48)
		Art.outline(ci, rim, Art.fade(Data.magic, 0.55 + 0.35 * sin(t * 6.0)), 4.0)


func _paint_light_over(ci: CanvasItem) -> void:
	var liquid := _liquid_color()
	Art.glow(ci, SURFACE, 190, Art.fade(liquid, 0.3 + (0.15 if stirring else 0.0)))
	Art.glow(ci, FIRE + Vector2(0, -25), 110, Color(1.0, 0.7, 0.3, 0.5 * _flicker(11.0)))
	Art.glow(ci, CANDLE + Vector2(0, -12), 22, Color(1.0, 0.85, 0.5, 0.7 * _flicker(15.0)))
	if pot.size() == 2 and stir_total > 0.0:
		var progress := clampf(stir_total / (TAU * STIR_TURNS), 0.0, 1.0)
		Art.glow(ci, POT + Vector2.from_angle(-PI / 2 + TAU * progress) * 215.0, 40, Art.fade(Data.lantern, 0.7))
	for p in particles:
		var kind: String = p["kind"]
		if kind == "spark" or kind == "ember":
			var f: float = p["life"] / p["max"]
			Art.glow(ci, p["pos"], p["size"] * 3.0, Art.fade(p["color"], f))


func _paint_ui(ci: CanvasItem) -> void:
	var rid := ci.get_canvas_item()
	var font := ThemeDB.fallback_font

	var tip := "Drag an ingredient into the cauldron."
	if pot.size() == 1:
		tip = "Add one more ingredient."
	elif pot.size() == 2:
		tip = "Stir! Circle your finger around the pot."
	var tip_w := font.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	tip_box.draw(rid, Rect2(10, 932, tip_w + 24, 40))
	ci.draw_string(font, Vector2(22, 959), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Data.parchment)
	if not pot.is_empty():
		sign_box.draw(rid, EMPTY_BTN)
		ci.draw_string(font, EMPTY_BTN.position + Vector2(0, 29), "Empty pot", HORIZONTAL_ALIGNMENT_CENTER,
			EMPTY_BTN.size.x, 19, Data.parchment)

	# Open recipe book: leather cover, two parchment pages, a shaded spine.
	book_box.draw(rid, Rect2(6, BOOK_TOP, 708, 300))
	ci.draw_string(font, Vector2(24, BOOK_TOP + 30), "Recipe book", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("e8c77a"))
	var page := Color("efe3c8")
	var page_edge := Color("d8c7a2")
	ci.draw_polygon(PackedVector2Array([Vector2(16, 1026), Vector2(360, 1026), Vector2(360, 1276), Vector2(16, 1276)]),
		PackedColorArray([page, page_edge, page_edge, page]))
	ci.draw_polygon(PackedVector2Array([Vector2(360, 1026), Vector2(704, 1026), Vector2(704, 1276), Vector2(360, 1276)]),
		PackedColorArray([page_edge, page, page, page_edge]))
	var clear := Color(0, 0, 0, 0)
	var crease := Color(0, 0, 0, 0.22)
	ci.draw_polygon(PackedVector2Array([Vector2(336, 1026), Vector2(360, 1026), Vector2(360, 1276), Vector2(336, 1276)]),
		PackedColorArray([clear, crease, crease, clear]))
	ci.draw_polygon(PackedVector2Array([Vector2(360, 1026), Vector2(384, 1026), Vector2(384, 1276), Vector2(360, 1276)]),
		PackedColorArray([crease, clear, clear, crease]))
	ci.draw_line(Vector2(360, 1026), Vector2(360, 1276), Color(0, 0, 0, 0.25), 3.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(640, 1020), Vector2(662, 1020), Vector2(662, 1060), Vector2(651, 1050),
		Vector2(640, 1060)]), Color("b0413e"))
	for x in [30.0, 380.0]:
		ci.draw_line(Vector2(x, 1149), Vector2(x + 310, 1149), Art.fade(Data.ink, 0.15), 1.5)
	for i in 4:
		_paint_recipe(ci, font, i)

	for p in popups:
		var pt: float = p["t"]
		var at := Vector2(0, 450 - pt * 30)
		var a := clampf(1.8 - pt, 0.0, 1.0)
		ci.draw_string_outline(font, at, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 720, 34, 8, Color(0, 0, 0, 0.6 * a))
		ci.draw_string(font, at, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 720, 34, Art.fade(p["color"], a))

	for f in flyers:
		var pos := _flyer_pos(f)
		var col: Color = Data.potions[f["id"]]["color"]
		var k: float = f["t"] / FLY_TIME
		Art.glow(ci, pos, 60, Art.fade(col, 0.5))
		Art.bottle(ci, pos, 60.0 + 20.0 * sin(k * PI), col)


func _paint_recipe(ci: CanvasItem, font: Font, i: int) -> void:
	var id: String = Data.potion_order[i]
	var info: Dictionary = Data.potions[id]
	var cell := _cell_rect(i)
	var known: bool = Data.discovered.has(id)
	var flash: float = cell_flash.get(id, 0.0)
	if flash > 0.0:
		Art.glow(ci, _bottle_spot(i), 80, Art.fade(info["color"], flash))
	if known:
		Art.bottle(ci, _bottle_spot(i), 66, info["color"])
	else:
		Art.bottle(ci, _bottle_spot(i), 66, Color("b8ad96"), 0.45)
	var name_text: String = info["name"] if known else "???"
	ci.draw_string(font, cell.position + Vector2(95, 34), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Data.ink)
	if known:
		var r: Array = info["recipe"]
		Art.ingredient(ci, r[0], cell.position + Vector2(112, 64), 30)
		ci.draw_string(font, cell.position + Vector2(132, 70), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Data.ink)
		Art.ingredient(ci, r[1], cell.position + Vector2(160, 64), 30)
	else:
		ci.draw_string(font, cell.position + Vector2(95, 66), "Not yet discovered", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Art.fade(Data.ink, 0.55))
	ci.draw_string(font, cell.position + Vector2(95, 96), "%d bottled" % Data.bottles[id], HORIZONTAL_ALIGNMENT_LEFT,
		-1, 17, Data.moss)
