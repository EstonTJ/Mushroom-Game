extends Node2D
## Dawn Market: after each night won, spend coins from scared-off creatures on
## lab upgrades. The first is the Bone Mortar, which lets monster bones go into
## the cauldron for Empowered potions.

signal closed

const Art = preload("res://scripts/art.gd")
const CLOSE := Rect2(620, 16, 84, 64)

const CARD_W := 640.0
const CARD_H := 196.0
const FIRST_CARD_Y := 540.0

## Opened from the menu or title (on top of the game) rather than at dawn.
var overlay := false
## When opened as an overlay: the save checkpoint to rewrite after a purchase
## ("" = don't save now; the next checkpoint will).
var save_phase := ""
var earned_coins := 0
var earned_bones := 0
var t := 0.0
var particles := []
var message := ""
var message_t := 0.0
var card_box: StyleBoxFlat
var buy_box: StyleBoxFlat
var soon_box: StyleBoxFlat


func _ready() -> void:
	if overlay:
		process_mode = Node.PROCESS_MODE_ALWAYS
	card_box = _box(Color("efe3c8"), Color("8a6242"), 22, 5)
	buy_box = _box(Color("4f8a44"), Color("2f5a30"), 14, 3)
	soon_box = _box(Color(0.94, 0.89, 0.78, 0.55), Color(0.54, 0.38, 0.26, 0.5), 22, 3)


func _box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b


func card_rect(i: int) -> Rect2:
	return Rect2(40, FIRST_CARD_Y + i * (CARD_H + 8), CARD_W, CARD_H)


func buy_rect(i: int) -> Rect2:
	var c := card_rect(i)
	return Rect2(c.end.x - 186, c.position.y + 16, 166, 50)


func _unhandled_input(event: InputEvent) -> void:
	if overlay:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap(get_global_mouse_position())


## As an overlay the market takes every touch, so nothing reaches the game.
func _input(event: InputEvent) -> void:
	if not overlay:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap(get_global_mouse_position())
	get_viewport().set_input_as_handled()


func tap(p: Vector2) -> void:
	if overlay and CLOSE.has_point(p):
		closed.emit()
		return
	for i in Data.shop_order.size():
		if buy_rect(i).has_point(p):
			try_buy(Data.shop_order[i])


func try_buy(item: String) -> bool:
	var info: Dictionary = Data.shop_items[item]
	if Data.upgrades.has(item):
		return false
	if not Data.can_buy_after(item):
		message = "You need the %s first." % Data.shop_items[info["requires"]]["name"]
		message_t = 0.0
		return false
	if Data.buy(item):
		message = "%s added to your lab!" % info["name"]
		var at := buy_rect(Data.shop_order.find(item)).get_center()
		for k in 40:
			particles.append({"pos": at, "vel": Vector2.from_angle(randf() * TAU) * randf_range(120, 380), "life": randf_range(0.6, 1.2),
				"max": 1.2, "color": [Color("ffd35a"), Color.WHITE, Color("8bc5c3")][k % 3]})
		if not overlay:
			Data.save_game("market")
		elif save_phase != "":
			Data.save_game(save_phase)
	else:
		message = "You need %d more coins." % (int(info["price"]) - Data.coins)
	message_t = 0.0
	return Data.upgrades.has(item)


func _process(delta: float) -> void:
	t += delta
	message_t += delta
	for p in particles:
		p["life"] -= delta
		p["vel"] = p["vel"] * 0.93 + Vector2(0, 80) * delta
		p["pos"] += p["vel"] * delta
	particles = particles.filter(func(p): return p["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var rid := get_canvas_item()
	_draw_sky()
	_draw_stall()

	# Earnings and purse.
	var purse := Rect2(40, 462, 640, 66)
	card_box.draw(rid, purse)
	Art.coin(self, purse.position + Vector2(44, 35), 34)
	draw_string(font, purse.position + Vector2(70, 44), str(Data.coins), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Data.ink)
	Art.bone(self, purse.position + Vector2(170, 35), 44)
	draw_string(font, purse.position + Vector2(200, 44), str(Data.bones), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Data.ink)
	var earned := "Last night: +%d coins, +%d bones" % [earned_coins, earned_bones]
	if overlay:
		earned = "Open any time from the Menu"
	draw_string(font, purse.position + Vector2(260, 44), earned, HORIZONTAL_ALIGNMENT_RIGHT, 360, 19, Color("6a5a48"))

	for i in Data.shop_order.size():
		_draw_item(font, rid, i, Data.shop_order[i])

	var soon := card_rect(Data.shop_order.size())
	soon.size.y = 76
	soon_box.draw(rid, soon)
	draw_string(font, soon.position + Vector2(0, 34), "More lab upgrades coming soon", HORIZONTAL_ALIGNMENT_CENTER, soon.size.x, 22,
		Color(0.4, 0.3, 0.22, 0.8))
	draw_string(font, soon.position + Vector2(0, 60), "Keep your coins and bones: the merchant brings new wares.", HORIZONTAL_ALIGNMENT_CENTER,
		soon.size.x, 15, Color(0.4, 0.3, 0.22, 0.7))

	if message != "" and message_t < 3.0:
		var a := clampf(3.0 - message_t, 0.0, 1.0)
		draw_string_outline(font, Vector2(0, 1266), message, HORIZONTAL_ALIGNMENT_CENTER, 720, 22, 7, Color(0, 0, 0, 0.6 * a))
		draw_string(font, Vector2(0, 1266), message, HORIZONTAL_ALIGNMENT_CENTER, 720, 22, Art.fade(Color("ffd35a"), a))

	for p in particles:
		var f: float = p["life"] / p["max"]
		Art.sparkle(self, p["pos"], 9.0 * f, Art.fade(p["color"], f))

	if overlay:
		card_box.draw(rid, CLOSE)
		draw_string(font, CLOSE.position + Vector2(0, 44), "X", HORIZONTAL_ALIGNMENT_CENTER, CLOSE.size.x, 30, Data.ink)


func _draw_item(font: Font, rid: RID, i: int, item: String) -> void:
	var info: Dictionary = Data.shop_items[item]
	var c := card_rect(i)
	card_box.draw(rid, c)
	var owned: bool = Data.upgrades.has(item)
	var icon := c.position + Vector2(96, 104)
	Art.glow(self, icon, 90, Color(1.0, 0.85, 0.5, 0.35))
	if item == "bone_appetit":
		_draw_bone_appetit(icon)
	elif item == "batch_brewer":
		_draw_batch_brewer(icon)
	else:
		_draw_mortar(icon, 1.0)
	# Long names shrink to fit beside the Buy button.
	var title_w := buy_rect(i).position.x - c.position.x - 200.0
	var size := 30
	while size > 18 and font.get_string_size(info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > title_w:
		size -= 1
	draw_string(font, c.position + Vector2(190, 48), info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Data.ink)
	draw_string(font, c.position + Vector2(190, 74), "Lab upgrade", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("8a6242"))
	draw_multiline_string(font, c.position + Vector2(190, 102), info["desc"], HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 210, 16, 4,
		Art.fade(Data.ink, 0.85))
	var b := buy_rect(i)
	if not owned and not Data.can_buy_after(item):
		draw_string(font, b.position + Vector2(-40, 38), "Needs " + Data.shop_items[info["requires"]]["name"], HORIZONTAL_ALIGNMENT_RIGHT,
			b.size.x + 30, 19, Color("8a6242"))
	elif owned:
		draw_string(font, b.position + Vector2(0, 38), "Owned", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 26, Color("4f8a44"))
		Art.sparkle(self, b.position + Vector2(20, 28), 9.0, Color("4f8a44"))
	else:
		var can := Data.coins >= int(info["price"])
		buy_box.bg_color = Color("4f8a44") if can else Color("9a8a70")
		buy_box.draw(rid, b)
		Art.coin(self, b.position + Vector2(34, 29), 30)
		draw_string(font, b.position + Vector2(56, 39), "%d  Buy" % int(info["price"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)


## A big cauldron with five bottles lined up in front of it.
func _draw_batch_brewer(at: Vector2) -> void:
	Art.shadow(self, at + Vector2(0, 50), 70, 10)
	draw_circle(at + Vector2(0, -6), 44, Color("2f2b2a"))
	draw_colored_polygon(Art.ellipse(at + Vector2(0, -40), 50, 14, 20), Color("3d3837"))
	draw_colored_polygon(Art.ellipse(at + Vector2(0, -40), 42, 10, 20), Color("7fd67a").lightened(0.1 * sin(t * 3.0)))
	for k in 5:
		var bp := at + Vector2(-56 + k * 28, 40 + absf(sin(t * 3.0 + k)) * -4.0)
		Art.bottle(self, bp, 30, [Color("b58fd6"), Color("e0a441"), Color("e8703f"), Color("9ff0f0"), Color("a8e0ff")][k])


## A little bone-loading contraption: a gear, a hopper of bones and a chute.
func _draw_bone_appetit(at: Vector2) -> void:
	var spin := t * 1.5
	var gear := at + Vector2(-26, 10)
	for k in 8:
		var ang := spin + k * TAU / 8.0
		draw_line(gear + Vector2.from_angle(ang) * 26.0, gear + Vector2.from_angle(ang) * 38.0, Color("8a8494"), 10.0, true)
	draw_circle(gear, 30, Color("8a8494"))
	draw_circle(gear, 12, Color("3e3a44"))
	var hopper := PackedVector2Array([at + Vector2(6, -62), at + Vector2(70, -62), at + Vector2(52, -14), at + Vector2(24, -14)])
	draw_colored_polygon(hopper, Color("8a6242"))
	Art.outline(self, hopper, Art.fade(Art.INK, 0.6), 2.0)
	for k in 3:
		Art.bone(self, at + Vector2(22 + k * 16, -64 - (k % 2) * 8), 30, 1.0, -0.7 + k * 0.6)
	draw_line(at + Vector2(38, -14), at + Vector2(46, 34), Color("6a4a30"), 12.0, true)
	var drop := fmod(t * 0.9, 1.0)
	Art.bone(self, at + Vector2(46, 20 + drop * 30), 26, 1.0 - drop, 1.2)
	Art.shadow(self, at + Vector2(0, 52), 64, 10)


## Stone mortar with a pestle and a bone poking out.
func _draw_mortar(at: Vector2, a: float) -> void:
	Art.shadow(self, at + Vector2(0, 46), 64, 12, a)
	Art.bone(self, at + Vector2(-18, -34), 56, a, -1.1)
	draw_line(at + Vector2(10, -10), at + Vector2(46, -70), Art.fade(Color("8a6242"), a), 14.0, true)
	draw_circle(at + Vector2(46, -70), 9, Art.fade(Color("8a6242"), a))
	var bowl := PackedVector2Array()
	for j in 17:
		var ang := PI * j / 16.0
		bowl.append(at + Vector2(cos(ang) * 60.0, sin(ang) * 46.0 - 6.0))
	draw_colored_polygon(bowl, Art.fade(Color("8a8494"), a))
	draw_colored_polygon(Art.ellipse(at + Vector2(0, -6), 60, 16, 24), Art.fade(Color("6a6474"), a))
	draw_colored_polygon(Art.ellipse(at + Vector2(0, -6), 48, 11, 20), Art.fade(Color("3e3a44"), a))
	draw_colored_polygon(Art.ellipse(at + Vector2(-22, 14), 14, 6, 10), Art.fade(Color("aaa4b4"), a))
	Art.outline(self, bowl, Art.fade(Art.INK, 0.6 * a), 2.0)


func _draw_sky() -> void:
	var top := Color("3a2f58")
	var low := Color("f0b070")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, 1280), Vector2(0, 1280)]),
		PackedColorArray([top, top, low, low]))
	Art.glow(self, Vector2(560, 300), 260, Color(1.0, 0.85, 0.5, 0.45))
	draw_circle(Vector2(560, 300), 60, Color("ffe0a0"))


## Wooden market stall with a striped awning, goods and a lantern.
func _draw_stall() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(60, 200, 18, 260), Color("5a4030"))
	draw_rect(Rect2(642, 200, 18, 260), Color("5a4030"))
	draw_rect(Rect2(50, 360, 620, 90), Color("7a5a3e"))
	draw_rect(Rect2(50, 360, 620, 10), Color("9a7a5a"))
	for k in 5:
		var jar := Vector2(120 + k * 110, 330)
		draw_rect(Rect2(jar.x - 22, jar.y - 30, 44, 50), Color(0.85, 0.93, 1.0, 0.35))
		draw_rect(Rect2(jar.x - 20, jar.y - 38, 40, 10), Color("8a6242"))
		if k % 2 == 0:
			Art.bottle(self, jar + Vector2(0, -2), 34, [Color("b58fd6"), Color("a8e0ff"), Color("e8703f")][k / 2])
		else:
			Art.bone(self, jar + Vector2(0, -4), 36, 1.0, -0.4 + k)
	var stripes := [Color("c84a3a"), Color("f5ead8")]
	for k in 10:
		var x := 40.0 + k * 64.0
		draw_rect(Rect2(x, 150, 64, 60), stripes[k % 2])
		var sc := PackedVector2Array()
		for j in 9:
			var ang := PI * j / 8.0
			sc.append(Vector2(x + 32 + cos(ang) * 32.0, 210 + sin(ang) * 20.0))
		draw_colored_polygon(sc, stripes[k % 2])
	draw_rect(Rect2(34, 140, 652, 14), Color("5a4030"))
	var sign := Rect2(240, 390, 240, 50)
	draw_rect(sign, Color("efe3c8"))
	draw_rect(sign, Color("5a4030"), false, 3.0)
	draw_string(font, sign.position + Vector2(0, 35), "Dawn Market", HORIZONTAL_ALIGNMENT_CENTER, sign.size.x, 26, Color("7a3a2a"))
	var lamp := Vector2(600, 250 + sin(t * 1.5) * 3.0)
	draw_line(Vector2(600, 210), lamp + Vector2(0, -14), Color("2a2a30"), 2.0)
	Art.glow(self, lamp, 50, Color(1.0, 0.8, 0.45, 0.5))
	draw_rect(Rect2(lamp.x - 12, lamp.y - 14, 24, 30), Color("ffcf7a"))
	draw_rect(Rect2(lamp.x - 12, lamp.y - 14, 24, 30), Art.INK, false, 2.0)
