extends Control

## Иконки HUD рисуются из PNG-спрайтов в assets/icons/,
## а не прямоугольниками в коде (старый код рисования удалён).

var icon_kind: String = "door"

const ICON_FILES: Dictionary = {
	"coin": "res://assets/icons/hud_coin.png",
	"door": "res://assets/icons/hud_door.png",
}

var _textures: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	var texture: Texture2D = _get_texture(icon_kind)

	if texture == null:
		return

	# Вписываем спрайт в size с сохранением пропорций (по центру).
	var scale: float = minf(
		size.x / texture.get_width(),
		size.y / texture.get_height()
	)
	var drawn_size: Vector2 = texture.get_size() * scale
	var offset: Vector2 = (size - drawn_size) / 2.0
	draw_texture_rect(
		texture,
		Rect2(offset, drawn_size),
		false
	)


func _get_texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		var path: String = str(ICON_FILES.get(kind, ""))

		if path != "" and ResourceLoader.exists(path):
			_textures[kind] = load(path)
		else:
			push_warning("Не найдена иконка HUD: " + path)
			_textures[kind] = null

	return _textures[kind]
