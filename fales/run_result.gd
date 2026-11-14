extends Control

const MENU_SCENE: String = "res://main_menu.tscn"
const ROOM_SCENE: String = "res://endless_room.tscn"

var busy: bool = false
var feedback: Label
var retry_button: Button
var menu_button: Button
var previous_back_setting: bool


func _ready() -> void:
	previous_back_setting = get_tree().quit_on_go_back
	get_tree().quit_on_go_back = false
	theme = preload("res://assets/ui/menu_theme.tres").duplicate()
	theme.default_font = preload("res://assets/fonts/Tiny5-Regular.ttf")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var background := ColorRect.new()
	background.color = Color("242f2b")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		outer.add_theme_constant_override(side, 18)
	add_child(outer)

	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3c554d")
	style.border_color = Color("9caa8f")
	style.set_border_width_all(3)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	frame.add_theme_stylebox_override("panel", style)
	outer.add_child(frame)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)

	_add_label(column, "РЕЗУЛЬТАТ ЗАБЕГА", 27)
	_add_label(column, GameState.result if not GameState.result.is_empty() else "Забег завершён.", 20)
	var room_text: String = "—" if GameState.run_last_cleared_room == 0 else str(GameState.run_last_cleared_room)
	_add_label(column, "Последняя зачищенная комната: %s" % room_text, 21)
	var new_record: bool = Profile.best_cleared_room > GameState.run_record_before
	_add_label(column, "Новый рекорд: %d" % Profile.best_cleared_room if new_record else "Рекорд: %d" % Profile.best_cleared_room, 21)
	_add_label(column, "Монеты за забег: +%d" % GameState.run_coins, 21)
	_add_label(column, "Всего монет: %d" % Profile.coins, 21)

	feedback = _add_label(column, "", 17)
	retry_button = _add_button(column, "Новый забег", _retry)
	menu_button = _add_button(column, "В главное меню", _open_menu)
	retry_button.grab_focus()


func _add_label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e2ead7"))
	parent.add_child(label)
	return label


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 54)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _retry() -> void:
	if busy:
		return
	var room: PackedScene = load(ROOM_SCENE) as PackedScene
	if room == null:
		feedback.text = "Не удалось загрузить комнату."
		return
	_set_busy(true)
	GameState.reset_run()
	var error: Error = get_tree().change_scene_to_packed(room)
	if error != OK:
		_set_busy(false)
		feedback.text = "Не удалось начать забег."


func _open_menu() -> void:
	if busy:
		return
	_set_busy(true)
	var error: Error = get_tree().change_scene_to_file(MENU_SCENE)
	if error != OK:
		_set_busy(false)
		feedback.text = "Не удалось открыть меню."


func _set_busy(value: bool) -> void:
	busy = value
	retry_button.disabled = value
	menu_button.disabled = value


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		_open_menu()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		_open_menu()


func _exit_tree() -> void:
	get_tree().quit_on_go_back = previous_back_setting
