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

const DURATION := 20.0
const SPAWN_EVERY := 0.9
const MAX_ON_SCREEN := 6
const BASKET_Y := 1110.0
const FLY_TIME := 0.5
const TRAIL := [Vector2(300, 100), Vector2(430, 380), Vector2(270, 700), Vector2(420, 1000), Vector2(340, 1140)]
const STREAM := [Vector2(-30, 800), Vector2(190, 730), Vector2(430, 780), Vector2(750, 690)]
const BANNER_TIME := 6.0
const SAFETY := "Real wild mushrooms can be deadly. Never eat one you find."


## One drawing layer. It calls back into this script so all drawing stays here.
class Layer extends Node2D:
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


var time_left := DURATION
var spawn_timer := 0.0
var items := []
var popups := []
var flyers := []
var bounce := {}
var particles := []
var butterflies := []
var rare_spawned := false
var obstacles := []
var banner := {}
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

var floor_layer: Layer
var shade_layer: Layer
var light_under: Layer
var objects: Layer
var light_over: Layer
var canopy_layer: Layer
var ui_layer: Layer
var track_box: StyleBoxFlat
var basket_box: StyleBoxFlat
var fill_box: StyleBoxFlat


func _ready() -> void:
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

	floor_layer = _add_layer(_paint_floor, false)
	shade_layer = _add_layer(_paint_shade, false)
	light_under = _add_layer(_paint_light_under, true)
	objects = _add_layer(_paint_objects, false)
	light_over = _add_layer(_paint_light_over, true)
	canopy_layer = _add_layer(_paint_canopy, false)
	ui_layer = _add_layer(_paint_ui, false)
	_place_obstacles()
	_make_banner()
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
	var berry_cols := [Color("d83a4a"), Color("4a5ad8"), Color("e87a2a")]
	while bushes.size() < 6:
		var p := Vector2(rng.randf_range(80, 640), rng.randf_range(200, 1060))
		if _near_trail(p, 70.0) or _in_stream(p, 60.0):
			continue
		var blobs := []
		for k in 5:
			blobs.append({"off": Vector2(rng.randf_range(-28, 28), rng.randf_range(-18, 8)), "r": rng.randf_range(18, 28)})
		bushes.append({"pos": p, "blobs": blobs, "berry": berry_cols[rng.randi() % berry_cols.size()], "seed": rng.randf() * 10.0})

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
		var hp := 3 if kind == "rock" else 4
		var hidden := _pick_hidden() if randf() < 0.7 else "beetle"
		obstacles.append({"kind": kind, "pos": p, "hp": hp, "max": hp, "shake": 0.0, "hidden": hidden,
			"peek": hidden != "beetle" and randf() < 0.5, "seed": randf() * 10.0, "gone": false})


## What hides under a rock or stump: rarer unlocked mushrooms are likelier.
func _pick_hidden() -> String:
	if Data.is_unlocked("ghost_fungus") and randf() < 0.15:
		return "ghost_fungus"
	var ids := Data.unlocked_mushrooms().filter(func(id): return Data.ingredients[id]["weight"] > 0.0)
	var total := 0.0
	for id in ids:
		total += 1.0 / float(Data.ingredients[id]["weight"])
	var r := randf() * total
	for id in ids:
		r -= 1.0 / float(Data.ingredients[id]["weight"])
		if r <= 0.0:
			return id
	return ids[-1]


func _make_banner() -> void:
	var fresh := Data.new_mushrooms(Data.day)
	if fresh.is_empty():
		return
	if Data.day == 1:
		banner = {"title": "Today's mushrooms", "ids": fresh, "line": "Tap them before they fade. Tap rocks and stumps to look underneath!"}
	else:
		var info: Dictionary = Data.ingredients[fresh[0]]
		banner = {"title": "New mushroom: " + info["name"], "ids": fresh, "latin": info["latin"], "line": info["fact"]}
	banner["t"] = 0.0


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
	if not banner.is_empty():
		banner["t"] += delta
		if banner["t"] > BANNER_TIME:
			banner = {}

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

	if not done:
		time_left -= delta
		spawn_timer -= delta
		if spawn_timer <= 0.0 and items.size() < MAX_ON_SCREEN:
			spawn_timer = SPAWN_EVERY
			_spawn()
		if time_left <= 0.0:
			time_left = 0.0
			done = true
			finished.emit()

	_update_particles(delta)
	_update_butterflies(delta)
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
	for it in items:
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
	_add_item(id, pos, life)


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
	if o["hidden"] == "beetle":
		_emit(o["pos"], Vector2.from_angle(randf_range(-PI, 0)) * 90.0, 2.0, 1.0, Color("2a2440"), "beetle")
		popups.append({"text": "Just a beetle!", "pos": o["pos"], "t": 0.0, "color": Color.WHITE})
	else:
		_add_item(o["hidden"], o["pos"], 5.0)
		popups.append({"text": "Found one!", "pos": o["pos"], "t": 0.0, "color": Color.WHITE})


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := get_global_mouse_position()
		for o in obstacles:
			if not o["gone"] and o["pos"].distance_to(p + Vector2(0, 10)) < 58.0:
				_hit_obstacle(o)
				return
		for i in range(items.size() - 1, -1, -1):
			var it: Dictionary = items[i]
			if it["pos"].distance_to(p) < 60.0:
				var info: Dictionary = Data.ingredients[it["id"]]
				Data.inventory[it["id"]] += 1
				popups.append({"text": "+1 " + info["name"], "pos": it["pos"], "t": 0.0, "color": info["color"]})
				flyers.append({"id": it["id"], "from": it["pos"], "t": 0.0})
				_burst(it["pos"], info["color"].lightened(0.35), 12, 160.0)
				items.remove_at(i)
				break


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
		var bp: Vector2 = b["pos"]
		Art.shadow(ci, bp + Vector2(4, 16), 44, 12)
		for bl in b["blobs"]:
			ci.draw_circle(bp + bl["off"], bl["r"], Color("3f6a3a"))
		for bl in b["blobs"]:
			var r: float = bl["r"]
			ci.draw_circle(bp + bl["off"] + Vector2(-r * 0.2, -r * 0.25), r * 0.65, Color("5a8a4a"))
		for k in 7:
			var bo := Vector2(sin(b["seed"] + k * 2.3) * 30.0, cos(b["seed"] + k * 1.7) * 14.0 - 6.0)
			ci.draw_circle(bp + bo, 4.5, b["berry"])
			ci.draw_circle(bp + bo + Vector2(-1.5, -1.5), 1.5, Color(1, 1, 1, 0.7))
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
	var dusk := 1.0 - time_left / DURATION
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


## Rock or stump that hides something. Cracks and splinters show the taps so
## far; it shakes on each tap. Some let a mushroom cap peek out at the edge.
func _paint_obstacle(ci: CanvasItem, o: Dictionary) -> void:
	var pos: Vector2 = o["pos"] + Vector2(sin(t * 70.0) * o["shake"] * 14.0, 0)
	var damage: int = o["max"] - o["hp"]
	var sd: float = o["seed"]
	if o["peek"]:
		Art.ingredient(ci, o["hidden"], pos + Vector2(40, 20), 30)
	if o["kind"] == "rock":
		Art.shadow(ci, pos + Vector2(6, 22), 56, 14)
		var pts := PackedVector2Array()
		for k in 12:
			var ang := TAU * k / 12.0
			var rr := 1.0 + 0.12 * sin(ang * 3.0 + sd) + 0.06 * sin(ang * 5.0 + sd * 2.0)
			pts.append(pos + Vector2(cos(ang) * 50.0, sin(ang) * 36.0 - 8.0) * rr)
		ci.draw_colored_polygon(pts, Color("8a8680"))
		ci.draw_colored_polygon(Art.ellipse(pos + Vector2(12, 6), 34, 20, 16), Color("76726c"))
		ci.draw_colored_polygon(Art.ellipse(pos + Vector2(-14, -24), 22, 11, 14), Color("aaa69e"))
		ci.draw_colored_polygon(Art.ellipse(pos + Vector2(-4, -36), 26, 9, 14), Color("6f9a4a"))
		Art.outline(ci, pts, Art.fade(Art.INK, 0.55), 2.0)
		for c in damage:
			var ang := sd + c * 2.1
			var crack := PackedVector2Array([pos + Vector2(0, -6)])
			for j in range(1, 4):
				crack.append(pos + Vector2(cos(ang + sin(j + c) * 0.5) * 14.0 * j, sin(ang) * 10.0 * j - 6.0))
			ci.draw_polyline(crack, Color("3a3834"), 2.5, true)
	else:
		Art.shadow(ci, pos + Vector2(6, 26), 52, 12)
		var lean := damage * 0.05 * (1.0 if sd > 5.0 else -1.0)
		var top := pos + Vector2(lean * 60.0, -34)
		for k in 3:
			var side := -1.0 if k == 0 else 1.0
			ci.draw_polyline(PackedVector2Array([pos + Vector2(side * 20 * (k + 1) * 0.6, 12), pos + Vector2(side * (34 + k * 10), 22),
				pos + Vector2(side * (48 + k * 12), 20)]), Color("4e3828"), 8.0 - k * 2.0, true)
		var body := PackedVector2Array([top + Vector2(-38, 0), top + Vector2(38, 0), pos + Vector2(42, 20), pos + Vector2(-42, 20)])
		ci.draw_colored_polygon(body, Color("5a4030"))
		for k in 5:
			var x := -28.0 + k * 14.0
			ci.draw_line(top + Vector2(x, 4), pos + Vector2(x * 1.1, 18), Color("3e2c20"), 2.0, true)
		Art.outline(ci, body, Art.fade(Art.INK, 0.7), 2.0)
		ci.draw_colored_polygon(Art.ellipse(top, 38, 12, 20), Color("c8a070"))
		Art.outline(ci, Art.ellipse(top, 25, 8, 16), Color("9a7448"), 1.5)
		Art.outline(ci, Art.ellipse(top, 12, 4, 12), Color("9a7448"), 1.5)
		Art.outline(ci, Art.ellipse(top, 38, 12, 20), Color("3e2c20"), 2.0)
		for c in damage:
			var x := -24.0 + c * 20.0
			ci.draw_polyline(PackedVector2Array([top + Vector2(x, 2), top + Vector2(x + 6, 18), top + Vector2(x - 2, 34)]),
				Color("2a1e14"), 2.5, true)
	if damage == 0 and fmod(t + sd, 3.0) < 0.4:
		Art.sparkle(ci, pos + Vector2(34, -44), sin(fmod(t + sd, 3.0) / 0.4 * PI) * 10.0, Color(1, 1, 0.9, 0.9))


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
	var dusk := 1.0 - time_left / DURATION
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
	var rid := ci.get_canvas_item()
	var font := ThemeDB.fallback_font

	# Timer: a sun rides the bar and it warms toward evening; pulses near the end.
	var frac := time_left / DURATION
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

	if not banner.is_empty():
		_paint_banner(ci, rid, font)


## Introduces the day's new mushroom (or the first three) with a real fact and
## a reminder never to eat wild mushrooms.
func _paint_banner(ci: CanvasItem, rid: RID, font: Font) -> void:
	var bt: float = banner["t"]
	var a := clampf(minf(bt * 4.0, (BANNER_TIME - bt) * 2.0), 0.0, 1.0)
	var box := Rect2(24, 158 - (1.0 - a) * 20.0, 672, 176)
	var style := basket_box.duplicate() as StyleBoxFlat
	style.bg_color = Color(0.12, 0.1, 0.06, 0.86 * a)
	style.border_color = Color(0.95, 0.85, 0.55, 0.7 * a)
	style.draw(rid, box)
	var ids: Array = banner["ids"]
	for i in ids.size():
		Art.ingredient(ci, ids[i], box.position + Vector2(62 + i * 58 - (ids.size() - 1) * 18, 96), 72.0 if ids.size() == 1 else 48.0, a)
	var tx := box.position.x + (140.0 if ids.size() == 1 else 190.0)
	var w := box.end.x - tx - 16.0
	ci.draw_string(font, Vector2(tx, box.position.y + 40), banner["title"], HORIZONTAL_ALIGNMENT_LEFT, w, 24, Color(1, 0.9, 0.6, a))
	var y := box.position.y + 64.0
	if banner.has("latin"):
		ci.draw_string(font, Vector2(tx, y), banner["latin"], HORIZONTAL_ALIGNMENT_LEFT, w, 15, Color(1, 1, 1, 0.6 * a))
		y += 24.0
	ci.draw_multiline_string(font, Vector2(tx, y), banner["line"], HORIZONTAL_ALIGNMENT_LEFT, w, 17, 3, Color(1, 1, 1, 0.92 * a))
	ci.draw_string(font, Vector2(box.position.x + 16, box.end.y - 14), SAFETY, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 32, 14,
		Color(1.0, 0.65, 0.55, a))
