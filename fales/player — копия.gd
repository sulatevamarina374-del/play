extends CharacterBody2D

signal shot_fired

@export var speed: float = 250.0
@export var attack_interval: float = 0.7

const PROJECTILE_SCENE = preload("res://projectile.tscn")

var attack_cooldown: float = 0.0
@export var max_health: float = 5.0

var health: float
var invulnerability_time: float = 0.0

@onready var joystick: Control = get_node_or_null("../HUD/Joystick")

func _ready() -> void:
	if GameState.health == -1:
		GameState.health = max_health

	health = GameState.health
	attack_interval = GameState.attack_interval

	print("Здоровье мага: ", health)


func _physics_process(delta: float) -> void:
	invulnerability_time = maxf(invulnerability_time - delta, 0.0)
		
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

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_queued_for_deletion():
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
	projectile.damage = GameState.damage
	projectile.direction = global_position.direction_to(
		nearest_enemy.global_position
	)

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	shot_fired.emit()

func take_damage(amount: float) -> void:
	if invulnerability_time > 0.0 or health <= 0:
		return

	health = maxf(health - amount, 0.0)
	GameState.health = health
	invulnerability_time = 1.0

	print("Здоровье мага: ", health)

	if health == 0:
		die()


func die() -> void:
	GameState.result = "Маг погиб. Попробуем ещё раз!"

	get_tree().call_deferred(
		"change_scene_to_file",
		"res://main_menu.tscn"
	)
