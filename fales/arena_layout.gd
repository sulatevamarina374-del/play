extends Node2D

const CLEARANCE: float = 48.0
const COLUMN_TEXTURE = preload("res://assets/environment/column_wall.png")

var obstacles: Array[Rect2] = []
var water_zones: Array[Rect2] = []
var bounds: Rect2
var navigation := AStar2D.new()
var navigation_by_clearance: Dictionary = {}
var routes: Dictionary = {}
var layout_name: String = "Открытая"


func setup(
	dimensions: Vector2,
	random: RandomNumberGenerator,
	boss_room: bool
) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bounds = Rect2(
		Vector2(64, 64),
		dimensions - Vector2(128, 128)
	)
	layout_name = "Открытая"

	if not boss_room and random.randf() < 0.65:
		var variant: int = random.randi_range(0, 4)

		match variant:
			0:
				layout_name = "Колонны"

				for x in [0.30, 0.70]:
					for y in [0.34, 0.58]:
						_add_obstacle(
							(dimensions * Vector2(x, y)).round(),
							Vector2(64, 96)
						)

			1:
				layout_name = "Три прохода"

				var height: float = minf(
					256.0,
					floorf(dimensions.y * 0.28 / 32.0) * 32.0
				)

				for x in [0.30, 0.70]:
					_add_obstacle(
						(dimensions * Vector2(x, 0.46)).round(),
						Vector2(64, height)
					)

			2:
				layout_name = "Смещённые стены"

				var width: float = minf(
					288.0,
					floorf(dimensions.x * 0.30 / 32.0) * 32.0
				)

				_add_obstacle(
					(dimensions * Vector2(0.35, 0.36)).round(),
					Vector2(width, 64)
				)

				_add_obstacle(
					(dimensions * Vector2(0.65, 0.60)).round(),
					Vector2(width, 64)
				)

			3:
				layout_name = "Четыре сектора"

				for x in [0.30, 0.70]:
					for y in [0.32, 0.62]:
						_add_obstacle(
							(dimensions * Vector2(x, y)).round(),
							Vector2(96, 128)
						)

			4:
				layout_name = "Водный перекрёсток"

				# Внутренний край существующих стен.
				var edge: float = 30.0

				# Ширина центрального вертикального прохода.
				var passage_width: float = clampf(
					floorf(dimensions.x * 0.34 / 32.0) * 32.0,
					256.0,
					320.0
				)

				# Ширина поперечного прохода.
				var passage_height: float = 320.0

				var left: float = (
					dimensions.x - passage_width
				) / 2.0

				var right: float = (
					dimensions.x + passage_width
				) / 2.0

				var top: float = (
					dimensions.y - passage_height
				) / 2.0

				var bottom: float = (
					dimensions.y + passage_height
				) / 2.0

				var pools: Array[Rect2] = [
					# Верхний левый провал.
					Rect2(
						Vector2(edge, edge),
						Vector2(left - edge, top - edge)
					),

					# Верхний правый провал.
					Rect2(
						Vector2(right, edge),
						Vector2(
							dimensions.x - edge - right,
							top - edge
						)
					),

					# Нижний левый провал.
					Rect2(
						Vector2(edge, bottom),
						Vector2(
							left - edge,
							dimensions.y - edge - bottom
						)
					),

					# Нижний правый провал.
					Rect2(
						Vector2(right, bottom),
						Vector2(
							dimensions.x - edge - right,
							dimensions.y - edge - bottom
						)
					)
				]

				for pool in pools:
					_add_obstacle(
						pool.get_center(),
						pool.size,
						true
					)

	_build_graph()
	queue_redraw()

func _add_obstacle(
	center: Vector2,
	dimensions: Vector2,
	water: bool = false
) -> void:
	var rect := Rect2(
		center - dimensions / 2.0,
		dimensions
	)
	obstacles.append(rect)

	var body := StaticBody2D.new()
	body.position = center

	if water:
		water_zones.append(rect)
		body.add_to_group("water_barriers")

	var shape := RectangleShape2D.new()
	shape.size = dimensions

	var collision := CollisionShape2D.new()
	collision.shape = shape

	body.add_child(collision)
	add_child(body)



func _inside_obstacle(point: Vector2, margin: float) -> bool:
	for rect in obstacles:
		if rect.grow(margin).has_point(point):
			return true

	return false


func is_spawn_safe(point: Vector2) -> bool:
	return (
		bounds.has_point(point)
		and not _inside_obstacle(point, 56.0)
	)


func segment_clear(
	from: Vector2,
	to: Vector2,
	margin: float = 8.0,
	for_shot: bool = false
) -> bool:
	for rect in obstacles:
		if for_shot and water_zones.has(rect):
			continue

		var box := rect.grow(margin)

		if box.has_point(from) or box.has_point(to):
			return false

		var corners := [
			box.position,
			Vector2(box.end.x, box.position.y),
			box.end,
			Vector2(box.position.x, box.end.y)
		]

		for index in range(4):
			if Geometry2D.segment_intersects_segment(
				from,
				to,
				corners[index],
				corners[(index + 1) % 4]
			) != null:
				return false

	return true


func _safe_point(point: Vector2, clearance: float = CLEARANCE) -> Vector2:
	var result := point.clamp(
		bounds.position,
		bounds.end - Vector2.ONE
	)

	if not _inside_obstacle(result, clearance):
		return result

	var best: float = INF
	var original: Vector2 = result

	for rect in obstacles:
		var box := rect.grow(clearance + 4.0)

		var candidates := [
			Vector2(box.position.x, original.y),
			Vector2(box.end.x, original.y),
			Vector2(original.x, box.position.y),
			Vector2(original.x, box.end.y),
			box.position,
			Vector2(box.end.x, box.position.y),
			box.end,
			Vector2(box.position.x, box.end.y)
		]

		for candidate in candidates:
			if (
				bounds.has_point(candidate)
				and not _inside_obstacle(candidate, clearance)
			):
				var distance: float = (
					point.distance_squared_to(candidate)
				)

				if distance < best:
					best = distance
					result = candidate

	return result


func _build_graph() -> void:
	navigation.clear()
	navigation_by_clearance.clear()
	var next_id: int = 2

	for rect in obstacles:
		var box := rect.grow(CLEARANCE + 4.0)

		for point in [
			box.position,
			Vector2(box.end.x, box.position.y),
			box.end,
			Vector2(box.position.x, box.end.y)
		]:
			if (
				bounds.has_point(point)
				and not _inside_obstacle(point, CLEARANCE)
			):
				navigation.add_point(next_id, point)
				next_id += 1

	for first in navigation.get_point_ids():
		for second in navigation.get_point_ids():
			if second > first and segment_clear(
				navigation.get_point_position(first),
				navigation.get_point_position(second),
				CLEARANCE
			):
				navigation.connect_points(first, second)



func _graph_for_clearance(clearance: float) -> AStar2D:
	# The conservative graph remains unchanged for reward reachability.
	# Smaller actors get their own graph, so walkable narrow passages
	# are not removed by the 48px clearance intended for the player.
	if is_equal_approx(clearance, CLEARANCE):
		return navigation
	var key: float = snappedf(clearance, 0.1)
	if navigation_by_clearance.has(key):
		return navigation_by_clearance[key]
	var graph := AStar2D.new()
	var next_id: int = 2
	for rect in obstacles:
		var box := rect.grow(clearance + 4.0)
		for point in [
			box.position,
			Vector2(box.end.x, box.position.y),
			box.end,
			Vector2(box.position.x, box.end.y)
		]:
			if bounds.has_point(point) and not _inside_obstacle(point, clearance):
				graph.add_point(next_id, point)
				next_id += 1
	for first in graph.get_point_ids():
		for second in graph.get_point_ids():
			if second > first and segment_clear(
				graph.get_point_position(first),
				graph.get_point_position(second),
				clearance
			):
				graph.connect_points(first, second)
	navigation_by_clearance[key] = graph
	return graph


func _route(from: Vector2, to: Vector2, clearance: float = CLEARANCE) -> PackedVector2Array:
	var graph: AStar2D = _graph_for_clearance(clearance)
	for id in [0, 1]:
		if graph.has_point(id):
			graph.remove_point(id)

	graph.add_point(0, from)
	graph.add_point(1, to)

	for id in graph.get_point_ids():
		if id < 2:
			continue

		var point := graph.get_point_position(id)

		if segment_clear(from, point, clearance):
			graph.connect_points(0, id)

		if segment_clear(to, point, clearance):
			graph.connect_points(1, id)

	if segment_clear(from, to, clearance):
		graph.connect_points(0, 1)

	return graph.get_point_path(0, 1)


func get_move_direction(actor: Node2D, target: Vector2) -> Vector2:
	var clearance: float = CLEARANCE
	if actor.has_method("navigation_clearance"):
		clearance = clampf(float(actor.call("navigation_clearance")), 12.0, CLEARANCE)
	var start := _safe_point(actor.global_position, clearance)
	var goal := _safe_point(target, clearance)

	if actor.global_position.distance_to(start) > 2.0:
		return actor.global_position.direction_to(start)

	if actor.global_position.distance_to(goal) < 6.0:
		return Vector2.ZERO

	if segment_clear(actor.global_position, goal, clearance):
		return actor.global_position.direction_to(goal)

	var id: int = actor.get_instance_id()
	var now: int = Time.get_ticks_msec()
	var data: Dictionary = routes.get(id, {})

	if (
		data.is_empty()
		or now - int(data["time"]) > 350
		or goal.distance_to(data["goal"]) > 48.0
	):
		data = {
			"time": now,
			"goal": goal,
			"path": _route(start, goal, clearance),
			"next": 1
		}
		routes[id] = data

	var path: PackedVector2Array = data["path"]
	var index: int = data["next"]

	while (
		index < path.size()
		and actor.global_position.distance_to(path[index]) < 10.0
	):
		# Do not cut across the corner before the next segment is clear.
		if index + 1 < path.size() and not segment_clear(
			actor.global_position, path[index + 1], clearance
		):
			break
		index += 1

	data["next"] = index

	if index >= path.size():
		return Vector2.ZERO

	return actor.global_position.direction_to(path[index])


func _draw() -> void:
	for pool in water_zones:
		_draw_water(pool)

	for rect in obstacles:
		if water_zones.has(rect):
			continue
		# All stone obstacles use the same wall texture; water remains untouched.
		var tile_size: Vector2 = COLUMN_TEXTURE.get_size()
		for y in range(0, int(rect.size.y), int(tile_size.y)):
			for x in range(0, int(rect.size.x), int(tile_size.x)):
				var part := Vector2(
					minf(tile_size.x, rect.size.x - x),
					minf(tile_size.y, rect.size.y - y)
				)
				draw_texture_rect_region(
					COLUMN_TEXTURE,
					Rect2(rect.position + Vector2(x, y), part),
					Rect2(Vector2.ZERO, part)
				)

func _draw_water(rect: Rect2) -> void:
	# Тёмная глубина провала.
	draw_rect(rect, Color("20212b"))
	draw_rect(rect.grow(-8), Color("24464b"))

	# Поверхность воды.
	var surface := rect.grow(-14)
	draw_rect(surface, Color("285e68"))

	# Небольшие пиксельные блики.
	for row in range(0, int(surface.size.y) - 4, 24):
		var shift: int = 8 if row % 48 == 0 else 20

		for x in range(shift, int(surface.size.x) - 16, 32):
			draw_rect(
				Rect2(
					surface.position + Vector2(x, row + 4),
					Vector2(12, 3)
				),
				Color("438a8d")
			)

	# Горизонтальные перекладины забора.
	for y in [rect.position.y + 5, rect.end.y - 8]:
		draw_rect(
			Rect2(
				Vector2(rect.position.x + 4, y),
				Vector2(rect.size.x - 8, 3)
			),
			Color("7d8974")
		)

	# Вертикальные перекладины.
	for x in [rect.position.x + 5, rect.end.x - 8]:
		draw_rect(
			Rect2(
				Vector2(x, rect.position.y + 4),
				Vector2(3, rect.size.y - 8)
			),
			Color("7d8974")
		)

	# Столбики сверху и снизу.
	for x in range(4, int(rect.size.x) - 4, 24):
		for y in [4.0, rect.size.y - 10.0]:
			_draw_fence_post(
				rect.position + Vector2(x, y)
			)

	# Столбики по бокам.
	for y in range(4, int(rect.size.y) - 4, 24):
		for x in [4.0, rect.size.x - 10.0]:
			_draw_fence_post(
				rect.position + Vector2(x, y)
			)


func _draw_fence_post(point: Vector2) -> void:
	draw_rect(
		Rect2(point, Vector2(6, 6)),
		Color("20212b")
	)
	draw_rect(
		Rect2(point + Vector2(1, 1), Vector2(4, 4)),
		Color("71816e")
	)
	draw_rect(
		Rect2(point + Vector2(1, 1), Vector2(4, 2)),
		Color("a0ad91")
	)


func can_reach(from: Vector2, to: Vector2) -> bool:
	if not bounds.has_point(from) or not bounds.has_point(to):
		return false

	if _inside_obstacle(from, CLEARANCE):
		return false
	if _inside_obstacle(to, CLEARANCE):
		return false

	if segment_clear(from, to, CLEARANCE):
		return true

	return not _route(from, to).is_empty()


func make_reward_fallback() -> void:
	# Только при генерации, до появления врагов и начала боя.
	for child in get_children():
		if child is StaticBody2D:
			remove_child(child)
			child.queue_free()

	obstacles.clear()
	water_zones.clear()
	routes.clear()
	layout_name = "Открытая — безопасный вариант"
	_build_graph()
	queue_redraw()
