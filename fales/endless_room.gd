extends Node2D

const HEALTH_SEGMENTS = preload("res://segmented_health_bar.gd")
const ARENA_LAYOUT = preload("res://arena_layout.gd")
const NORMAL = preload("res://enemy.tscn")
const RAM = preload("res://enemy_ram.tscn")
const ALCHEMIST = preload("res://enemy_alchemist.tscn")
const HEALER = preload("res://enemy_healer.tscn")
const FAST = preload("res://enemy_fast.tscn")
const SHOOTER = preload("res://enemy_shooter.tscn")
const BOSS = preload("res://boss.tscn")
const BOSS_RAM_SCRIPT = preload("res://boss_ram.gd")
const FLOOR = preload("res://assets/environment/floor_tile_01.png")
const FLOOR_VARIANTS = [
	preload("res://assets/environment/floor_tile_02.png"),
	preload("res://assets/environment/floor_tile_03.png"),
	preload("res://assets/environment/floor_tile_04.png"),
]
const WALL = preload("res://assets/environment/wall_tile.png")
const DOOR_CLOSED = preload("res://assets/environment/door_closed.png")
const DOOR_OPEN = preload("res://assets/environment/door_open.png")
const ENEMY_BULLET = preload("res://enemy_projectile.gd")
const MAGE_BULLET = preload("res://projectile.gd")
const FIRE_BULLET = preload("res://fire_projectile.gd")
const MAX_ENEMIES: int = 12
const ROOM_NAMES = ["Зал", "Длинный зал", "Широкий зал", "Квадратный зал"]
const ROOM_SIZES = [Vector2i(768, 960), Vector2i(640, 1152),
	Vector2i(1152, 832), Vector2i(896, 896)]
const ROOM_COLORS = [Color.WHITE, Color(0.92, 1.0, 0.94),
	Color(0.93, 0.96, 1.0), Color(1.0, 0.96, 0.90)]
const REWARD_BOOK = preload("res://reward_book.gd")
const REWARD_UI = preload("res://reward_choice_ui.gd")
const ROOM_REWARDS = preload("res://room_rewards.gd")


@onready var player: CharacterBody2D = $Player
@onready var exit_area: Area2D = $Exit
@onready var exit_sprite: Sprite2D = $Exit/Sprite2D
@onready var room_info: Label = $HUD/RoomInfo
@onready var boss_bar: ProgressBar = $HUD/BossHealth
@onready var boss_title: Label = $HUD/BossTitle

var rng := RandomNumberGenerator.new()
var room_size: Vector2i
var generated: bool = false
var room_cleared: bool = false
var exit_unlocked: bool = false
var transitioning: bool = false
var boss_node: CharacterBody2D
var initial_enemy_count: int = 0
var boss_frame: Panel
var arena_layout: Node2D
var reward_book: Area2D
var reward_ui: Control
var room_rewards
var ram_spawned: bool = false
var alchemist_spawned: bool = false
var healer_spawned: bool = false


func _ready() -> void:
	setup_boss_health_style()
	room_info.theme = preload("res://assets/ui/health_theme.tres")
	room_info.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room_info.add_theme_font_size_override("font_size", 22)
	room_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	room_info.custom_minimum_size = Vector2(180, 56)
	exit_area.monitoring = false
	exit_sprite.texture = DOOR_CLOSED
	player.set_physics_process(false)
	exit_area.body_entered.connect(_on_exit_body_entered)
	
	reward_ui = REWARD_UI.new()
	reward_ui.name = "RewardChoiceUI"
	$HUD.add_child(reward_ui)
	reward_ui.connect("reward_finished", _on_reward_finished)
	_generate_room.call_deferred()


func _generate_room() -> void:
	if GameState.run_seed == 0:
		rng.randomize()
		GameState.run_seed = rng.randi()
	rng.seed = GameState.run_seed + GameState.room_number * 104729
	var is_boss_room: bool = GameState.room_number % maxi(1, GameState.boss_every) == 0
	var room_type: int = rng.randi_range(0, ROOM_NAMES.size() - 1)
	if room_type == GameState.last_room_type:
		room_type = (room_type + rng.randi_range(1, ROOM_NAMES.size() - 1)) % ROOM_NAMES.size()
	GameState.last_room_type = room_type
	var room_name: String = ROOM_NAMES[room_type]
	var tint: Color = ROOM_COLORS[room_type]
	room_size = ROOM_SIZES[room_type]
	if is_boss_room:
		room_size = Vector2i(960, 960)
		room_name = "Арена босса"
		tint = Color(0.97, 0.91, 1.0)
	_build_floor(tint)
	_build_wall(Vector2(room_size.x / 2.0, 15), Vector2(room_size.x, 30), false)
	_build_wall(Vector2(room_size.x / 2.0, room_size.y - 15), Vector2(room_size.x, 30), false)
	_build_wall(Vector2(15, room_size.y / 2.0), Vector2(30, room_size.y), true)
	_build_wall(Vector2(room_size.x - 15, room_size.y / 2.0), Vector2(30, room_size.y), true)
	player.position = Vector2(room_size.x / 2.0, room_size.y - 140)
	exit_area.position = Vector2(room_size.x / 2.0, 80)
	var camera: Camera2D = $Player/Camera2D
	camera.limit_right = room_size.x
	camera.limit_bottom = room_size.y
	camera.reset_smoothing()
	camera.force_update_scroll()
	
	arena_layout = ARENA_LAYOUT.new()
	arena_layout.name = "ArenaLayout"
	add_child(arena_layout)
	arena_layout.setup(Vector2(room_size), rng, is_boss_room)
	room_rewards = ROOM_REWARDS.new()
	if not room_rewards.setup(
		self,
		player,
		exit_area,
		arena_layout,
		is_boss_room
	):
		push_error("Комната не запущена: не удалось подготовить награды.")
		return

	reward_book = room_rewards.book
	
	var points: Array[Vector2] = _spawn_points()
	if is_boss_room:
		_spawn_boss(points)
	else:
		var minimum: int = mini(MAX_ENEMIES - 2, 3 + floori((GameState.room_number - 1) / 3.0))
		var count: int = rng.randi_range(minimum, mini(MAX_ENEMIES, minimum + 2))
		for index in range(mini(count, points.size())):
			_spawn_regular_enemy(points[index], true)
			
	initial_enemy_count = get_tree().get_nodes_in_group("enemies").size()
	room_info.text = "Комната %d" % GameState.room_number
	player.set_physics_process(true)
	generated = true
	print("Комната %d: %s, врагов: %d" % [GameState.room_number, room_name, initial_enemy_count])


func _build_floor(tint: Color) -> void:
	var floor_sprite := Sprite2D.new()
	floor_sprite.name = "GeneratedFloor"
	floor_sprite.z_index = -10
	floor_sprite.centered = false
	floor_sprite.texture = FLOOR
	floor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_sprite.region_enabled = true
	floor_sprite.region_rect = Rect2(Vector2.ZERO, Vector2(room_size))
	floor_sprite.modulate = tint
	add_child(floor_sprite)
	for y in range(0, room_size.y, 64):
		for x in range(0, room_size.x, 64):
			if rng.randf() > 0.12:
				continue
			var tile := Sprite2D.new()
			tile.texture = FLOOR_VARIANTS[rng.randi_range(0, FLOOR_VARIANTS.size() - 1)]
			tile.centered = false
			tile.position = Vector2(x, y)
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tile.modulate = tint
			floor_sprite.add_child(tile)


func _build_wall(center: Vector2, dimensions: Vector2, vertical: bool) -> void:
	var wall := StaticBody2D.new()
	wall.position = center
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	var collision := CollisionShape2D.new()
	collision.shape = shape
	wall.add_child(collision)
	var sprite := Sprite2D.new()
	sprite.texture = WALL
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	if vertical:
		sprite.rotation = PI / 2.0
		sprite.region_rect = Rect2(0, 0, dimensions.y, dimensions.x)
	else:
		sprite.region_rect = Rect2(Vector2.ZERO, dimensions)
	wall.add_child(sprite)
	add_child(wall)


func _spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for y in range(128, room_size.y - 96, 80):
		for x in range(96, room_size.x - 95, 80):
			var point := Vector2(x, y) + Vector2(
				rng.randf_range(-2, 2),
				rng.randf_range(-2, 2)
			)
			if point.distance_to(player.position) < 240.0:
				continue
			if point.distance_to(exit_area.position) < 120.0:
				continue
			if not arena_layout.is_spawn_safe(point):
				continue
			points.append(point)
			
	# Use this room's RNG, not the global Array.shuffle random stream.
	for index in range(points.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var temporary: Vector2 = points[index]
		points[index] = points[other]
		points[other] = temporary
	return points


func _spawn_regular_enemy(point: Vector2, allow_ram: bool = false) -> void:
	var level: int = GameState.room_number - 1
	var shooter_chance: float = minf(0.35, maxf(0.0, (level - 1) * 0.025))
	var fast_chance: float = minf(0.35, 0.12 + level * 0.015)
	var roll: float = rng.randf()
	var scene: PackedScene = NORMAL
	if roll < shooter_chance:
		scene = SHOOTER
	elif roll < shooter_chance + fast_chance:
		scene = FAST
	
	if allow_ram and GameState.room_number >= 16:
		if scene == NORMAL and not healer_spawned:
			scene = HEALER
			healer_spawned = true
	
	if allow_ram and GameState.room_number >= 6:
		if scene == NORMAL and not ram_spawned:
			scene = RAM
			ram_spawned = true
	
	if allow_ram and GameState.room_number >= 11:
		if scene == NORMAL and not alchemist_spawned:
			scene = ALCHEMIST
			alchemist_spawned = true
	
	var enemy: CharacterBody2D = scene.instantiate()
	if scene == HEALER:
		enemy.set("health", 2.0)
		enemy.set("damage", 1.0)
	enemy.position = point
	enemy.z_index = 1
	var health_multiplier: float = GameState.enemy_health_multiplier()
	enemy.set("health", float(enemy.get("health")) * health_multiplier)
	enemy.set_meta("healer_max_health", float(enemy.get("health")))
	enemy.set("damage", float(enemy.get("damage")) * GameState.enemy_damage_multiplier())
	var base_speed: float = enemy.get("speed")
	enemy.set("speed", base_speed * minf(1.35, 1.0 + level * 0.015))
	if scene == SHOOTER:
		var interval: float = maxf(0.8, 1.8 / (1.0 + level * 0.025))
		enemy.set("attack_interval", interval)
		enemy.set("attack_cooldown", rng.randf_range(0.6, interval))
	add_child(enemy)


func _spawn_boss(points: Array[Vector2]) -> void:
	var tier: int = maxi(1, floori(GameState.room_number / float(maxi(1, GameState.boss_every))))
	if GameState.room_number == 20:
		boss_node = RAM.instantiate()
		boss_node.set_script(BOSS_RAM_SCRIPT)
		boss_node.set(
			"health",
			150.0 * GameState.enemy_health_multiplier()
		)
		boss_node.set("speed", 75.0)
		

		# Увеличиваем изображение и тень, но не коллизию.
		boss_node.get_node("Sprite2D").scale *= 1.35
		boss_node.get_node("Shadow").scale *= 1.35
	else:
		boss_node = BOSS.instantiate()

		boss_node.set(
			"health",
			85.0 * GameState.enemy_health_multiplier()
		)

		boss_node.set(
			"speed",
			minf(70.0, 55.0 + (tier - 1) * 2.0)
		)
		boss_node.set(
			"attack_interval",
			maxf(0.9, 2.2 - (tier - 1) * 0.12)
		)

	boss_node.position = Vector2(room_size.x / 2.0, 240)
	boss_node.z_index = 1
	boss_node.set(
		"damage",
		float(boss_node.get("damage")) * GameState.enemy_damage_multiplier()
	)

	add_child(boss_node)
	
	boss_bar.max_value = boss_node.get("health")
	boss_bar.value = boss_bar.max_value
	# First boss is alone; later bosses gain up to four guards.
	var guards: int = mini(4, tier - 1)
	for point in points:
		if guards <= 0:
			break
		if point.distance_to(boss_node.position) < 140.0:
			continue
		_spawn_regular_enemy(point)
		guards -= 1


func _process(_delta: float) -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	room_info.size = Vector2(maxf(180.0, room_info.get_combined_minimum_size().x), 56.0)
	room_info.position = Vector2((screen.x - room_info.size.x) / 2.0, 10.0)
	boss_frame.position = Vector2((screen.x - 300.0) / 2.0, 76.0)
	boss_frame.size = Vector2(300.0, 56.0)

	boss_bar.position = Vector2(12.0, 12.0)
	boss_bar.size = boss_frame.size - Vector2(24.0, 24.0)

	boss_title.position = boss_frame.position
	boss_title.size = boss_frame.size
	var boss_alive: bool = is_instance_valid(boss_node) and not boss_node.is_queued_for_deletion()
	boss_frame.visible = boss_alive
	boss_bar.visible = boss_alive
	boss_title.visible = boss_alive
	if boss_alive:
		boss_bar.value = boss_node.get("health")
		
		boss_title.text = "Босс — фаза %d" % int(
			boss_node.get("boss_phase")
		)
	
	if room_cleared:
		update_exit_state()
	
	if not generated or room_cleared or not is_instance_valid(player) or float(player.get("health")) <= 0:
		return
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_queued_for_deletion():
			return
			
	room_cleared = true
	GameState.run_last_cleared_room = maxi(
		GameState.run_last_cleared_room, GameState.room_number
	)
	Profile.record_cleared_room(GameState.room_number)

	# После зачистки убираем оставшиеся снаряды.
	for child in get_children():
		var script = child.get_script()
		if script == ENEMY_BULLET or script == MAGE_BULLET or script == FIRE_BULLET:
			child.queue_free()

	update_exit_state()
	if room_rewards != null:
		room_rewards.reveal()


func _on_exit_body_entered(body: Node2D) -> void:
	if not room_cleared or transitioning or not body.is_in_group("player"):
		return
	if float(player.get("health")) <= 0:
		return
	
	if not exit_unlocked:
		return

	if room_rewards == null:
		return

	if not room_rewards.all_collected():
		return
	transitioning = true
	player.call("save_run_shield")
	GameState.health = float(player.get("health"))
	GameState.room_number += 1
	get_tree().call_deferred("change_scene_to_file", "res://endless_room.tscn")

func setup_boss_health_style() -> void:
	var health_theme: Theme = preload("res://assets/ui/health_theme.tres")

	boss_frame = Panel.new()
	boss_frame.name = "BossFrame"
	boss_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss_frame.clip_contents = true
	boss_frame.add_theme_stylebox_override(
		"panel",
		health_theme.get_stylebox("normal", "Label").duplicate()
	)
	$HUD.add_child(boss_frame)
	boss_frame.hide()

	boss_bar.reparent(boss_frame, false)
	boss_bar.add_theme_stylebox_override(
		"background",
		StyleBoxEmpty.new()
	)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("d88170")
	fill.anti_aliasing = false
	boss_bar.add_theme_stylebox_override("fill", fill)
	boss_bar.show_percentage = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	boss_title.z_index = 1
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_title.add_theme_font_size_override("font_size", 22)
	boss_title.add_theme_color_override("font_color", Color("eef0dc"))
	boss_title.add_theme_color_override("font_outline_color", Color("20212b"))
	boss_title.add_theme_constant_override("outline_size", 2)
	var boss_segments = HEALTH_SEGMENTS.new()
	boss_segments.name = "HealthSegments"
	boss_segments.vertical = false
	boss_segments.segment_count = 10
	boss_segments.fill_color = Color("d88170")
	boss_segments.warn_low_health = false
	boss_bar.add_child(boss_segments)


func get_enemy_direction(actor: Node2D, target: Vector2) -> Vector2:
	if not is_instance_valid(arena_layout):
		return actor.global_position.direction_to(target)

	return arena_layout.get_move_direction(actor, target)


func has_clear_shot(from: Vector2, to: Vector2) -> bool:
	if not is_instance_valid(arena_layout):
		return true

	return arena_layout.segment_clear(from, to, 8.0, true)


func _on_reward_book_requested() -> void:
	if not room_cleared or transitioning:
		return
	if float(player.get("health")) <= 0.0:
		return

	reward_ui.call("open_offers")

func _on_reward_finished() -> void:
	if is_instance_valid(reward_book):
		reward_book.call("consume")

		if room_rewards != null:
			room_rewards.mark_book_completed()

	update_exit_state()

func update_exit_state() -> void:
	var ready_to_exit: bool = false

	if room_cleared and room_rewards != null:
		ready_to_exit = room_rewards.all_collected()

	if ready_to_exit == exit_unlocked:
		return

	exit_unlocked = ready_to_exit
	exit_sprite.texture = DOOR_OPEN if exit_unlocked else DOOR_CLOSED
	exit_area.set_deferred("monitoring", exit_unlocked)
