extends Node
## Saves a PNG of each screen. Needs a real window (not --headless):
##   Godot --path . --resolution 720x1280 res://tests/screenshots.tscn -- <output folder>

const Forage = preload("res://scripts/forage.gd")

var out_dir := "user://screenshots"


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _ready() -> void:
	Data.clear_save()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)

	# Day 1 forest: the first three mushrooms, rocks and stumps, the intro banner.
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await frames(50)
	await shot("0_unlock_day1")
	while main.phase == "unlock":
		main._on_action()
		await frames(2)
	await frames(40)
	var fg = main.phase_node
	var picked: Dictionary = fg.items[0]
	Data.inventory[picked["id"]] += 1
	fg.flyers.append({"id": picked["id"], "from": picked["pos"], "t": 0.0})
	fg.items.remove_at(0)
	fg._hit_obstacle(fg.obstacles[0])
	await frames(10)
	await shot("1_forage")

	# Mid-game cauldron (night 25): most jars unlocked, a paged recipe book.
	fg.time_left = 0.0
	await frames(3)
	Data.day = 25
	for id in Data.ingredient_order:
		Data.inventory[id] = 3
	for id in ["spore", "syrup", "ember", "ward", "ink_pool", "frost", "great_ward", "befuddle"]:
		Data.discovered[id] = true
		Data.bottles[id] = 1
	Data.upgrades["bone_mortar"] = true
	Data.bones = 3
	Data.coins = 27
	Data.bottles["frost+"] = 1
	var brew = main.phase_node
	for id in ["scarlet_elf_cup", "puffball"]:
		brew._on_press(brew.slot_center(Data.ingredient_order.find(id)))
		brew._on_release(brew.POT)
	# Two bubbles popped (one Perfect), the third swelling into its ring.
	brew._bubble_step(1.0)
	brew.bubble["f"] = 0.85
	brew._pop_bubble(true)
	brew._bubble_step(1.0)
	brew.bubble["f"] = 0.4
	brew._pop_bubble(true)
	brew._bubble_step(1.0)
	brew.bubble["f"] = 0.8
	brew.book_page = 1
	await frames(5)
	await shot("2_brew")

	# Night 25 fortify: the roster and a bar with more kinds than fit.
	main._on_action()
	await frames(3)
	var def = main.phase_node
	def.selected = "frost"
	def._fortify_tap(def.slots[1]["pos"])
	def.selected = "ink_pool"
	def._fortify_tap(def.slots[4]["pos"])
	await frames(5)
	await shot("3_fortify")

	# Full night with the new potions going off among all four creature types.
	main._on_action()
	def.night_amt = 1.0
	def.ground_layer.queue_redraw()
	def.canopy_layer.queue_redraw()
	def.ward = 4
	def.enemies = []
	var lineup := [["mischief", 0, 330.0], ["scuttler", 0, 520.0], ["stumpling", 1, 300.0], ["moth", 1, 560.0],
		["mischief", 1, 760.0], ["scuttler", 0, 740.0], ["mischief", 0, 150.0]]
	for row in lineup:
		var e: Dictionary = def._make_enemy(row[0], row[1])
		e["offset"] = row[2]
		e["pos"] = def.curves[row[1]].sample_baked(row[2])
		e["courage"] = 99.0
		def.enemies.append(e)
	def._spawn_area("frost", def.curves[1].sample_baked(560.0))
	def._spawn_area("befuddle", def.curves[0].sample_baked(330.0))
	def._spawn_area("ink_pool", def.curves[1].sample_baked(300.0))
	def._spawn_area("sulphur", def.curves[0].sample_baked(740.0))
	for i in 2:
		def._night_step(0.01)
	await frames(10)
	await shot("4_night")

	# The hut breaking down: whole, then 1 to 4 hits.
	for b in 5:
		def.hut_hp = Data.HUT_HP - b
		await frames(3)
		await shot("6_hut_%d" % b)

	# The Dawn Market after a night.
	var Shop = load("res://scripts/shop.gd")
	var sh = Shop.new()
	sh.earned_coins = 14
	sh.earned_bones = 2
	Data.coins = 44
	Data.upgrades.erase("bone_mortar")
	add_child(sh)
	await frames(20)
	await shot("10_market")
	sh.try_buy("bone_mortar")
	await frames(12)
	await shot("10_market_bought")
	sh.queue_free()

	# A mid-game unlock screen: Scarlet Elf Cup on night 6 (Frost becomes possible).
	main.queue_free()
	await frames(2)
	Data.day = 6
	var Unlock = load("res://scripts/unlock.gd")
	var un = Unlock.new()
	un.ids = Data.new_mushrooms(6)
	add_child(un)
	await frames(60)
	await shot("7_unlock_night6")
	un.queue_free()

	# Late game forest (night 33): all 15 mushrooms in the basket.
	await frames(2)
	Data.day = 33
	var late = Forage.new()
	add_child(late)
	late.items.append({"id": "ghost_fungus", "pos": Vector2(470, 640), "age": 0.5, "life": 3.0, "ph": 0.0})
	late.items.append({"id": "parasol", "pos": Vector2(200, 880), "age": 0.8, "life": 4.0, "ph": 0.3})
	late.items.append({"id": "chicken_of_the_woods", "pos": Vector2(560, 950), "age": 0.8, "life": 4.0, "ph": 0.6})
	late._hit_obstacle(late.obstacles[1])
	late._hit_obstacle(late.obstacles[1])
	await frames(40)
	await shot("5_forage_late")

	# Field Guide: the grid with everything found, then a page with a lookalike warning.
	var Guide = load("res://scripts/guide.gd")
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var g = Guide.new()
	layer.add_child(g)
	g.open()
	await frames(4)
	await shot("8_guide_grid")
	g.open("morel")
	await frames(20)
	await shot("9_guide_morel")
	g.open("lions_mane")
	await frames(20)
	await shot("9_guide_lions_mane")
	get_tree().quit()
