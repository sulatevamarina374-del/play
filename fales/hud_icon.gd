extends Control

var icon_kind: String = "door"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	match icon_kind:
		"coin":
			_draw_coin()
		_:
			_draw_door()


func _draw_door() -> void:
	draw_rect(Rect2(2, 1, 16, 22), Color("20212b"))
	draw_rect(Rect2(4, 2, 12, 20), Color("71836d"))
	draw_rect(Rect2(6, 4, 8, 16), Color("20212b"))
	draw_rect(Rect2(7, 5, 6, 14), Color("40594f"))
	draw_rect(Rect2(8, 7, 4, 12), Color("3c554d"))
	draw_rect(Rect2(8, 7, 4, 2), Color("a1af95"))
	draw_rect(Rect2(10, 13, 1, 2), Color("d2b56b"))


func _draw_coin() -> void:
	var outline := Color("20212b")
	var gold := Color("d2b56b")
	var light := Color("f0d887")
	var shade := Color("a77b37")

	draw_rect(Rect2(7, 1, 6, 2), outline)
	draw_rect(Rect2(4, 3, 12, 2), outline)
	draw_rect(Rect2(2, 5, 16, 10), outline)
	draw_rect(Rect2(4, 15, 12, 2), outline)
	draw_rect(Rect2(7, 17, 6, 2), outline)

	draw_rect(Rect2(7, 3, 6, 2), gold)
	draw_rect(Rect2(4, 5, 12, 10), gold)
	draw_rect(Rect2(6, 5, 8, 10), light)
	draw_rect(Rect2(8, 7, 4, 6), shade)
	draw_rect(Rect2(9, 7, 2, 6), light)
