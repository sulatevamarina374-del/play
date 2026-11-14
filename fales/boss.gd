extends "res://enemy_shooter.gd"

# ============================================================
# БОСС-СТРЕЛОК.
# 3 фазы. В каждой свой пул атак.
# Неуязвимость 0.8 сек при смене фазы.
# ============================================================

enum AttackType {
	FAN,       # веер
	CIRCLE,    # круг
	AIMED,     # прицельный залп
	SPIRAL,    # вращающаяся спираль
	SUMMON     # призыв + веер
}

const PHASE_TWO_AT: float = 0.70
const PHASE_THREE_AT: float = 0.35

const PHASE_TWO_INTERVAL_FACTOR: float = 0.80
const PHASE_THREE_INTERVAL_FACTOR: float = 0.65
const MIN_ATTACK_INTERVAL: float = 0.9

const PHASE_TRANSITION_INVULN: float = 0.8

const SPIRAL_STEPS: int = 8
const SPIRAL_STEP_DEG: float = 45.0
const SPIRAL_STAGGER: float = 0.1

const AIMED_SHOTS: int = 3
const AIMED_SPREAD_DEG: float = 7.0

# ВАЖНО: Проверь, что путь к обычному врагу верный!
# Если враг называется по-другому, поменяй здесь.
const SUMMON_SCENE = preload("res://enemy.tscn") 

var boss_phase: int = 1
var boss_max_health: float = 0.0
var phase_one_interval: float = 2.4

var invuln_left: float = 0.0
var attack_cycle_index: int = 0

var spiral_left: int = 0
var spiral_offset_deg: float = 0.0
var spiral_step_timer: float = 0.0
var spiral_base_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	boss_max_health = health
	phase_one_interval = attack_interval
	attack_cooldown = attack_interval


func _physics_process(delta: float) -> void:
	# 1. Управляем неуязвимостью при смене фазы
	if invuln_left > 0.0:
		invuln_left = maxf(invuln_left - delta, 0.0)

	# 2. Логика спирали (стреляет с задержкой)
	if spiral_left > 0:
		spiral_step_timer -= delta
		if spiral_step_timer <= 0.0:
			spiral_step_timer = SPIRAL_STAGGER
			spiral_left -= 1
			spiral_offset_deg += SPIRAL_STEP_DEG
			
			# Выпускаем два снаряда друг напротив друга
			_spawn_bullet(spiral_base_dir.rotated(deg_to_rad(spiral_offset_deg)))
			_spawn_bullet(spiral_base_dir.rotated(deg_to_rad(spiral_offset_deg + 180.0)))

	# 3. Вызываем базовую физику (движение, проверка кулдауна и т.д.)
	super._physics_process(delta)


func take_damage(amount: float) -> void:
	# Игнорируем урон во время смены фазы
	if invuln_left > 0.0:
		return

	super.take_damage(amount)

	if not is_alive() or boss_max_health <= 0.0:
		return

	_update_boss_phase()


func _update_boss_phase() -> void:
	var fraction: float = health / boss_max_health
	var next_phase: int = 1

	if fraction <= PHASE_THREE_AT:
		next_phase = 3
	elif fraction <= PHASE_TWO_AT:
		next_phase = 2

	if next_phase <= boss_phase:
		return

	boss_phase = next_phase
	invuln_left = PHASE_TRANSITION_INVULN
	spiral_left = 0
	attack_cycle_index = 0

	var factor: float
	if boss_phase == 2:
		factor = PHASE_TWO_INTERVAL_FACTOR
	else:
		factor = PHASE_THREE_INTERVAL_FACTOR

	attack_interval = maxf(MIN_ATTACK_INTERVAL, phase_one_interval * factor)
	
	# Сразу после неуязвимости босс выстрелит (кулдаун обнуляется)
	attack_cooldown = 0.0


func _next_attack() -> int:
	var pool: Array[int]

	match boss_phase:
		1:
			pool = [AttackType.FAN, AttackType.FAN, AttackType.AIMED]
		2:
			pool = [AttackType.FAN, AttackType.CIRCLE, AttackType.AIMED, AttackType.FAN, AttackType.CIRCLE]
		_:
			pool = [AttackType.SPIRAL, AttackType.CIRCLE, AttackType.AIMED, AttackType.SUMMON, AttackType.FAN, AttackType.SPIRAL]

	var chosen: int = pool[attack_cycle_index % pool.size()]
	attack_cycle_index += 1
	return chosen


func shoot() -> void:
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		return

	var direction: Vector2 = global_position.direction_to(player.global_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	var attack: int = _next_attack()

	match attack:
		AttackType.FAN:
			_shoot_fan(direction)
		AttackType.CIRCLE:
			_shoot_circle()
		AttackType.AIMED:
			_shoot_aimed(direction)
		AttackType.SPIRAL:
			_begin_spiral(direction)
		AttackType.SUMMON:
			_summon_minions()
			_shoot_fan(direction)


func _spawn_bullet(dir: Vector2) -> void:
	var bullet = BULLET_SCENE.instantiate()
	bullet.damage = damage
	bullet.direction = dir
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position


func _shoot_fan(direction: Vector2) -> void:
	var angles: Array[float]
	match boss_phase:
		1: angles = [-30.0, -15.0, 0.0, 15.0, 30.0]
		2: angles = [-40.0, -20.0, 0.0, 20.0, 40.0]
		_: angles = [-55.0, -35.0, -15.0, 0.0, 15.0, 35.0, 55.0]

	for angle in angles:
		_spawn_bullet(direction.rotated(deg_to_rad(angle)))


func _shoot_circle() -> void:
	var count: int = 8 if boss_phase == 2 else 12
	for i in count:
		var angle: float = TAU * float(i) / float(count)
		_spawn_bullet(Vector2.RIGHT.rotated(angle))


func _shoot_aimed(direction: Vector2) -> void:
	for i in AIMED_SHOTS:
		var offset_deg: float = (float(i) - (AIMED_SHOTS - 1) * 0.5) * AIMED_SPREAD_DEG
		_spawn_bullet(direction.rotated(deg_to_rad(offset_deg)))


func _begin_spiral(direction: Vector2) -> void:
	spiral_left = SPIRAL_STEPS
	spiral_offset_deg = 0.0
	spiral_step_timer = 0.0
	spiral_base_dir = direction


func _summon_minions() -> void:
	var count: int = 2 if boss_phase == 3 else 1
	for i in count:
		var minion = SUMMON_SCENE.instantiate()
		get_tree().current_scene.add_child(minion)
		var angle: float = TAU * float(i) / float(count) + randf() * 0.4
		minion.global_position = global_position + Vector2.RIGHT.rotated(angle) * 80.0
