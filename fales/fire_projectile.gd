extends "res://projectile.gd"

static var neutral_texture: Texture2D

var spent: bool = false
var element_color: Color = Color("ff9850")


func _ready() -> void:
	super._ready()
	sphere_trail.configure(element_color, 7.0)

	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite == null:
		return

	if neutral_texture == null:
		var image: Image = sprite.texture.get_image()
		if image == null:
			push_error("Не удалось прочитать текстуру стихийной сферы.")
			return

		if image.is_compressed() and image.decompress() != OK:
			push_error("Не удалось распаковать текстуру стихийной сферы.")
			return

		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var pixel: Color = image.get_pixel(x, y)
				var light: float = maxf(pixel.r, maxf(pixel.g, pixel.b))
				image.set_pixel(x, y, Color(light, light, light, pixel.a))

		neutral_texture = ImageTexture.create_from_image(image)

	sprite.texture = neutral_texture
	sprite.modulate = element_color


func _on_body_entered(body: Node2D) -> void:
	if spent or body.is_in_group("water_barriers"):
		return

	if body.is_in_group("enemies") or body is StaticBody2D:
		spent = true

	super._on_body_entered(body)
