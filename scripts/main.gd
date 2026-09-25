extends Node2D
## Runs the day loop: forage -> brew -> fortify -> night -> next day.
## Owns the top bar (title, hint, action button); each phase draws the rest.

const Forage = preload("res://scripts/forage.gd")
const Brew = preload("res://scripts/brew.gd")
const Defense = preload("res://scripts/defense.gd")
const Unlock = preload("res://scripts/unlock.gd")
const Guide = preload("res://scripts/guide.gd")

var phase := ""
var phase_node = null
var title: Label
var hint: Label
var action_btn: Button
var action := Callable()
var guide_btn: Button
var guide
var diag_timer := 0.0


func _ready() -> void:
	# 120 Hz phones would otherwise draw twice as often as this game needs.
	if OS.has_feature("web"):
		Engine.max_fps = 60
	_build_hud()
	var last := Data.take_last_diag()
	if not Data.load_game():
		Data.reset_game()
		_begin_day()
		return
	# Resume where the save was made: the forest, the cauldron or fortifying.
	match Data.saved_phase:
		"brew":
			_enter_brew()
		"fortify":
			_enter_fortify()
		_:
			_begin_day()
	var note := "Welcome back! Resumed day %d." % Data.day
	if not last.is_empty():
		note = "Resumed day %d. Last session stopped on day %d, %s (%d fps)." % [Data.day, int(last.get("day", 0)),
			str(last.get("phase", "?")), int(last.get("fps", 0))]
	hint.text = note


## Every 2 seconds, note where the game is (browser only) for crash reports.
func _process(delta: float) -> void:
	diag_timer -= delta
	if diag_timer <= 0.0:
		diag_timer = 2.0
		Data.write_diag(phase)


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
	hint.size = Vector2(370, 50)
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

	guide_btn = Button.new()
	guide_btn.text = "Guide"
	guide_btn.position = Vector2(404, 26)
	guide_btn.size = Vector2(104, 58)
	guide_btn.add_theme_font_size_override("font_size", 22)
	guide_btn.pressed.connect(open_guide)
	layer.add_child(guide_btn)

	var guide_layer := CanvasLayer.new()
	guide_layer.layer = 20
	guide_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(guide_layer)
	guide = Guide.new()
	guide.visible = false
	guide.closed.connect(_on_guide_closed)
	guide_layer.add_child(guide)


## Opens the Field Guide and pauses the game until it's closed.
func open_guide(on_page: String = "") -> void:
	guide.open(on_page)
	get_tree().paused = true


func _on_guide_closed() -> void:
	get_tree().paused = false


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


## A new day: first the dawn "new mushroom" screen if this day brings one
## that hasn't been shown yet, then the forest.
func _begin_day() -> void:
	if Data.unlock_seen < Data.day and not Data.new_mushrooms(Data.day).is_empty():
		_start_unlock()
	else:
		_start_day()


func _start_unlock() -> void:
	var node := Unlock.new()
	node.ids = Data.new_mushrooms(Data.day)
	var hint := "Three mushrooms grow in the forest." if Data.day == 1 else "Something new grows in the forest."
	_set_phase("unlock", node, "Day %d · Dawn" % Data.day, hint, "Next" if node.has_next() else "Start day", _on_unlock_continue)


func _on_unlock_continue() -> void:
	if phase != "unlock":
		return
	if phase_node.has_next():
		phase_node.next()
		action_btn.text = "Next" if phase_node.has_next() else "Start day"
		return
	Data.unlock_seen = Data.day
	_start_day()


func _start_day() -> void:
	Data.take_snapshot()
	Data.save_game()
	var forage := Forage.new()
	forage.finished.connect(_start_brew)
	_set_phase("forage", forage, "Day %d · Forage" % Data.day,
		"Tap mushrooms before they fade. Tap rocks and stumps to search!", "Done", _start_brew)


func _start_brew() -> void:
	if phase != "forage":
		return
	_enter_brew()


func _enter_brew() -> void:
	Data.save_game("brew")
	_set_phase("brew", Brew.new(), "Day %d · Brew" % Data.day,
		"Drag two mushrooms into the cauldron, then pop the bubbles.", "Fortify", _start_fortify)


func _start_fortify() -> void:
	if phase != "brew":
		return
	phase_node.return_pot()
	_enter_fortify()


func _enter_fortify() -> void:
	Data.save_game("fortify")
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
	elif Data.day >= Data.NIGHTS:
		_set_text("The hut is safe!", "You survived all %d nights. Well brewed." % Data.NIGHTS,
			"Play again", _new_game)
	else:
		_set_text("Dawn · hut is safe", "Repelled %d creatures. Unused bottles carry over." % repelled,
			"Next day", _next_day)


func _retry_day() -> void:
	Data.restore_snapshot()
	_start_day()


func _next_day() -> void:
	Data.day += 1
	Data.save_game()
	_begin_day()


func _new_game() -> void:
	Data.reset_game()
	_begin_day()
