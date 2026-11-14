extends Node2D

const EFFECT = preload("res://flame_recovery_effect.gd")
const CASTER = preload("res://flame_recovery_caster.gd")
const PLAYER = preload("res://player.gd")


class Dummy:
	extends "res://enemy_combat.gd"

	var health: float = 100.0


var failures: int = 0
var wall_enabled: bool = false

var mage: Node2D
var targets: Array[Node2D] = []


func _ready() -> void:
	call_deferred("run_tests")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FLAME RECOVERY TEST FAILURE: " + message)


func has_clear_shot(from: Vector2, to: Vector2) -> bool:
	return not wall_enabled or not (
		minf(from.x, to.x) < 80.0
		and maxf(from.x, to.x) >= 80.0
	)


func reset_targets() -> void:
	for enemy in targets:
		enemy.set("health", 100.0)
		enemy.combat_effects.clear()


func make_flame(level: int):
	var effect = EFFECT.new()

	effect.mage = mage
	effect.spell_id = "fire_breath"
	effect.level = level
	effect.direction = Vector2.RIGHT
	effect.damage = 1.0
	effect.burn_dps = 0.5

	add_child(effect)
	effect.set_physics_process(false)
	effect.global_position = Vector2.ZERO

	return effect


func run_tests() -> void:
	var old_spells: Array = GameState.selected_spells.duplicate(true)
	var old_timers: Dictionary = GameState.recovery_cooldowns.duplicate(true)
	var old_health: float = GameState.health
	var old_factor: float = GameState.healing_factor

	GameState.healing_factor = 1.0

	GameState.selected_spells.clear()
	GameState.selected_spells.append({
		"id": "fire_breath",
		"level": 1
	})

	mage = Dummy.new()
	add_child(mage)

	for point in [
		Vector2(100, 0),
		Vector2(100, 60),
		Vector2(-50, 0),
		Vector2(200, 0)
	]:
		var enemy = Dummy.new()

		add_child(enemy)
		enemy.position = point
		enemy.add_to_group("enemies")
		targets.append(enemy)

	var front = targets[0]
	var side = targets[1]

	# Узкий конус: направление и дальность.
	var flame = make_flame(1)
	flame._physics_process(0.01)

	check(
		is_equal_approx(float(front.get("health")), 99.0),
		"урон перед магом"
	)

	check(
		is_equal_approx(float(side.get("health")), 100.0),
		"цель за границей узкого конуса"
	)

	check(
		is_equal_approx(float(targets[2].get("health")), 100.0),
		"урон позади мага"
	)

	check(
		is_equal_approx(float(targets[3].get("health")), 100.0),
		"урон за пределами дальности"
	)

	flame._physics_process(0.1)

	check(
		is_equal_approx(float(front.get("health")), 99.0),
		"прямой урон повторяется каждый кадр"
	)

	check(
		is_equal_approx(front.combat_effects.tick(0.5), 0.25),
		"урон горения"
	)

	flame.free()

	# Повторное попадание обновляет, а не складывает горение.
	var refresh = make_flame(1)
	refresh._physics_process(0.01)

	check(
		is_equal_approx(front.combat_effects.burn_left, 2.0),
		"длительность горения не обновлена"
	)

	check(
		is_equal_approx(front.combat_effects.burn_per_second, 0.5),
		"горение сложилось"
	)

	refresh.free()

	reset_targets()

	var wide = make_flame(3)
	wide._physics_process(0.01)

	check(
		is_equal_approx(float(side.get("health")), 99.0),
		"конус не расширился"
	)

	wide.free()

	# Камень блокирует и удар, и горение.
	reset_targets()
	wall_enabled = true

	var blocked = make_flame(1)
	blocked._physics_process(0.01)

	check(
		is_equal_approx(float(front.get("health")), 100.0),
		"дыхание прошло сквозь камень"
	)

	check(
		is_zero_approx(front.combat_effects.burn_left),
		"горение наложено сквозь камень"
	)

	blocked.free()
	wall_enabled = false

	# Лечение: настоящий метод Player.heal без запуска игрока.
	GameState.selected_spells.clear()
	GameState.selected_spells.append({
		"id": "light_heal",
		"level": 1
	})

	GameState.recovery_cooldowns.clear()

	var player = PLAYER.new()
	player.max_health = 5.0
	player.health = 2.0

	var caster = CASTER.new()
	caster.mage = player

	check(
		is_zero_approx(caster.update_healing(17.0)),
		"лечение раньше отката"
	)

	caster.free()

	# Новый исполнитель должен продолжить старый отсчёт.
	caster = CASTER.new()
	caster.mage = player

	check(
		is_equal_approx(caster.update_healing(1.0), 1.0),
		"откат потерялся при пересоздании исполнителя"
	)

	for level in range(1, 4):
		GameState.selected_spells[0]["level"] = level
		GameState.recovery_cooldowns["light_heal"] = 0.0
		player.health = 1.0

		check(
			is_equal_approx(
				caster.update_healing(0.0),
				CASTER.HEAL_AMOUNTS[level - 1]
			),
			"лечение по уровню"
		)

		check(
			is_equal_approx(
				float(GameState.recovery_cooldowns["light_heal"]),
				CASTER.HEAL_INTERVALS[level - 1]
			),
			"откат по уровню"
		)

	player.health = 5.0
	GameState.recovery_cooldowns["light_heal"] = 0.0

	check(
		is_zero_approx(caster.update_healing(0.0)),
		"лечение при полном HP"
	)

	check(
		is_zero_approx(
			float(GameState.recovery_cooldowns["light_heal"])
		),
		"готовность потрачена при полном HP"
	)

	player.health = 4.75

	check(
		is_equal_approx(caster.update_healing(0.0), 0.25),
		"лечение выше максимума"
	)

	GameState.selected_spells[0]["level"] = 1
	GameState.recovery_cooldowns["light_heal"] = 0.0
	GameState.healing_factor = 1.5
	player.health = 1.0

	check(
		is_equal_approx(caster.update_healing(0.0), 1.5),
		"множитель лечения применён неверно"
	)

	player.health = 0.0
	GameState.recovery_cooldowns["light_heal"] = 0.0

	check(
		is_zero_approx(caster.update_healing(0.0)),
		"лечение воскресило мага"
	)

	caster.free()
	player.free()

	GameState.selected_spells.assign(old_spells)
	GameState.recovery_cooldowns = old_timers
	GameState.health = old_health
	GameState.healing_factor = old_factor

	print("FLAME_RECOVERY_TEST_RESULT failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
