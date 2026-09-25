extends Node
## Plays through a day with scripted taps, then checks the rules for mushrooms,
## potions and creatures directly, and prints PASS/FAIL for each.
## Run headless from the project folder:
##   Godot --headless --path . --quit-after 3000 res://tests/smoke_test.tscn

const Defense = preload("res://scripts/defense.gd")
const Forage = preload("res://scripts/forage.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func brew_pair(brew, a: String, b: String) -> void:
	for id in [a, b]:
		brew._on_press(brew.slot_center(Data.ingredient_order.find(id)))
		brew._on_release(brew.POT)
	brew._on_press(brew.POT + Vector2(120, 0))
	for k in 120:
		brew._on_stir(brew.POT + Vector2(120, 0).rotated(k * 0.3))
	brew._on_release(brew.POT)


## A night-map node for rule checks: night mode, nothing left to spawn.
func night_map(day: int) -> Node:
	Data.day = day
	var d = Defense.new()
	add_child(d)
	d.mode = "night"
	d.spawned = d.cfg["count"]
	return d


func _ready() -> void:
	# --- Mushroom unlock schedule --------------------------------------------
	var counts := []
	for n in [1, 2, 3, 5, 6, 9, 32, 33]:
		counts.append(Data.unlocked_mushrooms(n).size())
	check(counts == [3, 4, 5, 5, 6, 7, 14, 15], "unlocks: 3 on night 1, 4 on night 2, 5 on night 3, then +1 every 3 nights (got %s)" % str(counts))
	check(Data.unlock_night("ghost_fungus") == 2 and Data.unlock_night("shaggy_ink_cap") == 3
		and Data.unlock_night("scarlet_elf_cup") == 6 and Data.unlock_night("bleeding_tooth") == 33,
		"Ghost Fungus night 2, Ink Cap night 3, Elf Cup night 6, Bleeding Tooth night 33")
	check(Data.potion_night("ward") == 2 and Data.potion_night("roar") == 30 and Data.potion_night("spore") == 1,
		"potions become brewable when their mushrooms unlock")
	var every_pair_unique := true
	var seen := {}
	for id in Data.potion_order:
		for r in Data.potions[id]["recipes"]:
			var key := "+".join([r[0], r[1]] if r[0] < r[1] else [r[1], r[0]])
			if seen.has(key):
				every_pair_unique = false
			seen[key] = true
			if not (Data.ingredients.has(r[0]) and Data.ingredients.has(r[1])):
				every_pair_unique = false
	check(every_pair_unique, "every recipe uses real mushroom ids and no pair makes two potions")

	# --- One full day, played through the screens ----------------------------
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await frames(3)
	check(main.phase == "forage", "starts on forage")
	var forage = main.phase_node
	var only_unlocked := true
	for it in forage.items:
		if not Data.is_unlocked(it["id"]):
			only_unlocked = false
	for i in 60:
		if not Data.is_unlocked(forage._pick()):
			only_unlocked = false
	check(only_unlocked and forage.items.size() >= 3, "forage only offers unlocked mushrooms")
	check(forage.obstacles.size() >= 3, "rocks and stumps are placed on the walk")
	var rock: Dictionary = forage.obstacles[0]
	rock["hidden"] = "chanterelle"
	var hits_needed: int = rock["hp"]
	var before: int = forage.items.size()
	for i in hits_needed - 1:
		forage._hit_obstacle(rock)
	var still_there: bool = not rock["gone"]
	forage._hit_obstacle(rock)
	check(still_there and rock["gone"] and forage.items.size() == before + 1 and forage.items[-1]["id"] == "chanterelle",
		"a rock or stump takes %d taps, then reveals the mushroom under it" % hits_needed)
	forage.time_left = 0.0
	await frames(5)
	check(main.phase == "brew", "forage timer moves on to brew")

	for id in Data.ingredient_order:
		Data.inventory[id] = 4
	var brew = main.phase_node
	brew_pair(brew, "puffball", "fly_agaric")
	brew_pair(brew, "chanterelle", "puffball")
	brew_pair(brew, "fly_agaric", "chanterelle")
	brew_pair(brew, "puffball", "puffball")
	await frames(2)
	for id in ["spore", "syrup", "ember"]:
		check(Data.bottles[id] == 1 and Data.discovered.has(id), "brewed and discovered " + id)
	check(Data.inventory["puffball"] == 0, "sludge used up its mushrooms (puffball 4 -> 0)")
	brew._on_press(brew.slot_center(Data.ingredient_order.find("ghost_fungus")))
	check(brew.dragging == "", "a locked mushroom's jar can't be used")
	brew._on_release(brew.POT)
	brew._on_press(brew.slot_center(Data.ingredient_order.find("chanterelle")))
	brew._on_release(brew.POT)
	main._on_action()
	await frames(2)
	check(main.phase == "fortify" and Data.inventory["chanterelle"] == 2, "fortify; the pot is emptied back onto the shelf")

	var def = main.phase_node
	Data.bottles["ward"] = 1
	def.selected = "spore"
	def._fortify_tap(def.slots[1]["pos"])
	def.selected = "syrup"
	def._fortify_tap(def.slots[4]["pos"])
	def.selected = "ward"
	def._fortify_tap(def.HUT)
	check(def.slots[1]["trap"] == "spore" and def.slots[4]["trap"] == "syrup", "traps placed")
	check(def.ward == 3 and Data.bottles["ward"] == 0, "ward on the hut")
	def._fortify_tap(def.slots[4]["pos"])
	check(def.slots[4]["trap"] == "" and Data.bottles["syrup"] == 1, "tap a placed trap to take it back")

	main._on_action()
	await frames(2)
	check(main.phase == "night", "night starts")
	def.selected = "syrup"
	def._night_tap(def.slots[4]["pos"])
	check(def.slots[4]["trap"] == "syrup" and Data.bottles["syrup"] == 0, "night: place a trap on an empty spot")
	def.selected = "ember"
	def._night_tap(def.slots[1]["pos"])
	check(def.slots[1]["trap"] == "spore" and Data.bottles["ember"] == 1 and def.areas.is_empty(),
		"night: tapping an occupied spot does nothing")
	var thrown := false
	var steps := 0
	while not def.over and steps < 5000:
		def._night_step(0.05)
		if not thrown and def.enemies.size() > 0 and def.enemies[0]["offset"] > 100.0:
			def._night_tap(def.enemies[0]["pos"])
			thrown = true
		steps += 1
	await frames(2)
	check(def.over, "night ends (%d steps, %.0f s of game time)" % [steps, steps * 0.05])
	check(thrown and Data.bottles["ember"] == 0, "ember thrown")
	print("      night 1 result: phase=%s hut=%d/%d ward=%d repelled=%d/%d" % [main.phase, def.hut_hp,
		Data.HUT_HP, def.ward, def.repelled, def.cfg["count"]])
	if main.phase == "result" and def.hut_hp > 0:
		main._on_action()
		await frames(2)
		check(Data.day == 2 and main.phase == "forage", "next day begins")
	main.queue_free()
	await frames(1)

	# --- Nights grow: more creatures, new types easing in --------------------
	var n1 := Data.night_config(1)
	var n12 := Data.night_config(12)
	var n40 := Data.night_config(40)
	check(n1["waves"].size() == 1 and n1["waves"]["mischief"] == 6, "night 1 is 6 Mischief")
	check(n12["waves"].has("scuttler") and n12["waves"].has("moth") and n12["waves"].has("stumpling"),
		"by night 12 all four creature types come")
	var total40 := 0
	for k in n40["waves"]:
		total40 += n40["waves"][k]
	check(total40 > 20 and n40["courage"] > n1["courage"], "night 40 is bigger and braver (%d creatures)" % total40)

	# --- Creature rules --------------------------------------------------------
	var d = night_map(12)
	var c1: Curve2D = d.curves[1]
	var trap_moth: Dictionary = d._make_enemy("moth", 0)
	trap_moth["pos"] = d.slots[0]["pos"]
	trap_moth["offset"] = d.curves[0].get_baked_length() * 0.3
	d.slots[0]["trap"] = "spore"
	var imp: Dictionary = d._make_enemy("mischief", 1)
	var stump: Dictionary = d._make_enemy("stumpling", 1)
	var moth: Dictionary = d._make_enemy("moth", 1)
	for e in [imp, stump, moth]:
		e["offset"] = 300.0
		e["pos"] = c1.sample_baked(300.0)
	d._spawn_area("syrup", c1.sample_baked(300.0))
	d.enemies = [trap_moth, imp, stump, moth]
	d._night_step(0.2)
	check(not d.slots[0]["triggered"], "moths fly over traps without setting them off")
	check(imp["offset"] == 300.0 and imp["stuck"], "syrup holds a mischief in place")
	check(stump["offset"] > 300.0 and stump["offset"] < 300.0 + stump["speed"] * 0.2 * 0.6,
		"syrup only slows a stumpling (too heavy to stick)")
	check(is_equal_approx(moth["offset"], 300.0 + moth["speed"] * 0.2), "moths ignore syrup")

	# Ink Pool holds even a stumpling; Frost stops a moth; Befuddle walks them back.
	d.areas = []
	for e in [stump, moth, imp]:
		e["offset"] = 300.0
		e["pos"] = c1.sample_baked(300.0)
		e["courage"] = 99.0
	d.enemies = [stump]
	d._spawn_area("ink_pool", c1.sample_baked(300.0))
	d._night_step(0.2)
	check(stump["offset"] == 300.0, "Ink Pool holds even a stumpling")
	d.areas = []
	d.enemies = [moth]
	d._spawn_area("frost", c1.sample_baked(300.0))
	d._night_step(0.2)
	check(moth["offset"] == 300.0 and moth["frozen"], "Frost freezes a flying moth")
	d.areas = []
	d.enemies = [imp]
	d._spawn_area("befuddle", c1.sample_baked(300.0))
	d._night_step(0.2)
	check(imp["offset"] < 300.0 and imp["confused"], "Befuddle makes creatures walk backwards")

	var hitter: Dictionary = d._make_enemy("stumpling", 1)
	hitter["offset"] = c1.get_baked_length() - 0.1
	d.enemies = [hitter]
	d.areas = []
	d.ward = 1
	d.hut_hp = 5
	d._night_step(0.2)
	check(d.ward == 0 and d.hut_hp == 4, "a stumpling costs two hits (one warded, one to the hut)")

	# Hut potions and the roar.
	Data.bottles["mend"] = 2
	d.selected = "mend"
	d._night_tap(Vector2(100, 400))
	check(d.hut_hp == 5 and Data.bottles["mend"] == 1, "Mending Milk repairs the hut")
	d._night_tap(Vector2(100, 400))
	check(Data.bottles["mend"] == 1, "Mending Milk isn't wasted on a whole hut")
	Data.bottles["great_ward"] = 1
	d.selected = "great_ward"
	d._night_tap(Vector2(100, 400))
	check(d.ward == 5, "Great Ward blocks 5 hits")
	var a1: Dictionary = d._make_enemy("mischief", 0)
	var a2: Dictionary = d._make_enemy("scuttler", 1)
	a1["courage"] = 3.0
	a2["courage"] = 3.0
	d.enemies = [a1, a2]
	Data.bottles["roar"] = 1
	d.selected = "roar"
	d._night_tap(Vector2(600, 300))
	check(a1["courage"] == 1.0 and a2["courage"] == 1.0 and Data.bottles["roar"] == 0,
		"Lion's Roar scares every creature on the map")
	d.selected = ""

	# Bottle bar pages when there are many kinds.
	for id in Data.potion_order:
		Data.bottles[id] = 1
	var lay: Dictionary = d._bar_layout()
	check(lay["paged"] and lay["shown"].size() == d.BAR_MAX - 1 and lay["pages"] == 3,
		"bottle bar pages through %d kinds of bottle" % Data.potion_order.size())
	d.queue_free()

	print("DONE: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
