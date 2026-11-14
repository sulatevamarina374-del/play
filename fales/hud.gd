extends CanvasLayer

const HEALTH_SEGMENTS = preload("res://segmented_health_bar.gd")
const RUN_PAUSE = preload("res://run_pause.gd")
@onready var health_label: Label = $HealthLabel
const SHIELD_INDICATOR = preload("res://shield_indicator.gd")

var player: Node2D
var health_frame: Panel
var health_bar: ProgressBar
var health_fill: StyleBoxFlat
var shield_indicator: Control


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	setup_player_health()
	shield_indicator = SHIELD_INDICATOR.new()
	shield_indicator.source = player
	add_child(shield_indicator)

	update_layout()
	if not has_node("RunPause"):
		var run_pause = RUN_PAUSE.new()
		run_pause.name = "RunPause"
		add_child(run_pause)


func setup_player_health() -> void:
	var health_theme: Theme = preload("res://assets/ui/health_theme.tres")

	health_frame = Panel.new()
	health_frame.name = "PlayerHealthFrame"
	health_frame.size = Vector2(44, 168)
	health_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	health_frame.clip_contents = true
	health_frame.add_theme_stylebox_override(
		"panel",
		health_theme.get_stylebox("normal", "Label").duplicate()
	)
	add_child(health_frame)

	health_bar = ProgressBar.new()
	health_bar.name = "PlayerHealthBar"
	health_bar.position = Vector2(12, 12)
	health_bar.size = Vector2(20, 144)
	health_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := StyleBoxFlat.new()
	background.bg_color = Color("28352f")
	background.anti_aliasing = false
	health_bar.add_theme_stylebox_override("background", background)

	health_fill = StyleBoxFlat.new()
	health_fill.bg_color = Color("82a389")
	health_fill.anti_aliasing = false
	health_bar.add_theme_stylebox_override("fill", health_fill)
	health_frame.add_child(health_bar)

	health_label.theme = null
	health_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	health_label.custom_minimum_size = Vector2(64, 26)
	health_label.size = Vector2(64, 26)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label.add_theme_font_size_override("font_size", 20)
	health_label.add_theme_color_override("font_color", Color("eef0dc"))
	health_label.add_theme_color_override("font_outline_color", Color("20212b"))
	health_label.add_theme_constant_override("outline_size", 2)
	var health_segments = HEALTH_SEGMENTS.new()
	health_segments.name = "HealthSegments"
	health_segments.vertical = true
	health_segments.segment_count = 5
	health_bar.add_child(health_segments)

	health_label.text = ""
	health_label.hide()
	health_label.add_theme_font_size_override("font_size", 22)
	health_label.add_theme_color_override("font_color", Color("f2b9a6"))


func _process(_delta: float) -> void:
	update_layout()

	if not is_instance_valid(player):
		return

	var maximum_health: float = float(player.get("max_health"))
	var current_health: float = float(player.get("health"))

	health_bar.max_value = maxf(maximum_health, 0.001)
	health_bar.value = current_health

	var low_health: bool = (
		current_health > 0.0
		and current_health <= maximum_health * 0.25
	)

	health_label.text = "!" if low_health else ""
	health_label.visible = low_health
	health_fill.bg_color = (
		Color("d88170") if low_health else Color("82a389")
	)


func update_layout() -> void:
	var screen_size := get_viewport().get_visible_rect().size

	health_frame.position = Vector2(20, screen_size.y - 218)
	shield_indicator.position = health_frame.position + Vector2(-6, -42)
	health_label.position = Vector2(
		10,
		health_frame.position.y + 172
	)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	if event is InputEventKey:
		if not event.pressed or event.echo:
			return

		# Физическая клавиша G работает и при русской раскладке.
		if event.physical_keycode != KEY_G:
			return

		if not is_instance_valid(player):
			return

		if player.is_queued_for_deletion():
			return

		if float(player.get("health")) <= 0.0:
			return

		GameState.debug_invincible = not GameState.debug_invincible

		if GameState.debug_invincible:
			print("Бессмертие: ВКЛ")
		else:
			print("Бессмертие: ВЫКЛ")

		get_viewport().set_input_as_handled()
