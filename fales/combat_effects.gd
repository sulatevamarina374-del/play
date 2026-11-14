extends RefCounted

var slows: Dictionary = {}
var freeze_left: float = 0.0
var burn_left: float = 0.0
var burn_per_second: float = 0.0
var push_left: float = 0.0
var push_duration: float = 0.0
var push_velocity: Vector2 = Vector2.ZERO


func valid_positive(value: float) -> bool:
	return is_finite(value) and value > 0.0


func add_slow(source: String, duration: float, factor: float) -> void:
	if source.is_empty() or not valid_positive(duration):
		return
	if not is_finite(factor) or factor <= 0.0 or factor >= 1.0:
		return

	slows[source] = {"left": duration, "factor": factor}


func add_freeze(duration: float) -> void:
	if valid_positive(duration):
		freeze_left = duration


func add_burn(duration: float, damage_per_second: float) -> void:
	if valid_positive(duration) and valid_positive(damage_per_second):
		burn_left = duration
		burn_per_second = damage_per_second


func add_push(direction: Vector2, force: float, duration: float) -> void:
	if not direction.is_finite() or direction.is_zero_approx():
		return
	if not valid_positive(force) or not valid_positive(duration):
		return

	push_velocity = direction.normalized() * force
	push_duration = duration
	push_left = duration


func tick(delta: float) -> float:
	if not valid_positive(delta):
		return 0.0

	var burn_damage: float = minf(delta, burn_left) * burn_per_second
	burn_left = maxf(burn_left - delta, 0.0)

	if burn_left == 0.0:
		burn_per_second = 0.0

	freeze_left = maxf(freeze_left - delta, 0.0)
	push_left = maxf(push_left - delta, 0.0)

	for source in slows.keys():
		var data: Dictionary = slows[source]
		data["left"] = maxf(float(data["left"]) - delta, 0.0)

		if float(data["left"]) == 0.0:
			slows.erase(source)

	return burn_damage


func movement(base_velocity: Vector2) -> Vector2:
	if freeze_left > 0.0:
		return Vector2.ZERO

	var factor: float = 1.0

	for data in slows.values():
		factor = minf(factor, float(data["factor"]))

	var push: Vector2 = Vector2.ZERO

	if push_left > 0.0 and push_duration > 0.0:
		push = push_velocity * (push_left / push_duration)

	return base_velocity * factor + push


func clear() -> void:
	slows.clear()
	freeze_left = 0.0
	burn_left = 0.0
	burn_per_second = 0.0
	push_left = 0.0
	push_duration = 0.0
	push_velocity = Vector2.ZERO
