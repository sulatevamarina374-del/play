extends Node2D

const CASTER = preload("res://unique_spell_caster.gd")
const IMPACT = preload("res://spell_impact.gd")


class Dummy:
	extends Node2D

	var health: float = 100.0

	func take_damage(amount: float) -> void:
		health = maxf(health - amount, 0.0)


var failures: int = 0
var wall_enabled: bool = false
var mage: Node2D


func _ready() -> void:
	call_deferred("run_tests")


func has_clear_shot(from: Vector2, to: Vector2) -> bool:
	if not wall_enabled:
		return true

	return not (
		minf(from.x, to.x) < 120.0
		and maxf(from.x, to.x) >= 120.0
	)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("UNIQUE TEST FAILURE: " + message)


func enemy_at(point: Vector2) -> Node2D:
	var enemy = Dummy.new()
	add_child(enemy)
	enemy.position = point
	enemy.add_to_group("enemies")
	return enemy


func effect_at(id: String, victim: Node2D, point: Vector2):
	var effect = IMPACT.new()
	effect.mage = mage
	effect.target = victim
	effect.spell_id = id
	effect.damage = 2.0
	effect.delay = 1.0
	effect.radius = 52.0

	add_child(effect)
	effect.set_physics_process(false)
	effect.global_position = point

	return effect


func run_tests() -> void:
	var old_spells: Array = GameState.selected_spells.duplicate(true)

	GameState.selected_spells.clear()

	for id in CASTER.RULES:
		GameState.selected_spells.append({
			"id": str(id),
			"level": 1
		})

	mage = Dummy.new()
	add_child(mage)

	var caster = CASTER.new()
	mage.add_child(caster)
	caster.set_physics_process(false)

	var a = enemy_at(Vector2(100, 0))
	var b = enemy_at(Vector2(130, 0))
	var c = enemy_at(Vector2(250, 0))

	check(
		caster.candidates().size() == 3,
		"поиск целей"
	)

	var state: Dictionary = caster.states["dark_lightning"]
	state["cooldown"] = 0.0

	caster.update_spell("dark_lightning", 0.01)

	check(
		int(state["left"]) == 1,
		"молнии: первый из двух ударов"
	)

	caster.update_spell("dark_lightning", 0.2)

	check(
		int(state["left"]) == 0 and state["used"].size() == 2,
		"молнии: разные цели"
	)

	var seal = effect_at("dark_seal", a, a.position)
	seal._physics_process(0.5)

	check(
		is_equal_approx(a.health, 100.0),
		"печать взорвалась раньше задержки"
	)

	a.position.x = 110.0
	seal._physics_process(0.5)

	check(
		is_equal_approx(seal.global_position.x, 110.0),
		"печать не следует за целью"
	)

	check(
		is_equal_approx(a.health, 98.0)
		and is_equal_approx(b.health, 98.0),
		"урон печати по площади"
	)

	check(
		is_equal_approx(c.health, 100.0),
		"урон за пределами радиуса"
	)

	seal.strike()

	check(
		is_equal_approx(a.health, 98.0),
		"повторный урон одного взрыва"
	)

	var geyser = effect_at(
		"water_geyser",
		a,
		Vector2(100, 0)
	)

	a.position.x = 300.0
	geyser._physics_process(1.0)

	check(
		is_equal_approx(geyser.global_position.x, 100.0),
		"гейзер преследует цель"
	)

	check(
		is_equal_approx(a.health, 98.0)
		and is_equal_approx(b.health, 96.0),
		"выход из отметки гейзера"
	)

	a.position.x = 100.0
	wall_enabled = true

	check(
		caster.candidates().size() == 1,
		"цели за камнем доступны"
	)

	var blocked = effect_at("water_geyser", a, a.position)
	blocked.strike()

	check(
		is_equal_approx(a.health, 96.0)
		and is_equal_approx(b.health, 96.0),
		"взрыв проходит сквозь камень"
	)

	var lightning = effect_at("dark_lightning", b, b.position)
	lightning.strike()

	check(
		is_equal_approx(b.health, 96.0),
		"молния проходит сквозь камень"
	)

	wall_enabled = false

	var removed = effect_at("dark_seal", a, a.position)
	GameState.selected_spells.clear()
	removed._physics_process(1.0)

	check(
		is_equal_approx(a.health, 96.0),
		"заменённый навык продолжает бить"
	)

	GameState.selected_spells.assign(old_spells)

	print("UNIQUE_TEST_RESULT failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
