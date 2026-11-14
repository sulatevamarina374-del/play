extends Node

const EFFECT = preload("res://control_spell_effect.gd")

const COOLDOWNS: Dictionary = {
	"wind_waves": 4.0,
	"ice_ridge": 6.0,
	"ice_ring": 8.0
}

var states: Dictionary = {}

@onready var mage: Node2D = get_parent() as Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	for id in COOLDOWNS:
		states[id] = {
			"cooldown": 1.0,
			"left": 0,
			"gap": 0.0,
			"direction": Vector2.RIGHT
		}


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

	var targeting: Node = mage.get_node_or_null("UniqueSpellCaster")

	if not is_instance_valid(targeting):
		return

	for id in COOLDOWNS:
		var state: Dictionary = states[id]
		var level: int = level_of(str(id))

		if level == 0:
			state["cooldown"] = 1.0
			state["left"] = 0
			continue

		state["cooldown"] = maxf(
			float(state["cooldown"]) - delta,
			0.0
		)

		if int(state["left"]) > 0:
			state["gap"] = float(state["gap"]) - delta

			if float(state["gap"]) <= 0.0:
				spawn_effect(
					str(id),
					level,
					mage.global_position,
					state["direction"]
				)

				state["left"] = int(state["left"]) - 1
				state["gap"] = 0.18

			continue

		if float(state["cooldown"]) > 0.0:
			continue

		var targets: Array = targeting.call("candidates")

		if targets.is_empty():
			continue

		var victim: Node2D = targets[0]

		var reach: float = (
			360.0
			if id == "wind_waves"
			else (240.0 if id == "ice_ridge" else 110.0)
		)

		if mage.global_position.distance_to(victim.global_position) > reach:
			continue

		var direction: Vector2 = mage.global_position.direction_to(
			victim.global_position
		)

		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT

		state["cooldown"] = float(COOLDOWNS[id])

		if id == "ice_ridge":
			var offsets: Array[float] = [0.0]

			if level >= 2:
				offsets.append(36.0)

			if level >= 3:
				offsets.append(-36.0)

			for offset in offsets:
				spawn_effect(
					str(id),
					level,
					mage.global_position
						+ direction.orthogonal() * offset,
					direction
				)

		else:
			spawn_effect(
				str(id),
				level,
				mage.global_position,
				direction
			)

			if id == "wind_waves":
				state["left"] = level - 1
				state["gap"] = 0.18
				state["direction"] = direction


func spawn_effect(
	id: String,
	level: int,
	point: Vector2,
	direction: Vector2
) -> void:
	var effect = EFFECT.new()

	effect.mage = mage
	effect.spell_id = id
	effect.level = level
	effect.direction = direction
	effect.damage = GameState.resolve_spell_damage(id, 1.0)

	get_tree().current_scene.add_child(effect)
	effect.global_position = point
