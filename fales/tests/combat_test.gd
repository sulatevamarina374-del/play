extends Node

const EFFECTS = preload("res://combat_effects.gd")
const ENEMY = preload("res://enemy.gd")
const SHOOTER = preload("res://enemy_shooter.gd")
const BOSS = preload("res://boss.gd")
const PLAYER = preload("res://player.gd")

var failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("COMBAT TEST FAILURE: " + message)


func _run() -> void:
	var old_health: float = GameState.health
	test_effects()
	test_enemies()
	test_player()
	test_scaling()
	GameState.health = old_health

	print("COMBAT_TEST_RESULT failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func test_effects() -> void:
	var effects = EFFECTS.new()

	effects.add_slow("ice", 1.0, 0.5)
	effects.add_slow("water", 2.0, 0.8)
	check(
		effects.movement(Vector2(100, 0)).is_equal_approx(Vector2(50, 0)),
		"замедления перемножились"
	)

	effects.tick(1.0)
	check(
		effects.movement(Vector2(100, 0)).is_equal_approx(Vector2(80, 0)),
		"истёкшее замедление осталось"
	)

	effects.tick(1.0)
	check(
		effects.movement(Vector2(100, 0)).is_equal_approx(Vector2(100, 0)),
		"скорость не восстановилась"
	)

	effects.add_burn(2.0, 3.0)
	effects.add_burn(2.0, 3.0)
	check(
		is_equal_approx(effects.tick(0.5), 1.5),
		"повторное горение сложилось"
	)
	check(
		is_equal_approx(effects.tick(5.0), 4.5),
		"горение вышло за длительность"
	)
	check(
		is_zero_approx(effects.tick(1.0)),
		"горение не закончилось"
	)

	effects.add_push(Vector2.RIGHT, 100.0, 1.0)
	check(
		effects.movement(Vector2.ZERO).x > 0.0,
		"нет отбрасывания"
	)
	effects.tick(1.0)
	check(
		effects.movement(Vector2.ZERO).is_zero_approx(),
		"отбрасывание не закончилось"
	)

	effects.add_freeze(1.0)
	check(
		effects.movement(Vector2(100, 0)).is_zero_approx(),
		"заморозка не остановила движение"
	)
	effects.clear()
	check(
		effects.movement(Vector2(100, 0)).is_equal_approx(Vector2(100, 0)),
		"очистка эффектов"
	)


func test_enemies() -> void:
	for script in [ENEMY, SHOOTER, BOSS]:
		var enemy = script.new()
		enemy.health = 10.0

		enemy.take_damage(0.5)
		enemy.take_damage(-2.0)
		check(
			is_equal_approx(enemy.health, 9.5),
			"дробный или отрицательный урон"
		)

		enemy.apply_burn(1.0, 2.0)
		enemy.begin_combat_frame(0.5)
		check(
			is_equal_approx(enemy.health, 8.5),
			"враг не получил урон горения"
		)

		enemy.take_damage(100.0)
		check(
			not enemy.is_alive(),
			"погибший враг считается живым"
		)
		enemy.take_damage(1.0)
		check(
			is_zero_approx(enemy.health),
			"повторный смертельный урон"
		)
		enemy.free()

	var boss = BOSS.new()
	boss.add_to_group("boss")
	boss.apply_freeze(1.0, 0.5)

	check(
		is_zero_approx(boss.combat_effects.freeze_left),
		"босс полностью заморожен"
	)
	check(
		boss.combat_effects.movement(Vector2(100, 0)).is_equal_approx(Vector2(50, 0)),
		"босс не замедлен"
	)
	boss.free()


func test_player() -> void:
	var player = PLAYER.new()
	player.max_health = 5.0
	player.health = 2.0

	check(
		is_equal_approx(player.heal(1.5), 1.5),
		"дробное лечение"
	)
	player.heal(100.0)
	check(
		is_equal_approx(player.health, 5.0),
		"лечение выше максимума"
	)
	player.heal(-1.0)
	check(
		is_equal_approx(player.health, 5.0),
		"отрицательное лечение"
	)

	check(player.give_shield(2.5, 3.0), "щит не выдан")
	player.take_damage(1.0)
	check(
		is_equal_approx(player.shield_health, 1.5),
		"щит не поглотил урон"
	)
	check(
		is_equal_approx(player.health, 5.0),
		"урон прошёл сквозь щит"
	)

	player.take_damage(1.0)
	check(
		is_equal_approx(player.shield_health, 1.5),
		"неуязвимость потратила щит"
	)

	player.invulnerability_time = 0.0
	player.take_damage(2.0)
	check(
		is_zero_approx(player.shield_health),
		"щит не сломан"
	)
	check(
		is_equal_approx(player.health, 4.5),
		"остаток урона посчитан неправильно"
	)
	check(
		is_equal_approx(GameState.health, player.health),
		"здоровье не перенесено в GameState"
	)

	player.give_shield(1.0, 1.0)
	player.update_shield(2.0)
	check(
		is_zero_approx(player.shield_health),
		"щит не истёк"
	)

	player.health = 0.0
	check(
		is_zero_approx(player.heal(2.0)),
		"лечение воскресило погибшего"
	)
	check(
		not player.give_shield(1.0, 1.0),
		"щит выдан погибшему"
	)
	player.free()


func test_scaling() -> void:
	var old_basic: float = GameState.basic_damage_factor
	var old_spells: Dictionary = GameState.spell_damage_factors.duplicate(true)
	var old_healing: float = GameState.healing_factor
	var old_shield: float = GameState.shield_factor

	GameState.reset_combat_factors()

	check(
		is_equal_approx(
			GameState.resolve_spell_damage("fire_spheres", 1.0),
			1.0
		),
		"нейтральный урон"
	)

	GameState.basic_damage_factor = 1.5
	GameState.spell_damage_factors["fire_spheres"] = 1.25
	GameState.spell_damage_factors["ice_orbit"] = 0.5

	check(
		is_equal_approx(
			GameState.resolve_basic_damage(),
			float(GameState.damage) * 1.5
		),
		"обычный урон"
	)
	check(
		is_equal_approx(
			GameState.resolve_spell_damage("fire_spheres", 1.0),
			1.25
		),
		"дробный урон сферы"
	)
	check(
		is_equal_approx(
			GameState.resolve_spell_damage("ice_orbit", 1.0),
			0.5
		),
		"урон орбиты"
	)
	check(
		is_equal_approx(
			GameState.resolve_spell_damage("water_spheres", 1.0),
			1.0
		),
		"бонус задел другой навык"
	)
	check(
		is_zero_approx(GameState.scale_combat_amount(-1.0, 2.0)),
		"отрицательное значение"
	)

	GameState.healing_factor = 1.5
	GameState.shield_factor = 1.5

	var player = PLAYER.new()
	player.max_health = 5.0
	player.health = 1.0

	check(
		is_equal_approx(player.heal(1.0), 1.5),
		"множитель лечения применён неверно"
	)
	check(
		player.give_shield(2.0, 3.0),
		"щит с множителем"
	)
	check(
		is_equal_approx(player.shield_health, 3.0),
		"множитель щита применён дважды"
	)
	check(
		is_equal_approx(player.shield_max_health, 3.0),
		"максимум индикатора щита"
	)
	player.free()

	GameState.reset_combat_factors()

	check(
		is_equal_approx(
			GameState.resolve_spell_damage("fire_spheres", 1.0),
			1.0
		),
		"множитель не сбросился"
	)

	GameState.basic_damage_factor = old_basic
	GameState.spell_damage_factors = old_spells
	GameState.healing_factor = old_healing
	GameState.shield_factor = old_shield

	var scenes: Array[PackedScene] = [
		preload("res://projectile.tscn"),
		preload("res://fire_projectile.tscn")
	]

	for scene in scenes:
		var projectile = scene.instantiate()
		projectile.damage = 2.5
		projectile.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(projectile)

		check(
			is_equal_approx(float(projectile.damage), 2.5),
			"снаряд сбросил урон в _ready"
		)
		projectile.free()
