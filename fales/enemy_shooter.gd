extends "res://enemy_combat.gd"

@export var speed: float = 70.0
@export var health: float = 4.0
@export var damage: float = 1.0
@export var attack_interval: float = 1.8

const BULLET_SCENE = preload("res://enemy_projectile.tscn")

@onready var attack_area: Area2D = $AttackArea

var player: Node2D
var attack_cooldown: float = 1.8


func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if not begin_combat_frame(delta):
		return

	update_attack_rest(delta)

	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	var room = get_tree().current_scene
	var can_see: bool = true

	if room.has_method("has_clear_shot"):
		can_see = bool(room.call(
			"has_clear_shot",
			global_position,
			player.global_position
		))

	try_contact_attack(attack_area)

	attack_cooldown -= delta

	if attack_cooldown <= 0.0 and attack_rest_left <= 0.0:
		if can_see:
			shoot()
			start_attack_rest(RANGED_ATTACK_REST)

		attack_cooldown = attack_interval

	var direction: Vector2 = global_position.direction_to(
		player.global_position
	)
	var distance: float = global_position.distance_to(
		player.global_position
	)
	var target: Vector2 = global_position

	if not can_see or distance > 260.0:
		target = player.global_position
	elif distance < 180.0:
		target = global_position - direction * 128.0

	var desired_velocity: Vector2 = Vector2.ZERO

	if target.distance_to(global_position) > 1.0:
		var move_direction: Vector2 = global_position.direction_to(target)

		if room.has_method("get_enemy_direction"):
			move_direction = room.call(
				"get_enemy_direction",
				self,
				target
			)

		desired_velocity = move_direction * speed

	velocity = attack_movement(desired_velocity)
	move_and_slide()


func shoot() -> void:
	var bullet = BULLET_SCENE.instantiate()
	bullet.damage = damage

	bullet.direction = global_position.direction_to(
		player.global_position
	)

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
