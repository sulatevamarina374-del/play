extends Node

const IMPACT = preload("res://spell_impact.gd")
const RANGE: float = 480.0

const RULES: Dictionary = {
	"dark_lightning": {
		"cooldown": 4.0,
		"damage": 1.0,
		"delay": 0.0,
		"radius": 0.0
	},
	"dark_seal": {
		"cooldown": 6.0,
		"damage": 2.0,
		"delay": 1.0,
		"radius": 52.0
	},
	"water_geyser": {
		"cooldown": 5.0,
		"damage": 2.0,
		"delay": 0.8,
		"radius": 58.0
	}
}

var states: Dictionary = {}

@onready var mage: Node2D = get_parent() as Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	var index: int = 0

	for id in RULES:
		states[id] = {
			"cooldown": 0.8 + float(index) * 0.3,
			"left": 0,
			"gap": 0.0,
			"used": []
		}

		index += 1


func _physics_process(delta: float) -> void:
	if not is_instance_valid(mage) or float(mage.get("health")) <= 0.0:
		return

	for id in RULES:
		update_spell(str(id), delta)


func get_level(id: String) -> int:
	for spell in GameState.selected_spells:
		if str(spell.get("id", "")) == id:
			return clampi(int(spell.get("level", 1)), 1, 3)

	return 0


func update_spell(id: String, delta: float) -> void:
	var state: Dictionary = states[id]
	var level: int = get_level(id)

	if level == 0:
		state["cooldown"] = 0.8
		state["left"] = 0
		state["used"] = []
		return

	state["cooldown"] = maxf(
		float(state["cooldown"]) - delta,
		0.0
	)

	if int(state["left"]) > 0:
		state["gap"] = float(state["gap"]) - delta

		if float(state["gap"]) <= 0.0:
			if not launch(id, state):
				state["left"] = 0

		return

	if float(state["cooldown"]) > 0.0 or candidates().is_empty():
		return

	state["used"] = []
	state["left"] = level * 2 if id == "dark_lightning" else level
	state["cooldown"] = float(RULES[id]["cooldown"])

	launch(id, state)


func candidates() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var room: Node = get_tree().current_scene

	# Без правила препятствий не разрешаем удар сквозь всё.
	if not is_instance_valid(room) or not room.has_method("has_clear_shot"):
		return result

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D

		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue

		if float(enemy.get("health")) <= 0.0:
			continue

		if mage.global_position.distance_to(enemy.global_position) > RANGE:
			continue

		if room.call(
			"has_clear_shot",
			mage.global_position,
			enemy.global_position
		):
			result.append(enemy)

	result.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return mage.global_position.distance_squared_to(a.global_position) < mage.global_position.distance_squared_to(b.global_position)
	)

	return result


func launch(id: String, state: Dictionary) -> bool:
	var available: Array[Node2D] = candidates()
	var used: Array = state["used"]
	var target: Node2D = null

	for enemy in available:
		if not used.has(enemy.get_instance_id()):
			target = enemy
			break

	# Если доступные цели закончились, молнии могут повторить их.
	if target == null and id == "dark_lightning" and not available.is_empty():
		used.clear()
		target = available[0]

	if target == null:
		state["left"] = 0
		return false

	used.append(target.get_instance_id())

	state["used"] = used
	state["left"] = int(state["left"]) - 1
	state["gap"] = 0.18 if id == "dark_lightning" else 0.12

	var rule: Dictionary = RULES[id]
	var effect = IMPACT.new()

	effect.mage = mage
	effect.spell_id = id
	effect.target = target
	effect.damage = GameState.resolve_spell_damage(
		id,
		float(rule["damage"])
	)
	effect.delay = float(rule["delay"])
	effect.radius = float(rule["radius"])

	get_tree().current_scene.add_child(effect)
	effect.global_position = target.global_position

	return true
