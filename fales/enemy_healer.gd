extends "res://enemy_shooter_animated.gd"


# Первая стадия.
const HEAL_INTERVAL: float = 4.0
const HEAL_DISTANCE: float = 200.0
const HEAL_BASE_AMOUNT: float = 1.0

# Дистанции движения лекаря.
const SAFE_DISTANCE: float = 220.0
const FOLLOW_DISTANCE: float = 135.0

# Вторая стадия.
const PHASE_TWO_DAMAGE_FACTOR: float = 1.5
const PHASE_TWO_HEALTH_FACTOR: float = 3.0
const PHASE_TWO_ATTACK_INTERVAL: float = 2.0

const HEALER_COLOR: Color = Color.WHITE
const PHASE_TWO_COLOR: Color = Color(1.0, 0.35, 0.4)

const HEAL_LINE_TIME: float = 0.3


var healer_phase_two: bool = false
var heal_cooldown: float = HEAL_INTERVAL

var heal_line: Line2D
var heal_line_target: Node2D
var heal_line_time_left: float = 0.0


func _ready() -> void:
	super._ready()

	shooter_sprite.texture = preload(
		"res://assets/characters/enemy_healer_animations.png"
		)
		
	shooter_sprite.modulate = HEALER_COLOR

	# Временная линия показывает, кого лечит лекарь.
	heal_line = Line2D.new()
	heal_line.width = 3.0
	heal_line.default_color = Color(0.55, 1.0, 0.95, 0.9)
	heal_line.z_index = 2
	heal_line.visible = false
	add_child(heal_line)


func _physics_process(delta: float) -> void:
	_update_heal_line(delta)

	# Во второй стадии используем обычную физику стрелка:
	# движение, выстрелы, контактную атаку и анимации.
	if healer_phase_two:
		super._physics_process(delta)
		return

	# В первой стадии НЕ вызываем физику стрелка,
	# иначе лекарь мог бы атаковать.
	if not begin_combat_frame(delta):
		return

	if not is_instance_valid(player) or player.is_queued_for_deletion():
		velocity = Vector2.ZERO
		shooter_sprite.frame = 15
		return

	if float(player.get("health")) <= 0.0:
		velocity = Vector2.ZERO
		shooter_sprite.frame = 15
		return

	var allies: Array[Node2D] = _living_allies()

	# Если лекарь остался последним, переходит во вторую стадию.
	if allies.is_empty():
		_begin_second_phase()
		return

	heal_cooldown = maxf(heal_cooldown - delta, 0.0)

	if heal_cooldown <= 0.0:
		var wounded: Node2D = _find_wounded_ally(allies)

		if is_instance_valid(wounded):
			_heal_ally(wounded)
			heal_cooldown = HEAL_INTERVAL

	# Сначала уходит от мага, затем старается оставаться
	# достаточно близко к союзникам для лечения.
	var nearest_ally: Node2D = _find_nearest_ally(allies)
	var target_position: Vector2 = global_position

	var distance_to_player: float = global_position.distance_to(
		player.global_position
	)

	if distance_to_player < SAFE_DISTANCE:
		var away: Vector2 = player.global_position.direction_to(
			global_position
		)

		if away.is_zero_approx():
			away = Vector2.DOWN

		target_position = global_position + away * 128.0

	elif is_instance_valid(nearest_ally):
		if global_position.distance_to(nearest_ally.global_position) > FOLLOW_DISTANCE:
			target_position = nearest_ally.global_position

	var desired_velocity: Vector2 = Vector2.ZERO

	if global_position.distance_to(target_position) > 1.0:
		var direction: Vector2 = global_position.direction_to(
			target_position
		)

		var room = get_tree().current_scene

		if room.has_method("get_enemy_direction"):
			direction = room.call(
				"get_enemy_direction",
				self,
				target_position
			)

		desired_velocity = direction * speed

	# Замедление и отбрасывание сохраняются.
	velocity = combat_effects.movement(desired_velocity)
	move_and_slide()

	_update_support_animation(delta, not desired_velocity.is_zero_approx())


func _living_allies() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var room = get_tree().current_scene

	if not is_instance_valid(room):
		return result

	for node in get_tree().get_nodes_in_group("enemies"):
		var ally: Node2D = node as Node2D

		if not is_instance_valid(ally):
			continue

		if ally == self or ally.is_queued_for_deletion():
			continue

		# Учитываем только врагов текущей комнаты.
		if not room.is_ancestor_of(ally):
			continue

		if not ally.has_method("is_alive"):
			continue

		if not bool(ally.call("is_alive")):
			continue

		result.append(ally)

	return result


func _find_nearest_ally(allies: Array[Node2D]) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF

	for ally in allies:
		var distance: float = global_position.distance_to(
			ally.global_position
		)

		if distance < nearest_distance:
			nearest = ally
			nearest_distance = distance

	return nearest


func _find_wounded_ally(allies: Array[Node2D]) -> Node2D:
	var best_ally: Node2D = null
	var lowest_health_ratio: float = 2.0
	var room = get_tree().current_scene

	for ally in allies:
		if not ally.has_meta("healer_max_health"):
			continue

		var maximum: float = float(ally.get_meta("healer_max_health"))
		var current: float = float(ally.get("health"))

		if maximum <= 0.0 or current <= 0.0:
			continue

		if current >= maximum:
			continue

		if global_position.distance_to(ally.global_position) > HEAL_DISTANCE:
			continue

		# Камень между лекарем и союзником блокирует лечение.
		if room.has_method("has_clear_shot"):
			if not bool(room.call(
				"has_clear_shot",
				global_position,
				ally.global_position
			)):
				continue

		var health_ratio: float = current / maximum

		if health_ratio < lowest_health_ratio:
			lowest_health_ratio = health_ratio
			best_ally = ally

	return best_ally


func _heal_ally(ally: Node2D) -> void:
	var maximum: float = float(ally.get_meta("healer_max_health"))
	var current: float = float(ally.get("health"))

	var amount: float = (
		HEAL_BASE_AMOUNT * GameState.enemy_health_multiplier()
	)

	ally.set("health", minf(maximum, current + amount))

	heal_line_target = ally
	heal_line_time_left = HEAL_LINE_TIME
	heal_line.visible = true
	_update_heal_line(0.0)


func _update_heal_line(delta: float) -> void:
	if not is_instance_valid(heal_line):
		return

	heal_line_time_left = maxf(heal_line_time_left - delta, 0.0)

	if heal_line_time_left <= 0.0:
		heal_line.visible = false
		return

	if not is_instance_valid(heal_line_target):
		heal_line.visible = false
		return

	if heal_line_target.is_queued_for_deletion():
		heal_line.visible = false
		return

	heal_line.points = PackedVector2Array([
		Vector2.ZERO,
		to_local(heal_line_target.global_position)
	])


func _begin_second_phase() -> void:
	healer_phase_two = true

	heal_line.visible = false
	heal_line_time_left = 0.0

	# В комнате начальному здоровью лекаря присвоено 2 HP
	# с учётом общего множителя. Утроение даёт 6 HP
	# с тем же множителем.
	var first_phase_maximum: float = float(
		get_meta("healer_max_health", health)
	)

	var second_phase_maximum: float = (
		first_phase_maximum * PHASE_TWO_HEALTH_FACTOR
	)

	health = second_phase_maximum
	set_meta("healer_max_health", second_phase_maximum)

	# Начальный урон равен 1 и уже учитывает множитель комнаты.
	damage *= PHASE_TWO_DAMAGE_FACTOR

	attack_interval = PHASE_TWO_ATTACK_INTERVAL
	attack_cooldown = PHASE_TWO_ATTACK_INTERVAL

	shooter_sprite.texture = preload(
		"res://assets/characters/enemy_healer_combat_animations.png"
	)
	shooter_sprite.modulate = Color.WHITE
	shooter_sprite.frame = 15
	velocity = Vector2.ZERO


func _update_support_animation(delta: float, wants_to_walk: bool) -> void:
	if wants_to_walk and get_real_velocity().length_squared() > 1.0:
		shooter_walk_time += delta
		shooter_sprite.frame = int(
			shooter_walk_time * SHOOTER_WALK_FPS
		) % 4
	else:
		shooter_walk_time = 0.0
		shooter_sprite.frame = 15
