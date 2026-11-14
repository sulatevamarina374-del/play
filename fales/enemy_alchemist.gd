extends "res://enemy_shooter_animated.gd"


const ALCHEMIST_HAZARD = preload("res://alchemist_hazard.gd")

const ALCHEMIST_ATTACK_INTERVAL: float = 3.5
const ALCHEMIST_COLOR: Color = Color.WHITE


var alchemist_puddle: Node2D


func _ready() -> void:
	super._ready()
	shooter_sprite.texture = preload(
		"res://assets/characters/enemy_alchemist_animations.png"
	)

	# Временный оттенок, чтобы отличить алхимика от стрелка.
	shooter_sprite.modulate = ALCHEMIST_COLOR

	attack_interval = ALCHEMIST_ATTACK_INTERVAL
	attack_cooldown = 1.8


func shoot() -> void:
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		return

	var hazard = ALCHEMIST_HAZARD.new()
	hazard.source_enemy = self
	hazard.target_position = player.global_position

	# Учитывается общий рост урона врагов по комнатам.
	hazard.puddle_damage = damage * 0.5

	get_tree().current_scene.add_child(hazard)
	hazard.global_position = global_position

	# Запускаем существующую анимацию выстрела.
	# super.shoot() не вызываем: иначе появился бы и обычный снаряд.
	shooter_shot_left = SHOOTER_SHOT_TIME
	shooter_after_shot = true


func alchemist_register_puddle(new_puddle: Node2D) -> void:
	if is_instance_valid(alchemist_puddle):
		if not alchemist_puddle.is_queued_for_deletion():
			alchemist_puddle.queue_free()

	alchemist_puddle = new_puddle
