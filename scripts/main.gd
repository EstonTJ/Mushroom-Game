extends Node2D
## Runs the day loop: forage -> brew -> fortify -> night -> next day.
## Owns the top bar (title, hint, action button); each phase draws the rest.

const Forage = preload("res://scripts/forage.gd")
const Brew = preload("res://scripts/brew.gd")
const Defense = preload("res://scripts/defense.gd")
const Unlock = preload("res://scripts/unlock.gd")
const Guide = preload("res://scripts/guide.gd")
const Shop = preload("res://scripts/shop.gd")
const Menu = preload("res://scripts/menu.gd")
const Title = preload("res://scripts/title.gd")

var phase := ""
var phase_node = null
var title: Label
var hint: Label
var action_btn: Button
var action := Callable()
var guide_btn: Button
var guide
var menu
var diag_timer := 0.0
var hud_layer: CanvasLayer
var last_session_note := ""
var fps_label: Label


func _ready() -> void:
	# 120 Hz phones would otherwise draw twice as often as this game needs.
	if OS.has_feature("web"):
		Engine.max_fps = 60
	_build_hud()
	var last := Data.take_last_diag()
	var event := Data.take_last_event()
	# Playtesting shortcut: ?day=N in the web address starts a fresh run on
	# day N with 5 of every potion that can be brewed by then.
	var jump := _url_day()
	if jump > 0:
		Data.reset_game()
		Data.day = jump
		Data.unlock_seen = jump
		for id in Data.potion_order:
			if Data.potion_night(id) <= jump:
				Data.bottles[id] = 5
				Data.discovered[id] = true
		for id in Data.unlocked_mushrooms():
			Data.inventory[id] = 3
		_start_day()
		hint.text = "Playtest: started on day %d with 5 of each potion." % jump
		return
	var closed_normally: bool = str(event.get("kind", "")) == "page closed"
	if not last.is_empty() and not closed_normally and str(last.get("phase", "")) != "title":
		last_session_note = "Last session stopped: day %d, %s, %d fps" % [int(last.get("day", 0)), str(last.get("phase", "?")),
			int(last.get("fps", 0))]
		if not event.is_empty():
			last_session_note += ", " + str(event.get("kind", ""))
	show_title()


## The title screen, shown every time the game opens (and from the menu).
func show_title() -> void:
	get_tree().paused = false
	var has_save := Data.load_game()
	if not has_save:
		Data.reset_game()
	var title_node := Title.new()
	title_node.has_save = has_save
	title_node.save_day = Data.day
	title_node.best_day = maxi(Data.best_day, Data.day)
	title_node.note = last_session_note
	title_node.continue_pressed.connect(continue_game)
	title_node.new_game_pressed.connect(new_game)
	title_node.choose_pressed.connect(func(): open_menu("levels"))
	title_node.guide_pressed.connect(func(): open_guide())
	title_node.market_pressed.connect(open_market)
	_set_phase("title", title_node, "", "", "", Callable())


## Continue from the save, on the screen it was made on.
func continue_game() -> void:
	if phase != "title":
		return
	Data.load_game()
	match Data.saved_phase:
		"brew":
			_enter_brew()
		"fortify":
			_enter_fortify()
		"market":
			_start_market(0, 0)
		_:
			_begin_day()
	hint.text = "Welcome back! Resumed day %d." % Data.day


func new_game() -> void:
	Data.clear_save()
	Data.reset_game()
	_begin_day()


func _url_day() -> int:
	if not OS.has_feature("web"):
		return 0
	var search := str(JavaScriptBridge.eval("location.search"))
	var at := search.find("day=")
	if at < 0:
		return 0
	var digits := ""
	for ch in search.substr(at + 4):
		if not ch.is_valid_int():
			break
		digits += ch
	return clampi(digits.to_int(), 0, Data.NIGHTS)


## Every 2 seconds, note where the game is (browser only) for crash reports.
func _process(delta: float) -> void:
	if fps_label:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()
	diag_timer -= delta
	if diag_timer <= 0.0:
		diag_timer = 2.0
		Data.write_diag(phase)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_layer = layer

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
	guide_btn.text = "Menu"
	guide_btn.position = Vector2(404, 26)
	guide_btn.size = Vector2(104, 58)
	guide_btn.add_theme_font_size_override("font_size", 22)
	guide_btn.pressed.connect(open_menu)
	layer.add_child(guide_btn)

	# Frame counter for performance checks: add ?fps to the web address.
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.search")).contains("fps"):
		fps_label = Label.new()
		fps_label.position = Vector2(8, 1240)
		fps_label.add_theme_font_size_override("font_size", 22)
		fps_label.add_theme_color_override("font_color", Color.YELLOW)
		fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
		fps_label.add_theme_constant_override("outline_size", 6)
		layer.add_child(fps_label)

	var guide_layer := CanvasLayer.new()
	guide_layer.layer = 20
	guide_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(guide_layer)
	guide = Guide.new()
	guide.visible = false
	guide.closed.connect(_on_guide_closed)
	guide_layer.add_child(guide)
	menu = Menu.new()
	menu.visible = false
	menu.resumed.connect(_on_guide_closed)
	menu.guide_requested.connect(func(): open_guide())
	menu.night_chosen.connect(_on_night_chosen)
	menu.restart_confirmed.connect(_on_restart)
	menu.title_requested.connect(show_title)
	menu.market_requested.connect(open_market)
	guide_layer.add_child(menu)


## Opens the Field Guide and pauses the game until it's closed.
func open_guide(on_page: String = "") -> void:
	guide.open(on_page)
	get_tree().paused = true


func _on_guide_closed() -> void:
	get_tree().paused = false


## Opens the game menu (optionally on a page) and pauses the game until it's closed.
func open_menu(on_page: String = "main") -> void:
	menu.open()
	menu.page = on_page
	get_tree().paused = true


## The market on top of whatever is on screen (from the menu or title),
## pausing the game until it's closed.
func open_market() -> void:
	var shop := Shop.new()
	shop.overlay = true
	# From the title the loaded save is the current state, so a purchase can
	# be saved at once; mid-game it's saved at the next checkpoint.
	shop.save_phase = Data.saved_phase if phase == "title" else ""
	shop.closed.connect(func():
		shop.queue_free()
		get_tree().paused = false
		if phase == "title":
			show_title())
	menu.get_parent().add_child(shop)
	get_tree().paused = true


## Replay a night from the menu: today's unfinished progress is undone (as
## with Retry day), then that day starts in the forest with current stock.
func _on_night_chosen(n: int) -> void:
	get_tree().paused = false
	if phase in ["forage", "brew", "fortify", "night", "result"]:
		Data.restore_snapshot()
	Data.best_day = maxi(Data.best_day, Data.day)
	Data.day = n
	Data.unlock_seen = maxi(Data.unlock_seen, n)
	_start_day()
	hint.text = "Replaying night %d." % n


func _on_restart() -> void:
	get_tree().paused = false
	Data.clear_save()
	Data.reset_game()
	_begin_day()


func _on_action() -> void:
	if action.is_valid():
		action.call()


func _set_phase(new_phase: String, node: Node2D, t: String, h: String, button_text: String, on_action: Callable) -> void:
	phase = new_phase
	Data.write_diag(new_phase + " (starting)")
	# The title screen has its own buttons; the top bar is for play.
	hud_layer.visible = new_phase != "title"
	if phase_node:
		# Take the old screen out at once so it can't fire signals (a forest
		# timer running out, say) after the new screen has started.
		remove_child(phase_node)
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
	Data.best_day = maxi(Data.best_day, Data.day)
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
	Data.write_diag("night (starting)")
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
		var got_coins: int = phase_node.coins_earned
		var got_bones: int = phase_node.bones_earned
		_set_text("Dawn · hut is safe", "Repelled %d. Earned %d coins and %d bones." % [repelled, got_coins, got_bones],
			"To market", func(): _to_market(got_coins, got_bones))


func _retry_day() -> void:
	Data.restore_snapshot()
	_start_day()


## After a won night: the next day begins at the Dawn Market.
func _to_market(got_coins: int, got_bones: int) -> void:
	if phase != "result":
		return
	Data.day += 1
	Data.best_day = maxi(Data.best_day, Data.day)
	Data.save_game("market")
	_start_market(got_coins, got_bones)


func _start_market(got_coins: int, got_bones: int) -> void:
	var shop := Shop.new()
	shop.earned_coins = got_coins
	shop.earned_bones = got_bones
	_set_phase("market", shop, "Day %d · Dawn Market" % Data.day, "Spend coins on lab upgrades.", "Start day", _begin_day)


func _new_game() -> void:
	Data.reset_game()
	_begin_day()
