extends Control

class BookIcon:
	extends Control

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 32, 36), Color("20212b"))
		draw_rect(Rect2(3, 3, 26, 28), Color("82a389"))
		draw_rect(Rect2(6, 6, 20, 22), Color("40594f"))
		draw_rect(Rect2(6, 6, 3, 22), Color("a1b49a"))
		draw_rect(Rect2(9, 31, 20, 2), Color("d5dfc7"))


class OpenBook:
	extends Control

	func _draw() -> void:
		var middle: float = size.x / 2.0

		draw_rect(
			Rect2(0, 10, size.x, size.y - 10),
			Color("20212b")
		)
		draw_rect(
			Rect2(5, 15, size.x - 10, size.y - 20),
			Color("40594f")
		)

		var left := PackedVector2Array([
			Vector2(12, 12),
			Vector2(middle - 7, 22),
			Vector2(middle - 7, size.y - 12),
			Vector2(12, size.y - 22)
		])

		var right := PackedVector2Array([
			Vector2(middle + 7, 22),
			Vector2(size.x - 12, 12),
			Vector2(size.x - 12, size.y - 22),
			Vector2(middle + 7, size.y - 12)
		])

		draw_colored_polygon(left, Color("d5dfc7"))
		draw_colored_polygon(right, Color("c6d1b8"))

		draw_rect(
			Rect2(middle - 15, 24, 8, size.y - 38),
			Color("a1af95")
		)
		draw_rect(
			Rect2(middle + 7, 24, 8, size.y - 38),
			Color("a1af95")
		)
		draw_rect(
			Rect2(middle - 4, 22, 8, size.y - 32),
			Color("71836d")
		)


class SpellSlot:
	extends Button

	var selected: bool = false
	var occupied: bool = false
	var spell_color: Color = Color("b9c6aa")

	func _has_point(point: Vector2) -> bool:
		return point.distance_to(size / 2.0) <= size.x / 2.0

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = size.x / 2.0
		var border: Color = Color("20c6cf") if selected or has_focus() else Color("71836d")
		var fill: Color = spell_color if occupied else Color("b9c6aa")

		for y in range(0, int(size.y), 2):
			for x in range(0, int(size.x), 2):
				var distance: float = Vector2(x + 1, y + 1).distance_to(center)
				if distance <= radius:
					var color: Color = border if distance > radius - 4 else fill
					draw_rect(Rect2(x, y, 2, 2), color)

var book_button: Button
var shade: ColorRect
var pages: OpenBook
var close_button: Button

var left_title: Label
var details: VBoxContainer
var spell_title: Label
var description: Label

var slots: Array[SpellSlot] = []
var owns_pause: bool = false

@onready var joystick: Control = get_node_or_null("../Joystick")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = preload("res://assets/ui/upgrade_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	book_button = Button.new()
	book_button.tooltip_text = "Книга заклинаний"
	book_button.pressed.connect(open_book)
	add_child(book_button)

	var icon := BookIcon.new()
	icon.position = Vector2(12, 10)
	icon.size = Vector2(32, 36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_button.add_child(icon)

	shade = ColorRect.new()
	shade.color = Color(0.05, 0.07, 0.08, 0.8)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.hide()
	add_child(shade)

	pages = OpenBook.new()
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.resized.connect(pages.queue_redraw)
	shade.add_child(pages)

	left_title = make_label("Заклинания", 24)
	left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pages.add_child(left_title)

	for index in range(6):
		var slot := SpellSlot.new()
		slot.tooltip_text = "Пустой слот"

		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			slot.add_theme_stylebox_override(
				state,
				StyleBoxEmpty.new()
			)

		slot.pressed.connect(select_slot.bind(index))
		slot.focus_entered.connect(slot.queue_redraw)
		slot.focus_exited.connect(slot.queue_redraw)
		slot.resized.connect(slot.queue_redraw)

		pages.add_child(slot)
		slots.append(slot)

	details = VBoxContainer.new()
	details.add_theme_constant_override("separation", 16)
	pages.add_child(details)

	spell_title = make_label("Выбери заклинание", 24)
	details.add_child(spell_title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(scroll)

	description = make_label(
		"Нажми на круглый значок слева.\n\nЗдесь появятся название и описание заклинания.",
		20
	)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(description)

	close_button = Button.new()
	close_button.text = "Продолжить"
	close_button.pressed.connect(close_book)
	shade.add_child(close_button)

	update_layout()


func make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override(
		"font_color",
		Color("28352f")
	)
	label.add_theme_constant_override("outline_size", 0)

	return label


func _process(_delta: float) -> void:
	update_layout()


func update_layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size

	book_button.size = Vector2(56, 56)
	book_button.position = Vector2(screen.x - 72, 12)
	shade.size = screen

	pages.size = Vector2(
		minf(520.0, screen.x - 24.0),
		minf(430.0, screen.y - 156.0)
	)
	pages.position = (
		screen - Vector2(pages.size.x, pages.size.y + 72)
	) / 2.0

	var middle: float = pages.size.x / 2.0
	var page_width: float = middle - 48.0

	left_title.position = Vector2(24, 42)
	left_title.size = Vector2(page_width, 40)

	details.position = Vector2(middle + 24, 42)
	details.size = Vector2(page_width, pages.size.y - 84)

	var diameter: float = minf(64.0, (middle - 52.0) / 2.0)
	var gap: float = 12.0
	var first_x: float = (
		middle - diameter * 2.0 - gap
	) / 2.0
	var row_step: float = (
		pages.size.y - 158.0 - diameter
	) / 2.0

	for index in range(6):
		slots[index].size = Vector2(diameter, diameter)
		slots[index].position = Vector2(
			first_x + (index % 2) * (diameter + gap),
			108.0 + floorf(index / 2.0) * row_step
		)

	close_button.size = Vector2(200, 56)
	close_button.position = Vector2(
		(screen.x - 200) / 2.0,
		pages.position.y + pages.size.y + 16
	)

func refresh_slots() -> void:
	var element_colors: Dictionary = {
		"dark": Color("80609c"),
		"light": Color("efe3a0"),
		"wind": Color("94c89a"),
		"water": Color("5eadd1"),
		"fire": Color("dc8654"),
		"ice": Color("a5dce5")
	}

	for index in range(slots.size()):
		var slot: SpellSlot = slots[index]
		slot.occupied = false
		slot.spell_color = Color("b9c6aa")
		slot.tooltip_text = "Пустой слот"

		if index < GameState.selected_spells.size():
			var selected_spell: Dictionary = GameState.selected_spells[index]
			var spell_id: String = str(selected_spell.get("id", ""))
			var spell_data: Dictionary = GameState.SPELL_CATALOG.get_spell(spell_id)

			if not spell_data.is_empty():
				var element_id: String = str(spell_data.get("element", ""))
				var level: int = int(selected_spell.get("level", 1))

				slot.occupied = true
				slot.spell_color = element_colors.get(
					element_id, Color("b9c6aa")
				)
				slot.tooltip_text = "%s — уровень %d" % [
					str(spell_data.get("name", "Заклинание")),
					level
				]

		slot.queue_redraw()

	select_slot(0)

func select_slot(index: int) -> void:
	for number in range(slots.size()):
		slots[number].selected = number == index
		slots[number].queue_redraw()

	if index >= GameState.selected_spells.size():
		spell_title.text = "Пустой слот"
		description.text = "В этом слоте пока нет заклинания.\n\nПосле получения навыка здесь появится его описание."
		return

	var selected_spell: Dictionary = GameState.selected_spells[index]
	var spell_id: String = str(selected_spell.get("id", ""))
	var spell_data: Dictionary = GameState.SPELL_CATALOG.get_spell(spell_id)

	if spell_data.is_empty():
		spell_title.text = "Неизвестное заклинание"
		description.text = "Не удалось найти данные заклинания в каталоге."
		return

	var element_id: String = str(spell_data.get("element", ""))
	var element_name: String = str(
		GameState.SPELL_CATALOG.ELEMENTS.get(element_id, element_id)
	)
	var level: int = int(selected_spell.get("level", 1))

	spell_title.text = str(spell_data.get("name", "Заклинание"))
	description.text = "Стихия: %s\nУровень: %d / %d\n\n%s\n\nУлучшение:\n%s" % [
		element_name,
		level,
		GameState.MAX_SPELL_LEVEL,
		str(spell_data.get("description", "")),
		str(spell_data.get("upgrade", ""))
	]


func open_book() -> void:
	if shade.visible or get_tree().paused:
		return

	if is_instance_valid(joystick) and joystick.has_method("reset_stick"):
		joystick.call("reset_stick")
	refresh_slots()
	shade.show()
	owns_pause = true
	get_tree().paused = true


func close_book() -> void:
	shade.hide()

	if owns_pause:
		get_tree().paused = false
		owns_pause = false

	book_button.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if shade.visible and event.is_action_pressed("ui_cancel"):
		close_book()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if owns_pause:
		get_tree().paused = false
