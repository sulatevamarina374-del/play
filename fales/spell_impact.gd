extends Node2D

var mage: Node2D
var target: Node2D
var spell_id: String = ""
var damage: float = 0.0
var delay: float = 0.0
var radius: float = 0.0
var age: float = 0.0
var fired: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 8
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func active() -> bool:
	if not is_instance_valid(mage) or mage.is_queued_for_deletion():
		return false

	if float(mage.get("health")) <= 0.0:
		return false

	for spell in GameState.selected_spells:
		if str(spell.get("id", "")) == spell_id:
			return true

	return false


func alive(enemy: Variant) -> bool:
	# Сначала проверяем ссылку, без требования типа Node2D.
	if not is_instance_valid(enemy):
		return false

	if not (enemy is Node2D):
		return false

	if enemy.is_queued_for_deletion():
		return false

	return float(enemy.get("health")) > 0.0


func clear_line(from: Vector2, to: Vector2) -> bool:
	var room: Node = get_tree().current_scene

	return (
		is_instance_valid(room)
		and room.has_method("has_clear_shot")
		and bool(room.call("has_clear_shot", from, to))
	)


func _physics_process(delta: float) -> void:
	if not active():
		queue_free()
		return

	if not fired and spell_id == "dark_seal" and alive(target):
		global_position = target.global_position

	age += delta

	if not fired and age >= delay:
		strike()

	if fired and age >= delay + 0.28:
		queue_free()

	queue_redraw()


func strike() -> void:
	if fired:
		return

	fired = true

	if not active():
		return

	if spell_id == "dark_lightning":
		if alive(target):
			global_position = target.global_position

			if clear_line(mage.global_position, global_position):
				target.call("take_damage", damage)

		return

	# Камень между магом и центром эффекта блокирует удар.
	if not clear_line(mage.global_position, global_position):
		return

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D

		if not alive(enemy):
			continue

		if global_position.distance_to(enemy.global_position) > radius:
			continue

		# Площадь тоже не проходит через камень.
		if clear_line(global_position, enemy.global_position):
			enemy.call("take_damage", damage)


func _draw() -> void:
	var color: Color = Color("b8a0d1")

	if spell_id == "water_geyser":
		color = Color("5eadd1")

	if not fired:
		color.a = 0.65

		var box := Rect2(
			Vector2.ONE * -radius,
			Vector2.ONE * radius * 2.0
		)

		draw_rect(box, color, false, 2.0)
		draw_line(Vector2(-7, 0), Vector2(7, 0), color, 2.0)
		draw_line(Vector2(0, -7), Vector2(0, 7), color, 2.0)
		return

	color.a = clampf(
		1.0 - (age - delay) / 0.28,
		0.0,
		1.0
	)

	if spell_id == "dark_lightning":
		var points := PackedVector2Array([
			Vector2(0, -100),
			Vector2(-9, -65),
			Vector2(8, -45),
			Vector2(-6, -22),
			Vector2.ZERO
		])

		draw_polyline(points, color, 4.0, false)
		draw_rect(Rect2(-9, -4, 18, 8), color)

	elif spell_id == "water_geyser":
		for index in range(3):
			var height: float = 30.0 if index != 1 else 48.0

			draw_rect(
				Rect2(-18 + index * 14, -height, 8, height),
				color
			)

		draw_rect(
			Rect2(-radius, -4, radius * 2.0, 8),
			color
		)

	else:
		draw_rect(
			Rect2(-radius, -radius, radius * 2.0, radius * 2.0),
			color,
			false,
			4.0
		)

		draw_line(Vector2(-20, -20), Vector2(20, 20), color, 4.0)
		draw_line(Vector2(-20, 20), Vector2(20, -20), color, 4.0)
