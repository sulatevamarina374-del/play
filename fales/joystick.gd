extends Control

@export_range(0.1, 0.6, 0.05) var zone_height_ratio: float = 0.35
@export_range(16.0, 100.0, 1.0) var radius: float = 60.0
@export_range(0.0, 0.5, 0.01) var dead_zone: float = 0.15

var direction: Vector2 = Vector2.ZERO
var stick_center: Vector2 = Vector2.ZERO
var knob_position: Vector2 = Vector2.ZERO
var touch_id: int = -1
var mouse_dragging: bool = false

@onready var upgrade_panel: Control = get_node_or_null("../UpgradePanel") as Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reset_stick()


func _process(_delta: float) -> void:
	if is_active() and is_controls_blocked():
		reset_stick()


func _draw() -> void:
	if not is_active():
		return

	draw_circle(stick_center, radius, Color(0.18, 0.24, 0.21, 0.75))
	draw_arc(stick_center, radius, 0.0, TAU, 48, Color(0.59, 0.63, 0.54, 0.9), 3.0)
	draw_circle(stick_center + knob_position, 24.0, Color(0.14, 0.81, 0.83, 0.95))
	draw_circle(stick_center + knob_position, 10.0, Color(0.65, 0.94, 0.88, 0.95))


# Continue an existing gesture even if the finger leaves the bottom zone.
func _input(event: InputEvent) -> void:
	if not is_active():
		return

	if is_controls_blocked():
		reset_stick()
		return

	if event is InputEventScreenTouch:
		if event.index == touch_id and not event.pressed:
			reset_stick()
			get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if event.index == touch_id:
			update_stick(event.position)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.device == -1:
			return
		if mouse_dragging and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			reset_stick()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if event.device != -1 and mouse_dragging:
			update_stick(event.position)
			get_viewport().set_input_as_handled()


# GUI buttons get the event first; they cannot accidentally start a joystick.
func _unhandled_input(event: InputEvent) -> void:
	if is_active() or is_controls_blocked():
		return

	if event is InputEventScreenTouch:
		if event.pressed and is_inside_zone(event.position):
			touch_id = event.index
			start_stick(event.position)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		# Ignore mouse events synthesized from touch; the touch is handled above.
		if event.device == -1:
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_inside_zone(event.position):
				mouse_dragging = true
				start_stick(event.position)
				get_viewport().set_input_as_handled()


func is_active() -> bool:
	return touch_id >= 0 or mouse_dragging


func is_controls_blocked() -> bool:
	return is_instance_valid(upgrade_panel) and upgrade_panel.is_visible_in_tree()


func is_inside_zone(screen_position: Vector2) -> bool:
	var rect: Rect2 = get_viewport().get_visible_rect()
	var zone_top: float = rect.position.y + rect.size.y * (1.0 - zone_height_ratio)
	return rect.has_point(screen_position) and screen_position.y >= zone_top


func to_local_position(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position


func start_stick(screen_position: Vector2) -> void:
	stick_center = to_local_position(screen_position)
	knob_position = Vector2.ZERO
	direction = Vector2.ZERO
	queue_redraw()


func update_stick(screen_position: Vector2) -> void:
	var offset: Vector2 = to_local_position(screen_position) - stick_center
	knob_position = offset.limit_length(radius)
	direction = knob_position / radius
	if direction.length() < dead_zone:
		direction = Vector2.ZERO
	queue_redraw()


func reset_stick() -> void:
	touch_id = -1
	mouse_dragging = false
	direction = Vector2.ZERO
	knob_position = Vector2.ZERO
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_stick()
