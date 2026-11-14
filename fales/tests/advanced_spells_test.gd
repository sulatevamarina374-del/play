extends Node2D

const EFFECT = preload("res://advanced_spell_effect.gd")


class Dummy:
	extends Node2D

	var health: float = 10.0

	func take_damage(amount: float) -> void:
		health = maxf(health - amount, 0.0)


var failures: int = 0
var wall_enabled: bool = false
var mage: Node2D
var enemies: Array[Node2D] = []


func _ready() -> void:
	call_deferred("run_tests")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("ADVANCED TEST FAILURE: " + message)


func has_clear_shot(from: Vector2, to: Vector2) -> bool:
	return not wall_enabled or not (
		minf(from.x, to.x) < 120.0
		and maxf(from.x, to.x) >= 120.0
	)


func make_effect(id: String, level: int, victim: Node2D):
	var effect = EFFECT.new()

	effect.mage = mage
	effect.spell_id = id
	effect.level = level
	effect.target = victim
	effect.damage = 3.0 if id == "fire_meteors" else 1.0
	effect.delay = 1.0
	effect.radius = 64.0

	add_child(effect)
	effect.set_physics_process(false)

	return effect


func reset_targets() -> void:
	for index in range(enemies.size()):
		enemies[index].set("health", 10.0)
		enemies[index].position = Vector2(100 + index * 35, 0)


func run_tests() -> void:
	var old_spells: Array = GameState.selected_spells.duplicate(true)

	GameState.selected_spells.clear()

	for id in ["fire_meteors", "water_cascade", "wind_tornado"]:
		GameState.selected_spells.append({
			"id": id,
			"level": 1
		})

	mage = Dummy.new()
	add_child(mage)

	for index in range(6):
		var enemy = Dummy.new()
		add_child(enemy)
		enemy.add_to_group("enemies")
		enemies.append(enemy)

	reset_targets()

	# Каскад: ровно 2 / 4 / 6 разных целей.
	for level in range(1, 4):
		reset_targets()

		var chain = make_effect(
			"water_cascade",
			level,
			enemies[0]
		)

		for step in range(8):
			chain._physics_process(0.16)

		var hit_count: int = 0

		for enemy in enemies:
			if is_equal_approx(float(enemy.get("health")), 9.0):
				hit_count += 1

		check(
			hit_count == level * 2,
			"каскад: всего 2 / 4 / 6 разных целей"
		)

		chain.free()

	# Метеор: задержка и неподвижная отметка.
	reset_targets()

	var meteor = make_effect("fire_meteors", 1, enemies[0])
	meteor.global_position = enemies[0].global_position
	enemies[0].position.x = 400.0

	meteor._physics_process(0.5)

	check(
		is_equal_approx(float(enemies[1].get("health")), 10.0),
		"метеор ударил раньше задержки"
	)

	meteor._physics_process(0.5)

	check(
		is_equal_approx(meteor.global_position.x, 100.0),
		"метеор переместил отметку"
	)

	check(
		is_equal_approx(float(enemies[0].get("health")), 10.0),
		"метеор догнал ушедшую цель"
	)

	check(
		is_equal_approx(float(enemies[1].get("health")), 7.0),
		"урон метеора по площади"
	)

	meteor.free()

	# Камень блокирует распространение взрыва.
	reset_targets()
	wall_enabled = true

	var blocked = make_effect("fire_meteors", 1, enemies[0])
	blocked.global_position = enemies[0].global_position
	blocked._physics_process(1.0)

	check(
		is_equal_approx(float(enemies[0].get("health")), 7.0),
		"метеор не попал в доступную цель"
	)

	check(
		is_equal_approx(float(enemies[1].get("health")), 10.0),
		"метеор прошёл сквозь камень"
	)

	blocked.free()

	# Каскад тоже не перескакивает сквозь камень.
	reset_targets()

	var short_chain = make_effect(
		"water_cascade",
		3,
		enemies[0]
	)

	for step in range(8):
		short_chain._physics_process(0.16)

	check(
		short_chain.used.size() == 1,
		"каскад прошёл сквозь камень"
	)

	short_chain.free()
	wall_enabled = false

	# Смерч: движение и промежуток между попаданиями.
	reset_targets()

	var tornado = make_effect("wind_tornado", 1, enemies[0])
	tornado._physics_process(0.1)

	check(
		is_equal_approx(tornado.global_position.x, 11.0),
		"движение смерча"
	)

	tornado.global_position = enemies[0].global_position
	tornado._physics_process(0.01)

	check(
		is_equal_approx(float(enemies[0].get("health")), 9.0),
		"первый урон смерча"
	)

	tornado._physics_process(0.2)

	check(
		is_equal_approx(float(enemies[0].get("health")), 9.0),
		"смерч бьёт каждый кадр"
	)

	tornado._physics_process(0.5)

	check(
		is_equal_approx(float(enemies[0].get("health")), 8.0),
		"повторный урон смерча"
	)

	tornado.free()

	# Цель уже удалена, эффект ещё существует.
	var doomed = Dummy.new()
	add_child(doomed)

	var orphan = make_effect("wind_tornado", 1, doomed)
	doomed.free()

	orphan._physics_process(0.1)

	check(
		not orphan.destination_known,
		"обработка удалённой цели"
	)

	orphan.free()

	# Замена навыка отменяет его эффект.
	var cancelled = make_effect("fire_meteors", 1, enemies[0])
	GameState.selected_spells.clear()

	cancelled._physics_process(1.0)

	check(
		cancelled.is_queued_for_deletion(),
		"заменённый навык не отменён"
	)

	cancelled.free()

	GameState.selected_spells.assign(old_spells)

	print("ADVANCED_TEST_RESULT failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
