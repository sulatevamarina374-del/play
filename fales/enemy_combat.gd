extends CharacterBody2D

const EFFECTS = preload("res://combat_effects.gd")
var combat_effects = EFFECTS.new()
const CONTACT_ATTACK_REST: float = 1.0
const RANGED_ATTACK_REST: float = 0.45

var attack_rest_left: float = 0.0


func _enter_tree() -> void:
	# Вид сверху: персонажи не являются движущимися платформами.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	platform_floor_layers = 0
	platform_wall_layers = 0


func navigation_clearance() -> float:
	# Колонна должна обходиться с запасом именно для текущей формы.
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null and collider.shape is CircleShape2D:
		var circle := collider.shape as CircleShape2D
		var actual_scale: Vector2 = collider.global_scale.abs()
		return clampf(circle.radius * maxf(actual_scale.x, actual_scale.y) + 1.0, 12.0, 48.0)
	return 48.0


func is_alive() -> bool:
	return not is_queued_for_deletion() and float(get("health")) > 0.0


func take_damage(amount: float) -> void:
	if not is_alive() or not is_finite(amount) or amount <= 0.0:
		return

	var remaining: float = maxf(float(get("health")) - amount, 0.0)
	set("health", remaining)

	if remaining == 0.0:
		combat_effects.clear()
		queue_free()


func begin_combat_frame(delta: float) -> bool:
	if not is_alive():
		velocity = Vector2.ZERO
		return false

	var burn_damage: float = combat_effects.tick(delta)

	if burn_damage > 0.0:
		take_damage(burn_damage)

	if not is_alive() or combat_effects.freeze_left > 0.0:
		velocity = Vector2.ZERO
		return false

	return true


func apply_slow(source: String, duration: float, factor: float) -> void:
	if is_alive():
		combat_effects.add_slow(source, duration, factor)


func apply_freeze(duration: float, boss_speed_factor: float) -> void:
	if not is_alive():
		return

	if is_in_group("boss"):
		combat_effects.add_slow(
			"freeze_boss",
			duration,
			boss_speed_factor
		)
	else:
		combat_effects.add_freeze(duration)


func apply_burn(duration: float, damage_per_second: float) -> void:
	if is_alive():
		combat_effects.add_burn(duration, damage_per_second)


func apply_knockback(
	direction: Vector2,
	force: float,
	duration: float
) -> void:
	if is_alive():
		combat_effects.add_push(direction, force, duration)

func update_attack_rest(delta: float) -> void:
	if is_finite(delta) and delta > 0.0:
		attack_rest_left = maxf(attack_rest_left - delta, 0.0)


func start_attack_rest(duration: float) -> void:
	attack_rest_left = maxf(attack_rest_left, duration)


func attack_movement(base_velocity: Vector2) -> Vector2:
	if attack_rest_left > 0.0:
		base_velocity = Vector2.ZERO
	return combat_effects.movement(base_velocity)


func try_contact_attack(area: Area2D) -> bool:
	if attack_rest_left > 0.0 or not is_alive():
		return false
	if not is_instance_valid(area):
		return false

	for body in area.get_overlapping_bodies():
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		if not body.is_in_group("player") or not body.has_method("take_damage"):
			continue
		if float(body.get("health")) <= 0.0:
			continue

		start_attack_rest(CONTACT_ATTACK_REST)
		body.call("take_damage", float(get("damage")))
		return true

	return false
