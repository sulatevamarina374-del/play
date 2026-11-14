extends "res://enemy_combat.gd"

@export var speed: float = 100.0
@export var health: float = 3.0
@export var damage: float = 1.0

var player: Node2D
@onready var attack_area: Area2D = $AttackArea


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

	try_contact_attack(attack_area)

	var direction: Vector2 = global_position.direction_to(player.global_position)
	var room = get_tree().current_scene

	if room.has_method("get_enemy_direction"):
		direction = room.call(
			"get_enemy_direction",
			self,
			player.global_position
		)

	velocity = attack_movement(direction * speed)
	move_and_slide()
