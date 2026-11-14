extends Node

const EFFECT = preload("res://flame_recovery_effect.gd")

const HEAL_AMOUNTS: Array[float] = [
	1.0,
	1.5,
	2.0
]

const HEAL_INTERVALS: Array[float] = [
	18.0,
	16.0,
	14.0
]

var breath_left: float = 1.0

@onready var mage: Node2D = get_parent() as Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func level_of(id: String) -> int:
	for spell in GameState.selected_spells:
		if str(spell.get("id", "")) == id:
			return clampi(int(spell.get("level", 1)), 1, 3)

	return 0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(mage) or mage.is_queued_for_deletion():
		return

	if float(mage.get("health")) <= 0.0:
		return

	if update_healing(delta) > 0.0:
		var flash = EFFECT.new()

		flash.mage = mage
		flash.spell_id = "light_heal"

		get_tree().current_scene.add_child(flash)
		flash.global_position = (
			mage.global_position + Vector2(0, -44)
		)

	var level: int = level_of("fire_breath")

	if level == 0:
		breath_left = 1.0
		return

	breath_left = maxf(breath_left - delta, 0.0)

	if breath_left > 0.0:
		return

	var targeting: Node = mage.get_node_or_null("UniqueSpellCaster")

	if not is_instance_valid(targeting):
		return

	var targets: Array = targeting.call("candidates")

	if targets.is_empty():
		return

	var victim: Node2D = targets[0]

	if mage.global_position.distance_to(victim.global_position) > 180.0:
		return

	var effect = EFFECT.new()

	effect.mage = mage
	effect.spell_id = "fire_breath"
	effect.level = level

	effect.direction = mage.global_position.direction_to(
		victim.global_position
	)

	effect.damage = GameState.resolve_spell_damage(
		"fire_breath",
		1.0
	)

	effect.burn_dps = GameState.resolve_spell_damage(
		"fire_breath",
		0.5
	)

	get_tree().current_scene.add_child(effect)
	effect.global_position = mage.global_position

	breath_left = 5.0


func update_healing(delta: float) -> float:
	var level: int = level_of("light_heal")

	if level == 0:
		GameState.recovery_cooldowns.erase("light_heal")
		return 0.0

	if not is_finite(delta) or delta < 0.0:
		return 0.0

	if not is_instance_valid(mage) or mage.is_queued_for_deletion():
		return 0.0

	if float(mage.get("health")) <= 0.0 or not mage.has_method("heal"):
		return 0.0

	var interval: float = HEAL_INTERVALS[level - 1]

	var remaining: float = float(
		GameState.recovery_cooldowns.get(
			"light_heal",
			interval
		)
	)

	remaining = maxf(
		clampf(remaining, 0.0, interval) - delta,
		0.0
	)

	GameState.recovery_cooldowns["light_heal"] = remaining

	if remaining > 0.0:
		return 0.0

	if float(mage.get("health")) >= float(mage.get("max_health")):
		return 0.0

	var healed: float = float(
		mage.call(
			"heal",
			HEAL_AMOUNTS[level - 1]
		)
	)

	if healed > 0.0:
		GameState.recovery_cooldowns["light_heal"] = interval

	return healed
