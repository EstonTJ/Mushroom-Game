extends Node2D
## Fortify and night. One hut, two paths, three trap spots per path.
## Fortify: pick a bottle, tap a spot to place it (tap again to take it back),
## or tap the hut with a Moon Ward. Night: creatures walk the paths; a placed
## bottle bursts when one gets close. Saved bottles can still be placed on a free
## spot (including one whose trap already burst) or thrown anywhere else.
##
## Drawing is split into stacked layers (see _ready) so lights can be added on
## top with additive blending: ground -> light pools -> objects -> glows ->
## tree canopy -> UI. The ground and canopy only redraw while dusk turns to night.

signal night_over(won: bool, repelled: int)

const Art = preload("res://scripts/art.gd")

const HUT := Vector2(360, 1000)
const HUT_SIZE := 185.0
const POND := Vector2(360, 250)
const BAR_Y := 1130.0
const CELL_W := 120.0
const BAR_MAX := 6
const NIGHT_FADE := 1.5
const LANTERN_SIZE := 60.0
const LEFT_PATH := [Vector2(40, 120), Vector2(180, 330), Vector2(110, 560), Vector2(250, 780), Vector2(330, 950)]
const RIGHT_PATH := [Vector2(680, 120), Vector2(540, 320), Vector2(630, 560), Vector2(470, 780), Vector2(390, 950)]


## One drawing layer. It calls back into this script so all drawing stays here.
class Layer extends Node2D:
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


var curves: Array[Curve2D] = []
var slots := []
var mode := "fortify"
var selected := ""
var ward := 0
var hut_hp := Data.HUT_HP
var hit_flash := 0.0
var cfg: Dictionary = {}
var enemies := []
var areas := []
var popups := []
var particles := []
var fireflies := []
var spawned := 0
var queue := []
var intro := {}
var bar_page := 0
var roar_t := 1.0
var shake := 0.0
var spawn_timer := 0.0
var smoke_timer := 0.0
var repelled := 0
var over := false
var t := 0.0
var night_amt := 0.0

# Scenery, generated once from a fixed seed so the map is the same every night.
var moss := []
var grass := []
var stones := []
var pebbles := []
var fences := []
var lanterns := []
var clusters := []
var trees := []
var reeds := []

var ground_layer: Layer
var light_under: Layer
var objects: Layer
var light_over: Layer
var canopy_layer: Layer
var ui_layer: Layer
var status_box: StyleBoxFlat
var cell_box: StyleBoxFlat
var cell_selected_box: StyleBoxFlat


func _ready() -> void:
	cfg = Data.night_config(Data.day)
	for kind in Data.creature_order:
		for i in cfg["waves"].get(kind, 0):
			queue.append(kind)
	queue.shuffle()
	cfg["count"] = queue.size()
	curves.append(_make_curve(LEFT_PATH))
	curves.append(_make_curve(RIGHT_PATH))
	for path_i in 2:
		var c := curves[path_i]
		var length := c.get_baked_length()
		for f in [0.3, 0.55, 0.8]:
			slots.append({"pos": c.sample_baked(length * f), "trap": "", "triggered": false})
	_build_scenery()

	status_box = _box(Color(0.06, 0.05, 0.12, 0.7), Art.fade(Data.magic, 0.35), 14)
	cell_box = _box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.08), 16)
	cell_selected_box = _box(Art.fade(Data.magic, 0.22), Data.magic, 16)

	ground_layer = _add_layer(_paint_ground, false)
	light_under = _add_layer(_paint_light_under, true)
	objects = _add_layer(_paint_objects, false)
	light_over = _add_layer(_paint_light_over, true)
	canopy_layer = _add_layer(_paint_canopy, false)
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


func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(2)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b


func _make_curve(points: Array) -> Curve2D:
	var c := Curve2D.new()
	var n := points.size()
	for i in n:
		var prev: Vector2 = points[maxi(i - 1, 0)]
		var next: Vector2 = points[mini(i + 1, n - 1)]
		var handle := (next - prev) * 0.2
		c.add_point(points[i], -handle, handle)
	return c


# ---------------------------------------------------------------- scenery ---

func _near_path(p: Vector2, dist: float) -> bool:
	for c in curves:
		if c.get_closest_point(p).distance_to(p) < dist:
			return true
	return false


func _in_pond(p: Vector2, pad: float) -> bool:
	return ((p - POND) / Vector2(128.0 + pad, 68.0 + pad)).length() < 1.0


func _beside(c: Curve2D, f: float, side: float, dist: float) -> Vector2:
	var d := c.get_baked_length() * f
	var tangent := (c.sample_baked(d + 3.0) - c.sample_baked(d - 3.0)).normalized()
	return c.sample_baked(d) + tangent.orthogonal() * side * dist


func _fence(c: Curve2D, from: float, to: float, side: float) -> Array:
	var posts := []
	var length := c.get_baked_length()
	var d := length * from
	while d <= length * to:
		posts.append(_beside(c, d / length, side, 52.0))
		d += 34.0
	return posts


func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	for i in 26:
		moss.append({"pos": Vector2(rng.randf_range(0, 720), rng.randf_range(140, 1130)),
			"rx": rng.randf_range(50, 120), "ry": rng.randf_range(25, 60), "a": rng.randf_range(0.35, 0.8)})

	while grass.size() < 170:
		var p := Vector2(rng.randf_range(10, 710), rng.randf_range(150, 1125))
		if _near_path(p, 46.0) or _in_pond(p, 6.0):
			continue
		grass.append({"pos": p, "s": rng.randf_range(0.7, 1.4), "lean": rng.randf_range(-3, 3)})

	while stones.size() < 20:
		var p := Vector2(rng.randf_range(20, 700), rng.randf_range(160, 1110))
		if _near_path(p, 50.0) or _in_pond(p, 10.0) or p.distance_to(HUT) < 150.0:
			continue
		stones.append({"pos": p, "r": rng.randf_range(6, 15)})

	for c in curves:
		var length := c.get_baked_length()
		var d := 12.0
		while d < length - 12.0:
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			pebbles.append({"pos": _beside(c, d / length, side, rng.randf_range(24, 36)), "r": rng.randf_range(3, 6)})
			d += rng.randf_range(16, 34)

	fences.append(_fence(curves[0], 0.12, 0.34, 1.0))
	fences.append(_fence(curves[1], 0.40, 0.62, 1.0))
	fences.append(_fence(curves[0], 0.62, 0.72, -1.0))
	lanterns.append(_beside(curves[0], 0.44, -1.0, 62.0))
	lanterns.append(_beside(curves[1], 0.24, 1.0, 62.0))
	lanterns.append(_beside(curves[1], 0.70, -1.0, 62.0))

	var cols := [Color("b58fd6"), Color("d9623b"), Color("9ff0f0"), Color("e0a441"), Color("e98bb0")]
	while clusters.size() < 16:
		var p := Vector2(rng.randf_range(70, 650), rng.randf_range(190, 1080))
		if _near_path(p, 75.0) or _in_pond(p, 40.0) or p.distance_to(HUT) < 200.0:
			continue
		var crowded := false
		for l in lanterns:
			if l.distance_to(p) < 70.0:
				crowded = true
		for cl in clusters:
			if cl["pos"].distance_to(p) < 90.0:
				crowded = true
		if crowded:
			continue
		var color: Color = cols[rng.randi() % cols.size()]
		var shrooms := []
		for k in rng.randi_range(1, 3):
			var off := Vector2.ZERO if k == 0 else Vector2(rng.randf_range(-26, 26), rng.randf_range(-10, 14))
			shrooms.append({"off": off, "s": rng.randf_range(30, 60) * (1.0 if k == 0 else 0.6)})
		shrooms.sort_custom(func(a, b): return a["off"].y < b["off"].y)
		clusters.append({"pos": p, "color": color, "glow": color == Color("9ff0f0"), "shrooms": shrooms})
	clusters.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)

	var y := 190.0
	while y < 1080.0:
		trees.append(_tree(Vector2(rng.randf_range(-40, 0), y), rng))
		trees.append(_tree(Vector2(rng.randf_range(720, 760), y + 55.0), rng))
		y += rng.randf_range(110, 150)
	# Canopy over the path mouths, so creatures come out of the forest.
	trees.append(_tree(Vector2(-5, 110), rng))
	trees.append(_tree(Vector2(725, 110), rng))

	for i in 14:
		var ang := rng.randf_range(-0.3, PI + 0.3)
		reeds.append({"pos": POND + Vector2(cos(ang) * 122, sin(ang) * 60), "h": rng.randf_range(18, 32),
			"lean": rng.randf_range(-5, 5)})

	for i in 18:
		fireflies.append({"pos": Vector2(randf_range(40, 680), randf_range(170, 1100)),
			"vel": Vector2.from_angle(randf() * TAU) * 12.0, "phase": randf() * TAU})


func _tree(center: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var blobs := []
	for k in rng.randi_range(4, 5):
		blobs.append({"off": Vector2(rng.randf_range(-35, 35), rng.randf_range(-35, 35)), "r": rng.randf_range(38, 62)})
	return {"pos": center, "blobs": blobs}


# ------------------------------------------------------------------ logic ---

func start_night() -> void:
	mode = "night"
	spawn_timer = NIGHT_FADE


func _process(delta: float) -> void:
	t += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	roar_t = minf(1.0, roar_t + delta * 1.1)
	shake = maxf(0.0, shake - delta)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 14.0 if shake > 0.0 else Vector2.ZERO
	var was := night_amt
	if mode == "night":
		night_amt = minf(1.0, night_amt + delta / NIGHT_FADE)
	for p in popups:
		p["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.0)
	_update_particles(delta)
	if not intro.is_empty():
		intro["t"] += delta
		if intro["t"] > 4.0:
			intro = {}
	if mode == "night" and not over:
		_night_step(delta)
	if night_amt != was:
		ground_layer.queue_redraw()
		canopy_layer.queue_redraw()
	light_under.queue_redraw()
	objects.queue_redraw()
	light_over.queue_redraw()
	ui_layer.queue_redraw()


func _night_step(delta: float) -> void:
	if spawned < cfg["count"]:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			var kind: String = queue[spawned]
			# Scuttlers come in pairs: the next creature follows close behind.
			spawn_timer = cfg["interval"] * (0.45 if kind == "scuttler" else 1.0)
			enemies.append(_make_enemy(kind, randi() % 2))
			spawned += 1
			if not Data.seen_creatures.has(kind):
				Data.seen_creatures[kind] = true
				intro = {"kind": kind, "t": 0.0}

	for s in slots:
		if s["trap"] != "" and not s["triggered"]:
			for e in enemies:
				if e["flee"] < 0.0 and not _info(e)["flying"] and e["pos"].distance_to(s["pos"]) < 45.0:
					s["triggered"] = true
					_spawn_area(s["trap"], s["pos"])
					break

	for a in areas:
		a["time"] -= delta
	areas = areas.filter(func(a): return a["time"] > 0.0)

	for e in enemies:
		if e["flee"] >= 0.0:
			e["flee"] += delta
			e["pos"] += e["dir"] * 140.0 * delta
			continue
		var info := _info(e)
		var slow := 1.0
		var dps := 0.0
		var drowsy := false
		var sticky := false
		var frozen := false
		var confused := false
		e["hurt"] = maxf(0.0, e["hurt"] - delta)
		for a in areas:
			if e["pos"].distance_to(a["pos"]) < a["radius"]:
				var d: Dictionary = Data.potions[a["id"]]
				if d["family"] == "ember":
					continue
				if info["flying"] and not d.get("flying", true):
					continue
				var s_mult: float = d.get("slow", 1.0)
				if info["heavy"] and not d.get("heavy", true):
					s_mult = maxf(s_mult, 0.5)
				match d["family"]:
					"syrup":
						sticky = true
					"spore":
						drowsy = true
					"frost":
						frozen = true
					"befuddle":
						confused = true
				slow = minf(slow, s_mult)
				dps += d.get("dps", 0.0)
		e["drowsy"] = drowsy
		e["frozen"] = frozen
		e["confused"] = confused and slow < 0.0
		e["stuck"] = sticky and not frozen and slow >= 0.0 and slow < 0.6
		e["courage"] -= dps * delta
		if e["courage"] <= 0.0:
			_scare(e)
			repelled += 1
			_popup("Shoo!", e["pos"], Data.magic)
			continue
		var c: Curve2D = curves[e["path"]]
		e["offset"] = maxf(0.0, e["offset"] + e["speed"] * slow * delta)
		if e["offset"] >= c.get_baked_length():
			var blocked := 0
			var hits := 0
			for i in info["damage"]:
				if ward > 0:
					ward -= 1
					blocked += 1
				else:
					hut_hp -= 1
					hits += 1
			if hits == 0:
				repelled += 1
				_popup("Warded!", HUT + Vector2(0, -170), Data.magic)
				_burst(e["pos"], Data.magic, 16, 180.0)
			else:
				hit_flash = 0.4
				shake = maxf(shake, 0.2)
				_popup("-%d" % hits, HUT + Vector2(0, -170), Color("ff7a6b"))
				_burst(e["pos"], Color("ff7a6b"), 12, 140.0)
				for i in 6 * hits:
					var from := HUT + Vector2(randf_range(-70, 70), randf_range(-140, 0))
					_emit(from, Vector2(randf_range(-160, 160), randf_range(-260, -120)), 1.1, randf_range(5, 9),
						Color("6b4f3a") if randf() < 0.6 else Color("3e2f2a"), "debris")
			_scare(e)
		else:
			e["pos"] = c.sample_baked(e["offset"])
	enemies = enemies.filter(func(e): return e["flee"] < 1.0)

	if hut_hp <= 0:
		_end(false)
	elif spawned >= cfg["count"] and enemies.is_empty():
		_end(true)


func _make_enemy(kind: String, path: int) -> Dictionary:
	var info: Dictionary = Data.creatures[kind]
	var courage: float = cfg["courage"] * info["courage"]
	return {"kind": kind, "path": path, "offset": 0.0, "pos": curves[path].sample_baked(0.0),
		"courage": courage, "max": courage, "speed": cfg["speed"] * info["speed"] * randf_range(0.9, 1.15),
		"flee": -1.0, "dir": Vector2.UP, "seed": randf() * 10.0, "hurt": 0.0, "drowsy": false, "stuck": false,
		"frozen": false, "confused": false}


func _info(e: Dictionary) -> Dictionary:
	return Data.creatures[e["kind"]]


func _scare(e: Dictionary) -> void:
	e["flee"] = 0.0
	var away: Vector2 = e["pos"] - HUT
	e["dir"] = away.normalized() if away.length() > 1.0 else Vector2.UP
	for i in 8:
		_emit(e["pos"] + Vector2(randf_range(-14, 14), randf_range(-14, 10)),
			Vector2(randf_range(-40, 40), randf_range(-60, -10)), 0.8, 9.0, Color(0.6, 0.55, 0.75, 0.55), "puff")


func _spawn_area(id: String, pos: Vector2) -> void:
	var d: Dictionary = Data.potions[id]
	var duration: float = d.get("duration", 0.5)
	areas.append({"id": id, "pos": pos, "radius": d.get("radius", 0.0), "time": duration, "max": duration,
		"sd": randf() * TAU})
	match d["family"]:
		"ember":
			_burst(pos, d["color"].lightened(0.2), 24 + int(d["radius"] / 8.0), 3.0 * d["radius"])
		"frost":
			_burst(pos, Color(0.85, 0.95, 1.0), 22, 2.0 * d["radius"])
		_:
			_burst(pos, d["color"], 14, 160.0)
	var burst: float = d.get("burst", 0.0)
	if burst > 0.0:
		for e in enemies:
			if e["flee"] < 0.0 and e["pos"].distance_to(pos) < d["radius"]:
				e["courage"] -= burst
				e["hurt"] = 0.35


func _end(won: bool) -> void:
	over = true
	if won:
		# Bottles that never went off go back in the bag.
		for s in slots:
			if s["trap"] != "" and not s["triggered"]:
				Data.bottles[s["trap"]] += 1
				s["trap"] = ""
	night_over.emit(won, repelled)


func _popup(text: String, pos: Vector2, color: Color) -> void:
	popups.append({"text": text, "pos": pos, "t": 0.0, "color": color})


func _use_selected() -> void:
	Data.bottles[selected] -= 1
	if Data.bottles[selected] <= 0:
		selected = ""


func _unhandled_input(event: InputEvent) -> void:
	if over:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if p.y >= BAR_Y:
		_bar_tap(p)
		return
	if mode == "fortify":
		_fortify_tap(p)
	else:
		_night_tap(p)


func _fortify_tap(p: Vector2) -> void:
	for s in slots:
		if s["pos"].distance_to(p) < 50.0:
			if s["trap"] != "":
				Data.bottles[s["trap"]] += 1
				s["trap"] = ""
			elif selected != "" and _placeable(selected):
				s["trap"] = selected
				_burst(s["pos"], Data.potions[selected]["color"], 8, 90.0)
				_use_selected()
			return
	if selected == "":
		return
	var fam: String = Data.potions[selected]["family"]
	if (fam == "ward" or fam == "mend") and p.distance_to(HUT + Vector2(0, -80)) < 150.0:
		_use_hut_potion()
	elif fam == "roar":
		_popup("Save it for the night!", p, Data.parchment)


func _night_tap(p: Vector2) -> void:
	if selected == "":
		return
	var fam: String = Data.potions[selected]["family"]
	if fam == "ward" or fam == "mend":
		_use_hut_potion()
		return
	if fam == "roar":
		_roar()
		_use_selected()
		return
	# A free spot (empty, or its trap already burst) takes the bottle as a new trap.
	# A spot still holding an unburst trap ignores the tap, so it can't be thrown by accident.
	for s in slots:
		if s["pos"].distance_to(p) < 50.0:
			if _slot_free(s):
				s["trap"] = selected
				s["triggered"] = false
				_burst(s["pos"], Data.potions[selected]["color"], 8, 90.0)
				_use_selected()
			return
	_spawn_area(selected, p)
	_use_selected()


## Potions that can sit on a trap spot or be thrown onto the map.
func _placeable(id: String) -> bool:
	return Data.potions[id]["family"] in ["spore", "syrup", "ember", "frost", "befuddle"]


## Ward and mend potions work on the hut, wherever you tap at night.
func _use_hut_potion() -> void:
	var d: Dictionary = Data.potions[selected]
	if d["family"] == "ward":
		ward += d["ward"]
		_popup("Ward +%d" % d["ward"], HUT + Vector2(0, -170), Data.magic)
		for p in _ward_points():
			_burst(p, Data.magic, 5, 80.0)
	else:
		if hut_hp >= Data.HUT_HP:
			_popup("The hut is already whole", HUT + Vector2(0, -170), Data.parchment)
			return
		var before := hut_hp
		hut_hp = mini(Data.HUT_HP, hut_hp + int(d["heal"]))
		_popup("Hut +%d" % (hut_hp - before), HUT + Vector2(0, -170), Color("9ad8ff"))
		for i in 3:
			_burst(HUT + Vector2(randf_range(-70, 70), randf_range(-120, 0)), d["color"].lightened(0.3), 8, 90.0)
	_use_selected()


## Lion's Roar: a shockwave from the hut that scares every creature on the map.
func _roar() -> void:
	var burst: float = Data.potions[selected]["burst"]
	roar_t = 0.0
	shake = 0.5
	for e in enemies:
		if e["flee"] < 0.0:
			e["courage"] -= burst
			e["hurt"] = 0.4
	_popup("ROAR!", HUT + Vector2(0, -190), Color("f0c060"))


func _bar_items() -> Array:
	return Data.potion_order.filter(func(id): return Data.bottles[id] > 0)


## Which bottles show in the bar: up to BAR_MAX, or BAR_MAX - 1 plus page arrows.
func _bar_layout() -> Dictionary:
	var items := _bar_items()
	var paged := items.size() > BAR_MAX
	var per := BAR_MAX - 1 if paged else BAR_MAX
	var pages := maxi(1, ceili(float(items.size()) / per))
	bar_page = clampi(bar_page, 0, pages - 1)
	var shown := items.slice(bar_page * per, bar_page * per + per)
	var x0 := 60.0 if paged else (720.0 - shown.size() * CELL_W) / 2.0
	return {"shown": shown, "x0": x0, "paged": paged, "pages": pages}


func _bar_tap(p: Vector2) -> void:
	var lay := _bar_layout()
	if lay["paged"] and p.x < 60.0:
		bar_page = posmod(bar_page - 1, lay["pages"])
		return
	if lay["paged"] and p.x > 660.0:
		bar_page = posmod(bar_page + 1, lay["pages"])
		return
	var shown: Array = lay["shown"]
	var i := int((p.x - lay["x0"]) / CELL_W)
	if p.x >= lay["x0"] and i >= 0 and i < shown.size():
		var id: String = shown[i]
		selected = "" if selected == id else id


## How many hits the hut has taken: drives its damage stage.
func _broken() -> int:
	return clampi(Data.HUT_HP - hut_hp, 0, Data.HUT_HP - 1)


func _slot_free(s: Dictionary) -> bool:
	return s["trap"] == "" or s["triggered"]


# -------------------------------------------------------------- particles ---

func _emit(pos: Vector2, vel: Vector2, life: float, size: float, color: Color, kind: String) -> void:
	if particles.size() < 500:
		particles.append({"pos": pos, "vel": vel, "life": life, "max": life, "size": size, "color": color, "kind": kind})


func _burst(pos: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		_emit(pos, Vector2.from_angle(randf() * TAU) * randf_range(speed * 0.3, speed), randf_range(0.4, 0.8),
			randf_range(2.0, 4.0), color, "spark")


func _update_particles(delta: float) -> void:
	smoke_timer -= delta
	if smoke_timer <= 0.0:
		smoke_timer = 0.3
		_emit(Art.hut_chimney(HUT, HUT_SIZE), Vector2(randf_range(4, 12), randf_range(-28, -20)), 3.2, 7.0,
			Color(0.75, 0.72, 0.82, 0.3), "smoke")
		if _broken() >= 3:
			_emit(Art.hut_roof_hole(HUT, HUT_SIZE) + Vector2(randf_range(-10, 10), 0), Vector2(randf_range(-6, 6), randf_range(-34, -24)),
				2.6, 9.0, Color(0.2, 0.18, 0.2, 0.45), "smoke")
	for a in areas:
		if Data.potions[a["id"]]["family"] == "spore" and randf() < 0.5:
			var off := Vector2.from_angle(randf() * TAU) * randf() * float(a["radius"])
			_emit(a["pos"] + off, Vector2(randf_range(-8, 8), randf_range(-22, -8)), 1.4, 2.5, Color("d9b8ff"), "mote")

	for p in particles:
		p["life"] -= delta
		var v: Vector2 = p["vel"]
		match p["kind"]:
			"spark":
				v *= 0.92
			"puff":
				v *= 0.9
			"smoke":
				v.x += 3.0 * delta
			"debris":
				v.y += 600.0 * delta
		p["vel"] = v
		p["pos"] += v * delta
	particles = particles.filter(func(p): return p["life"] > 0.0)

	for f in fireflies:
		var v: Vector2 = f["vel"] + Vector2(randf_range(-40, 40), randf_range(-40, 40)) * delta
		v = v.limit_length(22.0)
		f["vel"] = v
		var fp: Vector2 = f["pos"] + v * delta
		f["pos"] = Vector2(wrapf(fp.x, 0.0, 720.0), wrapf(fp.y, 160.0, 1120.0))


# ---------------------------------------------------------------- drawing ---

## Blend a dusk colour toward its night version as night falls.
func _c(dusk: Color, night: Color) -> Color:
	return dusk.lerp(night, night_amt)


func _area_strength(a: Dictionary) -> float:
	var life: float = a["time"] / a["max"]
	return minf(1.0, life * 3.0) * minf(1.0, (1.0 - life) * 8.0 + 0.2)


func _hop(e: Dictionary) -> float:
	if e["flee"] >= 0.0 or e["stuck"]:
		return 0.0
	match e["kind"]:
		"mischief":
			return absf(sin(t * 7.0 + e["seed"])) * 5.0
		"stumpling":
			return absf(sin(t * 3.5 + e["seed"])) * 2.0
	return 0.0


## Where to draw a creature this frame: its path position, plus hop and a
## struggling shake while stuck in syrup.
func _draw_pos(e: Dictionary) -> Vector2:
	var pos: Vector2 = e["pos"] + Vector2(0, -_hop(e))
	if e["stuck"] and e["flee"] < 0.0:
		pos.x += sin(t * 40.0 + e["seed"]) * 2.5
	return pos


func _ward_points() -> Array:
	var pts := []
	var center := HUT + Vector2(0, -50)
	for k in 6:
		var ang := -PI / 2.0 + 0.52 + k * TAU / 6.0
		pts.append(center + Vector2(cos(ang) * 178.0, sin(ang) * 140.0))
	return pts


func _paint_ground(ci: CanvasItem) -> void:
	var top := _c(Color("4b4868"), Color("1b1a34"))
	var bottom := _c(Color("3f4d4b"), Color("131c25"))
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, 1280), Vector2(0, 1280)]),
		PackedColorArray([top, top, bottom, bottom]))

	var moss_col := _c(Color("5b7a5c"), Color("22382f"))
	for m in moss:
		ci.draw_colored_polygon(Art.ellipse(m["pos"], m["rx"], m["ry"], 20), Art.fade(moss_col, m["a"]))

	_paint_pond(ci)

	var stone_col := _c(Color("7a7688"), Color("3b3a4d"))
	for s in stones:
		var r: float = s["r"]
		Art.shadow(ci, s["pos"] + Vector2(2, r * 0.5), r * 1.1, r * 0.4)
		ci.draw_colored_polygon(Art.ellipse(s["pos"], r * 1.1, r * 0.8, 12), stone_col)
		ci.draw_colored_polygon(Art.ellipse(s["pos"] + Vector2(-r * 0.3, -r * 0.3), r * 0.5, r * 0.3, 10), stone_col.lightened(0.2))

	var edge := _c(Color("54463a"), Color("2c2530"))
	var dirt := _c(Color("8a7458"), Color("584842"))
	var worn := _c(Color("a08a6a"), Color("6a5850"))
	for c in curves:
		var pts := c.get_baked_points()
		for k in range(0, pts.size(), 2):
			ci.draw_circle(pts[k], 42, edge)
		for k in range(0, pts.size(), 2):
			ci.draw_circle(pts[k], 35, dirt)
		for k in range(0, pts.size(), 2):
			ci.draw_circle(pts[k], 16, worn)
	for pb in pebbles:
		var r: float = pb["r"]
		ci.draw_colored_polygon(Art.ellipse(pb["pos"], r * 1.2, r * 0.8, 10), stone_col.darkened(0.1))
		ci.draw_circle(pb["pos"] + Vector2(-r * 0.3, -r * 0.3), r * 0.3, stone_col.lightened(0.25))

	var blade := _c(Color("7d9a66"), Color("2e4a3a"))
	for g in grass:
		var p: Vector2 = g["pos"]
		var s: float = g["s"]
		var lean: float = g["lean"]
		ci.draw_line(p, p + Vector2(-5 + lean, -11) * s, blade, 2.0, true)
		ci.draw_line(p, p + Vector2(lean, -15) * s, blade, 2.0, true)
		ci.draw_line(p, p + Vector2(5 + lean, -10) * s, blade, 2.0, true)

	var wood := _c(Color("6d5140"), Color("3d2e2c"))
	for posts in fences:
		for i in posts.size() - 1:
			var a: Vector2 = posts[i]
			var b: Vector2 = posts[i + 1]
			ci.draw_line(a + Vector2(0, -16), b + Vector2(0, -16), wood, 4.0, true)
			ci.draw_line(a + Vector2(0, -7), b + Vector2(0, -7), wood, 4.0, true)
		for p in posts:
			Art.shadow(ci, p + Vector2(0, 2), 7, 3)
			ci.draw_rect(Rect2(p.x - 4, p.y - 24, 8, 26), wood.darkened(0.15))
			ci.draw_rect(Rect2(p.x - 4, p.y - 24, 8, 4), wood.lightened(0.15))


func _paint_pond(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(Art.ellipse(POND + Vector2(0, 4), 128, 68, 40), _c(Color("4a4b3e"), Color("1d2320")))
	var water := _c(Color("46607e"), Color("15263f"))
	ci.draw_colored_polygon(Art.ellipse(POND, 118, 58, 40), water)
	ci.draw_colored_polygon(Art.ellipse(POND + Vector2(0, 8), 100, 44, 40), water.darkened(0.2))

	var pad_col := _c(Color("5f8a58"), Color("2c4a38"))
	for lp in [[Vector2(-70, 14), 16.0], [Vector2(62, -20), 13.0], [Vector2(84, 18), 10.0]]:
		var c: Vector2 = POND + lp[0]
		var r: float = lp[1]
		var pad := PackedVector2Array([c])
		for i in 15:
			var ang := 0.45 + (TAU - 0.6) * i / 14.0
			pad.append(c + Vector2(cos(ang) * r, sin(ang) * r * 0.7))
		ci.draw_colored_polygon(pad, pad_col)
	var flower := POND + Vector2(-72, 10)
	for k in 5:
		ci.draw_circle(flower + Vector2.from_angle(k * TAU / 5.0) * 4.0, 3.5, _c(Color("f3b3cf"), Color("b07a98")))
	ci.draw_circle(flower, 2.5, Color("ffe08a"))

	var reed := _c(Color("5f7a4c"), Color("25382c"))
	for r in reeds:
		var base: Vector2 = r["pos"]
		var tip := base + Vector2(r["lean"], -r["h"])
		ci.draw_line(base, tip, reed, 2.0, true)
		ci.draw_colored_polygon(Art.ellipse(tip + Vector2(0, 6), 2.5, 6, 8), _c(Color("6d4a34"), Color("3a2a24")))


func _paint_light_under(ci: CanvasItem) -> void:
	var n := night_amt
	var flicker := 0.9 + 0.1 * sin(t * 13.0) * sin(t * 7.3)
	Art.glow(ci, HUT + Vector2(0, -20), 300, Art.fade(Data.lantern, (0.16 + 0.22 * n) * flicker))
	for l in lanterns:
		Art.glow(ci, Art.lantern_lamp(l, LANTERN_SIZE) + Vector2(0, 40), 150, Art.fade(Data.lantern, (0.1 + 0.22 * n) * flicker))
	Art.glow(ci, POND + Vector2(22, -6), 110, Color(0.8, 0.85, 1.0, 0.05 + 0.12 * n))
	for cl in clusters:
		if cl["glow"]:
			var pulse := 0.8 + 0.2 * sin(t * 2.0 + float(cl["pos"].x))
			Art.glow(ci, cl["pos"] + Vector2(0, -15), 90, Art.fade(Data.magic, (0.05 + 0.22 * n) * pulse))
	for s in slots:
		if _slot_free(s):
			Art.glow(ci, s["pos"], 60, Art.fade(Data.magic, 0.08 + 0.04 * sin(t * 3.0)))
		else:
			Art.glow(ci, s["pos"], 55, Art.fade(Data.potions[s["trap"]]["color"], 0.22))
	for a in areas:
		Art.glow(ci, a["pos"], a["radius"] * 1.4, Art.fade(Data.potions[a["id"]]["color"], 0.35 * _area_strength(a)))
	if ward > 0:
		Art.glow(ci, HUT + Vector2(0, -50), 230, Art.fade(Data.magic, 0.1 + 0.05 * sin(t * 4.0)))
	if hit_flash > 0.0:
		Art.glow(ci, HUT + Vector2(0, -60), 230, Color(1, 0.25, 0.2, hit_flash))


func _paint_objects(ci: CanvasItem) -> void:
	var n := night_amt
	var font := ThemeDB.fallback_font

	# Moon reflection with slow ripples.
	var moon := POND + Vector2(22 + sin(t * 1.5) * 3.0, -6)
	ci.draw_colored_polygon(Art.ellipse(moon, 26, 12, 24), Color(1, 0.97, 0.85, 0.3 + 0.45 * n))
	for k in 2:
		var rr := fmod(t * 12.0 + k * 20.0, 40.0)
		Art.outline(ci, Art.ellipse(moon, 26 + rr, 12 + rr * 0.45, 32), Color(1, 0.97, 0.85, (1.0 - rr / 40.0) * 0.25), 1.5)

	for cl in clusters:
		for m in cl["shrooms"]:
			Art.mushroom(ci, cl["pos"] + m["off"], m["s"], cl["color"])
	for l in lanterns:
		Art.lantern(ci, l, LANTERN_SIZE)

	for i in slots.size():
		var s: Dictionary = slots[i]
		if _slot_free(s):
			_paint_rune(ci, s["pos"])
		else:
			Art.shadow(ci, s["pos"] + Vector2(0, 14), 16, 5)
			Art.bottle(ci, s["pos"] + Vector2(0, -10 + sin(t * 2.2 + i) * 3.0), 52, Data.potions[s["trap"]]["color"])

	for a in areas:
		if Data.potions[a["id"]]["family"] == "syrup":
			_paint_syrup(ci, a)
		elif Data.potions[a["id"]]["family"] == "frost":
			_paint_frost(ci, a)

	if ward > 0:
		var ring := Art.ellipse(HUT + Vector2(0, -50), 178, 140, 64)
		ci.draw_colored_polygon(ring, Art.fade(Data.magic, 0.06))
		Art.outline(ci, ring, Art.fade(Data.magic, 0.5 + 0.25 * sin(t * 4.0)), 3.0)
	Art.hut(ci, HUT, HUT_SIZE, t, _broken())
	if ward > 0:
		var pts := _ward_points()
		for k in pts.size():
			Art.crystal(ci, pts[k] + Vector2(0, sin(t * 2.0 + k) * 3.0), 34, Data.magic, 1.0 if k < ward else 0.3)

	var order := enemies.duplicate()
	order.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	for e in order:
		var fade := 1.0 - maxf(0.0, e["flee"])
		var blink: bool = fmod(t + e["seed"], 3.2) < 0.12 or e["drowsy"]
		var pos := _draw_pos(e)
		var size: float = _info(e)["size"]
		var walk: float = (t * 0.35 if e["stuck"] else t) + e["seed"]
		Art.creature(ci, e["kind"], pos, size, fade, walk, blink)
		var top := pos.y - size * (1.35 if e["kind"] == "moth" else 1.05)
		if e["flee"] < 0.0 and e["courage"] < e["max"]:
			var w: float = 40.0 * e["courage"] / e["max"]
			ci.draw_rect(Rect2(pos.x - 20, top, 40, 6), Color(0, 0, 0, 0.55))
			ci.draw_rect(Rect2(pos.x - 20, top, w, 6), Data.magic)
		if e["frozen"] and e["flee"] < 0.0:
			var ice := Rect2(pos.x - size * 0.6, pos.y - size * 0.95, size * 1.2, size * 1.45)
			ci.draw_rect(ice, Color(0.75, 0.9, 1.0, 0.35))
			ci.draw_rect(ice, Color(0.9, 0.97, 1.0, 0.8), false, 2.0)
			ci.draw_line(ice.position + Vector2(6, 8), ice.position + Vector2(18, 26), Color(1, 1, 1, 0.8), 2.0, true)
		if e["confused"] and e["flee"] < 0.0:
			for k in 2:
				var ang := t * 3.0 + k * PI
				ci.draw_string(font, Vector2(pos.x - 6 + cos(ang) * 16, top - 4 + sin(ang) * 5), "?", HORIZONTAL_ALIGNMENT_LEFT,
					-1, 20, Color("e0b0ff"))
		if e["drowsy"] and e["flee"] < 0.0:
			for k in 3:
				var ph := fmod(t * 0.8 + k / 3.0, 1.0)
				var zp := Vector2(pos.x + 14 + ph * 16, top - 6 - ph * 30)
				ci.draw_string(font, zp, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 14 + int(ph * 8), Color(0.9, 0.85, 1.0, 1.0 - ph))

	for a in areas:
		match Data.potions[a["id"]]["family"]:
			"spore":
				_paint_spore(ci, a)
			"ember":
				_paint_ember(ci, a)
			"befuddle":
				_paint_befuddle(ci, a)

	if roar_t < 1.0:
		var rr := roar_t * 950.0
		ci.draw_arc(HUT + Vector2(0, -60), rr, 0, TAU, 96, Color(0.95, 0.75, 0.35, 1.0 - roar_t), 16.0 * (1.0 - roar_t) + 2.0, true)
		ci.draw_arc(HUT + Vector2(0, -60), rr * 0.8, 0, TAU, 96, Color(1.0, 0.9, 0.6, 0.6 * (1.0 - roar_t)), 6.0, true)

	for p in particles:
		if p["kind"] == "smoke" or p["kind"] == "puff":
			var f: float = p["life"] / p["max"]
			var size: float = p["size"] * (1.0 + (1.0 - f) * 2.0)
			Art.glow(ci, p["pos"], size * 2.0, Art.fade(p["color"], f))
		elif p["kind"] == "debris":
			var f: float = p["life"] / p["max"]
			var ang: float = p["life"] * 9.0
			var hs: float = p["size"]
			var c: Vector2 = p["pos"]
			var quad := PackedVector2Array()
			for corner in [Vector2(-hs, -hs * 0.35), Vector2(hs, -hs * 0.35), Vector2(hs, hs * 0.35), Vector2(-hs, hs * 0.35)]:
				quad.append(c + corner.rotated(ang))
			ci.draw_colored_polygon(quad, Art.fade(p["color"], minf(1.0, f * 2.0)))

	for p in popups:
		var pt: float = p["t"]
		var at: Vector2 = p["pos"] + Vector2(-100, -pt * 50)
		ci.draw_string_outline(font, at, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 200, 30, 6, Color(0, 0, 0, 0.6 * (1.0 - pt)))
		ci.draw_string(font, at, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 200, 30, Art.fade(p["color"], 1.0 - pt))


func _paint_rune(ci: CanvasItem, pos: Vector2) -> void:
	var col := Art.fade(Data.magic, (0.55 if mode == "fortify" else 0.35) + 0.2 * sin(t * 3.0))
	ci.draw_circle(pos, 32, Color(0.05, 0.1, 0.15, 0.3))
	ci.draw_arc(pos, 32, 0, TAU, 40, col, 2.0, true)
	for k in 6:
		var ang := t * 0.8 + k * TAU / 6.0
		ci.draw_arc(pos, 25, ang, ang + 0.55, 6, col, 3.0, true)
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -8), pos + Vector2(6, 0), pos + Vector2(0, 8),
		pos + Vector2(-6, 0)]), col)


func _paint_syrup(ci: CanvasItem, a: Dictionary) -> void:
	var s := _area_strength(a)
	var col: Color = Data.potions[a["id"]]["color"]
	var r: float = a["radius"]
	var sd: float = a["sd"]
	var center: Vector2 = a["pos"]
	var pts := PackedVector2Array()
	for k in 24:
		var ang := TAU * k / 24.0
		var rr := r * (0.82 + 0.12 * sin(ang * 3.0 + sd) + 0.06 * sin(ang * 5.0 + sd * 2.0))
		pts.append(center + Vector2(cos(ang), sin(ang) * 0.8) * rr)
	ci.draw_colored_polygon(pts, Art.fade(col.darkened(0.15), 0.85 * s))
	# Dark puddles (Ink Pool) get a light sheen at the edge so they show at night.
	var edge := col.lightened(0.45) if col.v < 0.45 else col.darkened(0.45)
	Art.outline(ci, pts, Art.fade(edge, 0.8 * s), 2.5)
	ci.draw_colored_polygon(Art.ellipse(center + Vector2(-r * 0.25, -r * 0.2), r * 0.3, r * 0.12, 16), Art.fade(col.lightened(0.45), 0.6 * s))
	for k in 4:
		var ph := fmod(t * 0.9 + k * 0.37 + sd, 1.0)
		var bp := center + Vector2(cos(sd + k * 1.9), sin(sd + k * 1.9) * 0.7) * r * 0.5
		ci.draw_arc(bp, 3.0 + ph * 6.0, 0, TAU, 12, Art.fade(col.lightened(0.5), (1.0 - ph) * s), 1.5, true)


func _paint_spore(ci: CanvasItem, a: Dictionary) -> void:
	var s := _area_strength(a)
	var col: Color = Data.potions[a["id"]]["color"]
	var r: float = a["radius"]
	var sd: float = a["sd"]
	var center: Vector2 = a["pos"]
	Art.glow(ci, center, r * 1.1, Art.fade(col, 0.35 * s))
	for k in 7:
		var ang := sd + k * TAU / 7.0 + t * 0.35
		var dist := r * (0.45 + 0.1 * sin(t * 1.7 + k))
		Art.glow(ci, center + Vector2(cos(ang), sin(ang)) * dist, r * 0.55, Art.fade(col.lightened(0.15), 0.45 * s))
	for k in 10:
		var ang := sd * 2.0 + k * 2.4 + t * 0.6
		var dist := r * 0.7 * fmod(k * 0.37 + t * 0.15, 1.0)
		ci.draw_circle(center + Vector2(cos(ang), sin(ang)) * dist, 2.5, Art.fade(Color("f1e0ff"), 0.8 * s))


func _paint_ember(ci: CanvasItem, a: Dictionary) -> void:
	var life: float = a["time"] / a["max"]
	var prog := 1.0 - life
	var r: float = a["radius"]
	var center: Vector2 = a["pos"]
	var col: Color = Data.potions[a["id"]]["color"]
	Art.glow(ci, center, r * (0.6 + 0.6 * prog), Art.fade(col.lightened(0.1), 0.7 * life))
	ci.draw_arc(center, r * (0.3 + 0.8 * prog), 0, TAU, 48, Art.fade(col.lightened(0.45), life), 10.0 * life + 1.0, true)
	ci.draw_arc(center, r * (0.2 + 0.6 * prog), 0, TAU, 48, Art.fade(col, life * 0.8), 5.0 * life + 1.0, true)


## Frost: a pale icy patch with spiky crystal edges and turning snowflakes.
func _paint_frost(ci: CanvasItem, a: Dictionary) -> void:
	var s := _area_strength(a)
	var r: float = a["radius"]
	var sd: float = a["sd"]
	var center: Vector2 = a["pos"]
	var pts := PackedVector2Array()
	for k in 32:
		var ang := TAU * k / 32.0
		var rr := r * (0.92 if k % 2 == 0 else 0.78 + 0.08 * sin(sd + k))
		pts.append(center + Vector2(cos(ang), sin(ang) * 0.8) * rr)
	ci.draw_colored_polygon(pts, Color(0.78, 0.92, 1.0, 0.4 * s))
	Art.outline(ci, pts, Color(0.92, 0.98, 1.0, 0.85 * s), 2.0)
	for k in 7:
		var ang := sd + k * 0.9
		var fp := center + Vector2(cos(ang), sin(ang) * 0.8) * r * (0.25 + 0.5 * fmod(k * 0.37, 1.0))
		var rot := t * 0.8 + k
		for j in 3:
			var dir := Vector2.from_angle(rot + j * PI / 3.0) * 7.0
			ci.draw_line(fp - dir, fp + dir, Color(1, 1, 1, 0.9 * s), 1.5, true)


## Befuddle: slowly turning violet spirals with a question mark or two.
func _paint_befuddle(ci: CanvasItem, a: Dictionary) -> void:
	var s := _area_strength(a)
	var col: Color = Data.potions[a["id"]]["color"]
	var r: float = a["radius"]
	var center: Vector2 = a["pos"]
	Art.glow(ci, center, r, Art.fade(col, 0.3 * s))
	for k in 3:
		var spiral := PackedVector2Array()
		for j in 24:
			var u := j / 23.0
			var ang := t * (1.6 if k % 2 == 0 else -1.2) + k * TAU / 3.0 + u * 5.0
			spiral.append(center + Vector2(cos(ang), sin(ang) * 0.8) * r * (0.1 + 0.85 * u))
		ci.draw_polyline(spiral, Art.fade(col.lightened(0.3), 0.7 * s), 3.0, true)


func _paint_light_over(ci: CanvasItem) -> void:
	var n := night_amt
	var broken := _broken()
	var wins := Art.hut_windows(HUT, HUT_SIZE)
	for i in wins.size():
		if i == 1 and broken >= 4:
			continue
		var dim := 0.5 if i == 0 and broken >= 2 else 1.0
		Art.glow(ci, wins[i], 45, Art.fade(Data.lantern, (0.3 + 0.25 * n) * dim))
	if broken < 4:
		Art.glow(ci, Art.hut_lamp(HUT, HUT_SIZE), 26, Color(1.0, 0.8, 0.45, 0.4 + 0.35 * n))
		Art.glow(ci, Art.hut_dormer(HUT, HUT_SIZE), 30, Art.fade(Data.lantern, 0.25 + 0.25 * n))
	Art.glow(ci, Art.hut_cauldron(HUT, HUT_SIZE), 40, Color(0.5, 1.0, 0.5, 0.2 + 0.2 * n))
	for l in lanterns:
		Art.glow(ci, Art.lantern_lamp(l, LANTERN_SIZE), 34, Color(1.0, 0.8, 0.45, 0.4 + 0.35 * n))
	for i in slots.size():
		var s: Dictionary = slots[i]
		if not _slot_free(s):
			Art.glow(ci, s["pos"] + Vector2(0, -6 + sin(t * 2.2 + i) * 3.0), 28, Art.fade(Data.potions[s["trap"]]["color"], 0.35))
	for e in enemies:
		var fade := 1.0 - maxf(0.0, e["flee"])
		var pos := _draw_pos(e)
		var size: float = _info(e)["size"]
		var walk: float = (t * 0.35 if e["stuck"] else t) + e["seed"]
		if not e["drowsy"]:
			for eye in Art.creature_eyes(e["kind"], pos, size, walk):
				Art.glow(ci, eye, size * 0.26, Color(1, 0.85, 0.35, 0.45 * fade * n))
		if e["hurt"] > 0.0:
			Art.glow(ci, pos + Vector2(0, -size * 0.2), size * 0.9, Color(1, 1, 1, e["hurt"] * 1.4))
		if e["frozen"] and e["flee"] < 0.0:
			Art.glow(ci, pos + Vector2(0, -size * 0.2), size * 0.8, Color(0.5, 0.8, 1.0, 0.35))
	if ward > 0:
		var pts := _ward_points()
		for k in mini(ward, pts.size()):
			Art.glow(ci, pts[k], 28, Art.fade(Data.magic, 0.45))
	for f in fireflies:
		var blink := 0.5 + 0.5 * sin(t * 3.0 + f["phase"])
		Art.glow(ci, f["pos"], 16, Color(0.8, 1.0, 0.5, 0.5 * blink * (0.25 + 0.75 * n)))
		Art.glow(ci, f["pos"], 4, Color(1, 1, 0.8, blink * (0.4 + 0.6 * n)))
	for p in particles:
		if p["kind"] == "spark" or p["kind"] == "mote":
			var f: float = p["life"] / p["max"]
			Art.glow(ci, p["pos"], p["size"] * 3.0, Art.fade(p["color"], f))
	if roar_t < 1.0:
		Art.glow(ci, HUT + Vector2(0, -60), 300.0 + roar_t * 500.0, Color(1.0, 0.8, 0.4, 0.35 * (1.0 - roar_t)))


func _paint_canopy(ci: CanvasItem) -> void:
	var leaf := _c(Color("34463a"), Color("0f1719"))
	var lit := _c(Color("46604c"), Color("172528"))
	for tr in trees:
		for b in tr["blobs"]:
			ci.draw_circle(tr["pos"] + b["off"], b["r"], leaf)
		for b in tr["blobs"]:
			var r: float = b["r"]
			ci.draw_circle(tr["pos"] + b["off"] + Vector2(-r * 0.2, -r * 0.25), r * 0.65, lit)
	var edge := Color(0, 0, 0, 0.25 + 0.3 * night_amt)
	var clear := Color(0, 0, 0, 0)
	ci.draw_polygon(PackedVector2Array([Vector2(0, 110), Vector2(110, 110), Vector2(110, BAR_Y), Vector2(0, BAR_Y)]),
		PackedColorArray([edge, clear, clear, edge]))
	ci.draw_polygon(PackedVector2Array([Vector2(610, 110), Vector2(720, 110), Vector2(720, BAR_Y), Vector2(610, BAR_Y)]),
		PackedColorArray([clear, edge, edge, clear]))


func _paint_ui(ci: CanvasItem) -> void:
	var font := ThemeDB.fallback_font
	var rid := ci.get_canvas_item()
	var status := Rect2(14, 118, 692, 44)
	status_box.draw(rid, status)
	if mode == "fortify":
		# Tonight's roster: an icon and count per creature type; a sparkle marks new ones.
		ci.draw_string(font, Vector2(30, 148), "Night %d:" % Data.day, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Data.parchment)
		var x := 130.0
		for kind in Data.creature_order:
			var n: int = cfg["waves"].get(kind, 0)
			if n == 0:
				continue
			Art.creature(ci, kind, Vector2(x, 150.0 if kind != "moth" else 160.0), 26.0, 1.0, t, false)
			ci.draw_string(font, Vector2(x + 18, 148), "x%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Data.parchment)
			if not Data.seen_creatures.has(kind):
				Art.sparkle(ci, Vector2(x + 16, 126), 7.0 + sin(t * 6.0) * 2.0, Data.magic.lightened(0.3))
			x += 100.0
	else:
		for i in Data.HUT_HP:
			Art.heart(ci, Vector2(40 + i * 28, 140), 20, Color("ff7a6b") if i < hut_hp else Color(1, 1, 1, 0.15))
		ci.draw_string(font, Vector2(470, 148), "Repelled %d/%d" % [repelled, cfg["count"]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Data.parchment)
	var ward_x := 330.0 if mode == "night" else 620.0
	Art.crystal(ci, Vector2(ward_x, 142), 24, Data.magic, 1.0 if ward > 0 else 0.35)
	ci.draw_string(font, Vector2(ward_x + 16, 148), "x%d" % ward, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Data.parchment)

	if not intro.is_empty():
		_paint_intro(ci, rid, font)

	ci.draw_rect(Rect2(0, BAR_Y, 720, 1280 - BAR_Y), Color("1a1426"))
	ci.draw_rect(Rect2(0, BAR_Y, 720, 3), Art.fade(Data.magic, 0.4))
	var lay := _bar_layout()
	var shown: Array = lay["shown"]
	if shown.is_empty():
		ci.draw_string(font, Vector2(0, BAR_Y + 80), "No bottles yet. Brew some during the day!", HORIZONTAL_ALIGNMENT_CENTER,
			720, 20, Color(1, 1, 1, 0.5))
	for i in shown.size():
		var id: String = shown[i]
		var info: Dictionary = Data.potions[id]
		var n: int = Data.bottles[id]
		var cell := Rect2(lay["x0"] + CELL_W * i + 5, BAR_Y + 10, CELL_W - 10, 130)
		(cell_selected_box if selected == id else cell_box).draw(rid, cell)
		Art.bottle(ci, Vector2(cell.get_center().x, BAR_Y + 64), 58, info["color"])
		var badge := Vector2(cell.end.x - 18, BAR_Y + 28)
		ci.draw_circle(badge, 14, Data.magic, true, -1.0, true)
		ci.draw_string(font, badge + Vector2(-14, 6), str(n), HORIZONTAL_ALIGNMENT_CENTER, 28, 17, Data.ink)
		ci.draw_string(font, Vector2(cell.position.x, BAR_Y + 126), info["name"], HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 15,
			Data.parchment)
	if lay["paged"]:
		for side in [0, 1]:
			var r := Rect2(6 if side == 0 else 666, BAR_Y + 40, 48, 70)
			cell_box.draw(rid, r)
			ci.draw_string(font, r.position + Vector2(0, 46), "<" if side == 0 else ">", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26,
				Data.parchment)
		ci.draw_string(font, Vector2(0, BAR_Y + 146), "%d/%d" % [bar_page + 1, lay["pages"]], HORIZONTAL_ALIGNMENT_CENTER, 720, 13,
			Color(1, 1, 1, 0.5))


## Banner that introduces a creature type the first time it appears.
func _paint_intro(ci: CanvasItem, rid: RID, font: Font) -> void:
	var it: float = intro["t"]
	var a := clampf(minf(it * 4.0, (4.0 - it) * 2.0), 0.0, 1.0)
	var kind: String = intro["kind"]
	var info: Dictionary = Data.creatures[kind]
	var box := Rect2(40, 176 - (1.0 - a) * 20.0, 640, 96)
	var style := status_box.duplicate() as StyleBoxFlat
	style.bg_color = Color(0.06, 0.05, 0.12, 0.85 * a)
	style.border_color = Art.fade(Data.magic, 0.6 * a)
	style.draw(rid, box)
	var s: float = info["size"]
	Art.creature(ci, kind, box.position + Vector2(62, 62 if kind != "moth" else 76), s * 1.05, a, t, false)
	ci.draw_string(font, box.position + Vector2(120, 38), "New: " + info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
		Art.fade(Data.magic.lightened(0.3), a))
	ci.draw_string(font, box.position + Vector2(120, 70), info["desc"], HORIZONTAL_ALIGNMENT_LEFT, 510, 18,
		Art.fade(Data.parchment, a))
