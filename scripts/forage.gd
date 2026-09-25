extends Node2D
## Day phase 1: a short timed walk. Tap ingredients before they fade.
## One Moonglow (the rare one) appears per walk, and it fades fast.
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
var moonglow_spawned := false
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
	var r := randf() * 12.0
	if r < 3.0:
		return "puffcap"
	if r < 6.0:
		return "honeyroot"
	if r < 10.0:
		return "dewmoss"
	return "emberleaf"


func _spawn() -> void:
	var id := _pick()
	var life := randf_range(3.0, 5.0)
	if not moonglow_spawned and (time_left < 6.0 or (time_left < 15.0 and randf() < 0.2)):
		id = "moonglow"
		life = 3.0
		moonglow_spawned = true
	var pos := Vector2(randf_range(90, 630), randf_range(210, 1040))
	for _attempt in 10:
		var clear := true
		for it in items:
			if it["pos"].distance_to(pos) < 120.0:
				clear = false
		if clear:
			break
		pos = Vector2(randf_range(90, 630), randf_range(210, 1040))
	items.append({"id": id, "pos": pos, "age": 0.0, "life": life, "ph": randf() * 1.4})
	for i in 6:
		_emit(pos + Vector2(randf_range(-12, 12), 4), Vector2(randf_range(-50, 50), randf_range(-80, -30)), 0.45, 3.0,
			Color("6b5a3e"), "clod")


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := get_global_mouse_position()
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

func _slot_pos(id: String) -> Vector2:
	return Vector2(72 + 144 * Data.ingredient_order.find(id), 1188)


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
	for lg in logs:
		_paint_log(ci, lg["a"], lg["b"], lg["w"])
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
		if it["id"] == "moonglow":
			for k in 3:
				var ang := t * 2.0 + k * TAU / 3.0
				Art.sparkle(ci, pos + Vector2(cos(ang) * 46.0, sin(ang) * 20.0 - 20.0 + bob), 6.0, Art.fade(Data.magic.lightened(0.4), a))

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
		if it["id"] == "moonglow":
			var pulse := 0.7 + 0.3 * sin(t * 5.0)
			Art.glow(ci, pos + Vector2(0, -15), 100, Art.fade(Data.magic, 0.45 * pulse))
			var rr := fmod(t * 60.0, 70.0)
			ci.draw_arc(pos + Vector2(0, -10), 30.0 + rr, 0, TAU, 32, Art.fade(Data.magic, (1.0 - rr / 70.0) * 0.6), 2.0, true)
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
	for i in range(1, 5):
		ci.draw_line(Vector2(144 * i, BASKET_Y + 30), Vector2(144 * i, BASKET_Y + 160), Color(0.3, 0.2, 0.1, 0.5), 3.0)
	for i in 5:
		var id: String = Data.ingredient_order[i]
		var b: float = bounce.get(id, 0.0)
		var pos := _slot_pos(id) + Vector2(0, -sin(b / 0.35 * PI) * 12.0)
		Art.glow(ci, pos + Vector2(0, -10), 46, Color(0.2, 0.12, 0.05, 0.35))
		Art.ingredient(ci, id, pos, 60.0 * (1.0 + b * 0.6))
		var label := "x%d" % Data.inventory[id]
		ci.draw_string_outline(font, Vector2(144 * i, 1262), label, HORIZONTAL_ALIGNMENT_CENTER, 144, 24, 6, Color(0.2, 0.12, 0.05, 0.8))
		ci.draw_string(font, Vector2(144 * i, 1262), label, HORIZONTAL_ALIGNMENT_CENTER, 144, 24, Data.parchment)

	for f in flyers:
		var k: float = f["t"] / FLY_TIME
		Art.ingredient(ci, f["id"], _flyer_pos(f), 70.0 - 20.0 * k)

	for p in popups:
		var pt: float = p["t"]
		var at: Vector2 = p["pos"] + Vector2(-110, -60 - pt * 50)
		ci.draw_string_outline(font, at, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 220, 26, 6, Color(0, 0, 0, 0.55 * (1.0 - pt)))
		ci.draw_string(font, at, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 220, 26, Art.fade(Data.parchment, 1.0 - pt))
