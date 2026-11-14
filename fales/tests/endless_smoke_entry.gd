extends Node
func _ready() -> void:
	var runner := Node.new()
	runner.set_script(preload("res://tests/endless_smoke_runner.gd"))
	get_tree().root.add_child.call_deferred(runner)
