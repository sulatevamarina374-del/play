extends Sprite2D

const ROBES = preload("res://robe_catalog.gd")

const IDLE_BODY: Texture2D = preload("res://assets/characters/mage_idle_body.png")
const WALK_BODY: Texture2D = preload("res://assets/characters/mage_walk_body.png")
const IDLE_ARM: Texture2D = preload("res://assets/characters/mage_idle_arm_shot.png")
const WALK_ARM: Texture2D = preload("res://assets/characters/mage_walk_arm_shot.png")
const SHADOW_TEXTURE: Texture2D = preload("res://assets/characters/mage_shadow.png")
const FLASH_TEXTURE: Texture2D = preload("res://assets/characters/shot_flash.png")

const IDLE_COUNT: int = 12
const WALK_COUNT: int = 8
const SHOT_ROWS: int = 6
const STAGE_SECONDS: float = 0.03
const PREPARE_WINDOW: float = 0.06
const RELEASE_SECONDS: float = 0.12
const IDLE_OFFSETS: Array[Vector2] = [
	Vector2(0, 0), Vector2(0, 0), Vector2(-1, 0), Vector2(-1, 0),
	Vector2(-1, 0), Vector2(0, 0), Vector2(0, 0), Vector2(1, 0),
	Vector2(1, 0), Vector2(1, 0), Vector2(0, 0), Vector2(0, 0)
]
const WALK_OFFSETS: Array[Vector2] = [
	Vector2(1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 0),
	Vector2(-1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 0)
]

@export_range(1.0, 12.0, 0.5) var idle_fps: float = 7.0
@export_range(1.0, 20.0, 0.5) var walk_fps: float = 10.0

var animation_phase: float = 0.0
var is_walking: bool = false
var shot_stage: int = 5
var release_elapsed: float = -1.0
var release_just_started: bool = false
var layers_ready: bool = false
var arm_sprite: Sprite2D
var robe_id: String = ""
var base_position: Vector2
var base_scale: Vector2
var flash_sprite: Sprite2D
@onready var player_body: CharacterBody2D = get_parent() as CharacterBody2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true

	base_position = position
	base_scale = scale

	if (
		Profile.owned_robe_ids.has(Profile.equipped_robe_id)
		and ROBES.DATA.has(Profile.equipped_robe_id)
	):
		robe_id = Profile.equipped_robe_id

		var robe_scale: float = ROBES.DATA[robe_id]["scale"]
		scale = base_scale * robe_scale

		# Сохраняем прежнюю точку опоры ног.
		position.y = (
			base_position.y
			+ base_scale.y * (29.0 - 27.0 * robe_scale)
		)
	else:
		# Размер нового обычного мага и точка опоры ног.
		var default_scale: float = 1.15
		scale = base_scale * default_scale
		position.y = (
			base_position.y
			+ base_scale.y * (29.0 - 25.0 * default_scale)
		)

	_set_animation(false)

	if is_instance_valid(player_body):
		if player_body.has_signal("shot_fired"):
			var callback: Callable = Callable(self, "play_shot")
			if not player_body.is_connected("shot_fired", callback):
				player_body.connect("shot_fired", callback)
		else:
			push_warning("Add signal shot_fired and shot_fired.emit() to player.gd.")
	# Deferred creation avoids adding nodes during the parent's setup.
	call_deferred("_setup_layers")


func _get_or_create_sprite(parent_node: Node, node_name: String) -> Sprite2D:
	var existing: Node = parent_node.get_node_or_null(NodePath(node_name))
	if existing != null:
		if existing is Sprite2D:
			return existing as Sprite2D
		push_warning(node_name + " exists but is not a Sprite2D.")
		return null
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = node_name
	parent_node.add_child(sprite)
	return sprite


func _setup_layers() -> void:
	if not is_instance_valid(player_body):
		return
	arm_sprite = _get_or_create_sprite(self, "MageArm")
	flash_sprite = _get_or_create_sprite(self, "MageShotFlash")
	if arm_sprite == null or flash_sprite == null:
		return
	arm_sprite.position = Vector2.ZERO
	arm_sprite.scale = Vector2.ONE
	arm_sprite.centered = true
	arm_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arm_sprite.modulate = Color.WHITE
	arm_sprite.z_index = 1
	arm_sprite.show()
	flash_sprite.texture = FLASH_TEXTURE
	flash_sprite.centered = true
	flash_sprite.scale = Vector2.ONE
	flash_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash_sprite.hframes = 1
	flash_sprite.vframes = 1
	flash_sprite.frame = 0
	flash_sprite.z_index = 2
	flash_sprite.hide()
	_ensure_shadow()
	layers_ready = true
	_set_animation(is_walking)
	_apply_visuals()


func _ensure_shadow() -> void:
	var shadow: Sprite2D = _get_or_create_sprite(player_body, "MageShadow")
	if shadow == null:
		return
	shadow.texture = SHADOW_TEXTURE
	shadow.centered = true
	shadow.hframes = 1
	shadow.vframes = 1
	shadow.frame = 0
	var shadow_offset: Vector2 = Vector2(-2.0, 29.0)

	if robe_id.is_empty():
		shadow_offset = Vector2(-4.5, 28.0)

	shadow.position = base_position + shadow_offset * base_scale
	shadow.scale = base_scale
	shadow.rotation = 0.0
	shadow.modulate = Color.WHITE
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.z_index = z_index - 1
	shadow.show()


func _set_animation(moving: bool) -> void:
	is_walking = moving
	animation_phase = 0.0
	frame = 0
	hframes = 1
	vframes = 1

	if robe_id.is_empty():
		texture = WALK_BODY if moving else IDLE_BODY
	else:
		texture = ROBES.DATA[robe_id][
			"walk_body" if moving else "idle_body"
		]

	hframes = WALK_COUNT if moving else IDLE_COUNT

	if is_instance_valid(arm_sprite):
		arm_sprite.frame = 0
		arm_sprite.hframes = 1
		arm_sprite.vframes = 1

		if robe_id.is_empty():
			arm_sprite.texture = WALK_ARM if moving else IDLE_ARM
		else:
			arm_sprite.texture = ROBES.DATA[robe_id][
				"walk_arm" if moving else "idle_arm"
			]

		arm_sprite.hframes = WALK_COUNT if moving else IDLE_COUNT
		arm_sprite.vframes = SHOT_ROWS


func play_shot() -> void:
	# The actual projectile already exists. Never delay or queue the attack.
	release_elapsed = 0.0
	release_just_started = true
	shot_stage = 2
	if layers_ready:
		_apply_visuals()


func _prepare_stage() -> int:
	# Anticipation only: it cannot create a projectile or show a release flash.
	var cooldown_value: Variant = player_body.get("attack_cooldown")
	if typeof(cooldown_value) != TYPE_FLOAT and typeof(cooldown_value) != TYPE_INT:
		return 5
	var remaining: float = float(cooldown_value)
	if remaining <= 0.0 or remaining > PREPARE_WINDOW:
		return 5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node2D and not enemy.is_queued_for_deletion():
			return 0 if remaining > STAGE_SECONDS else 1
	return 5


func _process(delta: float) -> void:
	if not layers_ready or not is_instance_valid(player_body):
		return
	var moving: bool = player_body.velocity.length_squared() > 1.0
	if moving != is_walking:
		_set_animation(moving)
	var count: int = WALK_COUNT if is_walking else IDLE_COUNT
	var fps: float = walk_fps if is_walking else idle_fps
	animation_phase = fmod(animation_phase + delta * fps, float(count))
	frame = int(animation_phase)

	if release_elapsed >= 0.0:
		# Keep the release visible for one rendered frame even after a slow frame.
		if release_just_started:
			release_just_started = false
		else:
			release_elapsed += delta
		if release_elapsed < RELEASE_SECONDS:
			shot_stage = 2 + mini(int(release_elapsed / STAGE_SECONDS), 3)
		else:
			release_elapsed = -1.0
			shot_stage = _prepare_stage()
	else:
		shot_stage = _prepare_stage()
	_apply_visuals()


func _apply_visuals() -> void:
	if not layers_ready:
		return
	var count: int = WALK_COUNT if is_walking else IDLE_COUNT
	var index: int = clampi(frame, 0, count - 1)
	arm_sprite.frame = shot_stage * count + index
	var body_offset: Vector2 = WALK_OFFSETS[index] if is_walking else IDLE_OFFSETS[index]
	# У синей мантии ходьба без вертикального сдвига тела.
	if robe_id == "blue" and is_walking:
		body_offset.y = 0.0

	var flash_base: Vector2 = Vector2(18.0, 2.0)

	if not robe_id.is_empty():
		flash_base = ROBES.DATA[robe_id]["flash"]

	flash_sprite.position = flash_base + body_offset
	flash_sprite.visible = shot_stage == 2 or shot_stage == 3
	flash_sprite.modulate = Color(1.0, 1.0, 1.0, 128.0 / 255.0 if shot_stage == 3 else 1.0)
