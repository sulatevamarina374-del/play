extends "res://enemy_grunt_animated.gd"


# Расстояние, с которого таран начинает подготовку.
const RAM_START_DISTANCE: float = 180.0

# Скорость обычного перемещения относительно обычного врага.
const RAM_WALK_FACTOR: float = 0.65

# Параметры рывка.
const RAM_PREPARE_TIME: float = 0.7
const RAM_CHARGE_TIME: float = 0.5
const RAM_CHARGE_SPEED: float = 330.0
const RAM_RECOVER_TIME: float = 1.0

const RAM_NORMAL_COLOR: Color = Color.WHITE

# Красный оттенок обозначает подготовку.
const RAM_PREPARE_COLOR: Color = Color(1.0, 0.35, 0.30)


enum RamPhase {
	WALK,
	PREPARE,
	CHARGE,
	RECOVER
}


var ram_phase: int = RamPhase.WALK
var ram_phase_time: float = 0.0
var ram_direction: Vector2 = Vector2.ZERO
var ram_walk_time: float = 0.0


func _ready() -> void:
	super._ready()
	grunt_sprite.modulate = RAM_NORMAL_COLOR


func _physics_process(delta: float) -> void:
	# Обрабатываем горение, заморозку и другие общие эффекты.
	# Физику обычного врага повторно не вызываем.
	if not begin_combat_frame(delta):
		if is_alive():
			# Заморозка отменяет незавершённый рывок:
			# после неё таран не атакует без нового предупреждения.
			if ram_phase == RamPhase.PREPARE or ram_phase == RamPhase.CHARGE:
				ram_set_phase(RamPhase.RECOVER)
				grunt_sprite.modulate = RAM_NORMAL_COLOR
				grunt_sprite.frame = 12
		return

	if not is_instance_valid(player) or player.is_queued_for_deletion():
		velocity = Vector2.ZERO
		grunt_sprite.modulate = RAM_NORMAL_COLOR
		grunt_sprite.frame = 15
		return

	if float(player.get("health")) <= 0.0:
		velocity = Vector2.ZERO
		grunt_sprite.modulate = RAM_NORMAL_COLOR
		grunt_sprite.frame = 15
		return

	ram_phase_time += delta

	var desired_velocity: Vector2 = Vector2.ZERO

	match ram_phase:
		RamPhase.WALK:
			grunt_sprite.modulate = RAM_NORMAL_COLOR

			var distance: float = global_position.distance_to(
				player.global_position
			)

			var room = get_tree().current_scene
			var can_see: bool = true

			if room.has_method("has_clear_shot"):
				can_see = bool(room.call(
					"has_clear_shot",
					global_position,
					player.global_position
				))

			if distance <= RAM_START_DISTANCE and can_see:
				# Направление фиксируется в начале подготовки.
				ram_direction = global_position.direction_to(
					player.global_position
				)

				if ram_direction.is_zero_approx():
					ram_direction = Vector2.DOWN

				ram_set_phase(RamPhase.PREPARE)
			else:
				var direction: Vector2 = global_position.direction_to(
					player.global_position
				)

				if room.has_method("get_enemy_direction"):
					direction = room.call(
						"get_enemy_direction",
						self,
						player.global_position
					)

				desired_velocity = direction * speed * RAM_WALK_FACTOR

		RamPhase.PREPARE:
			grunt_sprite.modulate = RAM_PREPARE_COLOR

			if ram_phase_time >= RAM_PREPARE_TIME:
				ram_set_phase(RamPhase.CHARGE)

		RamPhase.CHARGE:
			grunt_sprite.modulate = RAM_PREPARE_COLOR

			# Один удар за рывок. После попадания — передышка.
			if grunt_has_contact():
				grunt_hit_once()
				ram_set_phase(RamPhase.RECOVER)
			elif ram_phase_time >= RAM_CHARGE_TIME:
				ram_set_phase(RamPhase.RECOVER)
			else:
				desired_velocity = ram_direction * RAM_CHARGE_SPEED

		RamPhase.RECOVER:
			grunt_sprite.modulate = RAM_NORMAL_COLOR

			if ram_phase_time >= RAM_RECOVER_TIME:
				ram_set_phase(RamPhase.WALK)

	# Замедление и отбрасывание продолжают действовать.
	velocity = combat_effects.movement(desired_velocity)
	move_and_slide()

	# Стены, камни и другие статические препятствия
	# останавливают рывок.
	if ram_phase == RamPhase.CHARGE:
		for index in range(get_slide_collision_count()):
			var collision: KinematicCollision2D = get_slide_collision(index)

			if collision.get_collider() is StaticBody2D:
				ram_set_phase(RamPhase.RECOVER)
				break

	ram_update_animation(delta, not desired_velocity.is_zero_approx())


func ram_set_phase(next_phase: int) -> void:
	ram_phase = next_phase
	ram_phase_time = 0.0


func ram_update_animation(delta: float, wants_to_walk: bool) -> void:
	match ram_phase:
		RamPhase.WALK:
			if wants_to_walk and get_real_velocity().length_squared() > 1.0:
				ram_walk_time += delta
				grunt_sprite.frame = int(ram_walk_time * 8.0) % 4
			else:
				ram_walk_time = 0.0
				grunt_sprite.frame = 15

		RamPhase.PREPARE:
			var progress: float = ram_phase_time / RAM_PREPARE_TIME
			grunt_sprite.frame = 4 + clampi(int(progress * 4.0), 0, 3)

		RamPhase.CHARGE:
			var progress: float = ram_phase_time / RAM_CHARGE_TIME
			grunt_sprite.frame = 8 + clampi(int(progress * 4.0), 0, 3)

		RamPhase.RECOVER:
			var progress: float = ram_phase_time / RAM_RECOVER_TIME
			grunt_sprite.frame = 12 + clampi(int(progress * 4.0), 0, 3)


func grunt_animation_texture() -> Texture2D:
	return preload("res://assets/characters/enemy_ram_animations.png")
