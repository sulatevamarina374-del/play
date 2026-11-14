extends RefCounted

const RULES = preload("res://reward_schedule.gd")
const BOOK = preload("res://reward_book.gd")
const CHEST = preload("res://reward_chest.gd")
const CURRENCY_HUD = preload("res://reward_currency_hud.gd")

var book: Area2D
var chest: Area2D
var prepared: bool = false
var requires_book: bool = false
var requires_chest: bool = false
var book_completed: bool = false

func setup(
	room: Node2D,
	player: CharacterBody2D,
	exit_area: Area2D,
	layout: Node2D,
	is_boss: bool
) -> bool:
	if prepared:
		return true

	var plan: Dictionary = RULES.make_plan(
		GameState.room_number,
		is_boss,
		GameState.run_seed
	)
	requires_book = bool(plan["book"])
	requires_chest = bool(plan["chest"])

	var selected: Array[Vector2] = select_places(
		exit_area.position, layout, player.position,
		requires_book and requires_chest
	)

	if selected.is_empty():
		push_warning("Планировка не прошла проверку наград. Используется открытый вариант до начала боя.")
		layout.make_reward_fallback()
		selected = select_places(
			exit_area.position, layout, player.position,
			requires_book and requires_chest
		)

	if selected.is_empty():
		push_error("Даже открытая планировка не подходит для наград. Генерация остановлена.")
		return false

	var currency_hud = CURRENCY_HUD.new()
	currency_hud.name = "RewardCurrencyHUD"
	room.get_node("HUD").add_child(currency_hud)
	var place_index: int = 0

	if requires_chest:
		var new_chest = CHEST.new()
		new_chest.name = "RewardChest"
		new_chest.position = selected[place_index]
		new_chest.coin_amount = int(plan["coins"])
		new_chest.collision_mask = player.collision_layer
		new_chest.coins_received.connect(currency_hud.show_reward)
		new_chest.save_failed.connect(currency_hud.show_save_error)
		room.add_child(new_chest)
		chest = new_chest
		place_index += 1

	if requires_book:
		var new_book = BOOK.new()
		new_book.name = "RewardBook"
		new_book.position = selected[place_index]
		new_book.collision_mask = player.collision_layer
		new_book.interaction_requested.connect(
			Callable(room, "_on_reward_book_requested")
		)
		room.add_child(new_book)
		book = new_book

	prepared = true
	return true

func reveal() -> void:
	if is_instance_valid(chest):
		chest.call("reveal_chest")

	if is_instance_valid(book):
		book.call("reveal_book")


func find_places(
	exit_position: Vector2,
	layout: Node2D
) -> Array[Vector2]:
	var places: Array[Vector2] = []

	for row_y in [112, 176, 240, 304]:
		for column_x in [-64, 64, 0, -128, 128, -192, 192]:
			var point: Vector2 = (
				exit_position + Vector2(column_x, row_y)
			)
			var safe: bool = true

			for offset_y in [-44, -24, -4, 16]:
				for offset_x in [-24, 0, 24]:
					var sample: Vector2 = (
						point + Vector2(offset_x, offset_y)
					)

					if not bool(layout.call("is_spawn_safe", sample)):
						safe = false
						break

				if not safe:
					break

			if safe:
				places.append(point)

	return places

func mark_book_completed() -> void:
	if requires_book and is_instance_valid(book):
		book_completed = true


func all_collected() -> bool:
	if not prepared:
		return false

	if not requires_book and not requires_chest:
		return false

	if requires_book:
		if not is_instance_valid(book) or not book_completed:
			return false

	if requires_chest:
		if not is_instance_valid(chest):
			return false
		if chest.get("used") != true:
			return false

	return true


func select_places(
	exit_position: Vector2,
	layout: Node2D,
	start_position: Vector2,
	needs_two: bool
) -> Array[Vector2]:
	var selected: Array[Vector2] = []

	if not layout.can_reach(start_position, exit_position):
		return selected

	var accessible: Array[Vector2] = []
	for point in find_places(exit_position, layout):
		if layout.can_reach(start_position, point):
			accessible.append(point)

	if needs_two:
		for first in accessible:
			for second in accessible:
				if first.distance_to(second) >= 112.0:
					selected.append(first)
					selected.append(second)
					return selected
	elif not accessible.is_empty():
		var center: Vector2 = exit_position + Vector2(0, 112)
		selected.append(center if accessible.has(center) else accessible[0])

	return selected
