extends Node2D


const FLASK_SPEED: float = 240.0
const PUDDLE_RADIUS: float = 40.0
const PUDDLE_DURATION: float = 3.0
const PUDDLE_HIT_INTERVAL: float = 1.0


var source_enemy: Node2D
var target_position: Vector2 = Vector2.ZERO
var puddle_damage: float = 0.5

var is_puddle: bool = false
var puddle_time_left: float = PUDDLE_DURATION
var damage_cooldown: float = 0.0


func _ready() -> void:
	z_index = 2


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return

	# Снаряд и лужа исчезают, если алхимик погиб.
	if not is_instance_valid(source_enemy):
		queue_free()
		return

	if source_enemy.is_queued_for_deletion():
		queue_free()
		return

	if not bool(source_enemy.call("is_alive")):
		queue_free()
		return

	if is_puddle:
		_update_puddle(delta)
	else:
		_update_flask(delta)


func _update_flask(delta: float) -> void:
	var previous_position: Vector2 = global_position
	var next_position: Vector2 = global_position.move_toward(
		target_position,
		FLASK_SPEED * delta
	)

	var room = get_tree().current_scene

	# Камни блокируют полёт. Если снаряд встретил препятствие,
	# лужа появляется перед ним.
	if room.has_method("has_clear_shot"):
		var clear_path: bool = bool(room.call(
			"has_clear_shot",
			previous_position,
			next_position
		))

		if not clear_path:
			_create_puddle()
			return

	global_position = next_position

	if global_position.distance_to(target_position) <= 0.1:
		_create_puddle()


func _create_puddle() -> void:
	is_puddle = true
	puddle_time_left = PUDDLE_DURATION
	damage_cooldown = 0.0

	# Алхимик удалит предыдущую лужу, если она ещё существует.
	source_enemy.call("alchemist_register_puddle", self)

	queue_redraw()


func _update_puddle(delta: float) -> void:
	puddle_time_left -= delta

	if puddle_time_left <= 0.0:
		queue_free()
		return

	damage_cooldown = maxf(damage_cooldown - delta, 0.0)

	if damage_cooldown > 0.0:
		return

	var target: Node2D = source_enemy.get("player") as Node2D

	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return

	if float(target.get("health")) <= 0.0:
		return

	if global_position.distance_to(target.global_position) > PUDDLE_RADIUS:
		return

	# Лужа не наносит урон сквозь камень.
	var room = get_tree().current_scene

	if room.has_method("has_clear_shot"):
		if not bool(room.call(
			"has_clear_shot",
			global_position,
			target.global_position
		)):
			return

	if target.has_method("take_damage"):
		target.call("take_damage", puddle_damage)
		damage_cooldown = PUDDLE_HIT_INTERVAL


func _draw() -> void:
	if is_puddle:
		# Временный вид лужи; позже можно заменить на спрайт.
		draw_circle(
			Vector2.ZERO,
			PUDDLE_RADIUS,
			Color(1.0, 0.55, 0.10, 0.35)
		)

		draw_arc(
			Vector2.ZERO,
			PUDDLE_RADIUS,
			0.0,
			TAU,
			32,
			Color(1.0, 0.72, 0.25, 0.9),
			2.0
		)

		draw_circle(
			Vector2(-12.0, -6.0),
			5.0,
			Color(1.0, 0.8, 0.35, 0.7)
		)

		draw_circle(
			Vector2(10.0, 8.0),
			4.0,
			Color(1.0, 0.8, 0.35, 0.7)
		)
	else:
		# Временный вид летящего снаряда.
		draw_circle(
			Vector2.ZERO,
			7.0,
			Color(0.28, 0.16, 0.08)
		)

		draw_circle(
			Vector2.ZERO,
			4.5,
			Color(1.0, 0.65, 0.15)
		)
