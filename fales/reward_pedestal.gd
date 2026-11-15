extends StaticBody2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40.0, 12.0)

	collision.shape = shape
	collision.position = Vector2(0.0, 6.0)
	add_child(collision)


func _draw() -> void:
	# Тень, основание и передняя грань.
	draw_rect(Rect2(-22, 9, 44, 5), Color("20212b"))
	draw_rect(Rect2(-20, 0, 40, 12), Color("20212b"))
	draw_rect(Rect2(-18, 2, 36, 8), Color("40594f"))
	draw_rect(Rect2(-18, 2, 36, 2), Color("71836d"))

	# Верхняя каменная площадка.
	draw_rect(Rect2(-20, -6, 40, 8), Color("20212b"))
	draw_rect(Rect2(-18, -4, 36, 4), Color("a1af95"))
	draw_rect(Rect2(-18, 0, 36, 2), Color("71836d"))
