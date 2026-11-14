extends Node

const STRENGTHS: Array[float] = [2.0, 4.0, 6.0]
const DURATIONS: Array[float] = [5.0, 7.0, 9.0]
const INTERVAL: float = 10.0

@onready var mage: Node2D = get_parent() as Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func level_of_shield() -> int:
	for spell in GameState.selected_spells:
		if str(spell.get("id", "")) == "light_shield":
			return clampi(int(spell.get("level", 1)), 1, 3)

	return 0


func _physics_process(delta: float) -> void:
	update_skill(delta)


func update_skill(delta: float) -> bool:
	var level: int = level_of_shield()

	if level == 0:
		GameState.recovery_cooldowns.erase("light_shield")
		return false

	if not is_finite(delta) or delta < 0.0:
		return false

	if not is_instance_valid(mage) or mage.is_queued_for_deletion():
		return false

	if float(mage.get("health")) <= 0.0:
		return false

	if not mage.has_method("give_shield"):
		return false

	var remaining: float = float(
		GameState.recovery_cooldowns.get(
			"light_shield",
			INTERVAL
		)
	)

	remaining = maxf(
		clampf(remaining, 0.0, INTERVAL) - delta,
		0.0
	)

	GameState.recovery_cooldowns["light_shield"] = remaining

	if remaining > 0.0:
		return false

	var granted: bool = bool(
		mage.call(
			"give_shield",
			STRENGTHS[level - 1],
			DURATIONS[level - 1]
		)
	)

	if granted:
		GameState.recovery_cooldowns["light_shield"] = INTERVAL

	return granted
