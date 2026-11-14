extends Area2D

@export var speed: float = 180.0
@export var damage: float = 1.0

var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 4.0
var hit: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("water_barriers"):
		return
	if hit:
		return

	if body.is_in_group("player"):
		hit = true
		body.take_damage(damage)
		queue_free()

	elif body is StaticBody2D:
		hit = true
		queue_free()
