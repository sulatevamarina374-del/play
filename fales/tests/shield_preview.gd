extends Control

const INDICATOR = preload("res://shield_indicator.gd")

class Sample:
	extends Node2D

	var health: float = 5.0
	var shield_health: float = 4.0
	var shield_max_health: float = 4.0
	var shield_time_left: float = 3.0


var sample = Sample.new()
var indicator: Control
var caption: Label
var elapsed: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("22302b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	add_child(sample)

	indicator = INDICATOR.new()
	indicator.source = sample
	add_child(indicator)

	caption = Label.new()
	caption.text = "Проверка: полный щит → половина → скрыт.\nЦикл повторяется. Для остановки — F8."
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 20)
	add_child(caption)


func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, 9.0)

	sample.shield_health = (
		4.0 if elapsed < 3.0
		else (2.0 if elapsed < 6.0 else 0.0)
	)

	var screen: Vector2 = get_viewport_rect().size
	indicator.position = screen / 2.0 - Vector2(28, 20)
	caption.position = Vector2(20, 40)
	caption.size = Vector2(maxf(screen.x - 40.0, 1.0), 100)
