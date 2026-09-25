extends Node
## Plays through one full day with scripted taps and prints what happened.
## Run headless from the project folder:
##   Godot --headless --path . res://tests/smoke_test.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await frames(3)
	check(main.phase == "forage", "starts on forage")

	# Forage: let the timer run out. (Tapping needs a real pointer; test by hand.)
	var forage = main.phase_node
	check(forage.items.size() >= 3, "forage shows ingredients")
	forage.time_left = 0.0
	await frames(5)
	check(main.phase == "brew", "forage timer moves on to brew")

	# Brew every recipe plus one sludge.
	for id in Data.ingredient_order:
		Data.inventory[id] = 4
	var brew = main.phase_node
	var pairs := [["puffcap", "dewmoss"], ["honeyroot", "dewmoss"], ["emberleaf", "puffcap"],
		["moonglow", "honeyroot"], ["puffcap", "honeyroot"]]
	for pair in pairs:
		for id in pair:
			var i: int = Data.ingredient_order.find(id)
			brew._on_press(Vector2(brew.SLOT_W * i + 72, 220))
			brew._on_release(brew.POT)
		brew._on_press(brew.POT + Vector2(120, 0))
		for k in 120:
			brew._on_stir(brew.POT + Vector2(120, 0).rotated(k * 0.3))
		brew._on_release(brew.POT)
		await frames(2)
	for id in ["spore", "syrup", "ember", "ward"]:
		check(Data.bottles[id] == 1 and Data.discovered.has(id), "brewed and discovered " + id)
	check(Data.inventory["puffcap"] == 1, "sludge used up its ingredients (puffcap 4 -> 1)")

	# Leftover in the pot goes back on the shelf when leaving.
	brew._on_press(Vector2(brew.SLOT_W * 2 + 72, 220))
	brew._on_release(brew.POT)
	main._on_action()
	await frames(2)
	# dewmoss: 4, minus 1 for spore and 1 for syrup = 2 (the one left in the pot comes back).
	check(main.phase == "fortify" and Data.inventory["dewmoss"] == 2, "fortify; pot returned to shelf")

	# Fortify: spore trap on the left path, syrup on the right, ward on the hut.
	var def = main.phase_node
	def.selected = "spore"
	def._fortify_tap(def.slots[1]["pos"])
	def.selected = "syrup"
	def._fortify_tap(def.slots[4]["pos"])
	def.selected = "ward"
	def._fortify_tap(def.HUT)
	check(def.slots[1]["trap"] == "spore" and def.slots[4]["trap"] == "syrup", "traps placed")
	check(def.ward == 3 and Data.bottles["ward"] == 0, "ward on the hut")
	def._fortify_tap(def.slots[4]["pos"])
	check(def.slots[4]["trap"] == "" and Data.bottles["syrup"] == 1, "tap a placed trap takes it back")

	# Night: simulate in fixed steps, throw the ember at the first creature.
	main._on_action()
	await frames(2)
	check(main.phase == "night", "night starts")
	# Placing during the night: an empty spot takes the bottle as a trap...
	def.selected = "syrup"
	def._night_tap(def.slots[4]["pos"])
	check(def.slots[4]["trap"] == "syrup" and Data.bottles["syrup"] == 0, "night: place a trap on an empty spot")
	# ...a spot still holding an unburst trap ignores the tap (no accidental throw).
	def.selected = "ember"
	def._night_tap(def.slots[1]["pos"])
	check(def.slots[1]["trap"] == "spore" and Data.bottles["ember"] == 1 and def.areas.is_empty(),
		"night: tapping an occupied spot does nothing")
	var thrown := false
	var reused := false
	var steps := 0
	while not def.over and steps < 5000:
		def._night_step(0.05)
		if not thrown and def.enemies.size() > 0 and def.enemies[0]["offset"] > 100.0:
			def._night_tap(def.enemies[0]["pos"])
			thrown = true
		# ...and a spot whose trap already burst can take a new one.
		if thrown and not reused and def.slots[1]["triggered"]:
			Data.bottles["spore"] += 1
			def.selected = "spore"
			def._night_tap(def.slots[1]["pos"])
			check(def.slots[1]["trap"] == "spore" and not def.slots[1]["triggered"] and Data.bottles["spore"] == 0,
				"night: re-arm a spot after its trap burst")
			reused = true
		steps += 1
	await frames(2)
	check(def.over, "night ends (%d steps, %.0f s of game time)" % [steps, steps * 0.05])
	check(thrown and Data.bottles["ember"] == 0, "ember thrown")
	check(reused, "a burst spot was re-armed during the night")
	print("      night 1 result: phase=%s hut=%d/%d ward=%d repelled=%d/%d" % [main.phase, def.hut_hp,
		Data.HUT_HP, def.ward, def.repelled, def.cfg["count"]])

	if main.phase == "result" and def.hut_hp > 0:
		main._on_action()
		await frames(2)
		check(Data.day == 2 and main.phase == "forage", "next day begins")

	# Creature types: night 3 brings all four, each with its own rule.
	Data.day = 3
	var d3 = load("res://scripts/defense.gd").new()
	add_child(d3)
	await frames(1)
	check(d3.cfg["count"] == 16 and d3.queue.count("moth") == 3 and d3.queue.count("stumpling") == 4,
		"night 3 roster: 16 creatures incl. 3 moths and 4 stumplings")
	d3.mode = "night"
	d3.spawned = d3.cfg["count"]
	var c1: Curve2D = d3.curves[1]
	var trap_moth: Dictionary = d3._make_enemy("moth", 0)
	trap_moth["pos"] = d3.slots[0]["pos"]
	trap_moth["offset"] = d3.curves[0].get_baked_length() * 0.3
	d3.slots[0]["trap"] = "spore"
	var imp: Dictionary = d3._make_enemy("mischief", 1)
	var stump: Dictionary = d3._make_enemy("stumpling", 1)
	var moth: Dictionary = d3._make_enemy("moth", 1)
	for e in [imp, stump, moth]:
		e["offset"] = 300.0
		e["pos"] = c1.sample_baked(300.0)
	d3._spawn_area("syrup", c1.sample_baked(300.0))
	d3.enemies = [trap_moth, imp, stump, moth]
	d3._night_step(0.2)
	check(not d3.slots[0]["triggered"], "moths fly over traps without setting them off")
	check(imp["offset"] == 300.0 and imp["stuck"], "syrup holds a mischief in place")
	check(stump["offset"] > 300.0 and stump["offset"] < 300.0 + stump["speed"] * 0.2 * 0.6,
		"syrup only slows a stumpling (too heavy to stick)")
	check(is_equal_approx(moth["offset"], 300.0 + moth["speed"] * 0.2), "moths ignore syrup")
	var hitter: Dictionary = d3._make_enemy("stumpling", 1)
	hitter["offset"] = c1.get_baked_length() - 0.1
	d3.enemies = [hitter]
	d3.areas = []
	d3.ward = 1
	d3.hut_hp = 5
	d3._night_step(0.2)
	check(d3.ward == 0 and d3.hut_hp == 4, "a stumpling costs two hits (one warded, one to the hut)")
	d3.queue_free()

	print("DONE: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
