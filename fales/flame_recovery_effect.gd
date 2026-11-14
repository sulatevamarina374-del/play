extends "res://spell_impact.gd"

var level: int = 1
var direction: Vector2 = Vector2.RIGHT
var burn_dps: float = 0.0


func _physics_process(delta: float) -> void:
	if not active():
		queue_free()
		return

	age += delta

	if spell_id == "light_heal":
		global_position = mage.global_position + Vector2(0, -44)

	elif not fired:
		direction = direction.normalized()

		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT

		breath_hit()
		fired = true

	if age >= 0.4:
		queue_free()

	queue_redraw()


func half_angle() -> float:
	var widths: Array[float] = [40.0, 65.0, 90.0]

	return deg_to_rad(
		widths[clampi(level, 1, 3) - 1] * 0.5
	)


func breath_hit() -> void:
	var limit: float = cos(half_angle())

	for node in get_tree().get_nodes_in_group("enemies"):
		if not alive(node):
			continue

		var offset: Vector2 = (
			node.global_position - global_position
		)

		if offset.length_squared() > 180.0 * 180.0:
			continue

		if offset != Vector2.ZERO:
			if direction.dot(offset.normalized()) < limit:
				continue

		if not clear_line(global_position, node.global_position):
			continue

		node.call("take_damage", damage)

		if alive(node) and node.has_method("apply_burn"):
			node.call(
				"apply_burn",
				2.0,
				burn_dps
			)


func _draw() -> void:
	var alpha: float = clampf(
		1.0 - age / 0.4,
		0.0,
		1.0
	)

	if spell_id == "light_heal":
		var color := Color("efe3a0")
		color.a = alpha

		draw_rect(Rect2(-3, -11, 6, 22), color)
		draw_rect(Rect2(-11, -3, 22, 6), color)
		return

	var points := PackedVector2Array([
		Vector2.ZERO
	])

	var angle: float = half_angle()

	for index in range(13):
		var current: float = (
			direction.angle()
			- angle
			+ angle * 2.0 * float(index) / 12.0
		)

		points.append(
			Vector2.from_angle(current) * 180.0
		)

	var fill := Color("ff9850")
	fill.a = alpha * 0.25
	draw_colored_polygon(points, fill)

	points.append(Vector2.ZERO)

	var border := Color("ff9850")
	border.a = alpha
	draw_polyline(points, border, 2.0, false)
