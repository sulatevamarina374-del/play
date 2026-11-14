extends "res://spell_impact.gd"

const CHAIN_RANGE: float = 180.0
const CHAIN_GAP: float = 0.15

const TORNADO_RADIUS: float = 28.0
const TORNADO_SPEED: float = 110.0
const TORNADO_HIT_GAP: float = 0.6

var level: int = 1

var used: Array[int] = []
var jump_left: float = 0.0
var finished_at: float = 0.0

var trail: PackedVector2Array = PackedVector2Array()
var hit_times: Dictionary = {}

var destination: Vector2 = Vector2.ZERO
var destination_known: bool = false


func _physics_process(delta: float) -> void:
	if not active():
		queue_free()
		return

	age += delta

	if fired:
		if age >= finished_at + 0.28:
			queue_free()

		queue_redraw()
		return

	match spell_id:
		"fire_meteors":
			if age >= delay:
				strike()
				finished_at = age

		"water_cascade":
			jump_left -= delta

			if jump_left <= 0.0:
				chain_hit()

		"wind_tornado":
			tornado_tick(delta)

	queue_redraw()


func finish() -> void:
	fired = true
	finished_at = age


func valid_chain_target(enemy: Variant) -> bool:
	if not alive(enemy):
		return false

	if used.has(enemy.get_instance_id()):
		return false

	var reach: float = 480.0 if used.is_empty() else CHAIN_RANGE

	if global_position.distance_to(enemy.global_position) > reach:
		return false

	if mage.global_position.distance_to(enemy.global_position) > 480.0:
		return false

	return (
		clear_line(global_position, enemy.global_position)
		and clear_line(mage.global_position, enemy.global_position)
	)


func next_chain_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF

	for node in get_tree().get_nodes_in_group("enemies"):
		if not valid_chain_target(node):
			continue

		var distance: float = global_position.distance_squared_to(
			node.global_position
		)

		if distance < nearest_distance:
			nearest = node as Node2D
			nearest_distance = distance

	return nearest


func chain_hit() -> void:
	if not valid_chain_target(target):
		target = next_chain_target()

	if not alive(target):
		finish()
		return

	if trail.is_empty():
		trail.append(global_position)

	global_position = target.global_position
	trail.append(global_position)

	# Запоминаем цель до нанесения урона:
	# после попадания она может погибнуть.
	used.append(target.get_instance_id())

	target.call("take_damage", damage)
	target = null

	jump_left = CHAIN_GAP

	# Первая цель включена в итоговые 2 / 4 / 6.
	if used.size() >= clampi(level, 1, 3) * 2:
		finish()


func tornado_tick(delta: float) -> void:
	var duration: float = 1.0 + float(clampi(level, 1, 3))

	if age >= duration:
		finish()
		return

	if alive(target):
		destination = target.global_position
		destination_known = true

	if destination_known:
		var next_position: Vector2 = global_position.move_toward(
			destination,
			TORNADO_SPEED * delta
		)

		if clear_line(global_position, next_position):
			global_position = next_position

	for node in get_tree().get_nodes_in_group("enemies"):
		if not alive(node):
			continue

		if global_position.distance_to(node.global_position) > TORNADO_RADIUS:
			continue

		if not clear_line(global_position, node.global_position):
			continue

		var id: int = node.get_instance_id()

		if age < float(hit_times.get(id, -1.0)):
			continue

		hit_times[id] = age + TORNADO_HIT_GAP
		node.call("take_damage", damage)


func _draw() -> void:
	var alpha: float = 1.0

	if fired:
		alpha = clampf(
			1.0 - (age - finished_at) / 0.28,
			0.0,
			1.0
		)

	match spell_id:
		"fire_meteors":
			var color := Color("ff9850")
			color.a = alpha

			if not fired:
				color.a = 0.65

				draw_arc(
					Vector2.ZERO,
					radius,
					0.0,
					TAU,
					24,
					color,
					2.0,
					false
				)

				draw_line(Vector2(-8, 0), Vector2(8, 0), color, 2.0)
				draw_line(Vector2(0, -8), Vector2(0, 8), color, 2.0)

			else:
				draw_line(
					Vector2(35, -100),
					Vector2.ZERO,
					color,
					8.0
				)

				draw_arc(
					Vector2.ZERO,
					radius,
					0.0,
					TAU,
					24,
					color,
					5.0,
					false
				)

				draw_rect(Rect2(-12, -12, 24, 24), color)

		"water_cascade":
			var color := Color("5eadd1")
			color.a = alpha

			if trail.size() >= 2:
				var points := PackedVector2Array()

				for point in trail:
					points.append(to_local(point))

				draw_polyline(points, color, 3.0, false)

			draw_rect(Rect2(-6, -6, 12, 12), color)

		"wind_tornado":
			var color := Color("94c89a")
			color.a = alpha

			for index in range(4):
				var width: float = 12.0 + float(index) * 10.0
				var offset: float = sin(
					age * 10.0 + float(index)
				) * 4.0

				draw_rect(
					Rect2(
						-width / 2.0 + offset,
						-index * 9.0,
						width,
						4
					),
					color
				)
