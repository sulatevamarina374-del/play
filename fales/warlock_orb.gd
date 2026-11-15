extends Node2D

var lifetime: float = 5.0
var shoot_timer: float = 0.0
var shoot_interval: float = 1.5
const BULLET_SCENE = preload("res://enemy_projectile.tscn")
var player: Node2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	# Рисуем фиолетовую сферу
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_interval
		_shoot_at_player()

func _shoot_at_player() -> void:
	if not is_instance_valid(player): return
	var bullet = BULLET_SCENE.instantiate()
	bullet.damage = 1.0
	bullet.is_slowing = true # Турель стреляет фиолетовыми
	bullet.direction = global_position.direction_to(player.global_position)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position

func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(0.6, 0.1, 0.8, 0.8))
	draw_arc(Vector2.ZERO, 16.0, 0, TAU, 32, Color(1.0, 0.5, 1.0, 1.0), 2.0)
