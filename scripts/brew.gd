extends Node2D
## Day phase 2: drag two mushrooms into the cauldron, then pop the bubbles.
## Three bubbles rise one at a time and grow toward a target ring; tap as one
## fills the ring for a Perfect pop. Three Perfect pops make two bottles.
## A known pair makes a bottle (and discovers the recipe); anything else is sludge.
##
## Drawing is split into stacked layers like the night map: room -> light pools
## -> objects -> glows -> UI (recipe book, hints, flying bottles). The room is
## static and drawn once.

const Art = preload("res://scripts/art.gd")
const Baked = preload("res://scripts/baked.gd")

const POT := Vector2(360, 700)
const BUBBLES := 3
const BUBBLE_TIME := 1.3
## A tap counts as Perfect while the bubble is this far through its growth.
const PERFECT_FROM := 0.72
const PERFECT_TO := 1.0
## With the Bellows: bubbles take longer to swell and Perfect starts earlier.
const BELLOWS_TIME := 1.75
const BELLOWS_FROM := 0.62
## With the Everburning Coals: chance an all-Perfect brew makes a third bottle.
const COALS_CHANCE := 0.5
const BUBBLE_GAP := 0.45
const SLOT_W := 90.0
const SHELF_TOP := 128.0
const ROW_H := 108.0
const PER_ROW := 8
const PER_PAGE := 4
const PAGE_PREV := Rect2(520, 988, 48, 34)
const PAGE_NEXT := Rect2(652, 988, 48, 34)
const EMPTY_BTN := Rect2(560, 928, 140, 44)
const FIRE := Vector2(360, 942)
const WINDOW := Vector2(72, 520)
const CANDLE := Vector2(652, 572)
const SURFACE := POT + Vector2(0, -106)
const BOOK_TOP := 985.0
## Where the bone bowl sits once the Bone Mortar has been bought.
const BONE_BOWL := Vector2(78, 716)
const FLY_TIME := 0.9


## One drawing layer. It calls back into this script so all drawing stays here.
class Layer extends Node2D:
	var painter: Callable
	## How long the last redraw took, for performance checks.
	var last_usec := 0

	func _draw() -> void:
		var start := Time.get_ticks_usec()
		painter.call(self)
		last_usec = Time.get_ticks_usec() - start


var pot: Array[String] = []
var dragging := ""
var swirl := 0.0
var pot_bone := false
var auto_flight := 1.0
var bubble := {}
var bubbles_done := 0
var perfect_pops := 0
var results := []
var bubble_gap := 0.0
var rings := []
var marks := []
var popups := []
var particles := []
var flyers := []
var cell_flash := {}
var book_page := 0
var murk := 0.0
var t := 0.0
var steam_timer := 0.0
var ember_timer := 0.0

var room_layer: Baked
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
	room_layer = Baked.new(_paint_room)
	add_child(room_layer)
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

	_bubble_step(delta)
	auto_flight = minf(1.0, auto_flight + delta * 2.0)
	for r in rings:
		r["t"] += delta
	rings = rings.filter(func(r): return r["t"] < 0.5)
	for m in marks:
		m["t"] += delta
	marks = marks.filter(func(m): return m["t"] < 0.9)
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
	if pot_bone:
		Data.bones += 1
		pot_bone = false
	_reset_bubbles()


func _reset_bubbles() -> void:
	bubble = {}
	bubbles_done = 0
	perfect_pops = 0
	results = []
	bubble_gap = BUBBLE_GAP


func brewing() -> bool:
	return pot.size() == 2


func _unhandled_input(event: InputEvent) -> void:
	var p := get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(p)
		else:
			_on_release(p)


func _on_press(p: Vector2) -> void:
	if EMPTY_BTN.has_point(p) and not pot.is_empty():
		return_pot()
		return
	if PAGE_PREV.has_point(p):
		book_page = posmod(book_page - 1, _page_count())
		return
	if PAGE_NEXT.has_point(p):
		book_page = posmod(book_page + 1, _page_count())
		return
	if has_batcher() and batch_rect().has_point(p):
		var more := p.x > batch_rect().get_center().x
		Data.batch = clampi(Data.batch + (1 if more else -1), 1, Data.MAX_BATCH)
		return
	if has_auto() and auto_switch_rect().has_point(p):
		Data.auto_bone = not Data.auto_bone
		_auto_bone()
		return
	if has_mortar() and p.distance_to(BONE_BOWL) < 64.0:
		if Data.bones > 0 and not pot_bone:
			dragging = "bone"
		return
	if p.y > SHELF_TOP and p.y < SHELF_TOP + ROW_H * 2.0:
		var i := slot_at(p)
		if i >= 0:
			var id: String = Data.ingredient_order[i]
			if Data.is_unlocked(id) and Data.inventory[id] > 0 and pot.size() < 2:
				dragging = id
		return
	if brewing() and not bubble.is_empty() and p.y > SHELF_TOP + ROW_H * 2.0 and p.y < 930.0:
		_pop_bubble(true)


func has_mortar() -> bool:
	return Data.upgrades.has("bone_mortar")


func has_batcher() -> bool:
	return Data.upgrades.has("batch_brewer")


## The batch dial: tap the left half for fewer, the right half for more.
func batch_rect() -> Rect2:
	return Rect2(544, 866, 160, 52)


## How many potions the current pot would make: the dial, limited by how many
## more of each mushroom are on the shelf (a pair of the same mushroom needs two).
func batch_possible() -> int:
	if not has_batcher():
		return 1
	var extra := Data.MAX_BATCH - 1
	if pot.size() == 2:
		if pot[0] == pot[1]:
			extra = int(Data.inventory[pot[0]] / 2)
		else:
			extra = mini(Data.inventory[pot[0]], Data.inventory[pot[1]])
	return clampi(1 + extra, 1, Data.batch)


func has_auto() -> bool:
	return Data.upgrades.has("bone_appetit")


## The Bone Appétit's ON/OFF switch, just under the bone bowl.
func auto_switch_rect() -> Rect2:
	return Rect2(BONE_BOWL.x - 52, BONE_BOWL.y + 66, 104, 34)


## With the Bone Appétit on, a bone goes in by itself once two mushrooms are in.
func _auto_bone() -> void:
	if has_auto() and Data.auto_bone and brewing() and not pot_bone and Data.bones > 0:
		Data.bones -= 1
		pot_bone = true
		auto_flight = 0.0
		_splash(Color("efe6c0"))


func _on_release(p: Vector2) -> void:
	if dragging == "bone":
		if p.distance_to(POT) < 200.0 and not pot_bone:
			Data.bones -= 1
			pot_bone = true
			_splash(Color("efe6d0"))
			_popup("Bone added: it will be Empowered!", Color("f5e6c0"))
		dragging = ""
		return
	if dragging != "":
		if p.distance_to(POT) < 200.0 and pot.size() < 2:
			Data.inventory[dragging] -= 1
			pot.append(dragging)
			_splash(Data.ingredients[dragging]["color"])
			if brewing():
				_reset_bubbles()
				_auto_bone()
		dragging = ""


func _bubble_step(delta: float) -> void:
	if not brewing():
		return
	if bubble.is_empty():
		bubble_gap -= delta
		if bubble_gap <= 0.0:
			bubble = {"f": 0.0, "pos": SURFACE + Vector2(randf_range(-80, 80), -6), "seed": randf() * TAU}
	else:
		bubble["f"] += delta / bubble_time()
		if bubble["f"] >= 1.08:
			_pop_bubble(false)


func bubble_time() -> float:
	return BELLOWS_TIME if Data.upgrades.has("bellows") else BUBBLE_TIME


func perfect_from() -> float:
	return BELLOWS_FROM if Data.upgrades.has("bellows") else PERFECT_FROM


func bubble_radius(f: float) -> float:
	return 10.0 + 40.0 * clampf(f, 0.0, 1.0)


func bubble_pos(b: Dictionary) -> Vector2:
	var f: float = b["f"]
	return b["pos"] + Vector2(sin(f * 6.0 + b["seed"]) * 5.0, -f * 70.0)


## Pop the current bubble: Perfect if tapped while it fills the ring, Good if
## tapped early, Missed if it burst on its own. The third pop finishes the brew.
func _pop_bubble(tapped: bool) -> void:
	var f: float = bubble["f"]
	var at := bubble_pos(bubble)
	var r := bubble_radius(f)
	var perfect := tapped and f >= perfect_from() and f <= PERFECT_TO + 0.08
	var result := "perfect" if perfect else ("good" if tapped else "missed")
	results.append(result)
	if perfect:
		perfect_pops += 1
	var col := _liquid_color().lightened(0.35)
	_burst(at, Color("ffd35a") if perfect else col, 18 if perfect else 10, 200.0 if perfect else 130.0)
	rings.append({"pos": at, "r": r, "t": 0.0, "color": Color("ffd35a") if perfect else col})
	var label: String = {"perfect": "Perfect!", "good": "Good", "missed": "Missed"}[result]
	marks.append({"text": label, "pos": at + Vector2(0, -r - 10), "t": 0.0,
		"color": Color("ffd35a") if perfect else (Data.parchment if tapped else Color(1, 1, 1, 0.6))})
	bubble = {}
	bubble_gap = BUBBLE_GAP
	bubbles_done += 1
	if bubbles_done >= BUBBLES:
		_finish_brew()


func _finish_brew() -> void:
	var id: String = Data.recipe_for(pot[0], pot[1])
	var flawless := perfect_pops == BUBBLES
	var empowered := pot_bone
	# A batch uses one more of each mushroom per extra potion (taken now).
	var count := batch_possible()
	for i in count - 1:
		Data.inventory[pot[0]] -= 1
		Data.inventory[pot[1]] -= 1
	pot.clear()
	pot_bone = false
	_reset_bubbles()
	if id == "":
		murk = 1.0
		for i in 12:
			_emit(SURFACE + Vector2(randf_range(-110, 110), randf_range(-15, 15)),
				Vector2(randf_range(-25, 25), randf_range(-70, -30)), 1.6, 16.0, Color(0.35, 0.4, 0.3, 0.55), "smoke")
		_popup("Murky sludge... try another mix" if count == 1 else "A whole batch of sludge!", Color("b8c4a0"))
		return
	var key := id + ("+" if empowered else "")
	var info: Dictionary = Data.potion_stats(key)
	var made := 2 if flawless else 1
	var flare := flawless and Data.upgrades.has("everburning_coals") and randf() < COALS_CHANCE
	if flare:
		made = 3
	# Each extra potion in the batch takes another bone while they last.
	var plus_count := 0
	if empowered:
		plus_count = mini(count, 1 + Data.bones)
		Data.bones -= plus_count - 1
	Data.bottles[id + "+"] += plus_count * made
	Data.bottles[id] += (count - plus_count) * made
	_burst(SURFACE, info["color"], 30 + 10 * count, 260.0)
	for k in mini(count * made, 6):
		flyers.append({"id": id, "t": -0.15 * k})
	book_page = floori(float(Data.potion_order.find(id)) / PER_PAGE)
	var what: String = ("Perfect brew! +2 %s" % info["name"]) if flawless else ("+1 %s" % info["name"])
	if empowered:
		what = ("Perfect! +2 Empowered %s" if flawless else "+1 Empowered %s") % Data.potions[id]["name"]
	if count > 1:
		what = "Batch of %d! +%d %s%s" % [count, count * made, Data.potions[id]["name"],
			(" (%d empowered)" % (plus_count * made)) if plus_count > 0 else ""]
	if flare:
		what = "The coals flare! +%d %s" % [count * made, Data.potions[id]["name"]]
	if not Data.discovered.has(id):
		Data.discovered[id] = true
		what = ("Perfect! New recipe: %s x%d" % [info["name"], made]) if flawless else ("New recipe: %s!" % info["name"])
		if count > 1:
			what = "New recipe: %s! Batch +%d" % [info["name"], count * made]
	_popup(what, info["color"].lightened(0.25))


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
		steam_timer = 0.14 if brewing() else 0.22
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

## Centre of the jar for ingredient i: two shelf rows of PER_ROW jars.
func slot_center(i: int) -> Vector2:
	return Vector2(SLOT_W * (i % PER_ROW) + SLOT_W / 2.0, SHELF_TOP + 64.0 + floori(float(i) / PER_ROW) * ROW_H)


func slot_at(p: Vector2) -> int:
	if p.y < SHELF_TOP or p.y >= SHELF_TOP + ROW_H * 2.0 or p.x < 0.0 or p.x >= SLOT_W * PER_ROW:
		return -1
	var i := int((p.y - SHELF_TOP) / ROW_H) * PER_ROW + int(p.x / SLOT_W)
	return i if i < Data.ingredient_order.size() else -1


func _page_count() -> int:
	return ceili(float(Data.potion_order.size()) / PER_PAGE)


## Recipe book cell for potion i, on whichever page it lives.
func _cell_rect(i: int) -> Rect2:
	var k := i % PER_PAGE
	return Rect2(20 + (k % 2) * 350, 1035 + floori(k / 2.0) * 118, 330, 106)


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
	for h in [[112.0, 62.0, Color("7d9a5c")], [162.0, 80.0, Color("9a7a4c")], [560.0, 72.0, Color("8a6a9c")], [606.0, 56.0, Color("7d9a5c")]]:
		var x: float = h[0]
		var end := Vector2(x, 356.0 + h[1])
		var col: Color = h[2]
		ci.draw_line(Vector2(x, 356), end, Color("c8b48a"), 2.0, true)
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
	for row in 2:
		var y := SHELF_TOP + (row + 1) * ROW_H - 12.0
		ci.draw_rect(Rect2(0, y, 720, 18), Color("7a5a3e"))
		ci.draw_rect(Rect2(0, y, 720, 4), Color("9a7a5a"))
		ci.draw_rect(Rect2(0, y + 18, 720, 7), Color(0, 0, 0, 0.3))
		for x in [30.0, 690.0]:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 10, y + 18), Vector2(x + 10, y + 18), Vector2(x - 10, y + 44)]), Color("4a3424"))


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
	Art.glow(ci, SURFACE + Vector2(0, -40), 280, Art.fade(liquid, 0.14 + (0.08 if brewing() else 0.0)))


func _paint_objects(ci: CanvasItem) -> void:
	var rid := ci.get_canvas_item()
	var font := ThemeDB.fallback_font
	for i in Data.ingredient_order.size():
		_paint_jar(ci, rid, font, i)
	_paint_candle(ci)
	if has_mortar():
		_paint_bone_bowl(ci, font)
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

	if dragging == "bone":
		var m := get_global_mouse_position()
		Art.shadow(ci, m + Vector2(10, 40), 26, 7)
		Art.bone(ci, m, 70, 1.0, -0.5 + sin(t * 4.0) * 0.2)
	elif dragging != "":
		var m := get_global_mouse_position()
		Art.shadow(ci, m + Vector2(10, 50), 34, 9)
		Art.ingredient(ci, dragging, m, 92)


func _paint_jar(ci: CanvasItem, rid: RID, font: Font, i: int) -> void:
	var id: String = Data.ingredient_order[i]
	var c := slot_center(i)
	var unlocked := Data.is_unlocked(id)
	var n: int = Data.inventory[id] - (1 if dragging == id else 0)
	Art.shadow(ci, Vector2(c.x, c.y + 38), 32, 5)
	var body := Rect2(c.x - 32, c.y - 30, 64, 70)
	jar_box.draw(rid, body)
	ci.draw_rect(Rect2(c.x - 30, c.y - 34, 60, 7), Color("6a4a30"))
	ci.draw_rect(Rect2(c.x - 26, c.y - 44, 52, 12), Color("8a6242"))
	ci.draw_rect(Rect2(c.x - 26, c.y - 44, 52, 3), Color("a88058"))
	if unlocked:
		Art.ingredient(ci, id, c + Vector2(0, 6), 46, 1.0 if n > 0 else 0.25)
		ci.draw_line(Vector2(c.x - 24, c.y - 22), Vector2(c.x - 24, c.y + 18), Color(1, 1, 1, 0.28), 3.0, true)
		var tag := Rect2(c.x - 18, c.y + 22, 36, 18)
		ci.draw_rect(tag, Color("efe3c8"))
		ci.draw_rect(tag, Color("8a6242"), false, 1.5)
		ci.draw_string(font, tag.position + Vector2(0, 14), "x%d" % n, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 14, Data.ink)
		var label: String = Data.ingredients[id]["short"]
		ci.draw_string_outline(font, Vector2(c.x - 45, c.y - 49), label, HORIZONTAL_ALIGNMENT_CENTER, 90, 13, 4, Color(0, 0, 0, 0.6))
		ci.draw_string(font, Vector2(c.x - 45, c.y - 49), label, HORIZONTAL_ALIGNMENT_CENTER, 90, 13, Data.parchment)
	else:
		ci.draw_string(font, Vector2(c.x - 32, c.y + 12), "?", HORIZONTAL_ALIGNMENT_CENTER, 64, 30, Color(1, 1, 1, 0.35))
		ci.draw_string(font, Vector2(c.x - 45, c.y - 49), "Night %d" % Data.unlock_night(id), HORIZONTAL_ALIGNMENT_CENTER,
			90, 12, Color(1, 1, 1, 0.45))


## Little wall shelf with a wooden bowl of monster bones and a count.
func _paint_bone_bowl(ci: CanvasItem, font: Font) -> void:
	ci.draw_rect(Rect2(BONE_BOWL.x - 64, BONE_BOWL.y + 26, 128, 12), Color("6d5140"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(BONE_BOWL.x - 54, BONE_BOWL.y + 38), Vector2(BONE_BOWL.x - 34, BONE_BOWL.y + 38),
		Vector2(BONE_BOWL.x - 54, BONE_BOWL.y + 62)]), Color("4a3424"))
	var n: int = Data.bones - (1 if dragging == "bone" else 0)
	for k in mini(n, 4):
		Art.bone(ci, BONE_BOWL + Vector2(-18 + k * 12, -4 - (k % 2) * 8), 40, 1.0, -0.6 + k * 0.5)
	var bowl := PackedVector2Array()
	for j in 13:
		var ang := PI * j / 12.0
		bowl.append(BONE_BOWL + Vector2(cos(ang) * 46.0, sin(ang) * 30.0))
	ci.draw_colored_polygon(bowl, Color("8a6242"))
	ci.draw_colored_polygon(Art.ellipse(BONE_BOWL, 46, 10, 20), Color("6a4a30"))
	for k in mini(n, 4):
		Art.bone(ci, BONE_BOWL + Vector2(-16 + k * 11, -2), 30, 1.0, 0.3 - k * 0.4)
	Art.outline(ci, bowl, Art.fade(Art.INK, 0.6), 2.0)
	var tag := "x%d" % n
	ci.draw_string_outline(font, BONE_BOWL + Vector2(-40, 56), "Bones " + tag, HORIZONTAL_ALIGNMENT_CENTER, 80, 15, 4, Color(0, 0, 0, 0.6))
	ci.draw_string(font, BONE_BOWL + Vector2(-40, 56), "Bones " + tag, HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Data.parchment)
	if n > 0 and not pot_bone and dragging == "":
		Art.sparkle(ci, BONE_BOWL + Vector2(36, -26), 6.0 + 3.0 * sin(t * 5.0), Color(1, 0.95, 0.7))
	if has_auto():
		var sw := auto_switch_rect()
		ci.draw_rect(sw, Color("4f8a44") if Data.auto_bone else Color("5a4a40"))
		ci.draw_rect(sw, Color("2a1e14"), false, 2.0)
		ci.draw_string(font, sw.position + Vector2(0, 24), "Auto: " + ("ON" if Data.auto_bone else "OFF"), HORIZONTAL_ALIGNMENT_CENTER,
			sw.size.x, 16, Color.WHITE)
	if auto_flight < 1.0:
		var k := auto_flight
		var from := BONE_BOWL + Vector2(0, -10)
		var to := SURFACE + Vector2(-40, -10)
		var ctrl := (from + to) * 0.5 + Vector2(0, -160)
		Art.bone(ci, from.lerp(ctrl, k).lerp(ctrl.lerp(to, k), k), 44, 1.0, k * 8.0)


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
		var ph := fmod(t * (0.8 if not brewing() else 1.6) + k * 0.143, 1.0)
		var bp := SURFACE + Vector2(sin(k * 12.9) * 110.0, sin(k * 7.3) * 20.0 + 2.0)
		if ph < 0.8:
			ci.draw_circle(bp, 3.0 + ph * 9.0, liquid.lightened(0.25))
			ci.draw_circle(bp + Vector2(-2, -2), 1.5 + ph * 2.0, Art.fade(Color.WHITE, 0.6))
		else:
			ci.draw_arc(bp, 12.0 + (ph - 0.8) * 30.0, 0, TAU, 14, Art.fade(liquid.lightened(0.4), (1.0 - ph) * 5.0), 2.0, true)

	if pot_bone:
		var bang := t * 0.4 + PI * 0.5
		var bp := SURFACE + Vector2(cos(bang) * 50.0, sin(bang) * 10.0 - 8.0 + sin(t * 3.0) * 3.0)
		Art.glow(ci, bp, 40, Color(1, 0.95, 0.7, 0.35))
		Art.bone(ci, bp, 54, 1.0, -0.4 + sin(t * 1.5) * 0.3)
	for k in pot.size():
		var ang := swirl * 0.5 + k * PI + t * 0.25
		var bob := sin(t * 2.5 + k) * 4.0
		Art.ingredient(ci, pot[k], SURFACE + Vector2(cos(ang) * 75.0, sin(ang) * 16.0 - 14.0 + bob), 62)

	if brewing():
		_paint_bubble(ci)
		for k in BUBBLES:
			var pip := POT + Vector2.from_angle(-PI / 2 + (k - 1) * 0.2) * 243.0
			var col := Color(1, 1, 1, 0.15)
			if k < results.size():
				col = {"perfect": Color("ffd35a"), "good": Color("c8b890"), "missed": Color(1, 1, 1, 0.3)}[results[k]]
			ci.draw_circle(pip, 10, col)
			ci.draw_arc(pip, 10, 0, TAU, 16, Color(0, 0, 0, 0.5), 2.0, true)
			if k < results.size() and results[k] == "perfect":
				Art.sparkle(ci, pip, 7.0, Color.WHITE)
	for r in rings:
		var rt: float = r["t"] / 0.5
		ci.draw_arc(r["pos"], r["r"] * (1.0 + rt * 1.2), 0, TAU, 32, Art.fade(r["color"], 1.0 - rt), 4.0 * (1.0 - rt) + 1.0, true)

	if dragging != "" and pot.size() < 2:
		var rim := Art.ellipse(POT + Vector2(0, -110), 196, 62, 48)
		Art.outline(ci, rim, Art.fade(Data.magic, 0.55 + 0.35 * sin(t * 6.0)), 4.0)


## The rising bubble, its target ring (gold while a tap would be Perfect),
## a glossy highlight and a faint reflection of the potion colour.
func _paint_bubble(ci: CanvasItem) -> void:
	if bubble.is_empty():
		return
	var f: float = bubble["f"]
	var at := bubble_pos(bubble)
	var r := bubble_radius(f)
	var target := bubble_radius((perfect_from() + PERFECT_TO) * 0.5)
	var in_window := f >= perfect_from() and f <= PERFECT_TO + 0.08
	var ring_col := Color("ffd35a") if in_window else Color(1, 1, 1, 0.45)
	for k in 16:
		var a0 := TAU * k / 16.0 + t * 0.6
		ci.draw_arc(at, target, a0, a0 + TAU / 32.0, 4, ring_col, 3.0 if in_window else 2.0, true)
	var col := _liquid_color().lightened(0.25)
	ci.draw_circle(at, r, Art.fade(col, 0.45))
	ci.draw_circle(at + Vector2(r * 0.15, r * 0.2), r * 0.7, Art.fade(col.darkened(0.2), 0.25))
	ci.draw_arc(at, r, 0, TAU, 40, Art.fade(col.lightened(0.5), 0.9), 2.5, true)
	ci.draw_arc(at, r * 0.72, PI * 1.1, PI * 1.5, 10, Color(1, 1, 1, 0.85), maxf(2.0, r * 0.1), true)
	ci.draw_circle(at + Vector2(r * 0.35, -r * 0.4), r * 0.08, Color(1, 1, 1, 0.8))
	if f > 1.0:
		ci.draw_arc(at, r, 0, TAU, 40, Color(1, 0.4, 0.3, 0.8), 2.0, true)


func _paint_light_over(ci: CanvasItem) -> void:
	var liquid := _liquid_color()
	Art.glow(ci, SURFACE, 190, Art.fade(liquid, 0.3 + (0.15 if brewing() else 0.0)))
	Art.glow(ci, FIRE + Vector2(0, -25), 110, Color(1.0, 0.7, 0.3, 0.5 * _flicker(11.0)))
	Art.glow(ci, CANDLE + Vector2(0, -12), 22, Color(1.0, 0.85, 0.5, 0.7 * _flicker(15.0)))
	if not bubble.is_empty():
		var f: float = bubble["f"]
		var in_window := f >= perfect_from() and f <= PERFECT_TO + 0.08
		Art.glow(ci, bubble_pos(bubble), bubble_radius(f) * 1.6, Art.fade(Color("ffd35a") if in_window else liquid.lightened(0.3), 0.35))
	for p in particles:
		var kind: String = p["kind"]
		if kind == "spark" or kind == "ember":
			var f: float = p["life"] / p["max"]
			Art.glow(ci, p["pos"], p["size"] * 3.0, Art.fade(p["color"], f))


func _paint_ui(ci: CanvasItem) -> void:
	var rid := ci.get_canvas_item()
	var font := ThemeDB.fallback_font
	if has_batcher():
		var r := batch_rect()
		sign_box.draw(rid, r)
		ci.draw_string(font, r.position + Vector2(10, 36), "-", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Data.parchment)
		ci.draw_string(font, r.position + Vector2(r.size.x - 26, 36), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Data.parchment)
		var label := "Batch x%d" % Data.batch
		var possible := batch_possible()
		ci.draw_string(font, r.position + Vector2(0, 26), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 19, Data.parchment)
		if pot.size() == 2 and possible < Data.batch:
			ci.draw_string(font, r.position + Vector2(0, 46), "max %d" % possible, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color("ffb08a"))

	var tip := "Drag an ingredient into the cauldron."
	if pot.size() == 1:
		tip = "Add one more ingredient."
	elif pot.size() == 2:
		tip = "Tap each bubble when it fills the ring!"
	if has_mortar() and Data.bones > 0 and not pot_bone and pot.size() < 2:
		tip += " Add a bone to empower it."
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
	var first := book_page * PER_PAGE
	for i in range(first, mini(first + PER_PAGE, Data.potion_order.size())):
		_paint_recipe(ci, font, i)
	var gold := Color("e8c77a")
	for r in [PAGE_PREV, PAGE_NEXT]:
		sign_box.draw(rid, r)
	ci.draw_string(font, PAGE_PREV.position + Vector2(0, 25), "<", HORIZONTAL_ALIGNMENT_CENTER, PAGE_PREV.size.x, 22, gold)
	ci.draw_string(font, PAGE_NEXT.position + Vector2(0, 25), ">", HORIZONTAL_ALIGNMENT_CENTER, PAGE_NEXT.size.x, 22, gold)
	ci.draw_string(font, Vector2(PAGE_PREV.end.x, 1012), "%d/%d" % [book_page + 1, _page_count()], HORIZONTAL_ALIGNMENT_CENTER,
		PAGE_NEXT.position.x - PAGE_PREV.end.x, 18, gold)

	for p in popups:
		var pt: float = p["t"]
		var at := Vector2(0, 450 - pt * 30)
		var a := clampf(1.8 - pt, 0.0, 1.0)
		ci.draw_string_outline(font, at, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 720, 34, 8, Color(0, 0, 0, 0.6 * a))
		ci.draw_string(font, at, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 720, 34, Art.fade(p["color"], a))

	for m in marks:
		var mt: float = m["t"]
		var at: Vector2 = m["pos"] + Vector2(-80, -mt * 40)
		ci.draw_string_outline(font, at, m["text"], HORIZONTAL_ALIGNMENT_CENTER, 160, 26, 6, Color(0, 0, 0, 0.6 * (1.0 - mt)))
		ci.draw_string(font, at, m["text"], HORIZONTAL_ALIGNMENT_CENTER, 160, 26, Art.fade(m["color"], 1.0 - mt))

	for f in flyers:
		if f["t"] < 0.0:
			continue
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
	ci.draw_string(font, cell.position + Vector2(95, 34), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Data.ink)
	var from_night := Data.potion_night(id)
	if known:
		# Each known recipe as a pair of mushroom icons; a second one reads "or ...".
		var x := 112.0
		var shown := 0
		for r in info["recipes"]:
			if not (Data.is_unlocked(r[0]) and Data.is_unlocked(r[1])):
				continue
			if shown > 0:
				ci.draw_string(font, cell.position + Vector2(x - 12, 70), "or", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Art.fade(Data.ink, 0.6))
				x += 16.0
			Art.ingredient(ci, r[0], cell.position + Vector2(x, 70), 30)
			ci.draw_string(font, cell.position + Vector2(x + 18, 72), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Data.ink)
			Art.ingredient(ci, r[1], cell.position + Vector2(x + 44, 70), 30)
			x += 90.0
			shown += 1
	elif from_night > Data.day:
		ci.draw_string(font, cell.position + Vector2(95, 66), "Needs a mushroom from night %d" % from_night, HORIZONTAL_ALIGNMENT_LEFT,
			230, 14, Art.fade(Data.ink, 0.55))
	else:
		ci.draw_string(font, cell.position + Vector2(95, 66), "Not yet discovered", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Art.fade(Data.ink, 0.55))
	var bottled := "%d bottled" % Data.bottles[id]
	if Data.bottles[id + "+"] > 0:
		bottled += ", %d empowered" % Data.bottles[id + "+"]
	ci.draw_string(font, cell.position + Vector2(95, 98), bottled, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Data.moss)
