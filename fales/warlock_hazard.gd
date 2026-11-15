extends Node2D

var delay: float = 0.8
var radius: float = 64.0
var damage: float = 1.0
var timer: float = 0.0
var has_exploded: bool = false
var player: Node2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	queue_redraw()

func _process(delta: float) -> void:
	timer += delta
	if timer >= delay and not has_exploded:
		_explode()
	elif timer >= delay + 0.2: # Живем чуть-чуть после взрыва
		queue_free()
	
	queue_redraw() # Перерисовываем для анимации

func _explode() -> void:
	has_exploded = true
	if is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= radius:
			if player.has_method("take_damage"):
				player.take_damage(damage)
			if player.has_method("apply_slow"):
				player.apply_slow(0.25, 1.5) # Замедляем при взрыве

func _draw() -> void:
	if not has_exploded:
		# Растущий красный телеграф
		var progress = timer / delay
		draw_circle(Vector2.ZERO, radius * progress, Color(0.8, 0.0, 0.0, 0.3))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1.0, 0.0, 0.0, 0.8), 2.0)
	else:
		# Взрыв
		draw_circle(Vector2.ZERO, radius, Color(0.6, 0.1, 0.8, 0.6))
