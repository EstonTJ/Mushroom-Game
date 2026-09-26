extends Node2D
## Day phase 1: a short timed walk. Tap mushrooms before they fade. Only the
## mushrooms unlocked so far turn up; Ghost Fungus is the rare one (at most one
## per walk, and it fades fast). Rocks and stumps take a few taps to clear and
## often hide a mushroom, more likely a rare one.
##
## Drawing is split into stacked layers like the other screens: forest floor ->
## leaf shadows -> sun patches -> objects -> sunbeams and glows -> tree canopy
## -> UI (timer, basket, flying pickups). The floor and canopy are drawn once.

signal finished

const Art = preload("res://scripts/art.gd")
const Baked = preload("res://scripts/baked.gd")

const DURATION := 20.0
const SPAWN_EVERY := 0.9
const MAX_ON_SCREEN := 6
const BASKET_Y := 1110.0
const FLY_TIME := 0.5
## Under a rock or stump: a mushroom (else a beetle), and how often it's the
## glowing ghost fungus once that's unlocked.
const HIDDEN_MUSHROOM_CHANCE := 0.85
## Upgrades: seconds the Foraging Basket adds; how long a rare mushroom
## shimmers before appearing (Foxfire Lantern).
const BASKET_BONUS := 5.0
## How long the reishi find (glow and fact banner) stays up.
const REISHI_BANNER := 4.5
const FOXFIRE_LEAD := 1.2
const HIDDEN_GHOST_CHANCE := 0.25
const ROCK_STYLES := ["boulder", "mossy", "cairn", "slab"]
const STUMP_STYLES := ["stump", "bracket", "log", "snag"]
const TRAIL := [Vector2(300, 100), Vector2(430, 380), Vector2(270, 700), Vector2(420, 1000), Vector2(340, 1140)]
const STREAM := [Vector2(-30, 800), Vector2(190, 730), Vector2(430, 780), Vector2(750, 690)]


## One drawing layer. It calls back into this script so all drawing stays here.
class Layer extends Node2D:
	var painter: Callable
	## How long the last redraw took, for performance checks.
	var last_usec := 0

	func _draw() -> void:
		var start := Time.get_ticks_usec()
		painter.call(self)
		last_usec = Time.get_ticks_usec() - start


## Walk length: DURATION, or longer with the Foraging Basket.
var duration := DURATION
var time_left := DURATION
## Rare mushrooms waiting to appear, shimmering first (Foxfire Lantern).
var pending := []
## Reishi found under stumps on this walk, and the find's glowing moment.
var reishi_found := 0
var reishi_shine := {}
var spawn_timer := 0.0
var items := []
var popups := []
var flyers := []
var bounce := {}
var particles := []
var butterflies := []
var rare_spawned := false
## The Truffle Pig (a market helper): where it is, which way it faces, and
## how long it rests after each find.
var pig := {}
var obstacles := []
var done := false
var t := 0.0
var leaf_timer := 0.0

# Scenery, generated once from a fixed seed.
var trail: Curve2D
var moss := []
var grass := []
var flowers := []
var ferns := []
var stones := []
var litter := []
var logs := []
var trees := []
var shade_blobs := []
var sun_spots := []
var stream: Curve2D
var stepping := []
var bushes := []
var trunks := []
var clovers := []
var speckles := []

var floor_layer: Baked
var shade_layer: Layer
var light_under: Layer
var objects: Layer
var light_over: Layer
var canopy_layer: Baked
var ui_layer: Layer
var track_box: StyleBoxFlat
var basket_box: StyleBoxFlat
var fill_box: StyleBoxFlat


func _ready() -> void:
	if Data.upgrades.has("foraging_basket"):
		duration = DURATION + BASKET_BONUS
	time_left = duration
	_build_scenery()
	track_box = StyleBoxFlat.new()
	track_box.bg_color = Color(0, 0, 0, 0.3)
	track_box.set_corner_radius_all(8)
	track_box.anti_aliasing = true
	fill_box = StyleBoxFlat.new()
	fill_box.set_corner_radius_all(8)
	fill_box.anti_aliasing = true
	basket_box = StyleBoxFlat.new()
	basket_box.bg_color = Color("9a7446")
	basket_box.border_color = Color("6a4a2a")
	basket_box.set_border_width_all(4)
	basket_box.set_corner_radius_all(22)
	basket_box.anti_aliasing = true

	floor_layer = Baked.new(_paint_floor)
	add_child(floor_layer)
	shade_layer = _add_layer(_paint_shade, false)
	light_under = _add_layer(_paint_light_under, true)
	objects = _add_layer(_paint_objects, false)
	light_over = _add_layer(_paint_light_over, true)
	canopy_layer = Baked.new(_paint_canopy)
	add_child(canopy_layer)
	ui_layer = _add_layer(_paint_ui, false)
	_place_obstacles()
	if Data.upgrades.has("truffle_pig"):
		pig = {"pos": Vector2(120, 1020), "face": 1.0, "rest": 1.0, "walk": 0.0}
	for i in 3:
		_spawn()


func _add_layer(painter: Callable, additive: bool) -> Layer:
	var layer := Layer.new()
	layer.painter = painter
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		layer.material = m
	add_child(layer)
	return layer


func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	trail = Curve2D.new()
	for i in TRAIL.size():
		var prev: Vector2 = TRAIL[maxi(i - 1, 0)]
		var next: Vector2 = TRAIL[mini(i + 1, TRAIL.size() - 1)]
		var handle := (next - prev) * 0.22
		trail.add_point(TRAIL[i], -handle, handle)

	stream = Curve2D.new()
	for i in STREAM.size():
		var prev: Vector2 = STREAM[maxi(i - 1, 0)]
		var next: Vector2 = STREAM[mini(i + 1, STREAM.size() - 1)]
		var handle := (next - prev) * 0.3
		stream.add_point(STREAM[i], -handle, handle)
	# Stepping stones where the trail crosses the stream.
	var best := Vector2.ZERO
	var best_d := INF
	for q in trail.get_baked_points():
		var d := stream.get_closest_point(q).distance_to(q)
		if d < best_d:
			best_d = d
			best = q
	var along := trail.get_closest_offset(best)
	for k in [-36.0, 0.0, 36.0]:
		stepping.append(trail.sample_baked(along + k) + Vector2(rng.randf_range(-6, 6), 0))

	for i in 400:
		speckles.append({"pos": Vector2(rng.randf_range(0, 720), rng.randf_range(110, 1110)), "dark": rng.randf() < 0.5,
			"r": rng.randf_range(1.0, 2.5)})
	for i in 24:
		clovers.append({"pos": Vector2(rng.randf_range(20, 700), rng.randf_range(140, 1100)), "s": rng.randf_range(4, 6)})
	# Bushes come in five kinds: berry, flowering, holly, fir sapling and bramble.
	var berry_cols := [Color("d83a4a"), Color("4a5ad8"), Color("e87a2a")]
	var flower_cols := [Color("f7c6dc"), Color("fff6e8"), Color("d8c4f5")]
	var kinds := ["berry", "flower", "holly", "fir", "bramble", "berry", "flower", "holly"]
	var tries := 0
	while bushes.size() < kinds.size() and tries < 400:
		tries += 1
		var p := Vector2(rng.randf_range(70, 650), rng.randf_range(200, 1060))
		if _near_trail(p, 70.0) or _in_stream(p, 60.0) or _near_log(p, 30.0):
			continue
		var crowded := false
		for other in bushes:
			if other["pos"].distance_to(p) < 110.0:
				crowded = true
		if crowded:
			continue
		var kind: String = kinds[bushes.size()]
		var sc := rng.randf_range(0.8, 1.25)
		var blobs := []
		for k in rng.randi_range(4, 7):
			blobs.append({"off": Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 8)) * sc, "r": rng.randf_range(16, 28) * sc})
		var dots := []
		for k in rng.randi_range(6, 11):
			dots.append(Vector2(rng.randf_range(-32, 32), rng.randf_range(-26, 6)) * sc)
		bushes.append({"pos": p, "kind": kind, "s": sc, "blobs": blobs, "dots": dots,
			"berry": berry_cols[rng.randi() % berry_cols.size()], "flower": flower_cols[rng.randi() % flower_cols.size()],
			"seed": rng.randf() * 10.0})

	for i in 24:
		moss.append({"pos": Vector2(rng.randf_range(0, 720), rng.randf_range(120, 1110)),
			"rx": rng.randf_range(50, 130), "ry": rng.randf_range(25, 60), "light": rng.randf() < 0.5})
	for i in 220:
		grass.append({"pos": Vector2(rng.randf_range(0, 720), rng.randf_range(130, 1110)), "s": rng.randf_range(0.7, 1.4),
			"lean": rng.randf_range(-3, 3)})
	var petal_cols := [Color("fff8f0"), Color("ffe07a"), Color("f5a8c8"), Color("c8b0f0")]
	for i in 44:
		flowers.append({"pos": Vector2(rng.randf_range(20, 700), rng.randf_range(140, 1100)), "s": rng.randf_range(4, 7),
			"color": petal_cols[rng.randi() % petal_cols.size()]})
	for i in 9:
		var side := rng.randf_range(20, 110) if i % 2 == 0 else rng.randf_range(610, 700)
		ferns.append({"pos": Vector2(side, rng.randf_range(180, 1080)), "s": rng.randf_range(0.8, 1.3), "rot": rng.randf_range(-0.4, 0.4)})
	for i in 14:
		stones.append({"pos": Vector2(rng.randf_range(20, 700), rng.randf_range(140, 1100)), "r": rng.randf_range(6, 15)})
	var leaf_cols := [Color("c8843c"), Color("a8642c"), Color("d8b04a"), Color("8a5a2c")]
	for i in 50:
		litter.append({"pos": Vector2(rng.randf_range(0, 720), rng.randf_range(130, 1110)), "s": rng.randf_range(5, 9),
			"ang": rng.randf() * TAU, "color": leaf_cols[rng.randi() % leaf_cols.size()]})
	logs.append({"a": Vector2(40, 470), "b": Vector2(190, 440), "w": 34.0})
	logs.append({"a": Vector2(540, 860), "b": Vector2(690, 900), "w": 30.0})

	var y := 140.0
	while y < 1090.0:
		trees.append(_tree(Vector2(rng.randf_range(-45, -10), y), rng))
		trees.append(_tree(Vector2(rng.randf_range(730, 765), y + 60.0), rng))
		trunks.append({"pos": Vector2(18, y + 58), "side": 1.0})
		trunks.append({"pos": Vector2(702, y + 118), "side": -1.0})
		y += rng.randf_range(110, 150)

	for i in 12:
		shade_blobs.append({"pos": Vector2(rng.randf_range(0, 720), rng.randf_range(140, 1100)), "r": rng.randf_range(70, 140),
			"ph": rng.randf() * TAU})
	for i in 14:
		sun_spots.append({"pos": Vector2(rng.randf_range(60, 660), rng.randf_range(160, 1080)), "r": rng.randf_range(40, 90),
			"ph": rng.randf() * TAU})

	var wing_cols := [Color("f5c04a"), Color("9ad0f5"), Color("f5a8c8")]
	for i in 3:
		butterflies.append({"pos": Vector2(rng.randf_range(100, 620), rng.randf_range(200, 1000)),
			"target": Vector2(rng.randf_range(100, 620), rng.randf_range(200, 1000)), "color": wing_cols[i], "ph": rng.randf() * TAU})


func _near_trail(p: Vector2, dist: float) -> bool:
	return trail.get_closest_point(p).distance_to(p) < dist


func _in_stream(p: Vector2, pad: float) -> bool:
	return stream.get_closest_point(p).distance_to(p) < 34.0 + pad


func _near_log(p: Vector2, pad: float) -> bool:
	for lg in logs:
		if Geometry2D.get_closest_point_to_segment(p, lg["a"], lg["b"]).distance_to(p) < lg["w"] + pad:
			return true
	return false


## Rocks and stumps, placed fresh each walk. hidden is what's underneath:
## a mushroom id or "beetle". peek: a hint of the cap shows at the edge.
func _place_obstacles() -> void:
	var count := 3 if Data.day < 4 else 4
	var tries := 0
	while obstacles.size() < count and tries < 200:
		tries += 1
		var p := Vector2(randf_range(120, 600), randf_range(270, 1010))
		if _in_stream(p, 50.0) or _near_log(p, 50.0):
			continue
		var crowded := false
		for o in obstacles:
			if o["pos"].distance_to(p) < 170.0:
				crowded = true
		if crowded:
			continue
		var kind := "rock" if randf() < 0.5 else "stump"
		var style: String = (ROCK_STYLES if kind == "rock" else STUMP_STYLES).pick_random()
		var hp := (3 if kind == "rock" else 4) - (1 if Data.upgrades.has("rock_hammer") else 0)
		var hidden := _pick_hidden() if randf() < HIDDEN_MUSHROOM_CHANCE else "beetle"
		# Reishi grows on the stumps of broadleaf trees: a rare find under one.
		if kind == "stump" and Data.day >= Data.REISHI_NIGHT and randf() < Data.REISHI_STUMP_CHANCE:
			hidden = "reishi"
		obstacles.append({"kind": kind, "style": style, "pos": p, "hp": hp, "max": hp, "shake": 0.0, "hidden": hidden,
			"peek": hidden != "beetle" and randf() < 0.5, "seed": randf() * 10.0, "gone": false})


## What hides under a rock or stump: rare mushrooms are much likelier here
## than out in the open. Each unlocked kind's chance goes with 1 / weight^3,
## so a weight-1 rarity turns up 27 times as often as a weight-3 common one.
func _pick_hidden() -> String:
	if Data.is_unlocked("ghost_fungus") and randf() < HIDDEN_GHOST_CHANCE:
		return "ghost_fungus"
	var ids := Data.unlocked_mushrooms().filter(func(id): return Data.ingredients[id]["weight"] > 0.0)
	var total := 0.0
	for id in ids:
		total += _hidden_odds(id)
	var r := randf() * total
	for id in ids:
		r -= _hidden_odds(id)
		if r <= 0.0:
			return id
	return ids[-1]


func _hidden_odds(id: String) -> float:
	return 1.0 / pow(float(Data.ingredients[id]["weight"]), 3.0)


func _tree(center: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var blobs := []
	for k in rng.randi_range(4, 5):
		blobs.append({"off": Vector2(rng.randf_range(-30, 30), rng.randf_range(-35, 35)), "r": rng.randf_range(34, 54)})
	return {"pos": center, "blobs": blobs}


# ------------------------------------------------------------------ logic ---

func _process(delta: float) -> void:
	t += delta
	for p in popups:
		p["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.0)
	if not reishi_shine.is_empty():
		reishi_shine["t"] += delta
		if reishi_shine["t"] > REISHI_BANNER:
			reishi_shine = {}

	var still_flying := []
	for f in flyers:
		f["t"] += delta
		if f["t"] >= FLY_TIME:
			bounce[f["id"]] = 0.35
			_burst(_slot_pos(f["id"]), Data.ingredients[f["id"]]["color"].lightened(0.3), 8, 110.0)
		else:
			still_flying.append(f)
	flyers = still_flying
	for k in bounce.keys():
		bounce[k] = maxf(0.0, bounce[k] - delta)
	for o in obstacles:
		o["shake"] = maxf(0.0, o["shake"] - delta)

	var kept := []
	for it in items:
		it["age"] += delta
		if it["age"] < it["life"]:
			kept.append(it)
		else:
			for i in 5:
				_emit(it["pos"] + Vector2(randf_range(-16, 16), randf_range(-6, 6)), Vector2(randf_range(-20, 20), randf_range(-30, -10)),
					0.6, 10.0, Color(0.55, 0.45, 0.3, 0.4), "dust")
	items = kept

	var waiting := []
	for pd in pending:
		pd["t"] -= delta
		if pd["t"] <= 0.0 and not done:
			_add_item(pd["id"], pd["pos"], pd["life"])
		elif not done:
			waiting.append(pd)
	pending = waiting

	if not done:
		time_left -= delta
		spawn_timer -= delta
		if spawn_timer <= 0.0 and items.size() + pending.size() < MAX_ON_SCREEN:
			spawn_timer = SPAWN_EVERY
			_spawn()
		if time_left <= 0.0:
			time_left = 0.0
			done = true
			finished.emit()

	_update_particles(delta)
	_update_butterflies(delta)
	if not pig.is_empty() and not done:
		pig_step(delta)
	shade_layer.queue_redraw()
	light_under.queue_redraw()
	objects.queue_redraw()
	light_over.queue_redraw()
	ui_layer.queue_redraw()


func _pick() -> String:
	var ids := Data.unlocked_mushrooms().filter(func(id): return Data.ingredients[id]["weight"] > 0.0)
	var total := 0.0
	for id in ids:
		total += float(Data.ingredients[id]["weight"])
	var r := randf() * total
	for id in ids:
		r -= float(Data.ingredients[id]["weight"])
		if r <= 0.0:
			return id
	return ids[-1]


func _free_spot(p: Vector2) -> bool:
	if _in_stream(p, 10.0):
		return false
	for o in obstacles:
		if not o["gone"] and o["pos"].distance_to(p) < 90.0:
			return false
	for it in items + pending:
		if it["pos"].distance_to(p) < 120.0:
			return false
	return true


func _spawn() -> void:
	var id := _pick()
	var life := randf_range(3.0, 5.0)
	if not rare_spawned and Data.is_unlocked("ghost_fungus") and (time_left < 6.0 or (time_left < 15.0 and randf() < 0.2)):
		id = "ghost_fungus"
		life = 3.0
		rare_spawned = true
	var pos := Vector2(randf_range(90, 630), randf_range(210, 1040))
	for _attempt in 12:
		if _free_spot(pos):
			break
		pos = Vector2(randf_range(90, 630), randf_range(210, 1040))
	if Data.upgrades.has("foxfire_lantern") and is_rare(id):
		pending.append({"id": id, "pos": pos, "life": life, "t": FOXFIRE_LEAD})
		return
	_add_item(id, pos, life)


## Foxfire Lantern: a green shimmer where a rare mushroom is about to pop up
## (brighter as it nears), and a soft flicker round rocks and stumps hiding one.
func _paint_foxfire(ci: CanvasItem) -> void:
	var fox := Color(0.45, 1.0, 0.6)
	for pd in pending:
		var k := 1.0 - clampf(pd["t"] / FOXFIRE_LEAD, 0.0, 1.0)
		Art.glow(ci, pd["pos"] + Vector2(0, -10), 70.0 + 50.0 * k, Art.fade(fox, 0.55 + 0.4 * k))
		for j in 3:
			var ang := t * 3.0 + j * TAU / 3.0
			Art.sparkle(ci, pd["pos"] + Vector2(cos(ang) * 34.0, sin(ang) * 16.0 - 14.0), 8.0 + 5.0 * k, Art.fade(fox, 1.0))
	if not Data.upgrades.has("foxfire_lantern"):
		return
	for o in obstacles:
		if o["gone"] or o["hidden"] == "beetle" or not is_rare(o["hidden"]):
			continue
		var flick := 0.5 + 0.5 * sin(t * 2.3 + o["seed"] * 3.0)
		Art.glow(ci, o["pos"] + Vector2(0, 10), 95, Art.fade(fox, 0.3 + 0.25 * flick))
		if flick > 0.8:
			Art.sparkle(ci, o["pos"] + Vector2(-30, -30), 7.0, Art.fade(fox, 1.0))


## A found reishi floats up from its stump in a warm glow, and a banner
## shares the real fact about it.
func _paint_reishi_find(ci: CanvasItem) -> void:
	var k: float = reishi_shine["t"]
	var fade := clampf(REISHI_BANNER - k, 0.0, 1.0)
	var rise := minf(k, 1.2)
	var at: Vector2 = reishi_shine["pos"] + Vector2(0, -30 - rise * 60.0)
	Art.glow(ci, at, 90, Color(1, 0.8, 0.4, 0.5 * fade))
	Art.reishi(ci, at + Vector2(0, 20), 80, fade)
	var font := ThemeDB.fallback_font
	var box := Rect2(30, 150, 660, 110)
	ci.draw_rect(box, Color(0.12, 0.08, 0.06, 0.85 * fade))
	ci.draw_rect(box, Color(1, 0.85, 0.55, 0.8 * fade), false, 2.0)
	ci.draw_string(font, box.position + Vector2(0, 34), "You found a reishi!", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 26,
		Color(1, 0.86, 0.56, fade))
	ci.draw_multiline_string(font, box.position + Vector2(20, 62), Data.REISHI_FACT, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 40, 17, 2,
		Color(1, 0.97, 0.9, fade))


## Rare for the Foxfire Lantern: the ghost fungus and the least common kinds.
static func is_rare(id: String) -> bool:
	if id == "reishi":
		return true
	var w := float(Data.ingredients[id]["weight"])
	return w <= 1.5


func _add_item(id: String, pos: Vector2, life: float) -> void:
	items.append({"id": id, "pos": pos, "age": 0.0, "life": life, "ph": randf() * 1.4})
	for i in 6:
		_emit(pos + Vector2(randf_range(-12, 12), 4), Vector2(randf_range(-50, 50), randf_range(-80, -30)), 0.45, 3.0,
			Color("6b5a3e"), "clod")


## One tap on a rock or stump: it shakes and cracks, and on the last tap it
## breaks apart and shows what was underneath.
func _hit_obstacle(o: Dictionary) -> void:
	o["hp"] -= 1
	o["shake"] = 0.25
	var chip := Color("8a8680") if o["kind"] == "rock" else Color("6a4a30")
	for i in 6:
		_emit(o["pos"] + Vector2(randf_range(-20, 20), randf_range(-30, 0)), Vector2(randf_range(-110, 110), randf_range(-170, -60)),
			0.5, randf_range(2.5, 5.0), chip, "clod")
	if o["hp"] > 0:
		return
	o["gone"] = true
	for i in 18:
		_emit(o["pos"] + Vector2(randf_range(-30, 30), randf_range(-30, 10)), Vector2(randf_range(-200, 200), randf_range(-240, -60)),
			0.7, randf_range(3.0, 7.0), chip, "clod")
	for i in 6:
		_emit(o["pos"] + Vector2(randf_range(-20, 20), 0), Vector2(randf_range(-30, 30), randf_range(-40, -10)), 0.8, 14.0,
			Color(0.55, 0.45, 0.3, 0.45), "dust")
	if o["hidden"] == "reishi":
		Data.reishi += 1
		reishi_found += 1
		for i in 24:
			_emit(o["pos"] + Vector2(randf_range(-20, 20), randf_range(-30, 0)), Vector2(randf_range(-160, 160), randf_range(-220, -60)),
				0.9, randf_range(3.0, 6.0), Color("ffd890"), "clod")
		popups.append({"text": "Reishi! The mushroom of immortality", "pos": o["pos"], "t": 0.0, "color": Color("ffd890")})
		reishi_shine = {"pos": o["pos"], "t": 0.0}
	elif o["hidden"] == "beetle":
		_emit(o["pos"], Vector2.from_angle(randf_range(-PI, 0)) * 90.0, 2.0, 1.0, Color("2a2440"), "beetle")
		popups.append({"text": "Just a beetle!", "pos": o["pos"], "t": 0.0, "color": Color.WHITE})
	else:
		_add_item(o["hidden"], o["pos"], 5.0)
		popups.append({"text": "Found one!", "pos": o["pos"], "t": 0.0, "color": Color.WHITE})


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_at(get_global_mouse_position())


## Pig speed (px/s), how close its snout must get, and its rest after a find.
const PIG_SPEED := 130.0
const PIG_REACH := 36.0
const PIG_REST := 0.9
## With the Golden Snout.
const SNOUT_SPEED := 200.0
const SNOUT_REST := 0.45


## The pig trots to the nearest mushroom and gathers it, then rests a moment.
func pig_step(delta: float) -> void:
	if pig["rest"] > 0.0:
		pig["rest"] -= delta
		return
	var best := -1
	var best_d := INF
	for i in items.size():
		var d: float = items[i]["pos"].distance_to(pig["pos"])
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	var target: Vector2 = items[best]["pos"] + Vector2(-pig["face"] * 30.0, 16)
	var to := target - Vector2(pig["pos"])
	if to.length() > 4.0:
		pig["face"] = 1.0 if items[best]["pos"].x > pig["pos"].x else -1.0
		var speed := SNOUT_SPEED if Data.upgrades.has("golden_snout") else PIG_SPEED
		pig["pos"] = Vector2(pig["pos"]) + to.normalized() * minf(speed * delta, to.length())
		pig["walk"] += delta
	if items[best]["pos"].distance_to(pig["pos"] + Vector2(pig["face"] * 30.0, -16)) < PIG_REACH + 10.0:
		_collect(best, "Oink! +1 ")
		pig["rest"] = SNOUT_REST if Data.upgrades.has("golden_snout") else PIG_REST


## A tap on the forest floor: chips at a rock or stump, or picks a mushroom.
func tap_at(p: Vector2) -> void:
	for o in obstacles:
		if not o["gone"] and o["pos"].distance_to(p + Vector2(0, 10)) < 58.0:
			_hit_obstacle(o)
			return
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		if it["pos"].distance_to(p) < 60.0:
			_collect(i, "+1 ")
			break


## Gather item i into the basket (by a tap or the pig).
func _collect(i: int, prefix: String) -> void:
	var it: Dictionary = items[i]
	var info: Dictionary = Data.ingredients[it["id"]]
	Data.inventory[it["id"]] += 1
	popups.append({"text": prefix + info["name"], "pos": it["pos"], "t": 0.0, "color": info["color"]})
	flyers.append({"id": it["id"], "from": it["pos"], "t": 0.0})
	_burst(it["pos"], info["color"].lightened(0.35), 12, 160.0)
	items.remove_at(i)


# -------------------------------------------------------------- particles ---

func _emit(pos: Vector2, vel: Vector2, life: float, size: float, color: Color, kind: String) -> void:
	if particles.size() < 300:
		particles.append({"pos": pos, "vel": vel, "life": life, "max": life, "size": size, "color": color, "kind": kind,
			"ang": randf() * TAU, "spin": randf_range(-2, 2)})


func _burst(pos: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		_emit(pos, Vector2.from_angle(randf() * TAU) * randf_range(speed * 0.3, speed), randf_range(0.35, 0.7),
			randf_range(2.0, 4.0), color, "spark")


func _update_particles(delta: float) -> void:
	leaf_timer -= delta
	if leaf_timer <= 0.0:
		leaf_timer = randf_range(0.5, 1.0)
		var cols := [Color("c8843c"), Color("d8b04a"), Color("8aa84a")]
		_emit(Vector2(randf_range(40, 680), 115), Vector2(randf_range(-10, 10), randf_range(35, 55)), 30.0,
			randf_range(6, 9), cols[randi() % cols.size()], "leaf")
	for p in particles:
		p["life"] -= delta
		p["ang"] += p["spin"] * delta
		var v: Vector2 = p["vel"]
		match p["kind"]:
			"spark":
				v *= 0.9
			"clod":
				v.y += 400.0 * delta
			"dust":
				v *= 0.94
			"leaf":
				v.x = sin(t * 1.5 + p["spin"] * 3.0) * 30.0
		p["vel"] = v
		p["pos"] += v * delta
		if p["kind"] == "leaf" and p["pos"].y > BASKET_Y:
			p["life"] = 0.0
	particles = particles.filter(func(p): return p["life"] > 0.0)


func _update_butterflies(delta: float) -> void:
	for b in butterflies:
		var pos: Vector2 = b["pos"]
		var target: Vector2 = b["target"]
		if pos.distance_to(target) < 12.0:
			b["target"] = Vector2(randf_range(100, 620), randf_range(200, 1000))
		var wobble := Vector2(sin(t * 3.0 + b["ph"]), cos(t * 2.3 + b["ph"])) * 25.0
		b["pos"] = pos + ((target - pos).normalized() * 45.0 + wobble) * delta


# ---------------------------------------------------------------- drawing ---

## Basket compartments: one per unlocked mushroom, one row of up to 8,
## a second row once more than 8 are unlocked.
func _basket_ids() -> Array:
	return Data.unlocked_mushrooms()


func _slot_pos(id: String) -> Vector2:
	var ids := _basket_ids()
	var n := ids.size()
	var i := maxi(0, ids.find(id))
	var cell_w := 704.0 / 8.0 if n > 8 else minf(140.0, 704.0 / n)
	var row := i / 8
	var in_row := mini(8, n - row * 8)
	var x0 := 8.0 + (704.0 - in_row * cell_w) / 2.0
	var y := 1182.0 if n <= 8 else 1158.0 + row * 62.0
	return Vector2(x0 + (i % 8 + 0.5) * cell_w, y)


func _basket_icon() -> float:
	return 56.0 if _basket_ids().size() <= 8 else 34.0


func _flyer_pos(f: Dictionary) -> Vector2:
	var k: float = clampf(f["t"] / FLY_TIME, 0.0, 1.0)
	var from: Vector2 = f["from"]
	var to := _slot_pos(f["id"])
	var ctrl := (from + to) * 0.5 + Vector2(0, -220)
	return from.lerp(ctrl, k).lerp(ctrl.lerp(to, k), k)


func _paint_floor(ci: CanvasItem) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, 1280), Vector2(0, 1280)]),
		PackedColorArray([Color("86a86c"), Color("86a86c"), Color("5d8350"), Color("5d8350")]))
	for m in moss:
		ci.draw_colored_polygon(Art.ellipse(m["pos"], m["rx"], m["ry"], 20),
			Color(0.62, 0.76, 0.48, 0.45) if m["light"] else Color(0.3, 0.46, 0.28, 0.35))
	for sp in speckles:
		ci.draw_circle(sp["pos"], sp["r"], Color(0.2, 0.3, 0.15, 0.18) if sp["dark"] else Color(0.9, 0.95, 0.7, 0.14))

	# Stream: muddy banks, water, and a lighter current down the middle.
	var water_pts := stream.get_baked_points()
	for k in range(0, water_pts.size(), 2):
		ci.draw_circle(water_pts[k], 42, Color("6b5a3e"))
	for k in range(0, water_pts.size(), 2):
		ci.draw_circle(water_pts[k], 33, Color("4a7a8a"))
	for k in range(0, water_pts.size(), 2):
		ci.draw_circle(water_pts[k], 16, Color("5f93a2"))
	for k in range(0, water_pts.size(), 6):
		var q: Vector2 = water_pts[k]
		ci.draw_colored_polygon(Art.ellipse(q + Vector2(0, -40), 9, 5, 10), Color("7a6a4a"))

	for tr in trunks:
		var p: Vector2 = tr["pos"]
		var side: float = tr["side"]
		ci.draw_rect(Rect2(p.x - 22, p.y - 70, 44, 80), Color("5a4030"))
		ci.draw_line(p + Vector2(-8, -66), p + Vector2(-6, 6), Color("3e2c20"), 3.0)
		ci.draw_line(p + Vector2(8, -60), p + Vector2(10, 4), Color("3e2c20"), 3.0)
		for k in 3:
			var root := PackedVector2Array([p + Vector2(side * 10, 2 + k * 3), p + Vector2(side * (30 + k * 12), 8 + k * 5),
				p + Vector2(side * (50 + k * 18), 6 + k * 9)])
			ci.draw_polyline(root, Color("4e3828"), 7.0 - k * 1.5, true)

	var pts := trail.get_baked_points()
	for k in range(0, pts.size(), 2):
		ci.draw_circle(pts[k], 32, Color("8a7a58"))
	for k in range(0, pts.size(), 2):
		ci.draw_circle(pts[k], 26, Color("b09a72"))
	for k in range(0, pts.size(), 2):
		ci.draw_circle(pts[k], 11, Color("c4ae84"))

	for l in litter:
		Art.leaf(ci, l["pos"], l["s"], l["ang"], Art.fade(l["color"], 0.85))
	for s in stones:
		var r: float = s["r"]
		Art.shadow(ci, s["pos"] + Vector2(2, r * 0.5), r * 1.1, r * 0.4)
		ci.draw_colored_polygon(Art.ellipse(s["pos"], r * 1.1, r * 0.8, 12), Color("9a968c"))
		ci.draw_colored_polygon(Art.ellipse(s["pos"] + Vector2(-r * 0.3, -r * 0.3), r * 0.5, r * 0.3, 10), Color("bab6aa"))
	for st in stepping:
		Art.shadow(ci, st + Vector2(2, 6), 22, 8)
		ci.draw_colored_polygon(Art.ellipse(st, 22, 14, 16), Color("8a8680"))
		ci.draw_colored_polygon(Art.ellipse(st + Vector2(-5, -4), 11, 6, 12), Color("aaa69e"))
	for lg in logs:
		_paint_log(ci, lg["a"], lg["b"], lg["w"])
	for b in bushes:
		_paint_bush(ci, b)
	for cl in clovers:
		var cp: Vector2 = cl["pos"]
		var cs: float = cl["s"]
		for k in 3:
			ci.draw_circle(cp + Vector2.from_angle(-PI / 2.0 + k * TAU / 3.0) * cs * 0.7, cs * 0.6, Color("4f8a44"))
	for f in ferns:
		_paint_fern(ci, f["pos"], f["s"], f["rot"])
	for g in grass:
		var p: Vector2 = g["pos"]
		var s: float = g["s"]
		var lean: float = g["lean"]
		var blade := Color("4f7a44")
		ci.draw_line(p, p + Vector2(-5 + lean, -11) * s, blade, 2.0, true)
		ci.draw_line(p, p + Vector2(lean, -15) * s, blade.lightened(0.15), 2.0, true)
		ci.draw_line(p, p + Vector2(5 + lean, -10) * s, blade, 2.0, true)
	for fl in flowers:
		var p: Vector2 = fl["pos"]
		var s: float = fl["s"]
		for k in 5:
			ci.draw_circle(p + Vector2.from_angle(k * TAU / 5.0) * s * 0.8, s * 0.6, fl["color"])
		ci.draw_circle(p, s * 0.45, Color("e8a83a"))


func _paint_log(ci: CanvasItem, a: Vector2, b: Vector2, w: float) -> void:
	var n := (b - a).normalized().orthogonal() * w * 0.5
	Art.shadow(ci, (a + b) * 0.5 + Vector2(0, w * 0.45), a.distance_to(b) * 0.55, w * 0.25)
	ci.draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), Color("6a4a30"))
	for k in 5:
		var u := (k + 0.5) / 5.0
		ci.draw_line(a.lerp(b, u) + n * 0.8, a.lerp(b, u + 0.08) - n * 0.6, Color("4e3622"), 2.0, true)
	ci.draw_line(a + n * 0.55, b + n * 0.55, Color("8a6a48"), 3.0, true)
	ci.draw_circle(a, w * 0.5, Color("6a4a30"))
	ci.draw_circle(b, w * 0.5, Color("c8a878"))
	ci.draw_arc(b, w * 0.32, 0, TAU, 16, Color("9a7a50"), 2.0, true)
	ci.draw_arc(b, w * 0.15, 0, TAU, 12, Color("9a7a50"), 2.0, true)
	for k in 3:
		ci.draw_colored_polygon(Art.ellipse(a.lerp(b, 0.25 + k * 0.22) + n * 0.7, w * 0.35, w * 0.16, 12), Color("6f9a4a"))


func _paint_fern(ci: CanvasItem, pos: Vector2, s: float, rot: float) -> void:
	for k in 6:
		var ang := -PI / 2.0 + rot + (k - 2.5) * 0.42
		var dir := Vector2.from_angle(ang)
		var tip := pos + dir * 70.0 * s
		ci.draw_line(pos, tip, Color("3f6a3a"), 2.0, true)
		for j in range(1, 8):
			var at := pos.lerp(tip, j / 8.0)
			var leaflet := 13.0 * s * (1.0 - j / 9.0)
			var side := dir.orthogonal()
			ci.draw_line(at, at + (side + dir * 0.4).normalized() * leaflet, Color("5a8a4a"), 3.0, true)
			ci.draw_line(at, at + (-side + dir * 0.4).normalized() * leaflet, Color("5a8a4a"), 3.0, true)


func _paint_shade(ci: CanvasItem) -> void:
	for b in shade_blobs:
		var pos: Vector2 = b["pos"] + Vector2(sin(t * 0.5 + b["ph"]) * 10.0, cos(t * 0.4 + b["ph"]) * 6.0)
		Art.glow(ci, pos, b["r"], Color(0.08, 0.2, 0.08, 0.26))


func _paint_light_under(ci: CanvasItem) -> void:
	var dusk := 1.0 - time_left / duration
	for s in sun_spots:
		var pos: Vector2 = s["pos"] + Vector2(sin(t * 0.45 + s["ph"]) * 10.0, cos(t * 0.35 + s["ph"]) * 6.0)
		var pulse := 0.8 + 0.2 * sin(t * 1.3 + s["ph"])
		Art.glow(ci, pos, s["r"], Color(1.0, 0.92 - 0.2 * dusk, 0.6 - 0.25 * dusk, 0.16 * pulse))


func _paint_objects(ci: CanvasItem) -> void:
	# Moving glints on the stream.
	var length := stream.get_baked_length()
	for k in 14:
		var d := fmod(t * 45.0 + k * length / 14.0, length)
		var q := stream.sample_baked(d)
		var dir := (stream.sample_baked(minf(d + 4.0, length)) - q).normalized()
		var off := dir.orthogonal() * sin(k * 3.7) * 14.0
		ci.draw_line(q + off - dir * 9.0, q + off + dir * 9.0, Color(1, 1, 1, 0.35), 2.0, true)

	for o in obstacles:
		if not o["gone"]:
			_paint_obstacle(ci, o)

	var order := items.duplicate()
	order.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	for it in order:
		var age: float = it["age"]
		var remaining: float = it["life"] - age
		var a := 1.0
		if remaining < 1.0:
			a = 0.35 + 0.65 * absf(sin(remaining * 12.0))
		var pop := minf(1.0, age * 5.0)
		var grow := pop + 0.25 * sin(pop * PI) - (0.15 * (1.0 - remaining) if remaining < 1.0 else 0.0)
		if grow < 0.05:
			continue
		var bob := sin(age * 3.0) * 4.0
		var pos: Vector2 = it["pos"]
		Art.shadow(ci, pos + Vector2(0, 26), 30 * grow, 8 * grow, a)
		ci.draw_colored_polygon(Art.ellipse(pos + Vector2(0, 24), 26 * grow, 7 * grow, 16), Color(0.42, 0.35, 0.24, 0.6 * a))
		Art.ingredient(ci, it["id"], pos + Vector2(0, bob), 80.0 * grow, a)
		var tw := fmod(age + it["ph"], 1.4)
		if tw < 0.35:
			var ts := sin(tw / 0.35 * PI) * 11.0
			Art.sparkle(ci, pos + Vector2(24, -38 + bob), ts, Color(1, 1, 0.9, 0.95 * a))
		if it["id"] == "ghost_fungus":
			for k in 3:
				var ang := t * 2.0 + k * TAU / 3.0
				Art.sparkle(ci, pos + Vector2(cos(ang) * 46.0, sin(ang) * 20.0 - 20.0 + bob), 6.0, Color(0.8, 1.0, 0.85, a))

	for b in butterflies:
		_paint_butterfly(ci, b)
	if not pig.is_empty():
		Art.pig(ci, pig["pos"], 64, pig["face"], pig["walk"], pig["rest"] > 0.0, Data.upgrades.has("golden_snout"))

	for p in particles:
		var f: float = p["life"] / p["max"]
		match p["kind"]:
			"leaf":
				Art.leaf(ci, p["pos"], p["size"], p["ang"], p["color"])
			"clod":
				ci.draw_circle(p["pos"], p["size"], Art.fade(p["color"], f))
			"dust":
				Art.glow(ci, p["pos"], p["size"] * (2.0 + (1.0 - f) * 2.0), Art.fade(p["color"], f))
			"beetle":
				var bp: Vector2 = p["pos"]
				var legs := sin(t * 40.0) * 3.0
				for side in [-1.0, 1.0]:
					ci.draw_line(bp + Vector2(side * 4, -3), bp + Vector2(side * 11, -6 + legs * side), Color("1a1426"), 1.5, true)
					ci.draw_line(bp + Vector2(side * 4, 3), bp + Vector2(side * 11, 6 - legs * side), Color("1a1426"), 1.5, true)
				ci.draw_colored_polygon(Art.ellipse(bp, 7, 9, 12), Color("2a2440"))
				ci.draw_line(bp + Vector2(0, -8), bp + Vector2(0, 8), Color("5a4a86"), 1.0, true)


## Rock or stump that hides something, in one of several looks (its style).
## Cracks and splinters show the taps so far; it shakes on each tap. Some let
## a mushroom cap peek out at the edge.
func _paint_obstacle(ci: CanvasItem, o: Dictionary) -> void:
	var pos: Vector2 = o["pos"] + Vector2(sin(t * 70.0) * o["shake"] * 14.0, 0)
	var damage: int = o["max"] - o["hp"]
	var sd: float = o["seed"]
	if o["peek"] and o["hidden"] == "reishi":
		Art.reishi(ci, pos + Vector2(40, 22), 34)
	elif o["peek"]:
		Art.ingredient(ci, o["hidden"], pos + Vector2(40, 20), 30)
	match str(o.get("style", "boulder" if o["kind"] == "rock" else "stump")):
		"boulder":
			_paint_boulder(ci, pos, sd, 1.0, false)
		"mossy":
			_paint_boulder(ci, pos, sd, 1.05, true)
		"cairn":
			Art.shadow(ci, pos + Vector2(6, 22), 54, 13)
			var low := _stone(ci, pos + Vector2(0, 4), 52, 26, sd, Color("8a8680"))
			var mid := _stone(ci, pos + Vector2(-4, -26), 38, 19, sd + 1.3, Color("9a968e"))
			var top := _stone(ci, pos + Vector2(3, -50), 24, 13, sd + 2.6, Color("aaa69e"))
			for pts in [low, mid, top]:
				Art.outline(ci, pts, Art.fade(Art.INK, 0.55), 2.0)
			ci.draw_colored_polygon(Art.ellipse(pos + Vector2(-8, -60), 10, 4, 10), Color("8fb85a"))
		"slab":
			Art.shadow(ci, pos + Vector2(8, 20), 64, 12)
			var slab := PackedVector2Array([pos + Vector2(-62, 6), pos + Vector2(-48, -28), pos + Vector2(30, -36), pos + Vector2(64, -10),
				pos + Vector2(56, 18), pos + Vector2(-40, 22)])
			ci.draw_colored_polygon(slab, Color("7e7a86"))
			ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-48, -28), pos + Vector2(30, -36), pos + Vector2(64, -10),
				pos + Vector2(-50, -6)]), Color("a29eaa"))
			Art.outline(ci, slab, Art.fade(Art.INK, 0.55), 2.0)
			for k in 5:
				var lp := pos + Vector2(-34 + k * 18 + sin(sd + k) * 6.0, -22 + cos(sd * 2.0 + k) * 5.0)
				ci.draw_circle(lp, 3.0 + fmod(sd * (k + 1), 3.0), Color("d8c86a") if k % 2 == 0 else Color("b8c8a8"))
		"stump":
			_paint_stump(ci, pos, sd, damage, false)
		"bracket":
			_paint_stump(ci, pos, sd, damage, true)
		"log":
			Art.shadow(ci, pos + Vector2(4, 24), 66, 12)
			var body := PackedVector2Array([pos + Vector2(-50, -30), pos + Vector2(46, -34), pos + Vector2(46, 20), pos + Vector2(-50, 20)])
			ci.draw_colored_polygon(body, Color("6a4a34"))
			for k in 4:
				ci.draw_line(pos + Vector2(-44, -18 + k * 11), pos + Vector2(40, -20 + k * 11), Color("4e3626"), 2.0, true)
			Art.outline(ci, body, Art.fade(Art.INK, 0.7), 2.0)
			ci.draw_colored_polygon(Art.ellipse(pos + Vector2(46, -7), 16, 27, 18), Color("c8a070"))
			ci.draw_colored_polygon(Art.ellipse(pos + Vector2(47, -6), 9, 17, 16), Color("2a1e16"))
			Art.outline(ci, Art.ellipse(pos + Vector2(46, -7), 16, 27, 18), Color("3e2c20"), 2.0)
			ci.draw_colored_polygon(Art.ellipse(pos + Vector2(-14, -32), 26, 7, 14), Color("6f9a4a"))
			for c in damage:
				var x := -30.0 + c * 22.0
				ci.draw_polyline(PackedVector2Array([pos + Vector2(x, -30), pos + Vector2(x + 7, -8), pos + Vector2(x - 2, 16)]),
					Color("2a1e14"), 2.5, true)
		"snag":
			Art.shadow(ci, pos + Vector2(6, 26), 44, 11)
			for side in [-1.0, 1.0]:
				ci.draw_polyline(PackedVector2Array([pos + Vector2(side * 18, 12), pos + Vector2(side * 36, 22)]), Color("4e3828"), 7.0, true)
			var snag := PackedVector2Array([pos + Vector2(-26, 20), pos + Vector2(-22, -62), pos + Vector2(-8, -48), pos + Vector2(2, -84),
				pos + Vector2(12, -56), pos + Vector2(22, -70), pos + Vector2(26, 20)])
			ci.draw_colored_polygon(snag, Color("5e4432"))
			for k in 3:
				ci.draw_line(pos + Vector2(-14 + k * 12, -50), pos + Vector2(-16 + k * 14, 16), Color("3e2c20"), 2.0, true)
			ci.draw_colored_polygon(Art.ellipse(pos + Vector2(4, -20), 6, 9, 12), Color("1e1510"))
			Art.outline(ci, snag, Art.fade(Art.INK, 0.7), 2.0)
			for c in damage:
				var y := -40.0 + c * 18.0
				ci.draw_polyline(PackedVector2Array([pos + Vector2(-20, y), pos + Vector2(-4, y + 8), pos + Vector2(14, y + 2)]),
					Color("2a1e14"), 2.5, true)
	if o["kind"] == "rock":
		for c in damage:
			var ang := sd + c * 2.1
			var crack := PackedVector2Array([pos + Vector2(0, -6)])
			for j in range(1, 4):
				crack.append(pos + Vector2(cos(ang + sin(j + c) * 0.5) * 14.0 * j, sin(ang) * 10.0 * j - 6.0))
			ci.draw_polyline(crack, Color("3a3834"), 2.5, true)
	if damage == 0 and fmod(t + sd, 3.0) < 0.4:
		Art.sparkle(ci, pos + Vector2(34, -44), sin(fmod(t + sd, 3.0) / 0.4 * PI) * 10.0, Color(1, 1, 0.9, 0.9))


## A lumpy stone outline around c; returns it so callers can outline it.
func _stone(ci: CanvasItem, c: Vector2, rx: float, ry: float, sd: float, col: Color) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 12:
		var ang := TAU * k / 12.0
		var rr := 1.0 + 0.12 * sin(ang * 3.0 + sd) + 0.06 * sin(ang * 5.0 + sd * 2.0)
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry) * rr)
	ci.draw_colored_polygon(pts, col)
	ci.draw_colored_polygon(Art.ellipse(c + Vector2(-rx * 0.28, -ry * 0.45), rx * 0.42, ry * 0.3, 12), col.lightened(0.18))
	return pts


func _paint_boulder(ci: CanvasItem, pos: Vector2, sd: float, s: float, mossy: bool) -> void:
	Art.shadow(ci, pos + Vector2(6, 22), 56 * s, 14)
	var pts := PackedVector2Array()
	for k in 12:
		var ang := TAU * k / 12.0
		var rr := 1.0 + 0.12 * sin(ang * 3.0 + sd) + 0.06 * sin(ang * 5.0 + sd * 2.0)
		pts.append(pos + Vector2(cos(ang) * 50.0, sin(ang) * 36.0 - 8.0) * rr * s)
	ci.draw_colored_polygon(pts, Color("8a8680") if not mossy else Color("7e8474"))
	ci.draw_colored_polygon(Art.ellipse(pos + Vector2(12, 6), 34, 20, 16), Color("76726c"))
	ci.draw_colored_polygon(Art.ellipse(pos + Vector2(-14, -24), 22, 11, 14), Color("aaa69e"))
	if mossy:
		# A thick moss cushion over the top, with a fern sprig.
		ci.draw_colored_polygon(Art.ellipse(pos + Vector2(-2, -34), 44, 16, 18), Color("4f7a3a"))
		ci.draw_colored_polygon(Art.ellipse(pos + Vector2(-8, -38), 32, 10, 16), Color("7aa84e"))
		for k in 6:
			ci.draw_circle(pos + Vector2(-36 + k * 14, -26 + sin(sd + k) * 3.0), 5.0, Color("5f8f42"))
		_paint_fern(ci, pos + Vector2(34, -30), 0.5, 0.5)
	else:
		ci.draw_colored_polygon(Art.ellipse(pos + Vector2(-4, -36), 26, 9, 14), Color("6f9a4a"))
	Art.outline(ci, pts, Art.fade(Art.INK, 0.55), 2.0)


func _paint_stump(ci: CanvasItem, pos: Vector2, sd: float, damage: int, fungi: bool) -> void:
	Art.shadow(ci, pos + Vector2(6, 26), 52, 12)
	var lean := damage * 0.05 * (1.0 if sd > 5.0 else -1.0)
	var top := pos + Vector2(lean * 60.0, -34)
	for k in 3:
		var side := -1.0 if k == 0 else 1.0
		ci.draw_polyline(PackedVector2Array([pos + Vector2(side * 20 * (k + 1) * 0.6, 12), pos + Vector2(side * (34 + k * 10), 22),
			pos + Vector2(side * (48 + k * 12), 20)]), Color("4e3828"), 8.0 - k * 2.0, true)
	var body := PackedVector2Array([top + Vector2(-38, 0), top + Vector2(38, 0), pos + Vector2(42, 20), pos + Vector2(-42, 20)])
	ci.draw_colored_polygon(body, Color("5a4030") if not fungi else Color("4e3a2c"))
	for k in 5:
		var x := -28.0 + k * 14.0
		ci.draw_line(top + Vector2(x, 4), pos + Vector2(x * 1.1, 18), Color("3e2c20"), 2.0, true)
	Art.outline(ci, body, Art.fade(Art.INK, 0.7), 2.0)
	ci.draw_colored_polygon(Art.ellipse(top, 38, 12, 20), Color("c8a070") if not fungi else Color("a88a60"))
	Art.outline(ci, Art.ellipse(top, 25, 8, 16), Color("9a7448"), 1.5)
	Art.outline(ci, Art.ellipse(top, 12, 4, 12), Color("9a7448"), 1.5)
	Art.outline(ci, Art.ellipse(top, 38, 12, 20), Color("3e2c20"), 2.0)
	if fungi:
		# Moss creeping over the rim and a stack of shelf fungi on the side.
		ci.draw_colored_polygon(Art.ellipse(top + Vector2(-14, 2), 22, 7, 14), Color("6f9a4a"))
		for k in 3:
			var at := pos + Vector2(30 + k * 3, -4 - k * 12)
			var w := 20.0 - k * 4.0
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-4, 0), at + Vector2(w, -4), at + Vector2(w + 2, 2), at + Vector2(-4, 5)]),
				Color("d89a4a") if k % 2 == 0 else Color("c07a38"))
			ci.draw_line(at + Vector2(-2, 4), at + Vector2(w, 1), Color("fff0d0"), 1.5, true)
	for c in damage:
		var x := -24.0 + c * 20.0
		ci.draw_polyline(PackedVector2Array([top + Vector2(x, 2), top + Vector2(x + 6, 18), top + Vector2(x - 2, 34)]),
			Color("2a1e14"), 2.5, true)


## Bushes (painted once into the forest floor): berry, flowering, holly,
## fir sapling or bramble, each at its own size.
func _paint_bush(ci: CanvasItem, b: Dictionary) -> void:
	var bp: Vector2 = b["pos"]
	var sc: float = b["s"]
	var kind: String = b.get("kind", "berry")
	Art.shadow(ci, bp + Vector2(4, 16 * sc), 44 * sc, 12 * sc)
	if kind == "fir":
		for k in 3:
			var w := (40.0 - k * 11.0) * sc
			var y := bp.y + (10.0 - k * 22.0) * sc
			var tri := PackedVector2Array([Vector2(bp.x - w, y), Vector2(bp.x, y - 34.0 * sc), Vector2(bp.x + w, y)])
			ci.draw_colored_polygon(tri, Color("2f5a38"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(bp.x - w * 0.6, y - 4), Vector2(bp.x, y - 30.0 * sc), Vector2(bp.x, y - 4)]),
				Color("477a48"))
		ci.draw_rect(Rect2(bp.x - 4 * sc, bp.y + 8 * sc, 8 * sc, 10 * sc), Color("5a4030"))
		return
	var dark: Color = {"berry": Color("3f6a3a"), "flower": Color("4a7a40"), "holly": Color("24472e"), "bramble": Color("4a5a30")}[kind]
	var light: Color = {"berry": Color("5a8a4a"), "flower": Color("6e9e52"), "holly": Color("3a6a44"), "bramble": Color("6a7a3e")}[kind]
	for bl in b["blobs"]:
		ci.draw_circle(bp + bl["off"], bl["r"], dark)
	for bl in b["blobs"]:
		var r: float = bl["r"]
		ci.draw_circle(bp + bl["off"] + Vector2(-r * 0.2, -r * 0.25), r * 0.65, light)
	match kind:
		"berry":
			for d in b["dots"]:
				ci.draw_circle(bp + d, 4.5, b["berry"])
				ci.draw_circle(bp + d + Vector2(-1.5, -1.5), 1.5, Color(1, 1, 1, 0.7))
		"flower":
			for d in b["dots"]:
				for k in 5:
					ci.draw_circle(bp + d + Vector2.from_angle(k * TAU / 5.0) * 3.5, 3.0, b["flower"])
				ci.draw_circle(bp + d, 2.2, Color("f5c04a"))
		"holly":
			for d in b["dots"]:
				var tip: Vector2 = bp + d
				ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-7, 0), tip + Vector2(0, -4), tip + Vector2(7, 0), tip + Vector2(0, 4)]),
					Color("4f8a5a"))
			for k in 4:
				var bo: Vector2 = b["dots"][k]
				ci.draw_circle(bp + bo + Vector2(3, 5), 3.5, Color("d02a36"))
		"bramble":
			var thorn := Color("3a2a22")
			for k in 4:
				var a0: Vector2 = b["dots"][k]
				var a1: Vector2 = b["dots"][k + 1]
				ci.draw_line(bp + a0, bp + a1 + Vector2(0, -8), Color("6a3a3a"), 2.5, true)
				ci.draw_line(bp + (a0 + a1) / 2.0, bp + (a0 + a1) / 2.0 + Vector2(3, -5), thorn, 1.5, true)
			for k in range(4, b["dots"].size()):
				var d: Vector2 = b["dots"][k]
				ci.draw_circle(bp + d, 4.0, Color("2a1a3a"))
				ci.draw_circle(bp + d + Vector2(-1.2, -1.2), 1.3, Color(1, 1, 1, 0.5))


func _paint_butterfly(ci: CanvasItem, b: Dictionary) -> void:
	var pos: Vector2 = b["pos"]
	var flap := absf(sin(t * 16.0 + b["ph"]))
	var col: Color = b["color"]
	Art.shadow(ci, pos + Vector2(0, 40), 10, 3, 0.6)
	for side in [-1.0, 1.0]:
		ci.draw_colored_polygon(Art.ellipse(pos + Vector2(side * 9.0 * flap, -4), 10.0 * flap + 1.0, 8, 12), col)
		ci.draw_colored_polygon(Art.ellipse(pos + Vector2(side * 7.0 * flap, 6), 7.0 * flap + 1.0, 6, 12), col.darkened(0.15))
		ci.draw_circle(pos + Vector2(side * 10.0 * flap, -5), 2.0 * flap, Color(1, 1, 1, 0.7))
	ci.draw_line(pos + Vector2(0, -9), pos + Vector2(0, 10), Color("2b2233"), 3.0, true)
	ci.draw_line(pos + Vector2(0, -9), pos + Vector2(-5, -16), Color("2b2233"), 1.0, true)
	ci.draw_line(pos + Vector2(0, -9), pos + Vector2(5, -16), Color("2b2233"), 1.0, true)


func _paint_light_over(ci: CanvasItem) -> void:
	_paint_foxfire(ci)
	var dusk := 1.0 - time_left / duration
	var beam := Color(1.0, 0.95 - 0.2 * dusk, 0.7 - 0.3 * dusk, 0.09 + 0.02 * sin(t * 0.8))
	var clear := Color(beam.r, beam.g, beam.b, 0.0)
	for b in [[-90.0, 70.0], [110.0, 110.0], [310.0, 60.0], [500.0, 95.0]]:
		var x: float = b[0]
		var w: float = b[1]
		ci.draw_polygon(PackedVector2Array([Vector2(x, 110), Vector2(x + w, 110), Vector2(x + w + 330, 1110), Vector2(x + 330 - w * 0.4, 1110)]),
			PackedColorArray([beam, beam, clear, clear]))
	for it in items:
		var pos: Vector2 = it["pos"]
		if it["id"] == "ghost_fungus":
			var ghost := Color(0.55, 1.0, 0.65)
			var pulse := 0.7 + 0.3 * sin(t * 5.0)
			Art.glow(ci, pos + Vector2(0, -15), 100, Art.fade(ghost, 0.45 * pulse))
			var rr := fmod(t * 60.0, 70.0)
			ci.draw_arc(pos + Vector2(0, -10), 30.0 + rr, 0, TAU, 32, Art.fade(ghost, (1.0 - rr / 70.0) * 0.6), 2.0, true)
		else:
			Art.glow(ci, pos + Vector2(0, -15), 55, Color(1, 1, 0.8, 0.12))
	for p in particles:
		if p["kind"] == "spark":
			var f: float = p["life"] / p["max"]
			Art.glow(ci, p["pos"], p["size"] * 3.0, Art.fade(p["color"], f))


func _paint_canopy(ci: CanvasItem) -> void:
	for tr in trees:
		for b in tr["blobs"]:
			Art.shadow(ci, tr["pos"] + b["off"] + Vector2(18, 26), b["r"], b["r"] * 0.8, 0.8)
	for tr in trees:
		for b in tr["blobs"]:
			ci.draw_circle(tr["pos"] + b["off"], b["r"], Color("3f6b3e"))
		for b in tr["blobs"]:
			var r: float = b["r"]
			ci.draw_circle(tr["pos"] + b["off"] + Vector2(r * 0.15, -r * 0.2), r * 0.7, Color("5a8f4c"))
			ci.draw_circle(tr["pos"] + b["off"] + Vector2(r * 0.3, -r * 0.35), r * 0.3, Color("7aae5c"))


func _paint_ui(ci: CanvasItem) -> void:
	if not reishi_shine.is_empty():
		_paint_reishi_find(ci)
	var rid := ci.get_canvas_item()
	var font := ThemeDB.fallback_font

	# Timer: a sun rides the bar and it warms toward evening; pulses near the end.
	var frac := time_left / duration
	var track := Rect2(16, 120, 688, 18)
	track_box.draw(rid, track)
	var fill_col := Color("f5c04a").lerp(Color("e8703f"), 1.0 - frac)
	if time_left < 5.0 and not done:
		fill_col = fill_col.lerp(Color("ff5a4a"), 0.5 + 0.5 * sin(t * 10.0))
	if frac > 0.0:
		var fill := track
		fill.size.x = maxf(18.0, track.size.x * frac)
		fill_box.bg_color = fill_col
		fill_box.draw(rid, fill)
	var sun := Vector2(track.position.x + track.size.x * frac, track.get_center().y)
	for k in 8:
		var ang := k * TAU / 8.0 + t * 0.8
		ci.draw_line(sun + Vector2.from_angle(ang) * 16.0, sun + Vector2.from_angle(ang) * 22.0, Color("ffd35a"), 3.0, true)
	ci.draw_circle(sun, 13, Color("ffd35a"))
	ci.draw_circle(sun, 9, Color("fff0a0"))
	var secs := "%ds" % ceili(time_left)
	ci.draw_string_outline(font, Vector2(640, 166), secs, HORIZONTAL_ALIGNMENT_RIGHT, 64, 20, 4, Color(0, 0, 0, 0.5))
	ci.draw_string(font, Vector2(640, 166), secs, HORIZONTAL_ALIGNMENT_RIGHT, 64, 20, Data.parchment)

	# Woven basket with a compartment per ingredient.
	var body := Rect2(8, BASKET_Y + 14, 704, 150)
	basket_box.draw(rid, body)
	for row in 5:
		var y := body.position.y + 12.0 + row * 27.0
		var x := body.position.x + 10.0 + (row % 2) * 16.0
		while x < body.end.x - 26.0:
			ci.draw_rect(Rect2(x, y, 26, 22), Color("b38a56"))
			ci.draw_rect(Rect2(x, y, 26, 5), Color("c8a06a"))
			x += 32.0
	ci.draw_rect(Rect2(4, BASKET_Y + 4, 712, 22), Color("6a4a2a"))
	ci.draw_rect(Rect2(4, BASKET_Y + 4, 712, 6), Color("8a6a42"))
	var ids := _basket_ids()
	var icon := _basket_icon()
	for id in ids:
		var b: float = bounce.get(id, 0.0)
		var slot := _slot_pos(id)
		var pos := slot + Vector2(0, -sin(b / 0.35 * PI) * 12.0)
		Art.glow(ci, pos + Vector2(0, -10), icon * 0.8, Color(0.2, 0.12, 0.05, 0.35))
		Art.ingredient(ci, id, pos, icon * (1.0 + b * 0.6))
		var label := "x%d" % Data.inventory[id]
		var ly := slot.y + icon * 0.62 + 12.0
		var fs := 22 if icon > 40.0 else 15
		ci.draw_string_outline(font, Vector2(slot.x - 40, ly), label, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, 5, Color(0.2, 0.12, 0.05, 0.85))
		ci.draw_string(font, Vector2(slot.x - 40, ly), label, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, Data.parchment)

	for f in flyers:
		var k: float = f["t"] / FLY_TIME
		Art.ingredient(ci, f["id"], _flyer_pos(f), 70.0 - 20.0 * k)

	for p in popups:
		var pt: float = p["t"]
		var at: Vector2 = p["pos"] + Vector2(-110, -60 - pt * 50)
		ci.draw_string_outline(font, at, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 220, 26, 6, Color(0, 0, 0, 0.55 * (1.0 - pt)))
		ci.draw_string(font, at, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 220, 26, Art.fade(Data.parchment, 1.0 - pt))
