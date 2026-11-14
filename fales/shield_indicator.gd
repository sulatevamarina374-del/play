extends Control

var source: Node2D
var title: Label
var bar: ProgressBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(56, 40)

	title = Label.new()
	title.text = "Щит"
	title.size = Vector2(56, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("a5dce5"))
	title.add_theme_color_override("font_outline_color", Color("20212b"))
	title.add_theme_constant_override("outline_size", 2)
	add_child(title)

	bar = ProgressBar.new()
	bar.position = Vector2(6, 28)
	bar.size = Vector2(44, 8)
	bar.step = 0.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := StyleBoxFlat.new()
	background.bg_color = Color("20212b")
	background.anti_aliasing = false
	bar.add_theme_stylebox_override("background", background)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("a5dce5")
	fill.anti_aliasing = false
	bar.add_theme_stylebox_override("fill", fill)

	add_child(bar)
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	if not is_instance_valid(source):
		hide()
		return

	visible = (
		float(source.get("health")) > 0.0
		and float(source.get("shield_health")) > 0.0
		and float(source.get("shield_time_left")) > 0.0
	)

	if not visible:
		return

	bar.max_value = maxf(
		float(source.get("shield_max_health")),
		0.001
	)
	bar.value = float(source.get("shield_health"))
