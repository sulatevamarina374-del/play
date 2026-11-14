extends "res://skill_book.gd"

signal reward_finished

const WORKING_SPELLS: Array[String] = [
	"dark_spheres",
	"light_spheres",
	"wind_spheres",
	"water_spheres",
	"fire_spheres",
	"ice_spheres",

	"dark_orbit",
	"light_orbit",
	"wind_orbit",
	"water_orbit",
	"fire_orbit",
	"ice_orbit",

	"dark_lightning",
	"dark_seal",
	"water_geyser",

	"fire_meteors",
	"water_cascade",
	"wind_tornado",

	"wind_waves",
	"ice_ridge",
	"ice_ring",
	
	"fire_breath",
	"light_heal",
	"light_shield"
]

const ELEMENT_COLORS: Dictionary = {
	"dark": Color("80609c"),
	"light": Color("efe3a0"),
	"wind": Color("94c89a"),
	"water": Color("5eadd1"),
	"fire": Color("ff9850"),
	"ice": Color("a5dce5")
}

var offered_ids: Array[String] = []
var last_screen: Vector2 = Vector2(-1, -1)

var take_button: Button
var chosen_index: int = -1
var reward_used: bool = false
var replacement_id: String = ""


func _ready() -> void:
	super._ready()

	book_button.hide()
	left_title.text = "Выбор"
	spell_title.add_theme_font_size_override("font_size", 20)
	close_button.text = "Отказаться"
	z_index = 20

	take_button = Button.new()
	take_button.text = "Получить"
	take_button.disabled = true
	take_button.pressed.connect(take_selected_spell)
	shade.add_child(take_button)

	last_screen = Vector2(-1, -1)
	update_layout()


func open_offers() -> void:
	if reward_used or shade.visible or get_tree().paused:
		return

	if offered_ids.is_empty():
		make_offers()

	open_book()


func get_owned_level(spell_id: String) -> int:
	for spell in GameState.selected_spells:
		if str(spell.get("id", "")) == spell_id:
			return int(spell.get("level", 1))

	return 0


func make_offers() -> void:
	
	var candidates: Array[String] = []

	for spell_id in WORKING_SPELLS:
		var data: Dictionary = GameState.SPELL_CATALOG.get_spell(spell_id)
		if data.is_empty():
			continue

		if get_owned_level(spell_id) >= GameState.MAX_SPELL_LEVEL:
			continue

		candidates.append(spell_id)


	var random := RandomNumberGenerator.new()
	random.seed = GameState.run_seed + GameState.room_number * 8191 + 137

	while offered_ids.size() < 3 and not candidates.is_empty():
		var index: int = random.randi_range(0, candidates.size() - 1)
		offered_ids.append(candidates.pop_at(index))


func refresh_slots() -> void:
	if not replacement_id.is_empty():
		refresh_replacement_slots()
		return

	left_title.text = "Выбор"
	close_button.text = "Отказаться"
	last_screen = Vector2(-1, -1)
	update_layout()
	
	for index in range(slots.size()):
		var slot = slots[index]
		slot.visible = index < offered_ids.size()
		slot.occupied = false
		slot.tooltip_text = ""

		if index < offered_ids.size():
			var data: Dictionary = GameState.SPELL_CATALOG.get_spell(
				offered_ids[index]
			)
			var element: String = str(data.get("element", ""))

			slot.occupied = true
			slot.spell_color = ELEMENT_COLORS.get(
				element, Color("b9c6aa")
			)
			slot.tooltip_text = str(data.get("name", "Заклинание"))

		slot.queue_redraw()

	select_slot(0)


func select_slot(index: int) -> void:
	if not replacement_id.is_empty():
		select_replacement_slot(index)
		return
	chosen_index = -1

	for number in range(slots.size()):
		slots[number].selected = number == index
		slots[number].queue_redraw()

	if is_instance_valid(take_button):
		take_button.disabled = true

	if index < 0 or index >= offered_ids.size():
		spell_title.text = "Нет предложений"
		description.text = "Доступных навыков для этой книги нет."
		return

	chosen_index = index

	var spell_id: String = offered_ids[index]
	var data: Dictionary = GameState.SPELL_CATALOG.get_spell(spell_id)
	var element: String = str(data.get("element", ""))
	var element_name: String = str(
		GameState.SPELL_CATALOG.ELEMENTS.get(element, element)
	)
	var level: int = get_owned_level(spell_id)
	var action_text: String = "Новый навык"

	if level > 0:
		action_text = "Уровень: %d → %d" % [level, level + 1]

	spell_title.text = str(data.get("name", "Заклинание"))
	description.text = "%s\n\nСтихия: %s\n\n%s" % [
		action_text,
		element_name,
		str(data.get("description", ""))
	]

	if is_instance_valid(take_button):
		take_button.text = "Улучшить" if level > 0 else "Получить"
		take_button.disabled = false


func take_selected_spell() -> void:
	if reward_used or not shade.visible:
		return

	if not replacement_id.is_empty():
		var replace_result: String = GameState.replace_spell(
			chosen_index,
			replacement_id
		)

		if replace_result == "replaced":
			finish_reward()
		else:
			description.text = "Не удалось заменить навык. Нажми «Назад» и выбери снова."

		return

	if chosen_index < 0 or chosen_index >= offered_ids.size():
		return

	var spell_id: String = offered_ids[chosen_index]

	if get_owned_level(spell_id) == 0:
		if GameState.selected_spells.size() >= GameState.MAX_SPELL_SLOTS:
			replacement_id = spell_id
			refresh_slots()
			return

	var result: String = GameState.acquire_spell(spell_id)

	if result == "learned" or result == "upgraded":
		finish_reward()
		return

	if result == "max":
		description.text = "Этот навык уже максимального уровня."
	else:
		description.text = "Не удалось получить навык. Книга не потрачена."

	take_button.disabled = true


func close_book() -> void:
	if not is_instance_valid(shade) or not shade.visible:
		return

	if reward_used:
		return

	if not replacement_id.is_empty():
		replacement_id = ""
		refresh_slots()
		return

	finish_reward()


func update_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	if viewport_size == last_screen:
		return

	last_screen = viewport_size
	super.update_layout()

	# Расположение кругов навыков.
	var page_middle: float = pages.size.x / 2.0
	var slot_row_step: float = (pages.size.y - 130.0) / 3.0
	var is_replacing: bool = not replacement_id.is_empty()
	var slot_columns: int = 2 if is_replacing else 1
	var slot_gap: float = 12.0
	var slot_diameter: float = minf(64.0, slot_row_step - 8.0)

	if is_replacing:
		slot_diameter = minf(
			slot_diameter,
			(page_middle - 52.0) / 2.0
		)

	var shown_slot_count: int = offered_ids.size()

	if is_replacing:
		shown_slot_count = GameState.selected_spells.size()

	var slot_group_width: float = (
		slot_diameter * slot_columns
		+ slot_gap * (slot_columns - 1)
	)
	var slots_start_x: float = (
		page_middle - slot_group_width
	) / 2.0

	for index in range(slots.size()):
		slots[index].visible = index < shown_slot_count

		if index >= shown_slot_count:
			continue

		slots[index].size = Vector2(
			slot_diameter,
			slot_diameter
		)
		slots[index].position = Vector2(
			slots_start_x
			+ (index % slot_columns) * (slot_diameter + slot_gap),
			96.0
			+ floorf(float(index) / float(slot_columns)) * slot_row_step
		)

	# Во время создания интерфейса кнопка ещё может отсутствовать.
	if not is_instance_valid(take_button):
		return

	# Расположение кнопок.
	var action_button_width: float = minf(
		180.0,
		(viewport_size.x - 36.0) / 2.0
	)
	var action_buttons_start_x: float = (
		viewport_size.x - action_button_width * 2.0 - 12.0
	) / 2.0
	var action_buttons_y: float = (
		pages.position.y + pages.size.y + 16.0
	)

	take_button.size = Vector2(action_button_width, 56)
	take_button.position = Vector2(
		action_buttons_start_x,
		action_buttons_y
	)

	close_button.size = Vector2(action_button_width, 56)
	close_button.position = Vector2(
		action_buttons_start_x + action_button_width + 12.0,
		action_buttons_y
	)


func refresh_replacement_slots() -> void:
	left_title.text = "Заменить"
	close_button.text = "Назад"

	last_screen = Vector2(-1, -1)
	update_layout()

	for index in range(slots.size()):
		var slot = slots[index]
		slot.visible = index < GameState.selected_spells.size()
		slot.occupied = false
		slot.tooltip_text = ""

		if index < GameState.selected_spells.size():
			var owned: Dictionary = GameState.selected_spells[index]
			var data: Dictionary = GameState.SPELL_CATALOG.get_spell(
				str(owned.get("id", ""))
			)
			var element: String = str(data.get("element", ""))

			slot.occupied = true
			slot.spell_color = ELEMENT_COLORS.get(
				element, Color("b9c6aa")
			)
			slot.tooltip_text = "%s — уровень %d" % [
				str(data.get("name", "Заклинание")),
				int(owned.get("level", 1))
			]

		slot.queue_redraw()

	select_replacement_slot(0)


func select_replacement_slot(index: int) -> void:
	chosen_index = -1
	take_button.disabled = true

	for number in range(slots.size()):
		slots[number].selected = number == index
		slots[number].queue_redraw()

	if index < 0 or index >= GameState.selected_spells.size():
		return

	chosen_index = index

	var owned: Dictionary = GameState.selected_spells[index]
	var old_data: Dictionary = GameState.SPELL_CATALOG.get_spell(
		str(owned.get("id", ""))
	)
	var new_data: Dictionary = GameState.SPELL_CATALOG.get_spell(
		replacement_id
	)

	spell_title.text = "Замена навыка"
	description.text = "Убрать:\n%s\nУровень: %d\n\nПолучить:\n%s\nУровень: 1\n\nУровень старого навыка будет потерян." % [
		str(old_data.get("name", "Заклинание")),
		int(owned.get("level", 1)),
		str(new_data.get("name", "Заклинание"))
	]

	take_button.text = "Заменить"
	take_button.disabled = false
	
func finish_reward() -> void:
	if reward_used:
		return

	reward_used = true
	replacement_id = ""

	super.close_book()
	reward_finished.emit()
	
