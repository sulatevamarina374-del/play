extends Node

const ORBIT_SCRIPT = preload("res://orbit_spell_caster.gd")
const FIRE_SCENE = preload("res://fire_projectile.tscn")
const VOLLEY_INTERVAL: float = 2.0
const SHOT_GAP: float = 0.12
const SPHERE_SCALE: float = 2.0

const SPHERE_COLORS: Dictionary = {
	"dark_spheres": Color("80609c"),
	"light_spheres": Color("efe3a0"),
	"wind_spheres": Color("94c89a"),
	"water_spheres": Color("5eadd1"),
	"fire_spheres": Color("ff9850"),
	"ice_spheres": Color("a5dce5")
}

var spell_states: Dictionary = {}

@onready var mage: Node2D = get_parent() as Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	var index: int = 0

	for spell_id in SPHERE_COLORS:
		spell_states[spell_id] = {
			"cooldown": 0.3 * float(index + 1),
			"shots_left": 0,
			"gap_left": 0.0
		}

		index += 1
	
	if not mage.has_node("OrbitSpellCaster"):
		var orbit_caster = ORBIT_SCRIPT.new()
		orbit_caster.name = "OrbitSpellCaster"
		mage.call_deferred("add_child", orbit_caster)


func _physics_process(delta: float) -> void:
	if mage == null or float(mage.get("health")) <= 0.0:
		return

	for key in SPHERE_COLORS:
		update_sphere(str(key), delta)


func update_sphere(spell_id: String, delta: float) -> void:
	var state: Dictionary = spell_states[spell_id]
	var level: int = get_spell_level(spell_id)

	if level == 0:
		state["cooldown"] = VOLLEY_INTERVAL
		state["shots_left"] = 0
		state["gap_left"] = 0.0
		return

	state["cooldown"] = maxf(float(state["cooldown"]) - delta, 0.0)

	if int(state["shots_left"]) > 0:
		state["gap_left"] = float(state["gap_left"]) - delta

		if float(state["gap_left"]) <= 0.0:
			if fire_one(spell_id):
				state["shots_left"] = int(state["shots_left"]) - 1
				state["gap_left"] = SHOT_GAP
			else:
				state["shots_left"] = 0

		return

	if float(state["cooldown"]) <= 0.0 and fire_one(spell_id):
		state["shots_left"] = level - 1
		state["gap_left"] = SHOT_GAP
		state["cooldown"] = VOLLEY_INTERVAL


func get_spell_level(spell_id: String) -> int:
	for spell in GameState.selected_spells:
		if str(spell.get("id", "")) == spell_id:
			return clampi(int(spell.get("level", 1)), 1, 3)

	return 0


func find_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF
	var room: Node = get_tree().current_scene

	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = candidate as Node2D

		if enemy == null or enemy.is_queued_for_deletion():
			continue

		if room.has_method("has_clear_shot"):
			if not room.call(
				"has_clear_shot",
				mage.global_position,
				enemy.global_position
			):
				continue

		var distance: float = mage.global_position.distance_squared_to(
			enemy.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy

	return nearest


func fire_one(spell_id: String) -> bool:
	var target: Node2D = find_target()
	if target == null:
		return false

	var projectile = FIRE_SCENE.instantiate()
	projectile.damage = GameState.resolve_spell_damage(spell_id, 1.0)
	projectile.element_color = SPHERE_COLORS[spell_id]
	projectile.scale = Vector2.ONE * SPHERE_SCALE
	projectile.direction = mage.global_position.direction_to(
		target.global_position
	)

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = mage.global_position
	return true
	
