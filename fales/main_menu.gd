extends Control

const PREVIEW = preload("res://menu_mage_preview.gd")
const ROBES = preload("res://robe_catalog.gd")
const CATALOG = preload("res://spell_catalog.gd")
const FONT = preload("res://assets/fonts/Tiny5-Regular.ttf")
const SETTINGS_PATH: String = "user://menu_settings.cfg"


class GearIcon extends Control:
	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var ink := Color("c4cfb8")

		for index in range(8):
			var direction := Vector2.from_angle(
				float(index) * TAU / 8.0
			)
			draw_line(
				center + direction * 10.0,
				center + direction * 16.0,
				ink,
				5.0
			)

		draw_arc(center, 9.0, 0.0, TAU, 24, ink, 4.0)


var frame: Panel
var record_label: Label
var balance_label: Label
var gear: Button
var navigation: HBoxContainer
var content: Control
var home: Control
var hero: Control
var start_button: Button
var status: Label
var fire_info_label: Label
var fire_feedback_label: Label
var fire_buy_button: Button
var fire_buy_busy: bool = false
var element_fire_card: PanelContainer
var element_other_card: PanelContainer
var element_other_info: Label
var element_icon_buttons: Dictionary = {}
var selected_element_id: String = ""
var ice_buy_button: Button
var ice_feedback_label: Label
var ice_buy_busy: bool = false
var robe_buttons: Dictionary = {}
var robe_feedback: Label
var robe_bonus: Label
var robe_action: Button
var robe_portrait: Control
var robe_grid: GridContainer
var selected_robe_id: String = ""

var pages: Dictionary = {}
var tabs: Dictionary = {}
var current_page: String = "game"
var starting: bool = false
var previous_back_setting: bool = true
var settings := ConfigFile.new()


func _ready() -> void:
	# Старые узлы остаются в сцене, но больше не показываются.
	$Menu.hide()
	$MenuBackground.hide()

	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = preload("res://assets/ui/menu_theme.tres").duplicate()
	theme.default_font = FONT

	previous_back_setting = get_tree().quit_on_go_back
	get_tree().quit_on_go_back = false

	var background := ColorRect.new()
	background.color = Color("242f2b")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	add_child(background)

	frame = Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", make_frame())
	add_child(frame)

	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(content)

	balance_label = make_label(
		"Монеты: %d" % Profile.coins,
		20
	)
	balance_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	balance_label.clip_text = true
	frame.add_child(balance_label)

	record_label = make_label(
		"Рекорд: —" if Profile.best_cleared_room == 0
		else "Рекорд: %d" % Profile.best_cleared_room,
		24
	)
	record_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	record_label.clip_text = true
	
	record_label.add_theme_stylebox_override(
		"normal",
		make_frame()
	)
	add_child(record_label)

	gear = make_button("", show_page.bind("settings"))
	gear.tooltip_text = "Настройки"
	gear.add_theme_stylebox_override(
		"normal",
		StyleBoxEmpty.new()
	)
	add_child(gear)

	var icon := GearIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	gear.add_child(icon)

	build_home()
	build_robes()
	build_elements()
	build_settings()
	build_navigation()

	get_viewport().size_changed.connect(update_layout)

	show_page("game")
	update_layout()


func make_frame() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = preload("res://assets/ui/health_panel.png")

	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 12.0)
		style.set_content_margin(side, 12.0)

	return style


func make_label(
	text_value: String,
	font_size: int = 22
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_stylebox_override(
		"normal",
		StyleBoxEmpty.new()
	)

	return label


func make_button(
	text_value: String,
	action: Callable
) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 56
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)

	return button


func build_home() -> void:
	home = Control.new()
	home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(home)
	pages["game"] = home

	hero = PREVIEW.new()
	home.add_child(hero)

	status = make_label(GameState.result, 18)
	home.add_child(status)

	start_button = make_button("Начать игру", start_game)
	home.add_child(start_button)


func make_page(
	id: String,
	heading: String
) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	content.add_child(scroll)
	pages[id] = scroll

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	column.add_child(make_label(heading, 28))

	return column

func build_robes() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)

	content.add_child(column)
	pages["robes"] = column

	selected_robe_id = Profile.equipped_robe_id

	if (
		not ROBES.DATA.has(selected_robe_id)
		or not Profile.owned_robe_ids.has(selected_robe_id)
	):
		selected_robe_id = ""

	# Название и бонус выбранного образа.
	robe_bonus = make_label("", 16)
	robe_bonus.custom_minimum_size.y = 32
	column.add_child(robe_bonus)

	# Большой маг для примерки.
	robe_portrait = PREVIEW.new()
	robe_portrait.show_door = false
	robe_portrait.use_preview_override = true
	robe_portrait.custom_minimum_size.y = 35
	robe_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(robe_portrait)

	# Купить или надеть выбранную мантию.
	robe_action = make_button("", on_robe_action_pressed)
	robe_action.custom_minimum_size.y = 40
	column.add_child(robe_action)

	robe_feedback = make_label("", 12)
	robe_feedback.custom_minimum_size.y = 14
	column.add_child(robe_feedback)

	# Карточки всех образов внизу.
	var grid := GridContainer.new()
	robe_grid = grid
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)

	content.resized.connect(adapt_robe_grid)

	for id in ["", "green", "blue", "red"]:
		var card := Button.new()
		card.custom_minimum_size.y = 73
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(select_robe.bind(id))
		grid.add_child(card)

		robe_buttons[id] = card

		var inner := VBoxContainer.new()
		inner.name = "CardContent"
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 0)
		card.add_child(inner)
		inner.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		var picture = PREVIEW.new()
		picture.show_door = false
		picture.is_thumbnail = true
		picture.use_preview_override = true
		picture.preview_robe_id = id
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inner.add_child(picture)

		var caption: Label = make_label("", 13)
		caption.name = "Caption"
		inner.add_child(caption)

	adapt_robe_grid()
	refresh_robes()


func adapt_robe_grid() -> void:
	if is_instance_valid(robe_grid):
		robe_grid.columns = 4 if content.size.y < 440.0 else 3


func select_robe(id: String) -> void:
	if not id.is_empty() and not ROBES.DATA.has(id):
		return

	selected_robe_id = id
	robe_feedback.text = ""
	refresh_robes()


func refresh_robes() -> void:
	balance_label.text = "Монеты: %d" % Profile.coins

	robe_portrait.preview_robe_id = selected_robe_id
	robe_portrait.queue_redraw()

	if selected_robe_id.is_empty():
		robe_bonus.text = "Исходный маг\nБез бонуса"
	else:
		var data: Dictionary = ROBES.DATA[selected_robe_id]
		robe_bonus.text = data["name"] + "\n" + data["bonus"]

	if selected_robe_id == Profile.equipped_robe_id:
		robe_action.text = (
			"Надет" if selected_robe_id.is_empty() else "Надета"
		)
		robe_action.disabled = true

	elif (
		selected_robe_id.is_empty()
		or Profile.owned_robe_ids.has(selected_robe_id)
	):
		robe_action.text = "Надеть"
		robe_action.disabled = false

	else:
		robe_action.text = "Купить — %d монет" % ROBES.PRICE
		robe_action.disabled = false

	for id in ["", "green", "blue", "red"]:
		var card: Button = robe_buttons[id]
		var caption: Label = card.get_node("CardContent/Caption")

		var title: String
		var price: String

		if id.is_empty():
			title = "Исходный"
			price = "Бесплатно"
		else:
			title = str(ROBES.DATA[id]["name"]).replace(
				" мантия",
				""
			)
			price = "%d монет" % ROBES.PRICE

		caption.text = title + "\n" + price

		if id == selected_robe_id:
			card.modulate = Color(1, 1, 1)
		else:
			card.modulate = Color(0.72, 0.72, 0.72)


func on_robe_action_pressed() -> void:
	var id: String = selected_robe_id
	var result_code: String

	if id.is_empty() or Profile.owned_robe_ids.has(id):
		result_code = Profile.try_equip_robe(id)
	else:
		result_code = Profile.try_buy_robe(id)

	match result_code:
		"bought":
			robe_feedback.text = "Куплено. Нажми «Надеть»."
		"equipped":
			robe_feedback.text = "Мантия надета."
		"not_enough":
			robe_feedback.text = "Недостаточно монет."
		"save_failed":
			robe_feedback.text = (
				"Ошибка сохранения. Изменения отменены."
			)
		_:
			robe_feedback.text = "Не удалось выполнить действие."

	refresh_robes()


func build_elements() -> void:
	var column: VBoxContainer = make_page(
		"elements",
		"Стихии"
	)

	column.add_child(make_label(
		"Выбери стихию",
		20
	))

	# Область дерева и расположенных поверх него значков.
	var tree_area := Control.new()
	tree_area.custom_minimum_size.y = 300
	tree_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tree_area)

	var tree_image := TextureRect.new()
	tree_image.texture = load(
		"res://assets/ui/element_tree.png"
	) as Texture2D
	tree_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tree_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tree_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_area.add_child(tree_image)

	# Дерево по центру области.
	tree_image.anchor_left = 0.5
	tree_image.anchor_right = 0.5
	tree_image.offset_left = -128
	tree_image.offset_right = 128
	tree_image.offset_top = 22
	tree_image.offset_bottom = 278

	# Позиции значков: доля ширины области и отступ сверху.
	var icons: Array[Dictionary] = [
		{"id": "fire",  "x": 0.35, "y": 0.0},
		{"id": "ice",   "x": 0.65, "y": 0.0},
		{"id": "dark",  "x": 0.17, "y": 89.0},
		{"id": "water", "x": 0.83, "y": 89.0},
		{"id": "light", "x": 0.22, "y": 180.0},
		{"id": "wind",  "x": 0.78, "y": 180.0}
	]

	element_icon_buttons.clear()

	for data in icons:
		var element_id: String = data["id"]
		var icon_button := TextureButton.new()

		icon_button.texture_normal = load(
			"res://assets/ui/elements/%s.png" % element_id
		) as Texture2D

		icon_button.ignore_texture_size = true
		icon_button.stretch_mode = (
			TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		)
		icon_button.tooltip_text = CATALOG.ELEMENTS[element_id]
		icon_button.modulate = Color(0.7, 0.7, 0.7, 1.0)
		icon_button.pressed.connect(select_element.bind(element_id))

		tree_area.add_child(icon_button)

		var x: float = float(data["x"])
		var y: float = float(data["y"])

		icon_button.anchor_left = x
		icon_button.anchor_right = x
		icon_button.offset_left = -32
		icon_button.offset_right = 32
		icon_button.offset_top = y
		icon_button.offset_bottom = y + 64

		element_icon_buttons[element_id] = icon_button

	# Существующая рабочая карточка огня.
	element_fire_card = PanelContainer.new()
	element_fire_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	element_fire_card.add_theme_stylebox_override("panel", make_frame())
	column.add_child(element_fire_card)

	var fire_column := VBoxContainer.new()
	fire_column.add_theme_constant_override("separation", 8)
	element_fire_card.add_child(fire_column)

	fire_info_label = make_label("", 20)
	fire_info_label.custom_minimum_size.y = 100
	fire_column.add_child(fire_info_label)

	fire_buy_button = make_button(
		"Улучшить",
		upgrade_fire_pressed
	)
	fire_column.add_child(fire_buy_button)

	fire_feedback_label = make_label("", 18)
	fire_feedback_label.custom_minimum_size.y = 32
	fire_column.add_child(fire_feedback_label)

	# Временная информационная карточка остальных стихий.
	element_other_card = PanelContainer.new()
	element_other_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	element_other_card.add_theme_stylebox_override("panel", make_frame())
	column.add_child(element_other_card)

	var other_column := VBoxContainer.new()
	other_column.add_theme_constant_override("separation", 8)
	element_other_card.add_child(other_column)

	element_other_info = make_label("", 20)
	element_other_info.custom_minimum_size.y = 100
	other_column.add_child(element_other_info)

	ice_buy_button = make_button(
		"Улучшить",
		upgrade_ice_pressed
	)
	other_column.add_child(ice_buy_button)

	ice_feedback_label = make_label("", 18)
	ice_feedback_label.custom_minimum_size.y = 32
	other_column.add_child(ice_feedback_label)

	# До первого нажатия карточки скрыты.
	element_fire_card.hide()
	element_other_card.hide()

	refresh_fire_card()


func select_element(element_id: String) -> void:
	if not CATALOG.ELEMENTS.has(element_id):
		return

	selected_element_id = element_id

	for id in element_icon_buttons:
		var icon_button: TextureButton = element_icon_buttons[id]

		if id == element_id:
			icon_button.modulate = Color.WHITE
		else:
			icon_button.modulate = Color(0.7, 0.7, 0.7, 1.0)

	fire_feedback_label.text = ""
	ice_feedback_label.text = ""

	if element_id == "fire":
		element_other_card.hide()
		element_fire_card.show()
		refresh_fire_card()
		return

	element_fire_card.hide()
	element_other_card.show()
	refresh_other_element_card()


func refresh_other_element_card() -> void:
	var can_upgrade: bool = (
		selected_element_id == "ice"
		or selected_element_id == "water"
		or selected_element_id == "wind"
		or selected_element_id == "dark"
		or selected_element_id == "light"
	)

	ice_buy_button.visible = can_upgrade
	ice_feedback_label.visible = can_upgrade

	if not can_upgrade:
		if not CATALOG.ELEMENTS.has(selected_element_id):
			return

		var displayed_level: int = maxi(
			1,
			int(Profile.element_levels.get(selected_element_id, 0))
		)

		element_other_info.text = (
			"%s — уровень %d / 10\n" % [
				CATALOG.ELEMENTS[selected_element_id],
				displayed_level
			]
			+ "Прокачка этой стихии пока не подключена."
		)
		return

	var element_name: String = CATALOG.ELEMENTS[selected_element_id]
	var level: int
	var cost: int

	if selected_element_id == "ice":
		level = Profile.ice_level()
		cost = Profile.ice_upgrade_cost()
	elif selected_element_id == "water":
		level = Profile.water_level()
		cost = Profile.water_upgrade_cost()
	elif selected_element_id == "wind":
		level = Profile.wind_level()
		cost = Profile.wind_upgrade_cost()
	elif selected_element_id == "dark":
		level = Profile.dark_level()
		cost = Profile.dark_upgrade_cost()
	else:
		level = Profile.light_level()
		cost = Profile.light_upgrade_cost()

	if level < 1:
		element_other_info.text = (
			"%s\nОшибка уровня в профиле.\n" % element_name
			+ "Покупка заблокирована."
		)
		ice_buy_button.text = "Недоступно"
		ice_buy_button.disabled = true
		return

	var bonus: int = (level - 1) * 15
	var bonus_caption: String = "Бонус к урону"

	if selected_element_id == "light":
		bonus_caption = "Урон, лечение и щит"

	if level >= 10:
		element_other_info.text = (
			"%s — уровень 10 / 10\n" % element_name
			+ "%s: +%d%%\n" % [bonus_caption, bonus]
			+ "Максимальный уровень"
		)
		ice_buy_button.text = "Максимум"
		ice_buy_button.disabled = true
		return

	var next_bonus: int = level * 15

	element_other_info.text = (
		"%s — уровень %d / 10\n" % [element_name, level]
		+ "%s: +%d%% → +%d%%\n" % [
			bonus_caption,
			bonus,
			next_bonus
		]
		+ "Цена: %d монет" % cost
	)

	ice_buy_button.text = "Улучшить за %d" % cost
	ice_buy_button.disabled = ice_buy_busy or Profile.coins < cost


func upgrade_ice_pressed() -> void:
	if ice_buy_busy:
		return

	var element_id: String = selected_element_id

	if element_id not in ["ice", "water", "wind", "dark", "light"]:
		return

	ice_buy_busy = true
	refresh_other_element_card()

	var result: String

	if element_id == "ice":
		result = Profile.try_upgrade_ice()
	elif element_id == "water":
		result = Profile.try_upgrade_water()
	elif element_id == "wind":
		result = Profile.try_upgrade_wind()
	elif element_id == "dark":
		result = Profile.try_upgrade_dark()
	else:
		result = Profile.try_upgrade_light()

	match result:
		"ok":
			ice_feedback_label.text = "Улучшение сохранено."
		"insufficient":
			ice_feedback_label.text = "Недостаточно монет."
		"max":
			ice_feedback_label.text = "Уровень уже максимальный."
		"invalid":
			ice_feedback_label.text = "Ошибка данных уровня."
		_:
			ice_feedback_label.text = (
				"Не удалось сохранить покупку. "
				+ "Монеты и уровень возвращены."
			)

	refresh_fire_card()
	refresh_other_element_card()

	await get_tree().create_timer(0.6).timeout

	ice_buy_busy = false
	refresh_other_element_card()


func refresh_fire_card() -> void:
	balance_label.text = "Монеты: %d" % Profile.coins

	var level: int = Profile.fire_level()

	if level < 1:
		fire_info_label.text = (
			"Огонь\nОшибка уровня в профиле.\n"
			+ "Покупка заблокирована."
		)
		fire_buy_button.text = "Недоступно"
		fire_buy_button.disabled = true
		return

	var bonus: int = (level - 1) * 15

	if level >= 10:
		fire_info_label.text = (
			"Огонь — уровень 10 / 10\n"
			+ "Бонус: +%d%%\n" % bonus
			+ "Максимальный уровень"
		)
		fire_buy_button.text = "Максимум"
		fire_buy_button.disabled = true
		return

	var cost: int = Profile.fire_upgrade_cost()
	var next_bonus: int = level * 15

	fire_info_label.text = (
		"Огонь — уровень %d / 10\n" % level
		+ "Бонус к урону: +%d%% → +%d%%\n" % [bonus, next_bonus]
		+ "Цена: %d монет" % cost
	)

	fire_buy_button.text = "Улучшить за %d" % cost
	fire_buy_button.disabled = fire_buy_busy or Profile.coins < cost


func upgrade_fire_pressed() -> void:
	if fire_buy_busy:
		return

	# Короткая блокировка защищает от случайного двойного нажатия.
	fire_buy_busy = true
	refresh_fire_card()

	var result: String = Profile.try_upgrade_fire()

	match result:
		"ok":
			fire_feedback_label.text = "Огонь улучшен и сохранён."
		"insufficient":
			fire_feedback_label.text = "Недостаточно монет."
		"max":
			fire_feedback_label.text = "Уровень уже максимальный."
		"invalid":
			fire_feedback_label.text = "Ошибка данных уровня."
		_:
			fire_feedback_label.text = (
				"Не удалось сохранить покупку. "
				+ "Монеты и уровень возвращены."
			)

	refresh_fire_card()

	await get_tree().create_timer(0.6).timeout

	fire_buy_busy = false
	refresh_fire_card()


func build_settings() -> void:
	var column: VBoxContainer = make_page(
		"settings",
		"Настройки"
	)

	var error: Error = settings.load(SETTINGS_PATH)
	var volume: float = (
		db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0
	)

	if AudioServer.is_bus_mute(0):
		volume = 0.0

	if error == OK:
		var saved: Variant = settings.get_value(
			"audio",
			"volume",
			volume
		)

		if saved is float or saved is int:
			volume = clampf(float(saved), 0.0, 100.0)

	apply_volume(volume)

	var caption: Label = make_label(
		"Громкость: %d%%" % int(volume),
		24
	)
	column.add_child(caption)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = volume
	slider.custom_minimum_size.y = 56

	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("20212b")
	rail.content_margin_top = 3
	rail.content_margin_bottom = 3
	slider.add_theme_stylebox_override("slider", rail)

	var filled: StyleBoxFlat = rail.duplicate()
	filled.bg_color = Color("82a389")
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override(
		"grabber_area_highlight",
		filled
	)

	var knob := Image.create(
		12,
		20,
		false,
		Image.FORMAT_RGBA8
	)
	knob.fill(Color("20212b"))
	knob.fill_rect(
		Rect2i(2, 2, 8, 16),
		Color("c4cfb8")
	)

	var knob_texture := ImageTexture.create_from_image(knob)

	for icon_name in [
		"grabber",
		"grabber_highlight",
		"grabber_disabled"
	]:
		slider.add_theme_icon_override(
			icon_name,
			knob_texture
		)

	column.add_child(slider)

	var feedback: Label = make_label("", 18)
	column.add_child(feedback)

	slider.value_changed.connect(func(value: float) -> void:
		apply_volume(value)
		caption.text = "Громкость: %d%%" % int(value)
		settings.set_value("audio", "volume", value)

		feedback.text = (
			"" if settings.save(SETTINGS_PATH) == OK
			else "Не удалось сохранить настройку."
		)
	)

	column.add_child(make_button(
		"Назад к игре",
		show_page.bind("game")
	))


func apply_volume(value: float) -> void:
	AudioServer.set_bus_mute(0, value <= 0.0)
	AudioServer.set_bus_volume_db(
		0,
		linear_to_db(maxf(value / 100.0, 0.0001))
	)


func build_navigation() -> void:
	navigation = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	add_child(navigation)

	var group := ButtonGroup.new()

	for entry in [
		["robes", "Мантии"],
		["game", "Игра"],
		["elements", "Стихии"]
	]:
		var id: String = entry[0]
		var button: Button = make_button(
			entry[1],
			show_page.bind(id)
		)

		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		navigation.add_child(button)
		tabs[id] = button


func show_page(id: String) -> void:
	if starting or not pages.has(id):
		return

	current_page = id

	for key in pages:
		pages[key].visible = key == id

	for key in tabs:
		tabs[key].set_pressed_no_signal(key == id)

	gear.release_focus()
	# Даём тексту и карточкам рассчитаться по ширине,
	# затем подгоняем страницу под рамку.
	if id == "robes":
		await get_tree().process_frame
		await get_tree().process_frame

		if current_page == "robes" and pages.has("robes"):
			pages["robes"].position = Vector2.ZERO
			pages["robes"].size = content.size


func update_layout() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var width: float = minf(560.0, screen.x - 32.0)

	frame.position = Vector2(
		(screen.x - width) * 0.5,
		76
	)
	frame.size = Vector2(
		width,
		maxf(220.0, screen.y - 164.0)
	)

	balance_label.position = Vector2(24, 36)
	balance_label.size = Vector2(width - 48, 28)

	var badge_width: float = minf(
		240.0,
		width - 128.0
	)

	record_label.position = Vector2(
		(screen.x - badge_width) * 0.5,
		48
	)

	var record_font_size: int = 24

	while record_font_size > 14 and FONT.get_string_size(
		record_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		record_font_size
	).x > badge_width - 28.0:
		record_font_size -= 1

	record_label.add_theme_font_size_override(
		"font_size",
		record_font_size
	)
	record_label.size = Vector2(badge_width, 52)

	gear.position = Vector2(frame.position.x + 4, 12)
	gear.size = Vector2(56, 56)

	content.position = Vector2(24, 76)
	content.size = Vector2(
		width - 48,
		frame.size.y - 100
	)

	for page in pages.values():
		page.position = Vector2.ZERO
		page.size = content.size

	var has_status: bool = not status.text.is_empty()
	var reserved: float = 128.0 if has_status else 88.0

	hero.position = Vector2.ZERO
	hero.size = Vector2(
		content.size.x,
		maxf(1.0, content.size.y - reserved)
	)

	status.visible = has_status
	status.position = Vector2(
		0,
		content.size.y - 116
	)
	status.size = Vector2(content.size.x, 44)

	var start_width: float = minf(
		280.0,
		content.size.x
	)

	start_button.position = Vector2(
		(content.size.x - start_width) * 0.5,
		content.size.y - 64
	)
	start_button.size = Vector2(start_width, 64)

	navigation.position = Vector2(
		frame.position.x,
		screen.y - 72
	)
	navigation.size = Vector2(width, 56)


func start_game() -> void:
	if starting:
		return

	var room_scene := load(
		"res://endless_room.tscn"
	) as PackedScene

	if room_scene == null:
		status.text = "Не удалось загрузить игровую сцену."
		update_layout()
		return

	starting = true
	start_button.disabled = true

	GameState.reset_run()

	var error: Error = get_tree().change_scene_to_packed(
		room_scene
	)

	if error != OK:
		starting = false
		start_button.disabled = false
		status.text = "Не удалось начать забег."
		update_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if current_page != "game":
			show_page("game")

		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		show_page("game")


func _exit_tree() -> void:
	get_tree().quit_on_go_back = previous_back_setting
