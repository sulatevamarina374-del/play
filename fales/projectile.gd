extends Area2D

@export var speed: float = 450.0
@export var damage: float = 1.0
const TRAIL_SCRIPT = preload("res://sphere_trail.gd")

var sphere_trail

var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 3.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	sphere_trail = TRAIL_SCRIPT.new()
	sphere_trail.configure(Color("a5dce5"), 3.0)
	add_child(sphere_trail)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	sphere_trail.add_sample(global_position)

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("water_barriers"):
		return
	if body.is_in_group("enemies"):
		body.take_damage(damage)
		queue_free()
	elif body is StaticBody2D:
		queue_free()
