extends "res://enemy_ram.gd"

# Этот скрипт используется только боссом.

const BOSS_PHASE_TWO_AT: float = 0.70
const BOSS_PHASE_THREE_AT: float = 0.35

const BOSS_PREPARE: float = 0.45
const BOSS_CHARGE: float = 0.40
const BOSS_CHARGE_SPEED: float = 260.0
const BOSS_BETWEEN_CHARGES: float = 0.30
const BOSS_START_DISTANCE: float = 180.0

# --- НОВЫЕ ПАРАМЕТРЫ ---
const BOSS_EXHAUST_TIME: float = 2.0 # Время усталости в 3-й фазе
const TRAIL_INTERVAL: float = 0.08   # Как часто оставлять огненный след
const SHOCKWAVE_COUNT: int = 12      # Сколько пуль в ударной волне

# Путь к снаряду (проверь, чтобы он был верным в твоем проекте)
const BULLET_SCENE = preload("res://enemy_projectile.tscn")
# Подключаем наш новый скрипт огня
const FIRE_TRAIL_SCRIPT = preload("res://fire_trail.gd")

enum BossMove {
	WALK,
	PREPARE,
	CHARGE,
	BETWEEN,
	RECOVER,
	EXHAUSTED # Новое состояние для 3-й фазы
}

var boss_move: int = BossMove.WALK
var boss_move_time: float = 0.0

var boss_phase: int = 1
var boss_max_health: float = 0.0

var charges_left: int = 0
var boss_walk_time: float = 0.0
var trail_timer: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	boss_max_health = health


func take_damage(amount: float) -> void:
	# УЯЗВИМОСТЬ: В состоянии усталости получает двойной урон
	if boss_move == BossMove.EXHAUSTED:
		amount *= 2.0
		
	super.take_damage(amount)

	if not is_alive() or boss_max_health <= 0.0:
		return

	var fraction: float = health / boss_max_health

	if fraction <= BOSS_PHASE_THREE_AT:
		boss_phase = maxi(boss_phase, 3)
	elif fraction <= BOSS_PHASE_TWO_AT:
		boss_phase = maxi(boss_phase, 2)


func _boss_set_move(next_move: int) -> void:
	boss_move = next_move
	boss_move_time = 0.0


func _boss_recovery_time() -> float:
	if boss_phase == 3:
		return 1.0
	if boss_phase == 2:
		return 1.2 
	return 1.5


func _physics_process(delta: float) -> void:
	if not begin_combat_frame(delta):
		if is_alive() and boss_move != BossMove.WALK:
			charges_left = 0
			_boss_set_move(BossMove.RECOVER)
		return

	update_attack_rest(delta)

	if (
		not is_instance_valid(player)
		or player.is_queued_for_deletion()
		or float(player.get("health")) <= 0.0
	):
		velocity = Vector2.ZERO
		grunt_sprite.frame = 15
		return

	boss_move_time += delta

	var desired: Vector2 = Vector2.ZERO
	var room = get_tree().current_scene

	match boss_move:
		BossMove.WALK:
			var distance: float = global_position.distance_to(player.global_position)
			var clear: bool = true

			if room.has_method("has_clear_shot"):
				clear = bool(room.call("has_clear_shot", global_position, player.global_position))

			if distance <= BOSS_START_DISTANCE and clear:
				if boss_phase == 3:
					charges_left = 3
				elif boss_phase == 2:
					charges_left = 2
				else:
					charges_left = 1
					
				_boss_set_move(BossMove.PREPARE)
			else:
				var direction: Vector2 = global_position.direction_to(player.global_position)

				if room.has_method("get_enemy_direction"):
					direction = room.call("get_enemy_direction", self, player.global_position)

				var walk_factor: float = 1.0 + 0.1 * float(boss_phase - 1)
				desired = direction * speed * walk_factor

		BossMove.PREPARE:
			if boss_move_time >= BOSS_PREPARE:
				_boss_set_move(BossMove.CHARGE)
				trail_timer = 0.0

		BossMove.CHARGE:
			# Ударная волна при контакте с игроком
			if grunt_has_contact() and attack_rest_left <= 0.0:
				grunt_hit_once()
				start_attack_rest(CONTACT_ATTACK_REST)
				_spawn_shockwave() 
				
				charges_left = 0
				_boss_set_move(BossMove.RECOVER)

			elif boss_move_time >= BOSS_CHARGE:
				charges_left -= 1
				if charges_left > 0:
					_boss_set_move(BossMove.BETWEEN)
				else:
					_boss_set_move(BossMove.RECOVER)

			else:
				# Наведение (homing)
				var direction: Vector2 = global_position.direction_to(player.global_position)
				desired = direction * BOSS_CHARGE_SPEED
				
				# Огненный след со 2-й фазы
				if boss_phase >= 2:
					trail_timer -= delta
					if trail_timer <= 0.0:
						trail_timer = TRAIL_INTERVAL
						_drop_fire_trail()

		BossMove.BETWEEN:
			if boss_move_time >= BOSS_BETWEEN_CHARGES:
				_boss_set_move(BossMove.PREPARE)

		BossMove.RECOVER:
			# В 3-й фазе после всех рывков босс устаёт
			if boss_phase == 3 and charges_left == 0:
				_boss_set_move(BossMove.EXHAUSTED)
				grunt_sprite.modulate = Color(0.5, 0.8, 1.0) # Синеватый оттенок
			elif boss_move_time >= _boss_recovery_time():
				_boss_set_move(BossMove.WALK)

		BossMove.EXHAUSTED:
			# Стоит на месте 2 секунды, получает х2 урона
			if boss_move_time >= BOSS_EXHAUST_TIME:
				grunt_sprite.modulate = Color.WHITE
				_boss_set_move(BossMove.WALK)

	velocity = combat_effects.movement(desired)
	move_and_slide()

	# Ударная волна при столкновении со стеной
	if boss_move == BossMove.CHARGE:
		for index in range(get_slide_collision_count()):
			var collision: KinematicCollision2D = get_slide_collision(index)

			if collision.get_collider() is StaticBody2D:
				_spawn_shockwave() 
				charges_left = 0
				_boss_set_move(BossMove.RECOVER)
				break

	_boss_update_animation(delta, not desired.is_zero_approx())


func _spawn_shockwave() -> void:
	for i in SHOCKWAVE_COUNT:
		var bullet = BULLET_SCENE.instantiate()
		bullet.damage = damage
		bullet.direction = Vector2.RIGHT.rotated(TAU * float(i) / float(SHOCKWAVE_COUNT))
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position


func _drop_fire_trail() -> void:
	# Создаем огонь через наш новый скрипт
	var trail = FIRE_TRAIL_SCRIPT.new()
	trail.damage_amount = damage * 0.5 # Урон от огня чуть меньше прямого удара
	get_tree().current_scene.add_child(trail)
	trail.global_position = global_position


func _boss_update_animation(delta: float, moving: bool) -> void:
	match boss_move:
		BossMove.WALK:
			if moving and get_real_velocity().length_squared() > 1.0:
				boss_walk_time += delta
				grunt_sprite.frame = int(boss_walk_time * 8.0) % 4
			else:
				grunt_sprite.frame = 15

		BossMove.PREPARE:
			grunt_sprite.frame = 4 + clampi(int(boss_move_time / BOSS_PREPARE * 4.0), 0, 3)

		BossMove.CHARGE:
			grunt_sprite.frame = 8 + clampi(int(boss_move_time / BOSS_CHARGE * 4.0), 0, 3)

		BossMove.BETWEEN, BossMove.RECOVER:
			grunt_sprite.frame = 12 + clampi(int(boss_move_time / _boss_recovery_time() * 4.0), 0, 3)
			
		BossMove.EXHAUSTED:
			grunt_sprite.frame = 12


func grunt_animation_texture() -> Texture2D:
	return preload("res://assets/characters/taran_boss_sprite_sheet.png")
