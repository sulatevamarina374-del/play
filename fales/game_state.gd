extends Node

const SPELL_CATALOG = preload("res://spell_catalog.gd")
const MAX_SPELL_SLOTS: int = 6
const MAX_SPELL_LEVEL: int = 3
# Служебные множители текущего забега. Пока все нейтральны.
var basic_damage_factor: float = 1.0
var spell_damage_factors: Dictionary = {}
var healing_factor: float = 1.0
var shield_factor: float = 1.0

var selected_spells: Array[Dictionary] = []
var debug_invincible: bool = false

const BASE_MAX_HEALTH: float = 5.0
const BASE_DAMAGE: int = 1
const BASE_ATTACK_INTERVAL: float = 0.7
const BASE_MOVE_SPEED: float = 250.0

var max_health: float = BASE_MAX_HEALTH
var health: float = -1.0
var damage: int = BASE_DAMAGE
var attack_interval: float = BASE_ATTACK_INTERVAL
var move_speed: float = BASE_MOVE_SPEED
var result: String = ""
# Только данные текущего забега; сохранённый профиль не изменяется экраном.
var run_coins: int = 0
var run_last_cleared_room: int = 0
var run_record_before: int = 0

# Change this one value later to change the boss frequency.
var boss_every: int = 10
var room_number: int = 1
var run_seed: int = 0
var last_room_type: int = -1
var recovery_cooldowns: Dictionary = {}
var run_shield: Dictionary = {}


func reset_run() -> void:
	debug_invincible = false
	selected_spells.clear()
	reset_combat_factors()
	apply_fire_permanent_bonus()
	apply_ice_permanent_bonus()
	apply_water_permanent_bonus()
	apply_wind_permanent_bonus()
	apply_dark_permanent_bonus()
	apply_light_permanent_bonus()
	
	recovery_cooldowns.clear()
	clear_run_shield()
	max_health = BASE_MAX_HEALTH
	health = -1.0
	damage = BASE_DAMAGE
	attack_interval = BASE_ATTACK_INTERVAL
	move_speed = BASE_MOVE_SPEED

	# Действует только купленная и надетая мантия.
	if Profile.owned_robe_ids.has(Profile.equipped_robe_id):
		match Profile.equipped_robe_id:
			"green":
				move_speed *= 1.08
			"blue":
				max_health += 1.0
			"red":
				basic_damage_factor *= 1.10

	result = ""
	run_coins = 0
	run_last_cleared_room = 0
	run_record_before = Profile.best_cleared_room
	room_number = 1
	last_room_type = -1

	var random := RandomNumberGenerator.new()
	random.randomize()
	run_seed = random.randi()

func difficulty_stage() -> int:
	return floori((room_number - 1) / 5.0)


func enemy_health_multiplier() -> float:
	return pow(1.12, difficulty_stage())


func enemy_damage_multiplier() -> float:
	return pow(1.05, difficulty_stage())


func format_health(value: float) -> String:
	var shown: float = snappedf(value, 0.1)

	if is_equal_approx(shown, roundf(shown)):
		return str(int(roundf(shown)))

	return "%.1f" % shown

func _ready() -> void:
	print("Каталог заклинаний: ", SPELL_CATALOG.all_spells().size())


func acquire_spell(spell_id: String) -> String:
	if SPELL_CATALOG.get_spell(spell_id).is_empty():
		return "invalid"

	for index in range(selected_spells.size()):
		if selected_spells[index]["id"] == spell_id:
			var level: int = int(selected_spells[index]["level"])

			if level >= MAX_SPELL_LEVEL:
				return "max"

			selected_spells[index]["level"] = level + 1
			return "upgraded"

	if selected_spells.size() >= MAX_SPELL_SLOTS:
		return "full"

	selected_spells.append({
		"id": spell_id,
		"level": 1
	})

	return "learned"

func replace_spell(slot_index: int, spell_id: String) -> String:
	if slot_index < 0 or slot_index >= selected_spells.size():
		return "invalid_slot"

	if SPELL_CATALOG.get_spell(spell_id).is_empty():
		return "invalid"

	for spell in selected_spells:
		if str(spell.get("id", "")) == spell_id:
			return "already_owned"

	selected_spells[slot_index] = {
		"id": spell_id,
		"level": 1
	}

	return "replaced"

func reset_combat_factors() -> void:
	basic_damage_factor = 1.0
	spell_damage_factors.clear()
	healing_factor = 1.0
	shield_factor = 1.0


func scale_combat_amount(base_value: float, factor: float) -> float:
	if not is_finite(base_value) or not is_finite(factor):
		return 0.0
	if base_value <= 0.0 or factor <= 0.0:
		return 0.0

	var result_value: float = base_value * factor
	return result_value if is_finite(result_value) else 0.0


func resolve_basic_damage() -> float:
	return scale_combat_amount(float(damage), basic_damage_factor)


func resolve_spell_damage(spell_id: String, base_value: float) -> float:
	var factor: float = float(spell_damage_factors.get(spell_id, 1.0))
	return scale_combat_amount(base_value, factor)


func resolve_healing(base_value: float) -> float:
	return scale_combat_amount(base_value, healing_factor)


func resolve_shield(base_value: float) -> float:
	return scale_combat_amount(base_value, shield_factor)

func clear_run_shield() -> void:
	run_shield.clear()

func apply_fire_permanent_bonus() -> void:
	var level: int = Profile.fire_level()

	if level < 1:
		push_warning(
			"Некорректный уровень огня в профиле. "
			+ "Бонус огня не применён."
		)
		return

	var factor: float = 1.0 + float(level - 1) * 0.15

	for spell_id in [
		"fire_spheres",
		"fire_orbit",
		"fire_meteors",
		"fire_breath"
	]:
		spell_damage_factors[spell_id] = factor

func apply_ice_permanent_bonus() -> void:
	var level: int = Profile.ice_level()

	if level < 1:
		push_warning(
			"Некорректный уровень льда в профиле. "
			+ "Бонус льда не применён."
		)
		return

	var factor: float = 1.0 + float(level - 1) * 0.15

	for spell_id in [
		"ice_spheres",
		"ice_orbit",
		"ice_ridge",
		"ice_ring"
	]:
		spell_damage_factors[spell_id] = factor

func apply_water_permanent_bonus() -> void:
	var level: int = Profile.water_level()

	if level < 1:
		push_warning(
			"Некорректный уровень воды в профиле. "
			+ "Бонус воды не применён."
		)
		return

	var factor: float = 1.0 + float(level - 1) * 0.15

	for spell_id in [
		"water_spheres",
		"water_orbit",
		"water_cascade",
		"water_geyser"
	]:
		spell_damage_factors[spell_id] = factor

func apply_wind_permanent_bonus() -> void:
	var level: int = Profile.wind_level()

	if level < 1:
		push_warning(
			"Некорректный уровень ветра в профиле. "
			+ "Бонус ветра не применён."
		)
		return

	var factor: float = 1.0 + float(level - 1) * 0.15

	for spell_id in [
		"wind_spheres",
		"wind_orbit",
		"wind_waves",
		"wind_tornado"
	]:
		spell_damage_factors[spell_id] = factor

func apply_dark_permanent_bonus() -> void:
	var level: int = Profile.dark_level()

	if level < 1:
		push_warning(
			"Некорректный уровень тёмной стихии в профиле. "
			+ "Бонус не применён."
		)
		return

	var factor: float = 1.0 + float(level - 1) * 0.15

	for spell_id in [
		"dark_spheres",
		"dark_orbit",
		"dark_seal",
		"dark_lightning"
	]:
		spell_damage_factors[spell_id] = factor

func apply_light_permanent_bonus() -> void:
	var level: int = Profile.light_level()

	if level < 1:
		push_warning(
			"Некорректный уровень светлой стихии в профиле. "
			+ "Бонус не применён."
		)
		return

	var factor: float = 1.0 + float(level - 1) * 0.15

	spell_damage_factors["light_spheres"] = factor
	spell_damage_factors["light_orbit"] = factor

	healing_factor = factor
	shield_factor = factor
