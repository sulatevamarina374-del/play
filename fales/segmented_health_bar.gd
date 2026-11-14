extends Control

var vertical: bool = false
var segment_count: int = 5
var gap: float = 3.0
var fill_color: Color = Color("82a389")
var low_color: Color = Color("d88170")
var warn_low_health: bool = true
var low_threshold: float = 0.25
var smoothing_speed: float = 16.0

var displayed_ratio: float = 0.0
var actual_ratio: float = 0.0
var initialized: bool = false

@onready var source: ProgressBar = get_parent() as ProgressBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if not is_instance_valid(source):
		set_process(false)
		return

	source.step = 0.0
	source.show_percentage = false


func _process(delta: float) -> void:
	if not is_instance_valid(source):
		return

	var span: float = source.max_value - source.min_value
	actual_ratio = 0.0

	if span > 0.0:
		actual_ratio = clampf(
			(source.value - source.min_value) / span,
			0.0,
			1.0
		)

	if not initialized:
		displayed_ratio = actual_ratio
		initialized = true
	else:
		displayed_ratio = lerpf(
			displayed_ratio,
			actual_ratio,
			1.0 - exp(-smoothing_speed * delta)
		)

	if absf(displayed_ratio - actual_ratio) < 0.001:
		displayed_ratio = actual_ratio

	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	# Закрываем обычную заливку ProgressBar.
	draw_rect(Rect2(Vector2.ZERO, size), Color("20212b"))

	if not initialized:
		return

	var count: int = clampi(segment_count, 1, 32)
	var bar_color: Color = fill_color

	if warn_low_health and actual_ratio <= low_threshold:
		bar_color = low_color

	var axis_length: float = size.y if vertical else size.x
	var safe_gap: float = minf(gap, axis_length / float(count * 2))
	var cell_length: float = (
		axis_length - safe_gap * float(count - 1)
	) / float(count)

	for index in range(count):
		var fraction: float = clampf(
			displayed_ratio * float(count) - float(index),
			0.0,
			1.0
		)
		var cell: Rect2

		if vertical:
			cell = Rect2(
				Vector2(
					0,
					size.y - cell_length * float(index + 1) - safe_gap * index
				),
				Vector2(size.x, cell_length)
			)
		else:
			cell = Rect2(
				Vector2(float(index) * (cell_length + safe_gap), 0),
				Vector2(cell_length, size.y)
			)

		draw_rect(cell, Color("28352f"))

		if fraction <= 0.0:
			continue

		var filled: Rect2 = cell

		if vertical:
			filled.size.y = cell.size.y * fraction
			filled.position.y = cell.end.y - filled.size.y
		else:
			filled.size.x = cell.size.x * fraction

		draw_rect(filled, bar_color)
