extends "res://enemy_shooter.gd"

const SHOOTER_SHEET = preload("res://assets/characters/enemy_shooter_animations.png")
const SHOOTER_WALK_FPS: float = 8.0
const SHOOTER_PREVIEW_TIME: float = 0.35
const SHOOTER_SHOT_TIME: float = 0.20

var shooter_walk_time: float = 0.0
var shooter_shot_left: float = 0.0
var shooter_after_shot: bool = false

@onready var shooter_sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super._ready()
	shooter_sprite.texture = SHOOTER_SHEET
	shooter_sprite.region_enabled = false
	shooter_sprite.hframes = 4
	shooter_sprite.vframes = 4
	shooter_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shooter_sprite.frame = 15


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if not is_alive():
		return
	if combat_effects.freeze_left > 0.0:
		return
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		shooter_sprite.frame = 15
		return

	if shooter_shot_left > 0.0:
		var progress: float = 1.0 - shooter_shot_left / SHOOTER_SHOT_TIME
		shooter_sprite.frame = 8 + clampi(int(progress * 4.0), 0, 3)
		shooter_shot_left = maxf(shooter_shot_left - delta, 0.0)
		return

	if shooter_after_shot and attack_rest_left > 0.0:
		var recovery_time: float = maxf(RANGED_ATTACK_REST - SHOOTER_SHOT_TIME, 0.01)
		var progress: float = 1.0 - attack_rest_left / recovery_time
		shooter_sprite.frame = 12 + clampi(int(progress * 4.0), 0, 3)
		return
	shooter_after_shot = false

	var room = get_tree().current_scene
	var can_see: bool = true
	if room.has_method("has_clear_shot"):
		can_see = bool(room.call("has_clear_shot", global_position, player.global_position))

	if attack_rest_left <= 0.0 and can_see and attack_cooldown > 0.0 and attack_cooldown <= SHOOTER_PREVIEW_TIME:
		var progress: float = 1.0 - attack_cooldown / SHOOTER_PREVIEW_TIME
		shooter_sprite.frame = 4 + clampi(int(progress * 4.0), 0, 3)
	elif attack_rest_left <= 0.0 and get_real_velocity().length_squared() > 1.0:
		shooter_walk_time += delta
		shooter_sprite.frame = int(shooter_walk_time * SHOOTER_WALK_FPS) % 4
	else:
		shooter_walk_time = 0.0
		shooter_sprite.frame = 15


func shoot() -> void:
	super.shoot()
	shooter_shot_left = SHOOTER_SHOT_TIME
	shooter_after_shot = true
