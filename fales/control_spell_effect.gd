extends "res://spell_impact.gd"

const WAVE_SPEED: float = 300.0
const WAVE_RANGE: float = 360.0
const WAVE_HALF_WIDTH: float = 26.0

const RIDGE_RANGE: float = 240.0
const RIDGE_HALF_WIDTH: float = 12.0

var level: int = 1
var direction: Vector2 = Vector2.RIGHT

var used: Array[int] = []
var travelled: float = 0.0
var ridge_length: float = 0.0
var prepared: bool = false
var finished_at: float = 0.0


func _physics_process(delta: float) -> void:
	if not active():
		queue_free()
		return

	if not prepared:
		prepared = true
		direction = direction.normalized()

		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT

		if not clear_line(mage.global_position, global_position):
			queue_free()
			return

		if spell_id == "ice_ridge":
			ridge_length = clear_distance(
				global_position,
				RIDGE_RANGE
			)

	age += delta

	if fired:
		if age >= finished_at + 0.25:
			queue_free()

		queue_redraw()
		return

	match spell_id:
		"wind_waves":
			wave_tick(delta)

		"ice_ridge":
			if age >= 0.35:
				ridge_hit()
				finish()

		"ice_ring":
			ring_hit()
			finish()

	queue_redraw()


func finish() -> void:
	fired = true
	finished_at = age


func clear_distance(origin: Vector2, wanted: float) -> float:
	var distance: float = 0.0

	while distance < wanted:
		var next_distance: float = minf(
			distance + 8.0,
			wanted
		)

		if not clear_line(
			origin,
			origin + direction * next_distance
		):
			break

		distance = next_distance

	return distance


func hit_enemy(enemy: Variant) -> void:
	if not alive(enemy) or used.has(enemy.get_instance_id()):
		return

	used.append(enemy.get_instance_id())
	enemy.call("take_damage", damage)

	# Враг мог погибнуть от самого попадания.
	if not alive(enemy):
		return

	match spell_id:
		"wind_waves":
			if enemy.has_method("apply_knockback"):
				enemy.call(
					"apply_knockback",
					direction,
					320.0,
					0.3
				
				)

		"ice_ridge":
			if enemy.has_method("apply_slow"):
				enemy.call(
					"apply_slow",
					"ice_ridge",
					1.5,
					0.65
				)

		"ice_ring":
			if enemy.has_method("apply_freeze"):
				var duration: float = (
					1.0
					+ 0.5 * float(clampi(level, 1, 3) - 1)
				)

				enemy.call(
					"apply_freeze",
					duration,
					0.7
				)


func wave_tick(delta: float) -> void:
	var previous: Vector2 = global_position

	var wanted: float = minf(
		WAVE_SPEED * delta,
		WAVE_RANGE - travelled
	)

	var step: float = clear_distance(previous, wanted)

	global_position += direction * step
	travelled += step

	for node in get_tree().get_nodes_in_group("enemies"):
		if not alive(node):
			continue

		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
			node.global_position,
			previous,
			global_position
		)

		if closest.distance_to(node.global_position) <= WAVE_HALF_WIDTH:
			if clear_line(closest, node.global_position):
				hit_enemy(node)

	if step < wanted or travelled >= WAVE_RANGE:
		finish()


func ridge_hit() -> void:
	var side: Vector2 = direction.orthogonal()

	for node in get_tree().get_nodes_in_group("enemies"):
		if not alive(node):
			continue

		var offset: Vector2 = (
			node.global_position - global_position
		)

		var forward: float = offset.dot(direction)

		if forward < 0.0 or forward > ridge_length:
			continue

		if absf(offset.dot(side)) > RIDGE_HALF_WIDTH:
			continue

		if clear_line(global_position, node.global_position):
			hit_enemy(node)


func ring_hit() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not alive(node):
			continue

		if global_position.distance_to(node.global_position) > 110.0:
			continue

		if clear_line(global_position, node.global_position):
			hit_enemy(node)


func _draw() -> void:
	var alpha: float = 1.0

	if fired:
		alpha = clampf(
			1.0 - (age - finished_at) / 0.25,
			0.0,
			1.0
		)

	var color: Color = (
		Color("94c89a")
		if spell_id == "wind_waves"
		else Color("a5dce5")
	)

	color.a = alpha

	if spell_id == "ice_ring":
		draw_arc(
			Vector2.ZERO,
			110.0,
			0.0,
			TAU,
			32,
			color,
			4.0,
			false
		)
		return

	draw_set_transform(Vector2.ZERO, direction.angle())

	if spell_id == "wind_waves":
		draw_rect(
			Rect2(
				-4,
				-WAVE_HALF_WIDTH,
				8,
				WAVE_HALF_WIDTH * 2.0
			),
			color
		)

	else:
		if not fired:
			color.a = 0.45

		draw_rect(
			Rect2(
				0,
				-RIDGE_HALF_WIDTH,
				ridge_length,
				RIDGE_HALF_WIDTH * 2.0
			),
			color,
			false,
			2.0
		)

		if fired:
			for index in range(int(ridge_length / 20.0)):
				draw_rect(
					Rect2(index * 20 + 3, -9, 12, 18),
					color
				)

	draw_set_transform(Vector2.ZERO)
