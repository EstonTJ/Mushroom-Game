extends Node
## Saves forest screenshots: one showing every rock and stump style side by
## side, one as the forest normally deals them. Needs a window:
##   Godot --path . --resolution 720x1280 res://tests/forest_shot.tscn -- <output folder>

func snap(out_dir: String, name: String) -> void:
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _ready() -> void:
	var out_dir := "user://screenshots"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Data.clear_save()
	Data.reset_game()
	Data.day = 12
	Data.unlock_seen = 12
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._start_day()
	var forage = main.phase_node
	forage.items.clear()
	forage.obstacles.clear()
	var styles := [["rock", "boulder"], ["rock", "mossy"], ["rock", "cairn"], ["rock", "slab"],
		["stump", "stump"], ["stump", "bracket"], ["stump", "log"], ["stump", "snag"]]
	for i in styles.size():
		var pos := Vector2(190 + (i % 2) * 340, 300 + floori(i / 2.0) * 200)
		forage.obstacles.append({"kind": styles[i][0], "style": styles[i][1], "pos": pos, "hp": 3, "max": 3, "shake": 0.0,
			"hidden": "morel", "peek": false, "seed": 2.0 + i, "gone": false})
	forage.time_left = 999.0
	await snap(out_dir, "forest_styles")
	main._start_day()
	await snap(out_dir, "forest_normal")
	# The dawn stats page after night 6 (a boss night), then after night 7.
	Data.coins = 142
	Data.bones = 9
	Data.day = 7
	Data.last_night = {"night": 6, "repelled": 34, "total": 34, "hp": 3, "coins": 61, "bones": 4, "boss": "mischief_king"}
	main._start_dawn()
	await snap(out_dir, "dawn_boss")
	Data.day = 8
	Data.last_night = {"night": 7, "repelled": 36, "total": 36, "hp": 5, "coins": 38, "bones": 2, "boss": ""}
	main._start_dawn()
	await snap(out_dir, "dawn")
	# The new wares, page by page, and the forest with the new gear.
	Data.coins = 500
	Data.upgrades = {"truffle_pig": true}
	main._start_market(0, 0)
	for pg in 4:
		main.phase_node.page = pg
		await snap(out_dir, "market_%d" % pg)
	Data.upgrades = {"truffle_pig": true, "golden_snout": true, "foxfire_lantern": true, "foraging_basket": true, "rock_hammer": true}
	main.phase = "dawn"
	main._begin_day()
	var fr = main.phase_node
	if fr.obstacles.size() > 0:
		fr.obstacles[0]["hidden"] = "ghost_fungus"
	fr.pending.append({"id": "ghost_fungus", "pos": Vector2(560, 760), "life": 4.0, "t": 0.4})
	fr.pig["pos"] = Vector2(260, 900)
	await snap(out_dir, "forest_gear")
	Data.clear_save()
	get_tree().quit()
