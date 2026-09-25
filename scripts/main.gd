extends Node2D
## Runs the day loop: forage -> brew -> fortify -> night -> next day.
## Owns the top bar (title, hint, action button); each phase draws the rest.

const Forage = preload("res://scripts/forage.gd")
const Brew = preload("res://scripts/brew.gd")
const Defense = preload("res://scripts/defense.gd")

var phase := ""
var phase_node = null
var title: Label
var hint: Label
var action_btn: Button
var action := Callable()


func _ready() -> void:
	_build_hud()
	Data.reset_game()
	_start_day()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var bar := ColorRect.new()
	bar.color = Data.moss
	bar.size = Vector2(720, 110)
	layer.add_child(bar)

	title = Label.new()
	title.position = Vector2(24, 8)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Data.parchment)
	layer.add_child(title)

	hint = Label.new()
	hint.position = Vector2(24, 56)
	hint.size = Vector2(480, 50)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Data.magic)
	layer.add_child(hint)

	action_btn = Button.new()
	action_btn.position = Vector2(520, 22)
	action_btn.size = Vector2(180, 66)
	action_btn.add_theme_font_size_override("font_size", 24)
	action_btn.pressed.connect(_on_action)
	layer.add_child(action_btn)


func _on_action() -> void:
	if action.is_valid():
		action.call()


func _set_phase(new_phase: String, node: Node2D, t: String, h: String, button_text: String, on_action: Callable) -> void:
	phase = new_phase
	if phase_node:
		phase_node.queue_free()
	phase_node = node
	add_child(node)
	_set_text(t, h, button_text, on_action)


func _set_text(t: String, h: String, button_text: String, on_action: Callable) -> void:
	title.text = t
	hint.text = h
	action_btn.text = button_text
	action_btn.visible = button_text != ""
	action = on_action


func _start_day() -> void:
	Data.take_snapshot()
	var forage := Forage.new()
	forage.finished.connect(_start_brew)
	_set_phase("forage", forage, "Day %d · Forage" % Data.day,
		"Tap ingredients before they fade. Moonglow is rare!", "Done", _start_brew)


func _start_brew() -> void:
	if phase != "forage":
		return
	_set_phase("brew", Brew.new(), "Day %d · Brew" % Data.day,
		"Drag two ingredients into the cauldron, then stir.", "Fortify", _start_fortify)


func _start_fortify() -> void:
	if phase != "brew":
		return
	phase_node.return_pot()
	var defense := Defense.new()
	defense.night_over.connect(_on_night_over)
	_set_phase("fortify", defense, "Day %d · Fortify" % Data.day,
		"Tap a bottle, then a glowing spot. Moon Ward goes on the hut.", "Begin night", _start_night)


func _start_night() -> void:
	if phase != "fortify":
		return
	phase = "night"
	phase_node.start_night()
	_set_text("Night %d" % Data.day, "Tap a bottle, then a glowing spot to place it, or anywhere to throw.", "", Callable())


func _on_night_over(won: bool, repelled: int) -> void:
	phase = "result"
	if not won:
		_set_text("The hut was overrun", "Try the day again with a new plan.", "Retry day", _retry_day)
	elif Data.day >= Data.nights.size():
		_set_text("The hut is safe!", "You survived all %d nights. Well brewed." % Data.nights.size(),
			"Play again", _new_game)
	else:
		_set_text("Dawn · hut is safe", "Repelled %d creatures. Unused bottles carry over." % repelled,
			"Next day", _next_day)


func _retry_day() -> void:
	Data.restore_snapshot()
	_start_day()


func _next_day() -> void:
	Data.day += 1
	_start_day()


func _new_game() -> void:
	Data.reset_game()
	_start_day()
