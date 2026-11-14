extends Area2D

signal coins_received(amount: int)
signal save_failed

const PEDESTAL = preload("res://reward_pedestal.gd")

var coin_amount: int = 0
var revealed: bool = false
var used: bool = false
var opening: bool = false


func _ready() -> void:
	collision_layer = 0
	monitoring = true
	monitorable = false
	z_index = 2

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 36.0
	collision.shape = shape
	add_child(collision)

	add_child(PEDESTAL.new())
	body_entered.connect(_on_body_entered)


func reveal_chest() -> void:
	revealed = true
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not revealed or used or opening:
		return

	if not body.is_in_group("player"):
		return

	var room: Node = get_parent()

	if room.get("room_cleared") != true:
		return
	if room.get("transitioning") == true:
		return
	if float(body.get("health")) <= 0.0:
		return

	if coin_amount <= 0:
		push_error("У сундука не задана награда.")
		return

	opening = true

	if not Profile.try_add_coins(coin_amount):
		opening = false
		save_failed.emit()
		return

	# Считаем только уже успешно сохранённую награду.
	GameState.run_coins += coin_amount
	used = true
	opening = false
	set_deferred("monitoring", false)
	queue_redraw()
	coins_received.emit(coin_amount)


func _draw() -> void:
	if not revealed:
		return

	# Корпус.
	draw_rect(Rect2(-16, -22, 32, 16), Color("20212b"))
	draw_rect(Rect2(-14, -20, 28, 12), Color("71836d"))
	draw_rect(Rect2(-12, -18, 24, 8), Color("40594f"))
	draw_rect(Rect2(-14, -10, 28, 2), Color("d2b56b"))

	# Крышка.
	var lid_y: float = -38.0 if used else -32.0

	draw_rect(Rect2(-16, lid_y, 32, 12), Color("20212b"))
	draw_rect(Rect2(-14, lid_y + 2, 28, 8), Color("82a389"))
	draw_rect(Rect2(-12, lid_y + 2, 24, 2), Color("a1b49a"))
	draw_rect(Rect2(-10, lid_y + 6, 20, 2), Color("40594f"))

	if used:
		draw_rect(Rect2(-14, -28, 2, 8), Color("20212b"))
		draw_rect(Rect2(12, -28, 2, 8), Color("20212b"))
		draw_rect(Rect2(-14, -20, 28, 4), Color("20212b"))
	else:
		draw_rect(Rect2(-4, -23, 8, 9), Color("20212b"))
		draw_rect(Rect2(-2, -21, 4, 5), Color("d2b56b"))
