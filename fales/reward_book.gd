extends Area2D

signal interaction_requested

const BOOK_UI = preload("res://skill_book.gd")
const PEDESTAL = preload("res://reward_pedestal.gd")
var icon: Control

func _ready() -> void:
	collision_layer = 0
	monitoring = true
	monitorable = false
	z_index = 2

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 44.0
	collision.shape = shape
	add_child(collision)

	var pedestal = PEDESTAL.new()
	pedestal.name = "RewardPedestal"
	add_child(pedestal)

	icon = BOOK_UI.BookIcon.new()
	icon.size = Vector2(32, 36)
	icon.position = Vector2(-16, -40)
	icon.scale = Vector2.ONE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.hide()
	add_child(icon)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var room: Node = get_parent()
	if room.get("room_cleared") != true or room.get("transitioning") == true:
		return
	if float(body.get("health")) <= 0.0:
		return

	interaction_requested.emit()
	
func reveal_book() -> void:
	if is_instance_valid(icon):
		icon.show()

func consume() -> void:
	if is_instance_valid(icon):
		icon.hide()

	set_deferred("monitoring", false)
