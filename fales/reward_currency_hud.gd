extends Control

const HUD_ICON = preload("res://hud_icon.gd")

var balance: Label
var message: Label
var message_time: float = 0.0
var coin_icon: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 8
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = preload("res://assets/ui/health_theme.tres")

	balance = make_label()
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(balance)

	coin_icon = HUD_ICON.new()
	coin_icon.set("icon_kind", "coin")
	coin_icon.size = Vector2(20, 20)
	add_child(coin_icon)
	
	message = make_label()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.hide()
	add_child(message)

	update_display()


func make_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override(
		"font_color", Color("eef0dc")
	)
	label.add_theme_color_override(
		"font_outline_color", Color("20212b")
	)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_stylebox_override(
		"normal", StyleBoxEmpty.new()
	)

	return label


func _process(delta: float) -> void:
	update_display()

	if message_time > 0.0:
		message_time = maxf(message_time - delta, 0.0)

		if message_time <= 0.0:
			message.hide()


func update_display() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	balance.text = str(Profile.coins)

	var label_width: float = maxf(
		40.0,
		balance.get_combined_minimum_size().x
	)
	var group_width: float = 28.0 + label_width
	var group_left: float = screen.x - group_width - 16.0

	balance.size = Vector2(label_width, 32)
	balance.position = Vector2(group_left + 28.0, screen.y - 48.0)

	coin_icon.size = Vector2(20.0, 20.0)
	coin_icon.position = Vector2(group_left, screen.y - 42.0)

	message.size = Vector2(
		minf(340.0, screen.x - 32.0),
		72
	)
	message.position = Vector2(
		(screen.x - message.size.x) / 2.0,
		144
	)


func show_reward(amount: int) -> void:
	message.text = "+%d монет" % amount
	message.modulate = Color("eef0dc")
	message_time = 3.0
	message.show()
	update_display()


func show_save_error() -> void:
	message.text = "Не удалось сохранить монеты.\nОтойди и подойди к сундуку снова."
	message.modulate = Color("f2b9a6")
	message_time = 5.0
	message.show()
