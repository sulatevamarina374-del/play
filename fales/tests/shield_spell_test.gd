extends Node

const CASTER = preload("res://shield_spell_caster.gd")


class TestMage:
	extends "res://player.gd"

	var death_recorded: bool = false

	func die() -> void:
		death_recorded = true


var failures: int = 0


func _ready() -> void:
	call_deferred("run_tests")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("SHIELD TEST FAILURE: " + message)


func new_mage():
	var mage = TestMage.new()
	mage.max_health = 5.0
	mage.health = 5.0
	return mage


func run_tests() -> void:
	var old_spells: Array = GameState.selected_spells.duplicate(true)
	var old_timers: Dictionary = GameState.recovery_cooldowns.duplicate(true)
	var old_shield: Dictionary = GameState.run_shield.duplicate(true)

	var old_health: float = GameState.health
	var old_factor: float = GameState.shield_factor
	var old_debug: bool = GameState.debug_invincible

	GameState.debug_invincible = false
	GameState.shield_factor = 1.0
	GameState.clear_run_shield()

	# Переносим частично потраченный щит.
	var first = new_mage()

	check(
		first.give_shield(2.0, 4.0),
		"выдача щита"
	)

	first.take_damage(0.75)
	first.update_shield(1.5)

	var second = new_mage()
	second.restore_run_shield()

	check(
		is_equal_approx(second.shield_health, 1.25),
		"дверь восстановила прочность"
	)

	check(
		is_equal_approx(second.shield_max_health, 2.0),
		"потерян максимум полосы"
	)

	check(
		is_equal_approx(second.shield_time_left, 2.5),
		"дверь продлила время"
	)

	second.take_damage(2.0)

	check(
		is_equal_approx(second.health, 4.25),
		"избыток урона не дошёл до HP"
	)

	check(
		GameState.run_shield.is_empty(),
		"разрушенный щит сохранён"
	)

	# Истёкший щит не переносится.
	second.give_shield(2.0, 1.0)
	second.update_shield(1.1)

	var third = new_mage()
	third.restore_run_shield()

	check(
		is_zero_approx(third.shield_health),
		"истёкший щит перенёсся"
	)

	# Множитель не применяется повторно при переносе.
	GameState.shield_factor = 1.5
	second.give_shield(2.0, 4.0)
	third.restore_run_shield()

	check(
		is_equal_approx(third.shield_health, 3.0),
		"повторное умножение при переносе"
	)

	GameState.shield_factor = 1.0
	first.clear_temporary_shield()

	# Откат сохраняется при пересоздании исполнителя.
	GameState.selected_spells.clear()
	GameState.selected_spells.append({
		"id": "light_shield",
		"level": 1
	})

	GameState.recovery_cooldowns.clear()

	var caster = CASTER.new()
	caster.mage = first

	check(
		not caster.update_skill(9.0),
		"щит выдан до первого отката"
	)

	caster.free()

	caster = CASTER.new()
	caster.mage = first

	check(
		caster.update_skill(1.0),
		"откат потерян при пересоздании"
	)

	check(
		is_equal_approx(first.shield_health, 2.0),
		"прочность уровня 1"
	)

	check(
		not caster.update_skill(0.0),
		"щит выдан повторно без ожидания"
	)

	# Прочность и длительность по уровням.
	for level in range(1, 4):
		first.clear_temporary_shield()
		GameState.selected_spells[0]["level"] = level
		GameState.recovery_cooldowns["light_shield"] = 0.0

		check(
			caster.update_skill(0.0),
			"выдача щита по уровню"
		)

		check(
			is_equal_approx(
				first.shield_health,
				CASTER.STRENGTHS[level - 1]
			),
			"прочность по уровню"
		)

		check(
			is_equal_approx(
				first.shield_time_left,
				CASTER.DURATIONS[level - 1]
			),
			"время по уровню"
		)

	first.give_shield(1.0, 2.0)
	first.give_shield(1.0, 2.0)

	check(
		is_equal_approx(first.shield_health, 1.0),
		"прочность складывается"
	)

	# Бессмертие блокирует расход щита от урона.
	GameState.debug_invincible = true
	first.take_damage(3.0)

	check(
		is_equal_approx(first.shield_health, 1.0)
		and is_equal_approx(first.health, 5.0),
		"чит не блокирует урон"
	)

	# При смерти щит очищается.
	GameState.debug_invincible = false
	first.invulnerability_time = 0.0
	first.take_damage(100.0)

	check(
		first.death_recorded
		and GameState.run_shield.is_empty(),
		"щит не очищен после смерти"
	)

	GameState.recovery_cooldowns["light_shield"] = 0.0

	check(
		not caster.update_skill(0.0),
		"щит выдан погибшему магу"
	)

	GameState.selected_spells.clear()
	caster.update_skill(0.0)

	check(
		not GameState.recovery_cooldowns.has("light_shield"),
		"таймер удалённого навыка остался"
	)

	caster.free()
	first.free()
	second.free()
	third.free()

	GameState.selected_spells.assign(old_spells)
	GameState.recovery_cooldowns = old_timers
	GameState.run_shield = old_shield

	GameState.health = old_health
	GameState.shield_factor = old_factor
	GameState.debug_invincible = old_debug

	print("SHIELD_TEST_RESULT failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
