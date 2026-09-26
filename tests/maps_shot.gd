extends Node
## Saves a screenshot of every night map at fortify, and prints how long a
## ground creature takes on each path compared with an even pace (1.00).
##   Godot --path . --resolution 720x1280 res://tests/maps_shot.tscn -- <output folder>

func _ready() -> void:
	var out_dir := "user://screenshots"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Data.clear_save()
	Data.reset_game()
	var Def = load("res://scripts/defense.gd")
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for li in Def.LAYOUTS.size():
		var night := 1
		while Def.layout_for(night) != li:
			night += 1
		Data.day = night
		main._enter_fortify()
		var def = main.phase_node
		var notes := []
		for pi in def.curves.size():
			var p: PackedFloat32Array = def.pace[pi]
			var tt := 0.0
			for v in p:
				tt += 1.0 / v
			notes.append("%.2f" % (tt / p.size()))
		print("map %d %-14s night %2d  walk time vs even pace: %s" % [li, Def.LAYOUTS[li]["name"], night, ", ".join(notes)])
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("map_%d.png" % li))
	Data.clear_save()
	get_tree().quit()
