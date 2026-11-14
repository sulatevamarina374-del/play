extends Control

const ROBES = preload("res://robe_catalog.gd")

const BODY = preload("res://assets/characters/mage_idle_body.png")
const ARM = preload("res://assets/characters/mage_idle_arm_shot.png")
const SHADOW = preload("res://assets/characters/mage_shadow.png")
const DOOR = preload("res://assets/environment/door_open.png")

var show_door: bool = true

# Если включено, показываем выбранную карточку,
# даже если мантия ещё не куплена.
var use_preview_override: bool = false
var preview_robe_id: String = ""

var is_thumbnail: bool = false
var phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	phase = fmod(phase + delta * 7.0, 12.0)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var width_divisor: float = 88.0 if is_thumbnail else 150.0
	var height_divisor: float

	if is_thumbnail:
		height_divisor = 88.0
	elif show_door:
		height_divisor = 120.0
	else:
		height_divisor = 90.0

	var factor: float = minf(
		size.x / width_divisor,
		size.y / height_divisor
	)
	factor = minf(factor, 4.0)

	if factor >= 1.0:
		factor = floorf(factor)
	else:
		factor = maxf(0.1, factor)

	var center: Vector2 = (size * 0.5).round()
	var mage_y: float = -8.0 if show_door else -32.0

	if show_door:
		draw_texture_rect(
			DOOR,
			Rect2(
				center + Vector2(-48, -66) * factor,
				Vector2(96, 96) * factor
			),
			false
		)

	var shown_id: String = (
		preview_robe_id if use_preview_override
		else Profile.equipped_robe_id
	)

	var showing_robe: bool = ROBES.DATA.has(shown_id) and (
		use_preview_override
		or Profile.owned_robe_ids.has(shown_id)
	)

	var shadow_x: float = -34.0
	var shadow_y: float = 54.0

	if not showing_robe:
		shadow_x = -36.5
		shadow_y = 53.0

	draw_texture_rect(
		SHADOW,
		Rect2(
			center + Vector2(shadow_x, mage_y + shadow_y) * factor,
			Vector2(64, 16) * factor
		),
		false
	)

	var id: String

	if use_preview_override:
		id = preview_robe_id
	else:
		id = Profile.equipped_robe_id

	var body: Texture2D = BODY
	var arm: Texture2D = ARM
	var visual_scale: float = 1.0 if showing_robe else 1.15

	if (
		ROBES.DATA.has(id)
		and (
			use_preview_override
			or Profile.owned_robe_ids.has(id)
		)
	):
		body = ROBES.DATA[id]["idle_body"]
		arm = ROBES.DATA[id]["idle_arm"]
		visual_scale = ROBES.DATA[id]["scale"]

	var top_y: float = mage_y

	if not showing_robe:
		top_y = mage_y + 62.0 - 57.0 * visual_scale
	elif visual_scale != 1.0:
		top_y = mage_y + 61.0 - 59.0 * visual_scale

	var destination := Rect2(
		center + Vector2(-32.0 * visual_scale, top_y) * factor,
		Vector2(64, 64) * factor * visual_scale
	)

	var index: int = int(phase)

	draw_texture_rect_region(
		body,
		destination,
		Rect2(index * 64, 0, 64, 64)
	)

	# Шестая строка — рука в покое.
	draw_texture_rect_region(
		arm,
		destination,
		Rect2(index * 64, 5 * 64, 64, 64)
	)
