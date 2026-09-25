extends Node
## Saves a PNG of the title screen (with a day-11 save). Needs a real window:
##   Godot --path . --resolution 720x1280 res://tests/title_shot.tscn -- <output folder>

func _ready() -> void:
	var out_dir := "user://screenshots"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Data.clear_save()
	Data.reset_game()
	Data.day = 11
	Data.save_game()
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("title.png"))
	main.phase_node.page = "confirm"
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("title_confirm.png"))
	Data.clear_save()
	main.show_title()
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("title_fresh.png"))
	get_tree().quit()
