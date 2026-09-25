extends Node2D
## Day phase 1: a short timed walk. Tap ingredients before they fade.
## One Moonglow (the rare one) appears per walk, and it fades fast.

signal finished

const Art = preload("res://scripts/art.gd")

const DURATION := 20.0
const SPAWN_EVERY := 0.9
const MAX_ON_SCREEN := 6

var time_left := DURATION
var spawn_timer := 0.0
var items := []
var popups := []
var trees := []
var moonglow_spawned := false
var done := false


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 14:
		trees.append({"pos": Vector2(rng.randf_range(0, 720), rng.randf_range(150, 1100)),
			"r": rng.randf_range(40, 90)})
	for i in 3:
		_spawn()


func _process(delta: float) -> void:
	for p in popups:
		p["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.0)
	for it in items:
		it["age"] += delta
	items = items.filter(func(it): return it["age"] < it["life"])
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
	queue_redraw()


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
	var pos := Vector2(randf_range(70, 650), randf_range(200, 1040))
	for _attempt in 10:
		var clear := true
		for it in items:
			if it["pos"].distance_to(pos) < 120.0:
				clear = false
		if clear:
			break
		pos = Vector2(randf_range(70, 650), randf_range(200, 1040))
	items.append({"id": id, "pos": pos, "age": 0.0, "life": life})


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
				items.remove_at(i)
				break


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 720, 1280), Color("7d9a6b"))
	for t in trees:
		draw_circle(t["pos"], t["r"], Color("5f7d55"))

	draw_rect(Rect2(0, 110, 720, 14), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(0, 110, 720 * time_left / DURATION, 14), Data.lantern)

	for it in items:
		var remaining: float = it["life"] - it["age"]
		var a := 1.0
		if remaining < 1.0:
			a = 0.35 + 0.65 * absf(sin(remaining * 12.0))
		var grow: float = minf(1.0, it["age"] * 6.0 + 0.3)
		var bob := sin(float(it["age"]) * 3.0) * 4.0
		Art.ingredient(self, it["id"], it["pos"] + Vector2(0, bob), 76.0 * grow, a)

	for p in popups:
		var t: float = p["t"]
		draw_string(font, p["pos"] + Vector2(-100, -50 - t * 50), p["text"], HORIZONTAL_ALIGNMENT_CENTER,
			200, 24, Art.fade(Data.parchment, 1.0 - t))

	draw_rect(Rect2(0, 1110, 720, 170), Color(0, 0, 0, 0.3))
	draw_string(font, Vector2(20, 1146), "Basket", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Data.parchment)
	for i in 5:
		var id: String = Data.ingredient_order[i]
		Art.ingredient(self, id, Vector2(72 + 144 * i, 1205), 56)
		draw_string(font, Vector2(144 * i, 1266), "x%d" % Data.inventory[id], HORIZONTAL_ALIGNMENT_CENTER,
			144, 22, Data.parchment)
