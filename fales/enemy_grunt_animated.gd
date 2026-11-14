extends "res://enemy.gd"

const GRUNT_SHEET = preload(
	"res://assets/characters/enemy_grunt_animations.png"
)

const GRUNT_WALK_FPS: float = 8.0
const GRUNT_PREPARE_TIME: float = 0.35
const GRUNT_STRIKE_TIME: float = 0.20
const GRUNT_HIT_TIME: float = 0.05

enum GruntPhase { WALK, PREPARE, STRIKE, RECOVER }

var grunt_phase: int = GruntPhase.WALK
var grunt_phase_time: float = 0.0
var grunt_walk_time: float = 0.0
var grunt_hit_done: bool = false

@onready var grunt_sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super._ready()

	grunt_sprite.texture = grunt_animation_texture()
	grunt_sprite.region_enabled = false
	grunt_sprite.hframes = 4
	grunt_sprite.vframes = 4
	grunt_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grunt_sprite.frame = 15


func _physics_process(delta: float) -> void:
	if not begin_combat_frame(delta):
		if is_alive():
			if (
				grunt_phase == GruntPhase.PREPARE
				or grunt_phase == GruntPhase.STRIKE
			):
				if attack_rest_left > 0.0:
					grunt_set_phase(GruntPhase.RECOVER)
				else:
					grunt_set_phase(GruntPhase.WALK)
		return

	update_attack_rest(delta)

	if not is_instance_valid(player) or player.is_queued_for_deletion():
		velocity = Vector2.ZERO
		grunt_sprite.frame = 15
		return

	if float(player.get("health")) <= 0.0:
		velocity = Vector2.ZERO
		grunt_sprite.frame = 15
		return

	grunt_phase_time += delta

	match grunt_phase:
		GruntPhase.WALK:
			if attack_rest_left > 0.0:
				grunt_set_phase(GruntPhase.RECOVER)
			elif grunt_has_contact():
				grunt_set_phase(GruntPhase.PREPARE)

		GruntPhase.PREPARE:
			if grunt_phase_time >= grunt_animation_prepare_time():
				grunt_hit_done = false
				grunt_set_phase(GruntPhase.STRIKE)

		GruntPhase.STRIKE:
			if (
				not grunt_hit_done
				and grunt_phase_time >= GRUNT_HIT_TIME
			):
				grunt_hit_done = true
				start_attack_rest(CONTACT_ATTACK_REST)
				grunt_hit_once()

			if grunt_phase_time >= GRUNT_STRIKE_TIME:
				grunt_set_phase(GruntPhase.RECOVER)

		GruntPhase.RECOVER:
			if attack_rest_left <= 0.0:
				grunt_set_phase(GruntPhase.WALK)

	var desired_velocity: Vector2 = Vector2.ZERO

	if grunt_phase == GruntPhase.WALK:
		var direction: Vector2 = global_position.direction_to(
			player.global_position
		)
		var room = get_tree().current_scene

		if room.has_method("get_enemy_direction"):
			direction = room.call(
				"get_enemy_direction",
				self,
				player.global_position
			)

		desired_velocity = direction * speed

	velocity = attack_movement(desired_velocity)
	move_and_slide()

	grunt_update_frame(
		delta,
		not desired_velocity.is_zero_approx()
	)


func grunt_set_phase(next_phase: int) -> void:
	grunt_phase = next_phase
	grunt_phase_time = 0.0


func grunt_has_contact() -> bool:
	if not is_instance_valid(attack_area):
		return false

	for body in attack_area.get_overlapping_bodies():
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			continue

		if body.is_in_group("player") and float(body.get("health")) > 0.0:
			if grunt_contact_is_clear(body):
				return true

	return false


func grunt_hit_once() -> void:
	if not is_instance_valid(attack_area):
		return

	for body in attack_area.get_overlapping_bodies():
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			continue

		if not body.is_in_group("player") or not body.has_method("take_damage"):
			continue

		if float(body.get("health")) <= 0.0:
			continue

		if not grunt_contact_is_clear(body):
			continue

		body.call("take_damage", damage)
		return


func grunt_contact_is_clear(body: Node2D) -> bool:
	var room = get_tree().current_scene

	if room.has_method("has_clear_shot"):
		return bool(room.call(
			"has_clear_shot",
			global_position,
			body.global_position
		))

	return true


func grunt_update_frame(delta: float, wants_to_walk: bool) -> void:
	match grunt_phase:
		GruntPhase.WALK:
			if wants_to_walk and get_real_velocity().length_squared() > 1.0:
				grunt_walk_time += delta
				grunt_sprite.frame = int(
					grunt_walk_time * grunt_animation_walk_fps()
				) % 4
			else:
				grunt_walk_time = 0.0
				grunt_sprite.frame = 15

		GruntPhase.PREPARE:
			grunt_sprite.frame = 4 + clampi(
				int(grunt_phase_time / GRUNT_PREPARE_TIME * 4.0),
				0,
				3
			)

		GruntPhase.STRIKE:
			grunt_sprite.frame = 8 + clampi(
				int(grunt_phase_time / GRUNT_STRIKE_TIME * 4.0),
				0,
				3
			)

		GruntPhase.RECOVER:
			var progress: float = (
				1.0 - attack_rest_left / CONTACT_ATTACK_REST
			)
			grunt_sprite.frame = 12 + clampi(
				int(progress * 4.0),
				0,
				3
			)

func grunt_animation_texture() -> Texture2D:
	return GRUNT_SHEET


func grunt_animation_walk_fps() -> float:
	return GRUNT_WALK_FPS


func grunt_animation_prepare_time() -> float:
	return GRUNT_PREPARE_TIME
