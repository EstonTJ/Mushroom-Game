extends Node
## Stress test: plays every night from 1 to 40 with random taps on every
## screen, letting real frames run so drawing code is exercised too. Any
## SCRIPT ERROR or ERROR printed while it runs is a bug. Run headless:
##   Godot --headless --path . --quit-after 200000 res://tests/fuzz_test.tscn

var rng := RandomNumberGenerator.new()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func rand_point() -> Vector2:
	return Vector2(rng.randf_range(0, 720), rng.randf_range(110, 1280))


func _ready() -> void:
	Data.clear_save()
	rng.seed = 1234
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await frames(2)
	var night := 1
	var days_played := 0
	while night <= Data.NIGHTS and days_played < 80:
		days_played += 1
		Data.day = night
		print("night %d" % night)
		# Forest: tap rocks, stumps, mushrooms and random ground.
		var forage = main.phase_node
		for k in 30:
			if rng.randf() < 0.6 and forage.items.size() > 0:
				forage.tap_at(forage.items[rng.randi() % forage.items.size()]["pos"])
			elif rng.randf() < 0.5 and forage.obstacles.size() > 0:
				forage.tap_at(forage.obstacles[rng.randi() % forage.obstacles.size()]["pos"])
			else:
				forage.tap_at(rand_point())
			await frames(1)
		for id in Data.ingredient_order:
			Data.inventory[id] += rng.randi_range(0, 3)
		forage.time_left = 0.0
		await frames(3)

		# Cauldron: random pairs, random pop timing, sometimes empty the pot or flip pages.
		var brew = main.phase_node
		for k in 12:
			var unlocked := Data.unlocked_mushrooms()
			for j in 2:
				var id: String = unlocked[rng.randi() % unlocked.size()]
				brew._on_press(brew.slot_center(Data.ingredient_order.find(id)))
				await frames(1)
				brew._on_release(brew.POT if rng.randf() < 0.9 else rand_point())
			if rng.randf() < 0.1:
				brew._on_press(brew.EMPTY_BTN.get_center())
			if rng.randf() < 0.3:
				brew._on_press(brew.PAGE_NEXT.get_center() if rng.randf() < 0.5 else brew.PAGE_PREV.get_center())
			var guard := 0
			while brew.brewing() and guard < 200:
				guard += 1
				await frames(1)
				if not brew.bubble.is_empty() and rng.randf() < 0.25:
					brew._on_press(brew.POT)
					brew._on_release(brew.POT)
			await frames(1)
		main._on_action()
		await frames(3)

		# Fortify: random bottles on random spots, the hut and empty ground.
		var def = main.phase_node
		for k in 15:
			var items: Array = def._bar_items()
			if items.size() > 0:
				def.selected = items[rng.randi() % items.size()]
			var roll := rng.randf()
			if roll < 0.5:
				def._fortify_tap(def.slots[rng.randi() % def.slots.size()]["pos"])
			elif roll < 0.7:
				def._fortify_tap(def.HUT)
			else:
				def._bar_tap(Vector2(rng.randf_range(0, 720), def.BAR_Y + 60))
			await frames(1)
		main._on_action()

		# Night: step the simulation, throwing and placing at random.
		var steps := 0
		while not def.over and steps < 6000:
			def._night_step(0.05)
			steps += 1
			if steps % 20 == 0:
				var items: Array = def._bar_items()
				if items.size() > 0 and rng.randf() < 0.5:
					def.selected = items[rng.randi() % items.size()]
					var target: Vector2 = def.enemies[0]["pos"] if def.enemies.size() > 0 else rand_point()
					if rng.randf() < 0.3:
						target = def.slots[rng.randi() % def.slots.size()]["pos"]
					def._night_tap(target)
				if rng.randf() < 0.2:
					def._bar_tap(Vector2(20 if rng.randf() < 0.5 else 700, def.BAR_Y + 60))
				await frames(1)
		await frames(2)
		print("  night %d: %s, hut %d/%d, %d steps, memory %.1f MB, %d nodes, %d objects" % [night, "won" if def.hut_hp > 0 else "lost",
			maxi(def.hut_hp, 0), Data.HUT_HP, steps, OS.get_static_memory_usage() / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)])
		if main.phase != "result":
			print("  ERROR: night did not finish (phase %s)" % main.phase)
			break
		var lost: bool = def.hut_hp <= 0
		main._on_action()
		await frames(3)
		if lost:
			# Retry keeps the same night; top up bottles so the run keeps moving.
			for id in Data.potion_order:
				Data.bottles[id] += 3 if Data.potion_night(id) <= night else 0
		else:
			night += 1
	print("FUZZ DONE after %d days, reached night %d" % [days_played, night])
	get_tree().quit()
