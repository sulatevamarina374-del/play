extends Control

const CATALOG = preload("res://spell_catalog.gd")
const ROOM_SCENE: String = "res://endless_room.tscn"

const BUILDS: Array[Dictionary] = [
	{
		"name": "1. Все прямые сферы",
		"ids": ["dark_spheres", "light_spheres", "wind_spheres",
			"water_spheres", "fire_spheres", "ice_spheres"]
	},
	{
		"name": "2. Все орбиты",
		"ids": ["dark_orbit", "light_orbit", "wind_orbit",
			"water_orbit", "fire_orbit", "ice_orbit"]
	},
	{
		"name": "3. Молнии, площади и цепь",
		"ids": ["dark_lightning", "dark_seal", "water_geyser",
			"fire_meteors", "water_cascade", "wind_tornado"]
	},
	{
		"name": "4. Контроль и защита",
		"ids": ["wind_waves", "ice_ridge", "ice_ring",
			"fire_breath", "light_heal", "light_shield"]
	},
	{
		"name": "5. Смешанная сборка",
		"ids": ["water_spheres", "wind_orbit", "dark_lightning",
			"fire_meteors", "light_heal", "light_shield"]
	},
	{
		"name": "6. Контроль и ближний бой",
		"ids": ["dark_orbit", "wind_waves", "ice_ring",
			"ice_ridge", "water_cascade", "fire_breath"]
	}
]

var build_choice: OptionButton
var level_choice: OptionButton
var room_choice: SpinBox
var seed_choice: SpinBox
var god_mode: CheckBox
var preview: Label
var start_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("23312d")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16.0
	scroll.offset_top = 16.0
	scroll.offset_right = -16.0
	scroll.offset_bottom = -16.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)

	add_label(column, "Проверка смешанных сборок")
	add_label(
		column,
		"Только тестовая копия. Награды и рекорд сохраняются обычным способом!"
	)

	build_choice = OptionButton.new()
	build_choice.custom_minimum_size.y = 44.0
	for build in BUILDS:
		build_choice.add_item(str(build["name"]))
	column.add_child(build_choice)

	add_label(column, "Уровень всех шести навыков")

	level_choice = OptionButton.new()
	level_choice.custom_minimum_size.y = 44.0
	for level in range(1, 4):
		level_choice.add_item("Уровень %d" % level)
	column.add_child(level_choice)

	add_label(
		column,
		"Начальная комната: 1 — обычная, 5/15/30 — босс"
	)

	room_choice = SpinBox.new()
	room_choice.min_value = 1.0
	room_choice.max_value = 100.0
	room_choice.step = 1.0
	room_choice.value = 1.0
	column.add_child(room_choice)

	add_label(column, "Seed для повторения планировки")

	seed_choice = SpinBox.new()
	seed_choice.min_value = 1.0
	seed_choice.max_value = 2147483647.0
	seed_choice.step = 1.0
	seed_choice.value = 12345.0
	column.add_child(seed_choice)

	god_mode = CheckBox.new()
	god_mode.text = "Бессмертие при старте"
	god_mode.button_pressed = true
	column.add_child(god_mode)

	preview = add_label(column, "")

	start_button = Button.new()
	start_button.text = "Запустить проверку"
	start_button.custom_minimum_size.y = 56.0
	column.add_child(start_button)

	build_choice.item_selected.connect(update_preview)
	start_button.pressed.connect(start_test)
	update_preview(0)


func add_label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)
	return label


func update_preview(index: int) -> void:
	var lines: PackedStringArray = []

	for value in BUILDS[index]["ids"]:
		var id: String = str(value)
		var spell: Dictionary = CATALOG.get_spell(id)
		var element: String = str(spell.get("element", ""))

		lines.append("• %s — %s" % [
			str(CATALOG.ELEMENTS.get(element, element)),
			str(spell.get("name", id))
		])

	preview.text = "\n".join(lines)


func start_test() -> void:
	var build: Dictionary = BUILDS[build_choice.selected]
	var ids: Array = build["ids"]
	var seen: Dictionary = {}

	for value in ids:
		var id: String = str(value)

		if CATALOG.get_spell(id).is_empty() or seen.has(id):
			preview.text = "Ошибка набора навыков: " + id
			return

		seen[id] = true

	if ids.size() != GameState.MAX_SPELL_SLOTS:
		preview.text = "В сборке должно быть ровно шесть навыков."
		return

	var room_scene = load(ROOM_SCENE) as PackedScene

	if room_scene == null:
		preview.text = "Не удалось загрузить: " + ROOM_SCENE
		return

	start_button.disabled = true

	GameState.reset_run()
	GameState.room_number = int(room_choice.value)
	GameState.run_seed = int(seed_choice.value)
	GameState.debug_invincible = god_mode.button_pressed

	var level: int = level_choice.selected + 1

	for value in ids:
		GameState.selected_spells.append({
			"id": str(value),
			"level": level
		})

	print("MIXED_BUILD_START build=%s level=%d room=%d seed=%d" % [
		str(build["name"]),
		level,
		GameState.room_number,
		GameState.run_seed
	])

	var error: Error = get_tree().change_scene_to_packed(room_scene)

	if error != OK:
		preview.text = "Ошибка перехода: %d. Забег уже сброшен." % error
		start_button.disabled = false
