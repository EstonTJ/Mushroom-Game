extends Node
## Leak check: goes round every screen many times and prints memory and object
## counts after each lap. Numbers that keep climbing lap after lap are a leak.
## Needs a window (video memory isn't tracked headless):
##   Godot --path . --resolution 720x1280 res://tests/transition_test.tscn

const LAPS := 25


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func report(lap: int) -> void:
	print("lap %2d  objects %6d  nodes %5d  orphans %3d  video %6.1f MB  textures %6.1f MB  ram %6.1f MB" % [lap,
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])


func _ready() -> void:
	Data.clear_save()
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await frames(5)
	main.new_game()
	await frames(5)
	for lap in LAPS:
		Data.day = 1 + lap % 12
		main.show_title()
		await frames(8)
		main._start_day()
		await frames(8)
		main._start_brew()
		await frames(8)
		main._start_fortify()
		await frames(8)
		main._start_night()
		await frames(30)
		main._start_market(3, 1)
		await frames(8)
		main.open_menu()
		await frames(4)
		main.menu._close()
		await frames(4)
		report(lap)
	Data.clear_save()
	get_tree().quit()
