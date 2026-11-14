extends Node2D

const EFFECT = preload("res://control_spell_effect.gd")


class Dummy:
	extends "res://enemy_combat.gd"

	var health: float = 100.0


class Mage:
	extends Node2D

	var health: float = 5.0


var failures: int = 0
var wall_enabled: bool = false

var mage: Node2D
var normal
var boss


func _ready() -> void:
	call_deferred("run_tests")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("CONTROL TEST FAILURE: " + message)


func has_clear_shot(from: Vector2, to: Vector2) -> bool:
	return not wall_enabled or not (
		minf(from.x, to.x) < 80.0
		and maxf(from.x, to.x) >= 80.0
	)


func make_enemy(point: Vector2, is_boss: bool):
	var enemy = Dummy.new()

	add_child(enemy)
	enemy.position = point
	enemy.add_to_group("enemies")

	if is_boss:
		enemy.add_to_group("boss")

	return enemy


func make_effect(id: String, level: int):
	var effect = EFFECT.new()

	effect.mage = mage
	effect.spell_id = id
	effect.level = level
	effect.direction = Vector2.RIGHT
	effect.damage = 1.0

	add_child(effect)
	effect.set_physics_process(false)
	effect.global_position = Vector2.ZERO

	return effect


func reset_enemies() -> void:
	for enemy in [normal, boss]:
		enemy.set("health", 100.0)
		enemy.combat_effects.clear()

	normal.position = Vector2(100, 0)
	boss.position = Vector2(100, 50)


func run_tests() -> void:
	var old_spells: Array = GameState.selected_spells.duplicate(true)

	GameState.selected_spells.clear()

	for id in ["wind_waves", "ice_ridge", "ice_ring"]:
		GameState.selected_spells.append({
			"id": id,
			"level": 1
		})

	mage = Mage.new()
	add_child(mage)

	normal = make_enemy(Vector2(100, 0), false)
	boss = make_enemy(Vector2(100, 50), true)

	# Волна проверяет весь пройденный отрезок.
	var wave = make_effect("wind_waves", 1)
	wave._physics_process(0.4)

	check(
		is_equal_approx(float(normal.get("health")), 99.0),
		"попадание волны между кадрами"
	)

	check(
		normal.combat_effects.push_left > 0.0,
		"нет отбрасывания"
	)

	wave._physics_process(0.01)

	check(
		is_equal_approx(float(normal.get("health")), 99.0),
		"одна волна бьёт повторно"
	)

	wave.free()

	# Гряда: задержка, полоса и замедление.
	reset_enemies()

	var ridge = make_effect("ice_ridge", 1)
	ridge._physics_process(0.2)

	check(
		is_equal_approx(float(normal.get("health")), 100.0),
		"гряда ударила раньше отметки"
	)

	ridge._physics_process(0.16)

	check(
		is_equal_approx(float(normal.get("health")), 99.0),
		"урон гряды"
	)

	check(
		is_equal_approx(
			normal.combat_effects.movement(Vector2(100, 0)).x,
			65.0
		),
		"замедление гряды"
	)

	check(
		is_equal_approx(float(boss.get("health")), 100.0),
		"гряда задела цель вне полосы"
	)

	ridge.free()

	# Кольцо: обычный враг заморожен, босс только замедлен.
	reset_enemies()
	boss.position = Vector2(80, 40)

	var ring = make_effect("ice_ring", 3)
	ring._physics_process(0.01)

	check(
		is_equal_approx(normal.combat_effects.freeze_left, 2.0),
		"длительность заморозки"
	)

	check(
		normal.combat_effects.movement(Vector2(100, 0)) == Vector2.ZERO,
		"обычный враг не заморожен"
	)

	check(
		is_zero_approx(boss.combat_effects.freeze_left),
		"босс полностью заморожен"
	)

	check(
		is_equal_approx(
			boss.combat_effects.movement(Vector2(100, 0)).x,
			70.0
		),
		"замедление босса"
	)

	normal.combat_effects.tick(2.1)

	check(
		is_equal_approx(
			normal.combat_effects.movement(Vector2(100, 0)).x,
			100.0
		),
		"заморозка не закончилась"
	)

	ring.free()

	# Камень блокирует все три эффекта.
	wall_enabled = true

	for id in ["wind_waves", "ice_ridge", "ice_ring"]:
		reset_enemies()

		var blocked = make_effect(id, 1)
		blocked._physics_process(0.5)

		check(
			is_equal_approx(float(normal.get("health")), 100.0),
			"урон сквозь камень: " + id
		)

		blocked.free()

	wall_enabled = false

	# Уже удалённая цель не должна вызывать ошибку.
	var dead = Dummy.new()
	add_child(dead)

	var safe = make_effect("wind_waves", 1)
	dead.free()

	safe.hit_enemy(dead)

	# Замена навыка отменяет эффект.
	GameState.selected_spells.clear()
	safe._physics_process(0.1)

	check(
		safe.is_queued_for_deletion(),
		"заменённый навык не отменён"
	)

	safe.free()

	GameState.selected_spells.assign(old_spells)

	print("CONTROL_TEST_RESULT failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
