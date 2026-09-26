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


## Drop two mushrooms in, then pop the three bubbles: "perfect" taps each as
## it fills the ring, "early" taps each too soon, "none" lets them burst.
func brew_pair(brew, a: String, b: String, how: String = "perfect") -> void:
	for id in [a, b]:
		brew._on_press(brew.slot_center(Data.ingredient_order.find(id)))
		brew._on_release(brew.POT)
	for k in brew.BUBBLES:
		brew._bubble_step(1.0)
		if how == "none":
			brew._bubble_step(2.0)
			continue
		brew.bubble["f"] = 0.85 if how == "perfect" else 0.3
		brew._on_press(brew.POT)
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
	Data.clear_save()
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
	var complete := true
	for id in Data.ingredient_order:
		var info: Dictionary = Data.ingredients[id]
		for key in ["name", "latin", "edibility", "where", "season", "habitat"]:
			if str(info.get(key, "")) == "":
				complete = false
		if info.get("facts", []).size() != 2 or info.get("sources", []).size() < 1:
			complete = false
	check(complete and Data.kingdom_facts.size() == 12, "every mushroom has a full, sourced Field Guide entry; 12 fungi facts")

	# --- One full day, played through the screens ----------------------------
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await frames(3)
	check(main.phase == "title" and not main.hud_layer.visible and main.phase_node.buttons() == ["new", "guide"],
		"the game opens on the title screen (no save: New game and Field Guide)")
	main.phase_node.tap(main.phase_node.button_rect(0).get_center())
	await frames(2)
	check(main.phase == "unlock" and main.phase_node.ids.size() == 3 and main.hud_layer.visible,
		"New game opens on the unlock screen with 3 mushrooms")
	main._on_action()
	main._on_action()
	check(main.phase == "unlock" and not main.phase_node.has_next(), "Next steps through the mushroom cards")
	main._on_action()
	await frames(2)
	check(main.phase == "forage" and Data.unlock_seen == 1, "Start day goes to the forest")

	# Field Guide: pauses the game, opens pages for found mushrooms only.
	main.open_guide()
	var guide = main.guide
	check(get_tree().paused and guide.visible and guide.found_count() == 3, "the Field Guide opens, pauses the game and shows 3 found")
	guide.tap(guide.tile_rect(Data.ingredient_order.find("ghost_fungus")).get_center())
	check(guide.page == "", "a locked mushroom has no page yet")
	guide.tap(guide.tile_rect(Data.ingredient_order.find("fly_agaric")).get_center())
	check(guide.page == "fly_agaric", "tapping a found mushroom opens its page")
	await frames(2)
	guide.tap(guide.BACK.get_center())
	var before_fact: int = guide.fact_index
	guide.tap(guide.FACT_BOX.get_center())
	check(guide.page == "" and (Data.kingdom_facts.size() < 2 or guide.fact_index != before_fact), "Back returns to the grid; tapping the fact box shows another")
	guide.tap(guide.CLOSE.get_center())
	check(not get_tree().paused and not guide.visible, "closing the Field Guide unpauses the game")
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
	brew_pair(brew, "puffball", "fly_agaric", "perfect")
	check(Data.bottles["spore"] == 2 and Data.discovered.has("spore"), "three Perfect bubble pops make 2 bottles (Spore Cloud)")
	brew_pair(brew, "chanterelle", "puffball", "early")
	check(Data.bottles["syrup"] == 1 and brew.results.is_empty(), "early pops still brew 1 bottle (Sticky Syrup)")
	brew_pair(brew, "fly_agaric", "chanterelle", "none")
	check(Data.bottles["ember"] == 1 and Data.discovered.has("ember"), "bubbles left to burst still brew 1 bottle (Ember Burst)")
	# Bellows: slower bubbles and an earlier Perfect window.
	check(brew.bubble_time() == brew.BUBBLE_TIME and brew.perfect_from() == brew.PERFECT_FROM, "no Bellows: normal bubbles")
	Data.upgrades["bellows"] = true
	check(brew.bubble_time() > brew.BUBBLE_TIME and brew.perfect_from() < brew.PERFECT_FROM,
		"Bellows: bubbles swell slower and Perfect starts earlier")
	Data.upgrades.erase("bellows")
	# Everburning Coals: some Perfect brews make 3 bottles.
	Data.upgrades["everburning_coals"] = true
	seed(4)
	var made_counts := {}
	for i in 12:
		Data.inventory["puffball"] = 4
		Data.inventory["fly_agaric"] = 4
		var before_spore: int = Data.bottles["spore"]
		brew_pair(brew, "puffball", "fly_agaric", "perfect")
		made_counts[Data.bottles["spore"] - before_spore] = true
	check(made_counts.has(3) and made_counts.has(2) and made_counts.size() == 2,
		"Everburning Coals: a Perfect brew sometimes makes 3 bottles, otherwise 2")
	Data.upgrades.erase("everburning_coals")
	Data.inventory["puffball"] = 2
	Data.bottles["spore"] = 2
	brew_pair(brew, "puffball", "puffball", "perfect")
	await frames(2)
	check(Data.inventory["puffball"] == 0, "sludge used up its mushrooms (puffball 2 -> 0)")
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
	check(def.coins_earned > 0 and Data.coins == def.coins_earned, "scaring creatures off earns coins (%d)" % def.coins_earned)
	if main.phase == "result" and def.hut_hp > 0:
		var night_repelled: int = def.repelled
		var night_coins: int = def.coins_earned
		main._on_action()
		await frames(2)
		check(Data.day == 2 and main.phase == "dawn", "a won night leads to the dawn stats page, not straight to the market")
		check(main.phase_node.stats.get("night", 0) == 1 and main.phase_node.stats.get("repelled", -1) == night_repelled
			and main.phase_node.stats.get("coins", -1) == night_coins, "the dawn page shows the night's numbers")
		check(Data.load_game() and Data.saved_phase == "dawn" and Data.last_night.get("night", 0) == 1,
			"the dawn page is saved, with its stats, so a reload comes back to it")
		main.phase_node.tap(main.phase_node.MARKET_BTN.get_center())
		await frames(2)
		check(Data.day == 2 and main.phase == "market", "the dawn page's Market button opens the Dawn Market")
		var mk = main.phase_node
		Data.coins = 10
		check(not mk.try_buy("bone_mortar") and Data.coins == 10, "the Bone Mortar can't be bought without enough coins")
		Data.coins = 45
		check(mk.try_buy("bone_mortar") and Data.coins == 15 and Data.upgrades.has("bone_mortar"), "buying the Bone Mortar costs 30 coins")
		check(Data.load_game() and Data.upgrades.has("bone_mortar") and Data.coins == 15 and Data.saved_phase == "market",
			"the purchase is saved, and a reload resumes at the market")
		main._on_action()
		await frames(2)
		check(Data.day == 2 and main.phase == "unlock" and main.phase_node.current() == "ghost_fungus",
			"after the night, day 2 opens on the Ghost Fungus unlock screen")
		check(main.phase_node.new_brews() == ["ward"], "the unlock screen teases the new brew it makes possible")
		var reloaded := Data.load_game()
		check(reloaded and Data.day == 2 and Data.unlock_seen == 1, "the won night is saved before the unlock screen")
		main._on_action()
		await frames(2)
		check(main.phase == "forage", "then the forest")

		# Bones in the lab: with the Bone Mortar, a bone in the pot makes an Empowered potion.
		main.phase_node.time_left = 0.0
		await frames(3)
		var lab = main.phase_node
		Data.bones = 2
		Data.inventory["puffball"] = 2
		Data.inventory["fly_agaric"] = 2
		lab._on_press(lab.BONE_BOWL)
		lab._on_release(lab.POT)
		check(lab.pot_bone and Data.bones == 1, "a bone can be dragged into the cauldron")
		var spore_plus: int = Data.bottles["spore+"]
		brew_pair(lab, "puffball", "fly_agaric", "early")
		check(Data.bottles["spore+"] == spore_plus + 1 and not lab.pot_bone, "the brew comes out Empowered (Spore Cloud+)")
		var plain: Dictionary = Data.potion_stats("spore")
		var boosted: Dictionary = Data.potion_stats("spore+")
		check(boosted["radius"] > plain["radius"] and boosted["duration"] > plain["duration"] and boosted["dps"] > plain["dps"],
			"an Empowered potion is bigger, longer and stronger")
		check(Data.potion_stats("great_ward+")["ward"] == 7 and Data.potion_stats("mend+")["heal"] == 3, "Empowered wards and mends do more")
		lab._on_press(lab.BONE_BOWL)
		lab._on_release(lab.POT)
		lab.return_pot()
		check(Data.bones == 1 and not lab.pot_bone, "emptying the pot gives the bone back")

		# Bone Appétit: needs the Bone Mortar, then loads a bone into every brew by itself.
		Data.upgrades.erase("bone_mortar")
		Data.coins = 200
		check(not Data.buy("bone_appetit") and Data.coins == 200, "the Bone Appétit needs the Bone Mortar first")
		Data.upgrades["bone_mortar"] = true
		check(Data.buy("bone_appetit") and Data.coins == 140, "the Bone Appétit costs 60 coins")
		Data.bones = 2
		Data.inventory["puffball"] = 3
		Data.inventory["fly_agaric"] = 3
		var plus_before: int = Data.bottles["spore+"]
		brew_pair(lab, "puffball", "fly_agaric", "early")
		check(Data.bones == 1 and Data.bottles["spore+"] == plus_before + 1, "with the Bone Appétit, a bone goes in by itself")
		lab._on_press(lab.auto_switch_rect().get_center())
		check(not Data.auto_bone, "the switch on the bone bowl turns it off")
		var plain_before: int = Data.bottles["spore"]
		brew_pair(lab, "puffball", "fly_agaric", "early")
		check(Data.bones == 1 and Data.bottles["spore"] == plain_before + 1, "switched off, bones are saved")
		lab._on_press(lab.auto_switch_rect().get_center())
		Data.bones = 0
		brew_pair(lab, "puffball", "fly_agaric", "early")
		check(Data.bones == 0 and Data.bottles["spore"] == plain_before + 2, "with no bones left it brews a normal potion")

		# Loader of Mass Production: brew up to 5 at once.
		Data.coins = 100
		check(Data.buy("batch_brewer") and Data.coins == 0, "the Loader of Mass Production costs 100 coins")
		Data.auto_bone = false
		Data.batch = 1
		for k in 4:
			lab._on_press(lab.batch_rect().position + Vector2(lab.batch_rect().size.x - 10, 20))
		check(Data.batch == 5, "the batch dial goes up to 5")
		lab._on_press(lab.batch_rect().position + Vector2(10, 20))
		lab._on_press(lab.batch_rect().position + Vector2(10, 20))
		check(Data.batch == 3, "and back down")
		Data.inventory["puffball"] = 5
		Data.inventory["fly_agaric"] = 5
		var sp: int = Data.bottles["spore"]
		brew_pair(lab, "puffball", "fly_agaric", "early")
		check(Data.bottles["spore"] == sp + 3 and Data.inventory["puffball"] == 2 and Data.inventory["fly_agaric"] == 2,
			"a batch of 3 makes 3 potions from 3 of each mushroom")
		Data.inventory["puffball"] = 5
		Data.inventory["fly_agaric"] = 5
		sp = Data.bottles["spore"]
		brew_pair(lab, "puffball", "fly_agaric", "perfect")
		check(Data.bottles["spore"] == sp + 6, "a Perfect batch of 3 makes 6")
		Data.batch = 5
		Data.inventory["puffball"] = 2
		Data.inventory["fly_agaric"] = 4
		sp = Data.bottles["spore"]
		brew_pair(lab, "puffball", "fly_agaric", "early")
		check(Data.bottles["spore"] == sp + 2 and Data.inventory["puffball"] == 0, "a batch shrinks to the mushrooms on hand")
		Data.batch = 4
		Data.inventory["puffball"] = 4
		Data.inventory["fly_agaric"] = 4
		Data.bones = 2
		var sp_plus: int = Data.bottles["spore+"]
		sp = Data.bottles["spore"]
		lab._on_press(lab.BONE_BOWL)
		lab._on_release(lab.POT)
		brew_pair(lab, "puffball", "fly_agaric", "early")
		check(Data.bottles["spore+"] == sp_plus + 2 and Data.bottles["spore"] == sp + 2 and Data.bones == 0,
			"with 2 bones, a batch of 4 makes 2 Empowered and 2 plain")
		Data.batch = 1
		Data.day = 4
		main._begin_day()
		await frames(1)
		check(main.phase == "forage", "a day with no new mushroom goes straight to the forest")
	main.queue_free()
	await frames(1)

	# --- Night maps ---------------------------------------------------------------
	var Def = load("res://scripts/defense.gd")
	var maps_ok := true
	var map_notes := []
	for li in Def.LAYOUTS.size():
		var lay: Dictionary = Def.LAYOUTS[li]
		var cs := []
		for pts in lay["paths"]:
			var c := Curve2D.new()
			for q in pts:
				c.add_point(q)
			cs.append(c)
		for a_i in cs.size():
			var ca: Curve2D = cs[a_i]
			var end: Vector2 = lay["paths"][a_i][-1]
			if end.distance_to(Def.HUT) > 110.0:
				maps_ok = false
				map_notes.append("%s path %d misses the hut" % [lay["name"], a_i])
			for q in ca.get_baked_points():
				if lay["pond"] != null and ((q - Vector2(lay["pond"])) / Vector2(170.0, 110.0)).length() < 1.0:
					maps_ok = false
					map_notes.append("%s path %d runs through the pond" % [lay["name"], a_i])
					break
			for b_i in range(a_i + 1, cs.size()):
				var cb: Curve2D = cs[b_i]
				for q in ca.get_baked_points():
					if q.distance_to(Def.HUT) > 200.0 and cb.get_closest_point(q).distance_to(q) < 100.0:
						maps_ok = false
						map_notes.append("%s paths %d and %d come too close" % [lay["name"], a_i, b_i])
						break
	check(maps_ok, "every night map: paths reach the hut, miss the pond and stay apart %s" % str(map_notes))
	var nights_differ := true
	for n in range(1, Data.NIGHTS):
		if Def.layout_for(n) == Def.layout_for(n + 1):
			nights_differ = false
	var early_two := true
	for n in range(1, 6):
		if Def.LAYOUTS[Def.layout_for(n)]["paths"].size() != 2:
			early_two = false
	check(nights_differ and early_two and Def.layout_for(1) == 0,
		"each night uses a different map from the night before; nights 1-5 have two paths")

	# Pace: slow in the mud and on bends, quicker on straights; flyers ignore it.
	Data.day = 1
	var dm = Def.new()
	add_child(dm)
	var mud: Dictionary = dm.muds[0]
	var walker := {"kind": "mischief", "path": mud["path"], "offset": mud["offset"]}
	var in_mud: float = dm.pace_at(walker)
	var p0: PackedFloat32Array = dm.pace[0]
	var lo := 9.0
	var hi := 0.0
	for v in p0:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var flyer := {"kind": "moth", "path": mud["path"], "offset": mud["offset"]}
	check(in_mud < 0.6 and hi > 1.1 and lo < 0.6 and dm.pace_at(flyer) == 1.0,
		"creatures wade slowly through mud (%.2f), slow on bends and speed up on straights (%.2f to %.2f); flyers don't" % [in_mud, lo, hi])
	dm.queue_free()

	# --- Truffle Pig ------------------------------------------------------------
	Data.upgrades.erase("truffle_pig")
	var f_nopig = Forage.new()
	add_child(f_nopig)
	check(f_nopig.pig.is_empty(), "no pig on the walk until it's bought")
	f_nopig.queue_free()
	Data.upgrades["truffle_pig"] = true
	var fp = Forage.new()
	add_child(fp)
	await frames(1)
	fp.items = [{"id": "chanterelle", "pos": Vector2(400, 700), "age": 1.0, "life": 99.0, "ph": 0.0}]
	fp.pig["rest"] = 0.0
	var ch_before: int = Data.inventory["chanterelle"]
	for i in 300:
		fp.pig_step(0.05)
		if fp.items.is_empty():
			break
	check(fp.items.is_empty() and Data.inventory["chanterelle"] == ch_before + 1 and fp.pig["rest"] > 0.0,
		"the Truffle Pig trots over, gathers the mushroom, then rests")
	# Golden Snout: the same walk takes fewer steps and the rest is shorter.
	var plain_steps := 0
	fp.items = [{"id": "chanterelle", "pos": Vector2(600, 300), "age": 1.0, "life": 99.0, "ph": 0.0}]
	fp.pig["pos"] = Vector2(120, 1020)
	fp.pig["rest"] = 0.0
	while not fp.items.is_empty() and plain_steps < 400:
		fp.pig_step(0.05)
		plain_steps += 1
	Data.upgrades["golden_snout"] = true
	var snout_steps := 0
	fp.items = [{"id": "chanterelle", "pos": Vector2(600, 300), "age": 1.0, "life": 99.0, "ph": 0.0}]
	fp.pig["pos"] = Vector2(120, 1020)
	fp.pig["rest"] = 0.0
	while not fp.items.is_empty() and snout_steps < 400:
		fp.pig_step(0.05)
		snout_steps += 1
	check(snout_steps < plain_steps * 0.75 and fp.pig["rest"] < fp.PIG_REST,
		"the Golden Snout pig is faster (%d steps vs %d) and rests less" % [snout_steps, plain_steps])
	Data.upgrades.erase("golden_snout")
	fp.queue_free()
	Data.upgrades.erase("truffle_pig")

	# --- Forest gear ------------------------------------------------------------
	var f_plain = Forage.new()
	add_child(f_plain)
	var plain_hp: Array = f_plain.obstacles.map(func(o): return o["max"] - (0 if o["kind"] == "rock" else 1))
	check(f_plain.time_left == 20.0 and plain_hp.all(func(h): return h == 3), "without gear: a 20 s walk, rocks 3 taps, stumps 4")
	f_plain.queue_free()
	Data.upgrades["foraging_basket"] = true
	Data.upgrades["rock_hammer"] = true
	var f_gear = Forage.new()
	add_child(f_gear)
	var gear_hp: Array = f_gear.obstacles.map(func(o): return o["max"] - (0 if o["kind"] == "rock" else 1))
	check(f_gear.time_left == 25.0 and gear_hp.all(func(h): return h == 2),
		"Foraging Basket makes the walk 25 s; Rock Hammer takes a tap off rocks and stumps")
	f_gear.queue_free()
	Data.upgrades.erase("foraging_basket")
	Data.upgrades.erase("rock_hammer")
	# Foxfire Lantern: a rare mushroom shimmers first, then appears.
	Data.upgrades["foxfire_lantern"] = true
	var f_fox = Forage.new()
	add_child(f_fox)
	await frames(1)
	f_fox.items.clear()
	f_fox.pending.clear()
	f_fox.rare_spawned = true
	var rare_id := ""
	for id in Data.ingredient_order:
		if Data.is_unlocked(id) and f_fox.is_rare(id):
			rare_id = id
	var shimmered := false
	if rare_id != "":
		f_fox.set_process(false)
		f_fox.spawn_timer = 99.0
		f_fox.pending.append({"id": rare_id, "pos": Vector2(360, 600), "life": 4.0, "t": f_fox.FOXFIRE_LEAD})
		f_fox._process(0.5)
		shimmered = f_fox.items.is_empty() and f_fox.pending.size() == 1
		f_fox._process(1.0)
	check(rare_id == "" or (shimmered and f_fox.items.size() == 1 and f_fox.items[0]["id"] == rare_id and f_fox.pending.is_empty()),
		"Foxfire Lantern: a rare mushroom shimmers for a moment, then appears (%s)" % rare_id)
	check(f_fox.is_rare("ghost_fungus") and not f_fox.is_rare("puffball"), "the ghost fungus counts as rare; the puffball doesn't")
	f_fox.queue_free()
	Data.upgrades.erase("foxfire_lantern")

	# The market pages when there are more wares than fit.
	var Shop3 = load("res://scripts/shop.gd")
	var sh3 = Shop3.new()
	add_child(sh3)
	check(sh3.pages() == 4 and sh3.page_items() == ["bone_mortar", "bellows", "rock_hammer"], "the market shows 3 wares a page")
	sh3.tap(sh3.PAGE_NEXT.get_center())
	sh3.tap(sh3.PAGE_NEXT.get_center())
	check(sh3.page == 2 and sh3.page_items() == ["truffle_pig", "golden_snout", "batch_brewer"], "the arrows turn to the page with the Truffle Pig")
	Data.coins = 80
	sh3.tap(sh3.buy_rect(0).get_center())
	check(Data.upgrades.has("truffle_pig") and Data.coins == 5, "the Truffle Pig costs 75 coins")
	Data.coins = 200
	Data.upgrades.erase("truffle_pig")
	check(not Data.buy("golden_snout") and Data.coins == 200, "the Golden Snout needs the Truffle Pig first")
	Data.upgrades["truffle_pig"] = true
	check(Data.buy("golden_snout") and Data.coins == 135, "the Golden Snout costs 65 coins")
	Data.upgrades.erase("truffle_pig")
	Data.upgrades.erase("golden_snout")
	sh3.queue_free()
	Data.upgrades.erase("truffle_pig")

	# --- Nights grow: more creatures, new types easing in --------------------
	var n1 := Data.night_config(1)
	var n12 := Data.night_config(12)
	var n40 := Data.night_config(40)
	check(n1["waves"].size() == 1 and n1["waves"]["mischief"] == 10, "night 1 is 10 Mischief")
	check([Data.night_count(1), Data.night_count(2), Data.night_count(3), Data.night_count(4), Data.night_count(5)] == [10, 15, 23, 34, 36],
		"10 on night 1, +50% for three nights (15, 23, 34), then +2 a night")
	check(Data.night_boss(3) == "mischief_king" and Data.night_boss(6) == "moth_queen" and Data.night_boss(9) == "elder_stumpling"
		and Data.night_boss(12) == "mischief_king" and Data.night_boss(4) == "", "a boss every 3rd night, taking turns")
	check(Data.night_config(12)["waves"].has("thornback") and Data.night_config(21)["waves"].has("troll")
		and not Data.night_config(11)["waves"].has("thornback"), "harder creature types arrive over time")
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

	# Thornback armour halves bursts; wisps ignore spores; pufflings split.
	var thorn: Dictionary = d._make_enemy("thornback", 1)
	var imp2: Dictionary = d._make_enemy("mischief", 1)
	for e in [thorn, imp2]:
		e["offset"] = 400.0
		e["pos"] = c1.sample_baked(400.0)
		e["courage"] = 50.0
	d.enemies = [thorn, imp2]
	d.areas = []
	d._spawn_area("ember", c1.sample_baked(400.0))
	check(is_equal_approx(50.0 - thorn["courage"], (50.0 - imp2["courage"]) * 0.5), "Thornback armour halves burst damage")
	var wisp: Dictionary = d._make_enemy("wisp", 1)
	wisp["offset"] = 400.0
	wisp["pos"] = c1.sample_baked(400.0)
	wisp["courage"] = 5.0
	d.enemies = [wisp]
	d.areas = []
	d._spawn_area("spore", c1.sample_baked(400.0))
	d._night_step(0.5)
	check(wisp["courage"] == 5.0 and not wisp["drowsy"], "a Will-o'-Wisp ignores spore clouds")
	var puff: Dictionary = d._make_enemy("puffling", 1)
	puff["offset"] = 400.0
	puff["pos"] = c1.sample_baked(400.0)
	puff["courage"] = 0.01
	d.enemies = [puff]
	d.areas = []
	d._spawn_area("ember", c1.sample_baked(400.0))
	d._night_step(0.05)
	var kids: Array = d.enemies.filter(func(e): return e["kind"] == "scuttler")
	check(kids.size() == 2, "a scared Puffling bursts into 2 Scuttlers")
	d.enemies = []
	d.areas = []

	var hitter: Dictionary = d._make_enemy("stumpling", 1)
	hitter["offset"] = c1.get_baked_length() - 0.1
	d.enemies = [hitter]
	d.areas = []
	d.ward = 1
	d.hut_hp = 5
	d._night_step(0.2)
	check(d.ward == 0 and d.hut_hp == 4, "a stumpling costs two hits (one warded, one to the hut)")
	var coins_before: int = Data.coins
	var bones_before: int = Data.bones
	var scared: Dictionary = d._make_enemy("stumpling", 1)
	scared["offset"] = 200.0
	scared["pos"] = c1.sample_baked(200.0)
	scared["courage"] = 0.01
	d.enemies = [scared]
	d.areas = []
	d._spawn_area("ember", c1.sample_baked(200.0))
	d._night_step(0.05)
	check(Data.coins == coins_before + 5 and Data.bones == bones_before + 1, "a scared-off stumpling drops 5 coins and a bone")
	var warded: Dictionary = d._make_enemy("mischief", 1)
	warded["offset"] = c1.get_baked_length() - 0.1
	d.enemies = [warded]
	d.ward = 3
	var coins_mid: int = Data.coins
	d._night_step(0.2)
	check(Data.coins == coins_mid, "a creature blocked by the ward drops nothing")
	d.areas = []
	d._spawn_area("spore+", c1.sample_baked(300.0))
	check(is_equal_approx(d.areas[0]["radius"], Data.potion_stats("spore")["radius"] * 1.3), "an Empowered bottle lands with the bigger radius")
	d.areas = []
	d.ward = 0

	# Bosses: night 3 brings the Mischief King halfway through; he summons
	# minions, and the night can't be won until he's dealt with.
	var bn = night_map(3)
	check(bn.cfg["boss"] == "mischief_king" and bn.total_creatures() == bn.cfg["count"] + 1, "night 3 expects its creatures plus a boss")
	bn.spawned = bn.cfg["count"] / 2
	bn.spawn_timer = 1000.0
	bn.enemies = []
	bn._night_step(0.01)
	check(bn.boss_spawned and bn.enemies.size() == 1 and bn.enemies[0]["kind"] == "mischief_king", "the boss arrives halfway through the night")
	var king: Dictionary = bn.enemies[0]
	king["offset"] = 200.0
	king["pos"] = bn.curves[king["path"]].sample_baked(200.0)
	bn._night_step(4.1)
	check(bn.enemies.filter(func(e): return e["kind"] == "mischief").size() == 2, "the Mischief King summons Mischief as he marches")
	check(king["max"] > 10.0, "a boss is much braver than its minions")
	bn.spawned = bn.cfg["count"]
	var coins0: int = Data.coins
	var bones0: int = Data.bones
	king["courage"] = 0.01
	bn.enemies = [king]
	bn._spawn_area("ember", king["pos"])
	bn._night_step(0.05)
	check(Data.coins == coins0 + 25 and Data.bones == bones0 + 3, "a defeated boss drops 25 coins and 3 bones")
	bn.queue_free()
	var bn2 = night_map(6)
	bn2.enemies = []
	bn2.spawned = bn2.cfg["count"]
	bn2.boss_spawned = false
	bn2.cfg["count"] = 0
	bn2._night_step(0.01)
	check(not bn2.over or bn2.boss_spawned, "a boss night can't end before the boss has come")
	bn2.queue_free()
	Data.day = 12
	await frames(1)

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

	# Saving: the game saves at the start of each day and resumes there.
	Data.reset_game()
	Data.day = 7
	Data.inventory["morel"] = 5
	Data.bottles["frost"] = 2
	Data.discovered["frost"] = true
	Data.seen_creatures["moth"] = true
	Data.coins = 42
	Data.bones = 3
	Data.bottles["ember+"] = 2
	Data.upgrades["bone_mortar"] = true
	Data.save_game()
	Data.reset_game()
	check(Data.load_game() and Data.day == 7 and Data.inventory["morel"] == 5 and Data.bottles["frost"] == 2
		and Data.discovered.has("frost") and Data.seen_creatures.has("moth") and Data.coins == 42 and Data.bones == 3
		and Data.bottles["ember+"] == 2 and Data.upgrades.has("bone_mortar"), "a save loads back the same day, stock, coins, bones and upgrades")
	# Resuming mid-day: a save made when entering the cauldron or fortifying
	# brings a reloaded game back to that screen, with the morning's snapshot.
	Data.reset_game()
	Data.day = 5
	Data.inventory["puffball"] = 2
	Data.take_snapshot()
	Data.inventory["puffball"] = 6
	Data.save_game("brew")
	var m2 = load("res://main.tscn").instantiate()
	add_child(m2)
	await frames(2)
	check(m2.phase == "title" and m2.phase_node.buttons() == ["continue", "new", "choose", "market", "guide"] and m2.phase_node.save_day == 5,
		"with a save, the title offers Continue (day 5), New game, Choose a night, Market and Field Guide")
	m2.phase_node.tap(m2.phase_node.button_rect(0).get_center())
	await frames(2)
	check(m2.phase == "brew" and Data.day == 5 and Data.inventory["puffball"] == 6 and m2.hint.text.begins_with("Welcome back"),
		"a reload resumes on the cauldron with the foraged mushrooms")
	m2._on_action()
	await frames(2)
	check(m2.phase == "fortify" and Data.saved_phase == "brew", "moving on to fortify saves again")
	var m3_check := Data.load_game()
	check(m3_check and Data.saved_phase == "fortify", "the fortify save is on disk")
	Data.restore_snapshot()
	check(Data.inventory["puffball"] == 2, "Retry day after a reload restores the morning's stock")
	m2.queue_free()
	await frames(1)

	# The menu: resume, replay a reached night, start over.
	Data.clear_save()
	Data.reset_game()
	Data.day = 5
	Data.best_day = 5
	Data.coins = 20
	Data.save_game()
	var m4 = load("res://main.tscn").instantiate()
	add_child(m4)
	await frames(2)
	m4.continue_game()
	await frames(1)
	m4.open_menu()
	var mn = m4.menu
	check(get_tree().paused and mn.visible and mn.page == "main", "Menu opens and pauses the game")
	mn.tap(mn.main_button(0).get_center())
	check(not get_tree().paused and not mn.visible, "Resume closes it and unpauses")
	m4.open_menu()
	mn.tap(mn.main_button(2).get_center())
	check(mn.page == "levels" and mn.can_choose(5) and not mn.can_choose(6), "nights up to the furthest reached can be chosen")
	mn.tap(mn.tile_rect(6).get_center())
	check(mn.visible and Data.day == 5, "a locked night can't be picked")
	m4.phase_node.time_left = 0.0
	Data.inventory["puffball"] = 9
	mn.tap(mn.tile_rect(2).get_center())
	await frames(2)
	check(Data.day == 2 and Data.best_day == 5 and m4.phase == "forage" and not get_tree().paused,
		"picking night 2 replays it and keeps the furthest night (5)")
	check(Data.coins == 20, "replaying keeps coins and bones")
	check(Data.load_game() and Data.day == 2 and Data.best_day == 5, "the replay and furthest night are saved")
	# The market from the menu: opens on top, purchases stick through a retry.
	m4.open_menu()
	mn.tap(mn.main_button(3).get_center())
	await frames(1)
	var mk_over = m4.menu.get_parent().get_children().filter(func(c): return "overlay" in c and c.overlay)[0]
	check(get_tree().paused and m4.phase == "forage", "Market opens from the menu over the game, paused")
	Data.coins = 20
	Data.take_snapshot()
	Data.coins = 45
	check(mk_over.try_buy("bone_mortar") and Data.coins == 15, "buying from the menu's market works")
	Data.restore_snapshot()
	check(Data.coins == 0 and Data.upgrades.has("bone_mortar"), "a purchase isn't refunded by Retry day")
	mk_over.tap(mk_over.CLOSE.get_center())
	await frames(1)
	check(not get_tree().paused and m4.phase == "forage", "closing the market returns to the game")
	Data.upgrades.erase("bone_mortar")
	m4.open_menu()
	mn.tap(mn.main_button(4).get_center())
	await frames(2)
	check(m4.phase == "title" and not get_tree().paused and m4.phase_node.save_day == 2, "the menu can go back to the title screen")
	m4.continue_game()
	await frames(1)
	m4.open_menu()
	mn.tap(mn.main_button(5).get_center())
	check(mn.page == "confirm" and Data.day == 2, "Start over asks first")
	mn.tap(mn.NO.get_center())
	check(mn.page == "main" and Data.day == 2, "Cancel keeps the game")
	mn.tap(mn.main_button(5).get_center())
	mn.tap(mn.YES.get_center())
	await frames(2)
	check(Data.day == 1 and Data.best_day == 1 and Data.coins == 0 and m4.phase == "unlock" and not get_tree().paused,
		"Start over begins again on night 1")
	m4.show_title()
	await frames(1)
	Data.save_game()
	m4.show_title()
	await frames(1)
	var ttl = m4.phase_node
	ttl.tap(ttl.button_rect(1).get_center())
	check(ttl.page == "confirm" and m4.phase == "title", "New game from the title asks first when there's a save")
	ttl.tap(ttl.NO.get_center())
	check(ttl.page == "main", "Cancel returns to the title")
	m4.queue_free()
	await frames(1)

	Data.clear_save()
	check(not Data.load_game(), "with no save, the game starts fresh")

	print("DONE: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
