extends Node
## Screenshots of reishi: the dish and a reishi in the cauldron, the find
## under a stump, and an Everlasting cloud at night with its bottle.
##   Godot --path . --resolution 720x1280 res://tests/reishi_shot.tscn -- <output folder>

var out_dir := "user://screenshots"


func snap(name: String, n: int = 20) -> void:
	for i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Data.clear_save()
	Data.reset_game()
	Data.day = 9
	Data.unlock_seen = 9
	Data.reishi = 3
	Data.bones = 4
	Data.upgrades = {"bone_mortar": true}
	for id in Data.ingredient_order:
		Data.inventory[id] = 3
	Data.save_game("brew")
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	Data.load_game()
	main._enter_brew()
	var brew = main.phase_node
	for id in ["puffball", "fly_agaric"]:
		brew._on_press(brew.slot_center(Data.ingredient_order.find(id)))
		brew._on_release(brew.POT)
	brew.add_reishi()
	await snap("reishi_brew")
	main._start_day()
	var fr = main.phase_node
	fr.reishi_shine = {"pos": Vector2(360, 700), "t": 1.3}
	fr.set_process(false)
	await snap("reishi_find")
	Data.bottles["spore~"] = 1
	Data.bottles["syrup~"] = 1
	Data.bottles["spore"] = 3
	main._enter_fortify()
	var def = main.phase_node
	def.night_amt = 1.0
	def._spawn_area("spore~", def.muds[0]["pos"])
	def.areas[-1]["time"] -= 5.0
	await snap("reishi_night", 30)
	Data.clear_save()
	get_tree().quit()
