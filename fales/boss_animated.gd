extends "res://boss.gd"

const BOSS_ANIM_SHEET = preload("res://assets/characters/boss_guardian_animations.png")
const BOSS_ANIM_WALK_FPS: float = 8.0
const BOSS_ANIM_PREVIEW_TIME: float = 0.35
const BOSS_ANIM_SHOT_TIME: float = 0.20

var boss_anim_walk_time: float = 0.0
var boss_anim_shot_left: float = 0.0
var boss_anim_after_shot: bool = false

@onready var boss_anim_sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super._ready()
	boss_anim_sprite.texture = BOSS_ANIM_SHEET
	boss_anim_sprite.region_enabled = false
	boss_anim_sprite.hframes = 4
	boss_anim_sprite.vframes = 4
	boss_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss_anim_sprite.frame = 15


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if not is_alive():
		return
	if combat_effects.freeze_left > 0.0:
		return
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		boss_anim_sprite.frame = 15
		return

	if boss_anim_shot_left > 0.0:
		var progress: float = 1.0 - boss_anim_shot_left / BOSS_ANIM_SHOT_TIME
		boss_anim_sprite.frame = 8 + clampi(int(progress * 4.0), 0, 3)
		boss_anim_shot_left = maxf(boss_anim_shot_left - delta, 0.0)
		return

	if boss_anim_after_shot and attack_rest_left > 0.0:
		var recovery_time: float = maxf(RANGED_ATTACK_REST - BOSS_ANIM_SHOT_TIME, 0.01)
		var progress: float = 1.0 - attack_rest_left / recovery_time
		boss_anim_sprite.frame = 12 + clampi(int(progress * 4.0), 0, 3)
		return
	boss_anim_after_shot = false

	var room = get_tree().current_scene
	var can_see: bool = true
	if room.has_method("has_clear_shot"):
		can_see = bool(room.call("has_clear_shot", global_position, player.global_position))

	if attack_rest_left <= 0.0 and can_see and attack_cooldown > 0.0 and attack_cooldown <= BOSS_ANIM_PREVIEW_TIME:
		var progress: float = 1.0 - attack_cooldown / BOSS_ANIM_PREVIEW_TIME
		boss_anim_sprite.frame = 4 + clampi(int(progress * 4.0), 0, 3)
	elif attack_rest_left <= 0.0 and get_real_velocity().length_squared() > 1.0:
		boss_anim_walk_time += delta
		boss_anim_sprite.frame = int(boss_anim_walk_time * BOSS_ANIM_WALK_FPS) % 4
	else:
		boss_anim_walk_time = 0.0
		boss_anim_sprite.frame = 15


func shoot() -> void:
	super.shoot()
	boss_anim_shot_left = BOSS_ANIM_SHOT_TIME
	boss_anim_after_shot = true
