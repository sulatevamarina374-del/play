extends Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP

	theme = preload("res://assets/ui/upgrade_theme.tres")
	add_theme_font_size_override("font_size", 16)

	custom_minimum_size = Vector2(180, 56)
	size = Vector2(180, 56)

	tooltip_text = "Тестовый чит: отключает входящий урон."

	set_pressed_no_signal(GameState.debug_invincible)
	toggled.connect(on_toggled)

	refresh()


func _process(_delta: float) -> void:
	refresh()


func on_toggled(enabled: bool) -> void:
	if get_tree().paused:
		set_pressed_no_signal(GameState.debug_invincible)
		return

	GameState.debug_invincible = enabled

	# Убираем активное движение джойстиком при переключении.
	var joystick: Node = get_parent().get_node_or_null("Joystick")

	if is_instance_valid(joystick) and joystick.has_method("reset_stick"):
		joystick.call("reset_stick")

	refresh()


func refresh() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size

	# Внизу по центру, выше строки монет.
	position = Vector2(
		(screen.x - size.x) / 2.0,
		screen.y - size.y - 64.0
	)

	var player: Node = get_tree().get_first_node_in_group("player")

	disabled = not is_instance_valid(player)

	if is_instance_valid(player):
		disabled = (
			player.is_queued_for_deletion()
			or float(player.get("health")) <= 0.0
		)

	set_pressed_no_signal(GameState.debug_invincible)

	text = (
		"ТЕСТ: бессмертие\nВКЛ"
		if GameState.debug_invincible
		else "ТЕСТ: бессмертие\nВЫКЛ"
	)

	add_theme_color_override(
		"font_color",
		Color("20c6cf") if GameState.debug_invincible else Color("eef0dc")
	)

	add_theme_color_override(
		"font_pressed_color",
		Color("20c6cf")
	)
