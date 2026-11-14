extends Node

const EFFECT = preload("res://advanced_spell_effect.gd")

const COOLDOWNS: Dictionary = {
	"fire_meteors": 7.0,
	"water_cascade": 5.0,
	"wind_tornado": 7.0
}

var cooldowns: Dictionary = {}

@onready var mage: Node2D = get_parent() as Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	var index: int = 0

	for id in COOLDOWNS:
		cooldowns[id] = 1.0 + float(index) * 0.4
		index += 1


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
		var level: int = level_of(str(id))

		if level == 0:
			cooldowns[id] = 1.0
			continue

		cooldowns[id] = maxf(
			float(cooldowns[id]) - delta,
			0.0
		)

		if float(cooldowns[id]) > 0.0:
			continue

		var targets: Array = targeting.call("candidates")

		if targets.is_empty():
			continue

		var amount: int = (
			mini(level, targets.size())
			if id == "fire_meteors"
			else 1
		)

		for index in range(amount):
			spawn_effect(str(id), level, targets[index])

		cooldowns[id] = float(COOLDOWNS[id])


func spawn_effect(id: String, level: int, victim: Node2D) -> void:
	var effect = EFFECT.new()

	effect.mage = mage
	effect.spell_id = id
	effect.target = victim
	effect.level = level

	var base_damage: float = (
		3.0 if id == "fire_meteors" else 1.0
	)

	effect.damage = GameState.resolve_spell_damage(
		id,
		base_damage
	)

	effect.delay = 1.0
	effect.radius = 64.0

	get_tree().current_scene.add_child(effect)

	effect.global_position = (
		victim.global_position
		if id == "fire_meteors"
		else mage.global_position
	)
