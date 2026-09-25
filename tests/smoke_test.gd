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
	def.selected = "ember"
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

	print("DONE: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
