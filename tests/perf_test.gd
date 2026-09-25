extends Node
## Times each drawing layer of each screen in a busy state and prints the
## average milliseconds per redraw. Run headless:
##   Godot --headless --path . --quit-after 2000 res://tests/perf_test.tscn
## Numbers are desktop speed; a phone browser runs GDScript many times slower.

const Defense = preload("res://scripts/defense.gd")
const Forage = preload("res://scripts/forage.gd")
const Brew = preload("res://scripts/brew.gd")


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func report(title: String, node: Node, n: int) -> void:
	var totals := {}
	for i in n:
		await frames(1)
		for child in node.get_children():
			if "last_usec" in child:
				totals[child.painter.get_method()] = totals.get(child.painter.get_method(), 0) + child.last_usec
	var sum := 0.0
	var parts := []
	for k in totals:
		var ms: float = totals[k] / 1000.0 / n
		sum += ms
		parts.append("%s %.2f" % [k.trim_prefix("_paint_"), ms])
	print("%-26s total %.2f ms/frame  (%s)" % [title, sum, ", ".join(parts)])


func _ready() -> void:
	Data.clear_save()
	Data.reset_game()
	Data.day = 25
	for id in Data.ingredient_order:
		Data.inventory[id] = 3
	for key in Data.bottle_keys():
		Data.bottles[key] = 1
	var f = Forage.new()
	add_child(f)
	await report("forest (night 25)", f, 60)
	f.queue_free()
	var b = Brew.new()
	add_child(b)
	await report("cauldron", b, 60)
	b.queue_free()
	var d = Defense.new()
	add_child(d)
	await report("fortify (night 25)", d, 60)
	d.start_night()
	d.night_amt = 1.0
	for i in 40:
		var e: Dictionary = d._make_enemy(Data.creature_order[i % Data.creature_order.size()], i % 2)
		e["offset"] = 40.0 + i * 20.0
		e["pos"] = d.curves[i % 2].sample_baked(e["offset"])
		e["courage"] = 999.0
		d.enemies.append(e)
	d.spawned = d.cfg["count"]
	d._spawn_area("spore", d.curves[0].sample_baked(300.0))
	d._spawn_area("syrup", d.curves[1].sample_baked(300.0))
	await report("night with 40 creatures", d, 60)
	get_tree().quit()
