extends Node2D
## Between a won night and the next day: a dawn screen that introduces each
## newly unlocked mushroom on a field-guide card (name, Latin name, how common
## it is, a true fact, a safety note) and teases any new brew it makes possible.
## Several new mushrooms (the first morning) show one card at a time.

const Art = preload("res://scripts/art.gd")

const CARD := Rect2(40, 222, 640, 830)
const SHOW := Vector2(360, 525)
const SAFETY := "Real wild mushrooms can be deadly. Never eat one you find."

var ids: Array = []
var index := 0
var t := 0.0
var particles := []
var stars := []
var card_box: StyleBoxFlat


func _ready() -> void:
	card_box = StyleBoxFlat.new()
	card_box.bg_color = Color("efe3c8")
	card_box.border_color = Color("8a6242")
	card_box.set_border_width_all(6)
	card_box.set_corner_radius_all(28)
	card_box.shadow_color = Color(0, 0, 0, 0.35)
	card_box.shadow_size = 18
	card_box.anti_aliasing = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 50:
		stars.append({"pos": Vector2(rng.randf_range(0, 720), rng.randf_range(110, 700)), "ph": rng.randf() * TAU})
	_celebrate()


func has_next() -> bool:
	return index < ids.size() - 1


func next() -> void:
	index = mini(index + 1, ids.size() - 1)
	t = 0.0
	_celebrate()


func current() -> String:
	return ids[index] if index < ids.size() else ""


func _celebrate() -> void:
	if current() == "":
		return
	var col: Color = Data.ingredients[current()]["color"]
	for i in 36:
		var cols := [Color("ffd35a"), col.lightened(0.3), Color.WHITE]
		particles.append({"pos": SHOW + Vector2(0, -60), "vel": Vector2.from_angle(randf() * TAU) * randf_range(120, 420),
			"life": randf_range(0.7, 1.4), "max": 1.4, "color": cols[i % cols.size()], "size": randf_range(4, 9)})


## How common a mushroom is on forest walks, as a word and 1-3 stars.
func rarity(id: String) -> Array:
	var w: float = Data.ingredients[id]["weight"]
	if w <= 0.0 or w <= 1.0:
		return ["Rare", 3]
	if w < 3.0:
		return ["Uncommon", 2]
	return ["Common", 1]


## Potions that become brewable on this day (their mushrooms have just all arrived).
func new_brews() -> Array:
	return Data.potion_order.filter(func(p): return Data.potion_night(p) == Data.day)


func _process(delta: float) -> void:
	t += delta
	for p in particles:
		p["life"] -= delta
		p["vel"] = p["vel"] * 0.94 + Vector2(0, 60) * delta
		p["pos"] += p["vel"] * delta
	particles = particles.filter(func(p): return p["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	_draw_dawn()
	var id := current()
	if id == "":
		return
	var info: Dictionary = Data.ingredients[id]

	# Card pops in.
	var pop := minf(1.0, t * 3.0)
	var ease := pop + 0.12 * sin(pop * PI)
	var card := Rect2(CARD.position + Vector2(0, (1.0 - pop) * 60.0), CARD.size)
	var a := pop
	draw_set_transform(card.get_center(), 0.0, Vector2.ONE * (0.9 + 0.1 * ease))
	var local := Rect2(card.position - card.get_center(), card.size)
	card_box.draw(get_canvas_item(), local)
	draw_set_transform(Vector2.ZERO)

	var title := "New mushroom unlocked!" if Data.day > 1 else "Your first mushrooms"
	draw_string_outline(font, Vector2(0, card.position.y + 58), title, HORIZONTAL_ALIGNMENT_CENTER, 720, 34, 6, Art.fade(Color("8a6242"), 0.25 * a))
	draw_string(font, Vector2(0, card.position.y + 58), title, HORIZONTAL_ALIGNMENT_CENTER, 720, 34, Art.fade(Color("7a3a2a"), a))

	# Turning light rays and a glow behind the mushroom, rising from a mossy mound.
	var show := SHOW + Vector2(0, (1.0 - pop) * 60.0)
	var col: Color = info["color"]
	for k in 12:
		var ang := t * 0.35 + k * TAU / 12.0
		draw_colored_polygon(PackedVector2Array([show + Vector2(0, -70), show + Vector2(0, -70) + Vector2.from_angle(ang - 0.09) * 230.0,
			show + Vector2(0, -70) + Vector2.from_angle(ang + 0.09) * 230.0]), Color(1.0, 0.85, 0.45, 0.16 * a))
	Art.glow(self, show + Vector2(0, -70), 200, Art.fade(col.lightened(0.4), 0.45 * a))
	draw_colored_polygon(Art.ellipse(show + Vector2(0, 38), 150, 36, 32), Art.fade(Color("5f8a4a"), a))
	draw_colored_polygon(Art.ellipse(show + Vector2(-30, 30), 80, 16, 24), Art.fade(Color("7aa85a"), a))
	for k in 7:
		var gp := show + Vector2(-120 + k * 40, 34 + sin(k * 2.1) * 6)
		draw_line(gp, gp + Vector2(-4, -14), Art.fade(Color("4f7a44"), a), 2.0, true)
		draw_line(gp, gp + Vector2(3, -17), Art.fade(Color("4f7a44"), a), 2.0, true)
	var grow := clampf((t - 0.15) * 2.2, 0.0, 1.0)
	var size := 230.0 * (grow + 0.15 * sin(grow * PI))
	if size > 4.0:
		Art.ingredient(self, id, show + Vector2(0, 8 + sin(t * 2.0) * 3.0), size, a)

	# Name, Latin name, rarity.
	var y := card.position.y + 468.0
	draw_string(font, Vector2(card.position.x, y), info["name"], HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 42, Art.fade(Data.ink, a))
	draw_string(font, Vector2(card.position.x, y + 36), info["latin"], HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 22,
		Art.fade(Color("6a5a48"), a))
	var r := rarity(id)
	var label: String = r[0]
	var stars_n: int = r[1]
	var ed: String = info.get("edibility", "")
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var ew := font.get_string_size(ed, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var row_w := lw + stars_n * 26.0 + 10.0 + (40.0 + ew if ed != "" else 0.0)
	var rx := card.get_center().x - row_w / 2.0
	draw_string(font, Vector2(rx, y + 76), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.fade(Color("8a6242"), a))
	for k in stars_n:
		Art.sparkle(self, Vector2(rx + lw + 22 + k * 26, y + 69), 10.0, Art.fade(Color("e0a030"), a))
	if ed != "":
		var ex := rx + lw + stars_n * 26.0 + 30.0
		draw_circle(Vector2(ex, y + 69), 4, Art.fade(Data.ink, 0.4 * a))
		draw_string(font, Vector2(ex + 16, y + 76), ed, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.fade(Data.edibility_color(ed), a))

	# The fact.
	draw_line(Vector2(card.position.x + 60, y + 100), Vector2(card.end.x - 60, y + 100), Art.fade(Data.ink, 0.15 * a), 2.0)
	draw_multiline_string(font, Vector2(card.position.x + 50, y + 138), info["facts"][0], HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 100,
		23, 3, Art.fade(Data.ink, 0.9 * a))

	# A new potion it makes possible, kept a mystery.
	var brews := new_brews()
	if not brews.is_empty():
		var by := y + 276.0
		var tw := font.get_string_size("New brew possible:", HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		var bx := card.get_center().x - (tw + 10.0 + brews.size() * 44.0) / 2.0
		draw_string(font, Vector2(bx, by), "New brew possible:", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Art.fade(Color("7a3a2a"), a))
		for k in brews.size():
			var bp := Vector2(bx + tw + 32 + k * 44, by - 12)
			Art.bottle(self, bp, 46, Color("b8ad96"), 0.8 * a)
			draw_string(font, bp + Vector2(-20, 8), "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Art.fade(Data.ink, a))

	draw_string(font, Vector2(card.position.x, card.end.y - 28), SAFETY, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 17,
		Art.fade(Color("b0413e"), a))

	# A fungi-kingdom fact under the card, a different one each day.
	if Data.kingdom_facts.size() > 0:
		var fact: String = Data.kingdom_facts[(Data.day - 1 + index) % Data.kingdom_facts.size()]
		var fy := card.end.y + (78.0 if ids.size() > 1 else 56.0)
		draw_string_outline(font, Vector2(40, fy), "Did you know?", HORIZONTAL_ALIGNMENT_CENTER, 640, 22, 6, Color(0, 0, 0, 0.5 * a))
		draw_string(font, Vector2(40, fy), "Did you know?", HORIZONTAL_ALIGNMENT_CENTER, 640, 22, Art.fade(Color("ffd35a"), a))
		draw_multiline_string_outline(font, Vector2(50, fy + 32), fact, HORIZONTAL_ALIGNMENT_CENTER, 620, 20, 3, 6, Color(0, 0, 0, 0.55 * a))
		draw_multiline_string(font, Vector2(50, fy + 32), fact, HORIZONTAL_ALIGNMENT_CENTER, 620, 20, 3, Art.fade(Color.WHITE, a))

	# One dot per new mushroom when there are several.
	if ids.size() > 1:
		for k in ids.size():
			var dp := Vector2(360 - (ids.size() - 1) * 14 + k * 28, card.end.y + 34)
			draw_circle(dp, 7, Color("ffd35a") if k == index else Color(1, 1, 1, 0.35))

	for p in particles:
		var f: float = p["life"] / p["max"]
		Art.sparkle(self, p["pos"], p["size"] * f, Art.fade(p["color"], f))


func _draw_dawn() -> void:
	var top := Color("241f48")
	var mid := Color("7a4a78")
	var low := Color("f0a060")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, 700), Vector2(0, 700)]),
		PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, 700), Vector2(720, 700), Vector2(720, 1280), Vector2(0, 1280)]),
		PackedColorArray([mid, mid, low, low]))
	for s in stars:
		var tw := 0.4 + 0.6 * absf(sin(t * 1.5 + s["ph"]))
		draw_circle(s["pos"], 1.8, Color(1, 1, 0.9, 0.7 * tw))
	var sun := Vector2(360, 1250 - minf(t, 3.0) * 12.0)
	Art.glow(self, sun, 420, Color(1.0, 0.8, 0.4, 0.55))
	draw_circle(sun, 90, Color("ffd890"))
	var hills := [[Color("3a2a48"), 1130.0, 0.0], [Color("2a2038"), 1180.0, 2.0]]
	for h in hills:
		var pts := PackedVector2Array([Vector2(0, 1280)])
		for k in 25:
			var x := k * 30.0
			pts.append(Vector2(x, h[1] + sin(x * 0.012 + h[2]) * 40.0 + sin(x * 0.031 + h[2]) * 14.0))
		pts.append(Vector2(720, 1280))
		draw_colored_polygon(pts, h[0])
	for k in 9:
		var tx := 30.0 + k * 85.0
		var ty := 1165.0 + sin(tx * 0.012) * 40.0
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 22, ty + 20), Vector2(tx, ty - 60 - (k % 3) * 18), Vector2(tx + 22, ty + 20)]),
			Color("1e1830"))
