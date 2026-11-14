extends CharacterBody2D

signal shot_fired

var speed: float = GameState.BASE_MOVE_SPEED
var attack_interval: float = GameState.BASE_ATTACK_INTERVAL

const PROJECTILE_SCENE = preload("res://projectile.tscn")

var attack_cooldown: float = 0.0
var max_health: float = GameState.BASE_MAX_HEALTH

var health: float
var invulnerability_time: float = 0.0
var shield_health: float = 0.0
var shield_time_left: float = 0.0
var shield_max_health: float = 0.0

@onready var joystick: Control = get_node_or_null("../HUD/Joystick")

func _ready() -> void:
	max_health = GameState.max_health
	speed = GameState.move_speed
	attack_interval = GameState.attack_interval

	if GameState.health == -1:
		GameState.health = max_health

	health = clampf(GameState.health, 0.0, max_health)
	GameState.health = health
	restore_run_shield()

	print("Здоровье мага: ", health)
	var fire_caster = preload("res://fire_spell_caster.gd").new()
	fire_caster.name = "FireSpellCaster"
	add_child(fire_caster)
	var unique_caster = preload("res://unique_spell_caster.gd").new()
	unique_caster.name = "UniqueSpellCaster"
	add_child(unique_caster)
	var advanced_caster = preload("res://advanced_spell_caster.gd").new()
	advanced_caster.name = "AdvancedSpellCaster"
	add_child(advanced_caster)
	var control_caster = preload("res://control_spell_caster.gd").new()
	control_caster.name = "ControlSpellCaster"
	add_child(control_caster)
	var flame_recovery = preload("res://flame_recovery_caster.gd").new()
	flame_recovery.name = "FlameRecoveryCaster"
	add_child(flame_recovery)
	var shield_caster = preload("res://shield_spell_caster.gd").new()
	shield_caster.name = "ShieldSpellCaster"
	add_child(shield_caster)


func _physics_process(delta: float) -> void:
	invulnerability_time = maxf(invulnerability_time - delta, 0.0)
	update_shield(delta)
		
	var direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)
	
	if is_instance_valid(joystick):
		if joystick.direction != Vector2.ZERO:
			direction = joystick.direction

	velocity = direction * speed
	move_and_slide()

	attack_cooldown -= delta

	if attack_cooldown <= 0.0:
		shoot_at_nearest_enemy()
		attack_cooldown = attack_interval


func shoot_at_nearest_enemy() -> void:
	var nearest_enemy: Node2D = null
	var nearest_distance: float = INF
	var room := get_tree().current_scene

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_queued_for_deletion():
			continue
		if room.has_method("has_clear_shot"):
			if not room.call(
				"has_clear_shot",
				global_position,
				enemy.global_position
			):
				continue
		var distance := global_position.distance_squared_to(
			enemy.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	if nearest_enemy == null:
		return

	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.damage = GameState.resolve_basic_damage()
	projectile.direction = global_position.direction_to(
		nearest_enemy.global_position
	)

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	shot_fired.emit()

func update_shield(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return

	shield_time_left = maxf(
		shield_time_left - delta,
		0.0
	)

	save_run_shield()


func heal(amount: float) -> float:
	if health <= 0.0 or is_queued_for_deletion():
		return 0.0

	var effective_amount: float = GameState.resolve_healing(amount)
	var previous: float = health

	health = minf(health + effective_amount, max_health)
	GameState.health = health

	return health - previous


func give_shield(amount: float, duration: float) -> bool:
	if health <= 0.0 or is_queued_for_deletion():
		return false

	if not is_finite(duration) or duration <= 0.0:
		return false

	var effective_amount: float = GameState.resolve_shield(amount)

	if effective_amount <= 0.0:
		return false

	shield_health = effective_amount
	shield_max_health = effective_amount
	shield_time_left = duration

	save_run_shield()
	return true


func take_damage(amount: float) -> void:
	if GameState.debug_invincible:
		return

	if invulnerability_time > 0.0 or health <= 0.0:
		return

	if not is_finite(amount) or amount <= 0.0:
		return

	var remaining: float = amount

	if shield_health > 0.0 and shield_time_left > 0.0:
		var absorbed: float = minf(
			shield_health,
			remaining
		)

		shield_health -= absorbed
		remaining -= absorbed

		if shield_health <= 0.0:
			clear_temporary_shield()

	health = maxf(health - remaining, 0.0)
	GameState.health = health
	invulnerability_time = 1.0

	save_run_shield()

	if health == 0.0:
		die()


func die() -> void:
	GameState.result = "Маг погиб. Попробуем ещё раз!"

	get_tree().call_deferred(
		"change_scene_to_file",
		"res://run_result.tscn"
	)


func clear_temporary_shield() -> void:
	shield_health = 0.0
	shield_max_health = 0.0
	shield_time_left = 0.0
	GameState.clear_run_shield()


func save_run_shield() -> void:
	if (
		health <= 0.0
		or not is_finite(shield_health)
		or not is_finite(shield_max_health)
		or not is_finite(shield_time_left)
		or shield_health <= 0.0
		or shield_max_health <= 0.0
		or shield_time_left <= 0.0
	):
		clear_temporary_shield()
		return

	shield_health = minf(
		shield_health,
		shield_max_health
	)

	GameState.run_shield = {
		"health": shield_health,
		"maximum": shield_max_health,
		"time_left": shield_time_left
	}


func restore_run_shield() -> void:
	var saved_health: float = float(
		GameState.run_shield.get("health", 0.0)
	)

	var saved_maximum: float = float(
		GameState.run_shield.get("maximum", 0.0)
	)

	var saved_time: float = float(
		GameState.run_shield.get("time_left", 0.0)
	)

	if (
		health <= 0.0
		or not is_finite(saved_health)
		or not is_finite(saved_maximum)
		or not is_finite(saved_time)
		or saved_health <= 0.0
		or saved_maximum <= 0.0
		or saved_time <= 0.0
	):
		clear_temporary_shield()
		return

	shield_max_health = saved_maximum
	shield_health = minf(saved_health, saved_maximum)
	shield_time_left = saved_time

	save_run_shield()
