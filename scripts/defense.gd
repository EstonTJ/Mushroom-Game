extends Node2D
## Fortify and night. One hut, two paths, three trap spots per path.
## Fortify: pick a bottle, tap a spot to place it (tap again to take it back),
## or tap the hut with a Moon Ward. Night: creatures walk the paths; a placed
## bottle bursts when one gets close, and saved bottles can be thrown anywhere.

signal night_over(won: bool, repelled: int)

const Art = preload("res://scripts/art.gd")

const HUT := Vector2(360, 1000)
const BAR_Y := 1130.0
const MOON := Vector2(360, 230)
const CELL_W := 180.0
const LEFT_PATH := [Vector2(40, 120), Vector2(180, 330), Vector2(110, 560), Vector2(250, 780), Vector2(330, 950)]
const RIGHT_PATH := [Vector2(680, 120), Vector2(540, 320), Vector2(630, 560), Vector2(470, 780), Vector2(390, 950)]

var curves: Array[Curve2D] = []
var slots := []
var decor := []
var mode := "fortify"
var selected := ""
var ward := 0
var hut_hp := Data.HUT_HP
var hit_flash := 0.0
var cfg: Dictionary = {}
var enemies := []
var areas := []
var popups := []
var spawned := 0
var spawn_timer := 0.0
var repelled := 0
var over := false
var t := 0.0


func _ready() -> void:
	cfg = Data.nights[Data.day - 1]
	curves.append(_make_curve(LEFT_PATH))
	curves.append(_make_curve(RIGHT_PATH))
	for path_i in 2:
		var c := curves[path_i]
		var length := c.get_baked_length()
		for f in [0.3, 0.55, 0.8]:
			slots.append({"pos": c.sample_baked(length * f), "trap": "", "triggered": false})

	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	while decor.size() < 24:
		var p := Vector2(rng.randf_range(20, 700), rng.randf_range(170, 1100))
		var near_path := false
		for c in curves:
			if c.get_closest_point(p).distance_to(p) < 70.0:
				near_path = true
		if near_path or p.distance_to(HUT) < 190.0 or p.distance_to(MOON) < 110.0:
			continue
		var cols := [Color("b58fd6"), Color("d9623b"), Color("9ff0f0"), Color("e0a441")]
		decor.append({"pos": p, "s": rng.randf_range(30, 70), "color": cols[rng.randi() % cols.size()]})


func _make_curve(points: Array) -> Curve2D:
	var c := Curve2D.new()
	var n := points.size()
	for i in n:
		var prev: Vector2 = points[maxi(i - 1, 0)]
		var next: Vector2 = points[mini(i + 1, n - 1)]
		var handle := (next - prev) * 0.2
		c.add_point(points[i], -handle, handle)
	return c


func start_night() -> void:
	mode = "night"
	spawn_timer = 1.5


func _process(delta: float) -> void:
	t += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	for p in popups:
		p["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.0)
	if mode == "night" and not over:
		_night_step(delta)
	queue_redraw()


func _night_step(delta: float) -> void:
	if spawned < cfg["count"]:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = cfg["interval"]
			var path := randi() % 2
			enemies.append({"path": path, "offset": 0.0, "pos": curves[path].sample_baked(0.0),
				"courage": cfg["courage"], "max": cfg["courage"],
				"speed": cfg["speed"] * randf_range(0.9, 1.15), "flee": -1.0, "dir": Vector2.UP})
			spawned += 1

	for s in slots:
		if s["trap"] != "" and not s["triggered"]:
			for e in enemies:
				if e["flee"] < 0.0 and e["pos"].distance_to(s["pos"]) < 45.0:
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
		var slow := 1.0
		var dps := 0.0
		for a in areas:
			if e["pos"].distance_to(a["pos"]) < a["radius"]:
				var d: Dictionary = Data.potions[a["id"]]
				slow = minf(slow, d["slow"])
				dps += d["dps"]
		e["courage"] -= dps * delta
		if e["courage"] <= 0.0:
			_scare(e)
			repelled += 1
			_popup("Shoo!", e["pos"], Data.magic)
			continue
		var c: Curve2D = curves[e["path"]]
		e["offset"] += e["speed"] * slow * delta
		if e["offset"] >= c.get_baked_length():
			if ward > 0:
				ward -= 1
				repelled += 1
				_popup("Warded!", HUT + Vector2(0, -170), Data.magic)
			else:
				hut_hp -= 1
				hit_flash = 0.4
				_popup("-1", HUT + Vector2(0, -170), Color("ff7a6b"))
			_scare(e)
		else:
			e["pos"] = c.sample_baked(e["offset"])
	enemies = enemies.filter(func(e): return e["flee"] < 1.0)

	if hut_hp <= 0:
		_end(false)
	elif spawned >= cfg["count"] and enemies.is_empty():
		_end(true)


func _scare(e: Dictionary) -> void:
	e["flee"] = 0.0
	var away: Vector2 = e["pos"] - HUT
	e["dir"] = away.normalized() if away.length() > 1.0 else Vector2.UP


func _spawn_area(id: String, pos: Vector2) -> void:
	var d: Dictionary = Data.potions[id]
	areas.append({"id": id, "pos": pos, "radius": d["radius"], "time": d["duration"], "max": d["duration"]})
	if d["burst"] > 0.0:
		for e in enemies:
			if e["flee"] < 0.0 and e["pos"].distance_to(pos) < d["radius"]:
				e["courage"] -= d["burst"]


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
		var i := int(p.x / CELL_W)
		if i >= 0 and i < 4:
			var id: String = Data.potion_order[i]
			if Data.bottles[id] > 0:
				selected = "" if selected == id else id
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
			elif selected != "" and selected != "ward":
				s["trap"] = selected
				_use_selected()
			return
	if selected == "ward" and p.distance_to(HUT + Vector2(0, -60)) < 120.0:
		ward += Data.potions["ward"]["ward"]
		_popup("Ward +%d" % Data.potions["ward"]["ward"], HUT + Vector2(0, -170), Data.magic)
		_use_selected()


func _night_tap(p: Vector2) -> void:
	if selected == "":
		return
	if selected == "ward":
		ward += Data.potions["ward"]["ward"]
		_popup("Ward +%d" % Data.potions["ward"]["ward"], HUT + Vector2(0, -170), Data.magic)
	else:
		_spawn_area(selected, p)
	_use_selected()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var night := mode == "night"
	draw_rect(Rect2(0, 0, 720, 1280), Color("1d1a33") if night else Color("3b3552"))
	draw_circle(MOON, 46, Color(1, 0.97, 0.85, 0.9 if night else 0.35))

	for d in decor:
		Art.mushroom(self, d["pos"], d["s"], d["color"], 0.55 if night else 0.8, night and d["color"] == Color("9ff0f0"))

	for c in curves:
		var pts := c.get_baked_points()
		for k in range(0, pts.size(), 3):
			draw_circle(pts[k], 34, Color("5e5040"))
		for k in range(0, pts.size(), 3):
			draw_circle(pts[k], 26, Color("7d6a52"))

	Art.hut(self, HUT, 160)
	if hit_flash > 0.0:
		draw_circle(HUT + Vector2(0, -60), 130, Color(1, 0.3, 0.3, hit_flash))
	if ward > 0:
		var pulse := 0.6 + 0.3 * sin(t * 4.0)
		draw_arc(HUT + Vector2(0, -60), 135, 0, TAU, 64, Art.fade(Data.magic, pulse), 6)

	for s in slots:
		if s["trap"] != "" and not s["triggered"]:
			Art.bottle(self, s["pos"], 56, Data.potions[s["trap"]]["color"])
		elif not night:
			var glow := 0.5 + 0.3 * sin(t * 3.0)
			draw_arc(s["pos"], 36, 0, TAU, 40, Art.fade(Data.magic, glow), 4)

	for a in areas:
		var col: Color = Data.potions[a["id"]]["color"]
		var life: float = a["time"] / a["max"]
		var strength := minf(1.0, life * 3.0)
		draw_circle(a["pos"], a["radius"], Art.fade(col, 0.3 * strength))
		draw_arc(a["pos"], a["radius"], 0, TAU, 48, Art.fade(col, 0.8 * strength), 3)

	for e in enemies:
		var fade := 1.0 - maxf(0.0, e["flee"])
		var wobble := sin(t * 10.0 + e["offset"] * 0.1) * 3.0
		Art.creature(self, e["pos"] + Vector2(0, wobble), 40, fade)
		if e["flee"] < 0.0 and e["courage"] < e["max"]:
			var w: float = 40.0 * e["courage"] / e["max"]
			draw_rect(Rect2(e["pos"].x - 20, e["pos"].y - 40, 40, 5), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(e["pos"].x - 20, e["pos"].y - 40, w, 5), Data.magic)

	for p in popups:
		var pt: float = p["t"]
		draw_string(font, p["pos"] + Vector2(-100, -pt * 50), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 200, 28,
			Art.fade(p["color"], 1.0 - pt))

	var status := "Tonight: %d creatures  ·  Ward %d" % [cfg["count"], ward]
	if night:
		status = "Hut %d/%d  ·  Ward %d  ·  Repelled %d/%d" % [maxi(hut_hp, 0), Data.HUT_HP, ward, repelled, cfg["count"]]
	draw_rect(Rect2(0, 110, 720, 44), Color(0, 0, 0, 0.35))
	draw_string(font, Vector2(0, 141), status, HORIZONTAL_ALIGNMENT_CENTER, 720, 22, Data.parchment)

	# Bottle bar
	draw_rect(Rect2(0, BAR_Y, 720, 1280 - BAR_Y), Color(0, 0, 0, 0.5))
	for i in 4:
		var id: String = Data.potion_order[i]
		var info: Dictionary = Data.potions[id]
		var n: int = Data.bottles[id]
		var x := CELL_W * i
		if selected == id:
			draw_rect(Rect2(x + 6, BAR_Y + 6, CELL_W - 12, 1280 - BAR_Y - 12), Art.fade(Data.magic, 0.35))
		var known: bool = Data.discovered.has(id)
		Art.bottle(self, Vector2(x + CELL_W / 2, BAR_Y + 62), 70, info["color"] if known else Color("777777"),
			1.0 if n > 0 else 0.35)
		draw_string(font, Vector2(x + CELL_W - 60, BAR_Y + 38), "x%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
			Data.parchment)
		draw_string(font, Vector2(x, BAR_Y + 132), info["name"] if known else "???", HORIZONTAL_ALIGNMENT_CENTER,
			CELL_W, 20, Data.parchment)
