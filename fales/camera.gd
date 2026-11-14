extends Camera2D


func _ready() -> void:
	get_viewport().size_changed.connect(update_zoom)
	update_zoom()


func update_zoom() -> void:
	var screen_size := get_viewport().get_visible_rect().size

	var zoom_value := maxf(
		screen_size.x / 480.0,
		screen_size.y / 640.0
	)

	zoom = Vector2(zoom_value, zoom_value)
