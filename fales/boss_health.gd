extends ProgressBar

var boss: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_percentage = false
	size = Vector2(300, 24)

	find_boss.call_deferred()


func find_boss() -> void:
	boss = get_tree().get_first_node_in_group("boss") as Node2D

	if is_instance_valid(boss):
		max_value = boss.health
		value = boss.health


func _process(_delta: float) -> void:
	var screen_size := get_viewport().get_visible_rect().size
	position = Vector2((screen_size.x - size.x) / 2.0, 95)

	if not is_instance_valid(boss):
		hide()
		return

	if boss.is_queued_for_deletion():
		hide()
		return

	show()
	value = boss.health
