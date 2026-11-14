extends CanvasLayer

const RESULT_SCENE: String = "res://run_result.tscn"

var owns_pause: bool = false
var confirming_exit: bool = false
var leaving: bool = false
var previous_quit_on_go_back: bool = true
var application_in_background: bool = false
var back_pending: bool = false

var root: Control
var pause_button: Button
var shade: ColorRect
var panel: PanelContainer
var title: Label
var message: Label
var primary: Button
var secondary: Button


func _ready() -> void:
	previous_quit_on_go_back = get_tree().quit_on_go_back
	get_tree().quit_on_go_back = false
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50

	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://assets/ui/upgrade_theme.tres")
	add_child(root)

	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.tooltip_text = "Пауза"
	pause_button.position = Vector2(16, 16)
	pause_button.size = Vector2(56, 56)
	pause_button.pressed.connect(open_pause)
	root.add_child(pause_button)

	shade = ColorRect.new()
	shade.color = Color(0.04, 0.06, 0.07, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	shade.hide()

	panel = PanelContainer.new()
	shade.add_child(panel)

	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("3c554d")
	frame.border_color = Color("9caa8f")
	frame.set_border_width_all(3)
	frame.content_margin_left = 20
	frame.content_margin_right = 20
	frame.content_margin_top = 20
	frame.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", frame)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)

	title = Label.new()
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

	message = Label.new()
	message.add_theme_font_size_override("font_size", 20)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(message)

	primary = Button.new()
	primary.custom_minimum_size.y = 56
	primary.add_theme_font_size_override("font_size", 22)
	primary.pressed.connect(on_primary)
	column.add_child(primary)

	secondary = Button.new()
	secondary.custom_minimum_size.y = 56
	secondary.add_theme_font_size_override("font_size", 22)
	secondary.pressed.connect(on_secondary)
	column.add_child(secondary)

	get_viewport().size_changed.connect(update_layout)
	update_layout()
	refresh_text()


func _process(_delta: float) -> void:
	pause_button.disabled = leaving or (
		get_tree().paused and not owns_pause
	)


func update_layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size

	panel.size = Vector2(
		minf(340.0, screen.x - 32.0),
		minf(360.0, screen.y - 32.0)
	)
	panel.position = (screen - panel.size) * 0.5


func reset_controls() -> void:
	var scene: Node = get_tree().current_scene

	if not is_instance_valid(scene):
		return

	for node in scene.find_children("*", "", true, false):
		if node.has_method("reset_stick"):
			node.call("reset_stick")


func open_pause() -> void:
	if owns_pause or leaving or get_tree().paused:
		return

	reset_controls()
	confirming_exit = false
	owns_pause = true
	get_tree().paused = true
	refresh_text()
	shade.show()
	primary.grab_focus()


func close_pause() -> void:
	if not owns_pause or leaving:
		return

	shade.hide()
	reset_controls()
	owns_pause = false
	get_tree().paused = false
	pause_button.release_focus()


func refresh_text() -> void:
	title.text = "Завершить забег?" if confirming_exit else "Пауза"

	message.text = (
		"Забег закончится.\nПолученные монеты и рекорд сохранятся."
		if confirming_exit else "Бой остановлен."
	)

	primary.text = "Завершить" if confirming_exit else "Продолжить"
	secondary.text = "Назад" if confirming_exit else "В главное меню"


func on_primary() -> void:
	if confirming_exit:
		leave_run()
	else:
		close_pause()


func on_secondary() -> void:
	if leaving:
		return

	confirming_exit = not confirming_exit
	refresh_text()

	if confirming_exit:
		secondary.grab_focus()
	else:
		primary.grab_focus()


func leave_run() -> void:
	if leaving or not owns_pause:
		return

	leaving = true

	var previous_result: String = GameState.result
	GameState.result = "Забег завершён игроком."

	get_tree().paused = false

	var error: Error = get_tree().change_scene_to_file(RESULT_SCENE)

	if error != OK:
		GameState.result = previous_result
		get_tree().paused = true
		leaving = false
		message.text = "Не удалось открыть результат.\nМожно вернуться в игру."
		push_error("Не удалось открыть экран результата: %s" % error)


func _unhandled_input(event: InputEvent) -> void:
	if application_in_background:
		return
	
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return

	if owns_pause:
		if confirming_exit:
			confirming_exit = false
			refresh_text()
			primary.grab_focus()
		else:
			close_pause()

	elif not get_tree().paused:
		open_pause()

	else:
		return

	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	get_tree().quit_on_go_back = previous_quit_on_go_back

	if owns_pause:
		get_tree().paused = false

func _notification(what: int) -> void:
	if not is_node_ready():
		return

	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			application_in_background = true
			open_pause()

		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			application_in_background = false
			# После возвращения не снимаем паузу автоматически.

		NOTIFICATION_WM_GO_BACK_REQUEST:
			if leaving or application_in_background or back_pending:
				return

			back_pending = true
			call_deferred("send_back_action")


func send_back_action() -> void:
	back_pending = false

	if leaving or application_in_background:
		return

	var pressed := InputEventAction.new()
	pressed.action = "ui_cancel"
	pressed.pressed = true
	get_viewport().push_input(pressed)

	var released := InputEventAction.new()
	released.action = "ui_cancel"
	released.pressed = false
	get_viewport().push_input(released)
