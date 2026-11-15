extends Node2D
class_name FireTrail

# Настройки следа
var lifetime: float = 3.0        # Сколько секунд живет огонь
var damage_amount: float = 1.0   # Урон за тик
var radius: float = 32.0         # Радиус опасной зоны
var tick_interval: float = 0.5   # Как часто наносить урон (в секундах)

var _tick_timer: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	# Ищем игрока, чтобы проверять расстояние
	_player = get_tree().get_first_node_in_group("player")
	queue_redraw() # Заставляем Godot нарисовать круг


func _process(delta: float) -> void:
	lifetime -= delta
	
	# Плавно исчезаем в последние 0.5 секунды
	if lifetime < 0.5:
		modulate.a = maxf(lifetime / 0.5, 0.0)

	if lifetime <= 0.0:
		queue_free()
		return

	if _tick_timer > 0.0:
		_tick_timer -= delta

	# Проверяем, не стоит ли игрок в огне
	if is_instance_valid(_player) and _player.get("health") > 0.0:
		if global_position.distance_to(_player.global_position) <= radius:
			if _tick_timer <= 0.0:
				_tick_timer = tick_interval
				if _player.has_method("take_damage"):
					_player.take_damage(damage_amount)


func _draw() -> void:
	# Рисуем полупрозрачный оранжевый круг
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.3, 0.0, 0.5))
	# Можно добавить обводку для красоты:
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1.0, 0.6, 0.0, 0.8), 2.0)
