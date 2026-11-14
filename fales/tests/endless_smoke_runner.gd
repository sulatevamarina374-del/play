extends Node

const LAYOUT = preload("res://arena_layout.gd")
const REWARDS = preload("res://room_rewards.gd")
const RULES = preload("res://reward_schedule.gd")
const BOOK = preload("res://reward_book.gd")
const CHEST = preload("res://reward_chest.gd")
const SIZES: Array[Vector2] = [
	Vector2(768, 960), Vector2(640, 1152),
	Vector2(1152, 832), Vector2(896, 896)
]
const ROOMS: Array[int] = [1, 3, 5, 6, 10, 15]

var failures: int = 0
var checked_layouts: int = 0
var fallback_count: int = 0


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("TEST FAILURE: " + message)


func _run() -> void:
	var coins_before: int = Profile.coins
	var record_before: int = Profile.best_cleared_room
	test_layouts()
	test_forced_fallback()
	test_completion()
	check(Profile.coins == coins_before, "тест изменил монеты")
	check(Profile.best_cleared_room == record_before, "тест изменил рекорд")
	print("REWARD_TEST_RESULT layouts=%d fallbacks=%d failures=%d" % [
		checked_layouts, fallback_count, failures
	])
	get_tree().quit(0 if failures == 0 else 1)


func test_layouts() -> void:
	for seed_index in range(20):
		for number in ROOMS:
			var is_boss: bool = number % 5 == 0
			var seed_value: int = 123456 + seed_index * 1009
			var plan: Dictionary = RULES.make_plan(number, is_boss, seed_value)
			check(plan == RULES.make_plan(number, is_boss, seed_value), "повторный бросок изменил награду")
			check(bool(plan["book"]) or bool(plan["chest"]), "нет награды")
			if number % 3 == 0:
				check(bool(plan["book"]), "нет обязательной книги")
			if is_boss:
				check(bool(plan["chest"]), "нет сундука босса")
			else:
				check(bool(plan["chest"]) == (number % 3 != 0), "чередование наград")
			if bool(plan["chest"]):
				var amount: int = int(plan["coins"])
				check(amount >= (7 if is_boss else 3), "слишком мало монет")
				check(amount <= (10 if is_boss else 7), "слишком много монет")

			for size in SIZES:
				var dimensions: Vector2 = Vector2(960, 960) if is_boss else size
				var random := RandomNumberGenerator.new()
				random.seed = seed_value + number * 104729
				var layout = LAYOUT.new()
				layout.setup(dimensions, random, is_boss)
				var rewards = REWARDS.new()
				var start: Vector2 = Vector2(dimensions.x / 2.0, dimensions.y - 140)
				var exit_point: Vector2 = Vector2(dimensions.x / 2.0, 80)
				var needs_two: bool = bool(plan["book"]) and bool(plan["chest"])
				var places: Array[Vector2] = rewards.select_places(exit_point, layout, start, needs_two)
				if places.is_empty():
					fallback_count += 1
					layout.make_reward_fallback()
					places = rewards.select_places(exit_point, layout, start, needs_two)
				check(places.size() == (2 if needs_two else 1), "число мест")
				check(layout.can_reach(start, exit_point), "нет пути к двери")
				var safe_places: Array[Vector2] = rewards.find_places(exit_point, layout)
				for point in places:
					check(safe_places.has(point), "небезопасный размер площадки")
					check(layout.can_reach(start, point), "награда недоступна")
				if places.size() == 2:
					check(places[0].distance_to(places[1]) >= 112.0, "награды слишком близко")
				checked_layouts += 1
				layout.free()


func test_forced_fallback() -> void:
	var layout = LAYOUT.new()
	var random := RandomNumberGenerator.new()
	random.seed = 77
	layout.setup(Vector2(768, 960), random, true)
	# Намеренно испорченная планировка только внутри теста.
	layout._add_obstacle(Vector2(384, 480), Vector2(768, 64))
	layout._build_graph()
	var rewards = REWARDS.new()
	var start: Vector2 = Vector2(384, 820)
	var exit_point: Vector2 = Vector2(384, 80)
	check(not rewards.find_places(exit_point, layout).is_empty(), "нет свободных площадок для проверки пути")
	check(rewards.select_places(exit_point, layout, start, true).is_empty(), "тестовая преграда не блокирует путь")
	layout.make_reward_fallback()
	var places: Array[Vector2] = rewards.select_places(exit_point, layout, start, true)
	check(places.size() == 2, "открытый резервный вариант не восстановил два места")
	check(layout.obstacles.is_empty() and layout.water_zones.is_empty(), "остались старые препятствия")
	layout.free()


func test_completion() -> void:
	var rewards = REWARDS.new()
	var book = BOOK.new()
	var chest = CHEST.new()
	rewards.book = book
	rewards.chest = chest
	rewards.requires_book = true
	rewards.requires_chest = true
	check(not rewards.all_collected(), "неподготовленная награда завершена")

	rewards.prepared = true
	check(not rewards.all_collected(), "две неполученные награды завершены")
	rewards.mark_book_completed()
	check(not rewards.all_collected(), "одна книга завершила обе награды")
	chest.used = true
	check(rewards.all_collected(), "обе награды не завершили условие")

	rewards.book_completed = false
	check(not rewards.all_collected(), "один сундук завершил обе награды")
	rewards.mark_book_completed()
	check(rewards.all_collected(), "не работает обратный порядок наград")

	rewards.requires_chest = false
	check(rewards.all_collected(), "одна завершённая книга")
	rewards.book_completed = false
	check(not rewards.all_collected(), "открытие книги не равно получению")
	rewards.requires_book = false
	rewards.requires_chest = true
	chest.used = false
	check(not rewards.all_collected(), "неполученный сундук")
	chest.used = true
	check(rewards.all_collected(), "один завершённый сундук")
	chest.free()
	check(not rewards.all_collected(), "отсутствующая награда считается полученной")
	book.free()
