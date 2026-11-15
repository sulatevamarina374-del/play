extends "res://boss.gd"

const ORB_SCRIPT = preload("res://warlock_orb.gd")
const HAZARD_SCRIPT = preload("res://warlock_hazard.gd")

var teleport_cooldown: float = 0.0

func _ready() -> void:
	super._ready()
	# Чтобы телепорт не срабатывал в первую же секунду
	teleport_cooldown = 2.0 

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if teleport_cooldown > 0.0:
		teleport_cooldown -= delta
		
	# ИДЕЯ 1: Телепорт, если игрок слишком близко
	if is_instance_valid(player) and teleport_cooldown <= 0.0:
		if global_position.distance_to(player.global_position) < 150.0:
			_teleport_away()

func _teleport_away() -> void:
	teleport_cooldown = 4.0 # Кулдаун телепорта
	var room = get_tree().current_scene
	var room_size = room.get("room_size") if room else Vector2(800, 600)
	
	# Пытаемся найти точку подальше от игрока
	var new_pos = global_position
	for i in 10: # 10 попыток найти хорошую точку
		var test_pos = Vector2(
			randf_range(100.0, room_size.x - 100.0),
			randf_range(100.0, room_size.y - 100.0)
		)
		if test_pos.distance_to(player.global_position) > 250.0:
			new_pos = test_pos
			break
			
	global_position = new_pos
	# Небольшой визуальный эффект исчезновения
	modulate.a = 0.5
	await get_tree().create_timer(0.1).timeout
	modulate.a = 1.0

func _next_attack() -> int:
	# Переопределяем пул атак под Колдуна
	var pool: Array[int]
	match boss_phase:
		1:
			pool = [AttackType.FAN] # 1 фаза: только веер
		2:
			pool = [AttackType.FAN, AttackType.AIMED, AttackType.SPIRAL] # 2 фаза: веер + замедление + зона
		_:
			pool = [AttackType.FAN, AttackType.AIMED, AttackType.SUMMON, AttackType.SPIRAL] # 3 фаза

	var chosen: int = pool[attack_cycle_index % pool.size()]
	attack_cycle_index += 1
	return chosen

func shoot() -> void:
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		return

	var direction: Vector2 = global_position.direction_to(player.global_position)
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	
	var attack: int = _next_attack()

	match attack:
		AttackType.FAN:
			_shoot_fan(direction)
		AttackType.AIMED:
			# ИДЕЯ 4: Замедленный выстрел (Сначала веер, потом фиолетовый шар с задержкой)
			_shoot_fan(direction)
			await get_tree().create_timer(0.5).timeout
			if is_instance_valid(player) and is_alive():
				var delayed_dir = global_position.direction_to(player.global_position)
				_spawn_slowing_bullet(delayed_dir)
		AttackType.SPIRAL:
			# ИДЕЯ 3: Проклятая зона под игроком
			_spawn_hazard(player.global_position)
		AttackType.SUMMON:
			# ИДЕЯ 2: Призыв турелей
			_summon_orbs()

# --- Вспомогательные функции ---

func _spawn_slowing_bullet(dir: Vector2) -> void:
	var bullet = BULLET_SCENE.instantiate()
	bullet.damage = damage
	bullet.is_slowing = true
	bullet.direction = dir
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position

func _spawn_hazard(pos: Vector2) -> void:
	var hazard = HAZARD_SCRIPT.new()
	hazard.damage = damage
	get_tree().current_scene.add_child(hazard)
	hazard.global_position = pos

func _summon_orbs() -> void:
	var count = 2 if boss_phase == 2 else 3
	for i in count:
		var orb = ORB_SCRIPT.new()
		get_tree().current_scene.add_child(orb)
		var angle = TAU * float(i) / float(count) + randf() * 0.5
		orb.global_position = global_position + Vector2.RIGHT.rotated(angle) * 120.0

# Переопределяем веер, чтобы в 3-й фазе фиолетовые пули летели веером
func _shoot_fan(direction: Vector2) -> void:
	var angles: Array[float]
	if boss_phase == 1:
		angles = [-15.0, 0.0, 15.0]
	elif boss_phase == 2:
		angles = [-20.0, 0.0, 20.0]
	else:
		angles = [-30.0, -15.0, 0.0, 15.0, 30.0] # В 3-й фазе веер шире

	for angle in angles:
		var bullet_dir = direction.rotated(deg_to_rad(angle))
		# В 3-й фазе центральный шар замедляет
		if boss_phase == 3 and angle == 0.0:
			_spawn_slowing_bullet(bullet_dir)
		else:
			_spawn_bullet(bullet_dir)
