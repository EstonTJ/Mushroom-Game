extends Node
## Saves a PNG of each phase. Needs a real window (not --headless):
##   Godot --path . res://tests/screenshots.tscn -- <output folder>

var out_dir := "user://screenshots"


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)

	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await frames(40)
	await shot("1_forage")

	main.phase_node.time_left = 0.0
	await frames(3)
	for id in Data.ingredient_order:
		Data.inventory[id] = 3
	var brew = main.phase_node
	for pair in [["puffcap", "dewmoss"], ["honeyroot", "dewmoss"], ["emberleaf", "puffcap"]]:
		for id in pair:
			brew._on_press(Vector2(brew.SLOT_W * Data.ingredient_order.find(id) + 72, 220))
			brew._on_release(brew.POT)
		brew._on_press(brew.POT + Vector2(120, 0))
		for k in 70:
			brew._on_stir(brew.POT + Vector2(120, 0).rotated(k * 0.3))
		brew._on_release(brew.POT)
	for id in ["moonglow", "honeyroot"]:
		brew._on_press(Vector2(brew.SLOT_W * Data.ingredient_order.find(id) + 72, 220))
		brew._on_release(brew.POT)
	brew._on_press(brew.POT + Vector2(120, 0))
	for k in 30:
		brew._on_stir(brew.POT + Vector2(120, 0).rotated(k * 0.3))
	await frames(5)
	await shot("2_brew")
	# Finish the stir and catch the new bottle mid-flight to the recipe book.
	for k in 40:
		brew._on_stir(brew.POT + Vector2(120, 0).rotated(9.0 + k * 0.3))
	await frames(22)
	await shot("2b_brew_result")

	main._on_action()
	await frames(3)
	var def = main.phase_node
	def.selected = "spore"
	def._fortify_tap(def.slots[1]["pos"])
	def.selected = "syrup"
	def._fortify_tap(def.slots[4]["pos"])
	def.selected = "ember"
	await frames(5)
	await shot("3_fortify")

	main._on_action()
	# Skip the dusk-to-night fade so the shot shows full night.
	def.night_amt = 1.0
	def.ground_layer.queue_redraw()
	def.canopy_layer.queue_redraw()
	def.ward = 4
	for i in 160:
		def._night_step(0.05)
	await frames(3)
	await shot("4_night")

	# Potions going off: a spore cloud, a syrup puddle and an ember burst.
	if def.enemies.size() > 0:
		def._spawn_area("spore", def.enemies[0]["pos"])
	def._spawn_area("syrup", def.curves[1].sample_baked(300.0))
	def._spawn_area("ember", def.curves[0].sample_baked(250.0))
	await frames(12)
	await shot("5_night_effects")
	get_tree().quit()
