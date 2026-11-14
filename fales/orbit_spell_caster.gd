extends Node2D

# Предварительные параметры только для тестовой копии.
const ORBIT_RADIUS: float = 64.0
const ROTATION_TIME: float = 4.0
const HIT_INTERVAL: float = 1.0
const HIT_DAMAGE: float = 1.0
const SPHERE_SIZE: float = 32.0
const HIT_RADIUS: float = 8.0
const TRAIL_SCRIPT = preload("res://sphere_trail.gd")

const SOURCE_TEXTURE = preload("res://assets/effects/mage_projectile.png")

const COLORS: Dictionary = {
	"dark_orbit": Color("80609c"),
	"light_orbit": Color("efe3a0"),
	"wind_orbit": Color("94c89a"),
	"water_orbit": Color("5eadd1"),
	"fire_orbit": Color("ff9850"),
	"ice_orbit": Color("a5dce5")
}

static var neutral_texture: Texture2D

var angle: float = 0.0
var visible_orbs: Array[Dictionary] = []
var hit_timers: Dictionary = {}
var hit_shape: CircleShape2D = CircleShape2D.new()
var orbit_trails: Dictionary = {}
var trail_signature: String = ""

@onready var mage: CharacterBody2D = get_parent() as CharacterBody2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2
	hit_shape.radius = HIT_RADIUS

	if neutral_texture == null:
		var image: Image = SOURCE_TEXTURE.get_image()

		if image == null:
			push_error("Не удалось прочитать текстуру вращающихся сфер.")
			set_physics_process(false)
			return

		if image.is_compressed() and image.decompress() != OK:
			push_error("Не удалось распаковать текстуру вращающихся сфер.")
			set_physics_process(false)
			return

		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var pixel: Color = image.get_pixel(x, y)
				var light: float = maxf(pixel.r, maxf(pixel.g, pixel.b))
				image.set_pixel(x, y, Color(light, light, light, pixel.a))

		neutral_texture = ImageTexture.create_from_image(image)


func _physics_process(delta: float) -> void:
	visible_orbs.clear()

	for key in hit_timers.keys():
		var remaining: float = float(hit_timers[key]) - delta

		if remaining <= 0.0:
			hit_timers.erase(key)
		else:
			hit_timers[key] = remaining

	if not is_instance_valid(mage):
		clear_orbit_trails()
		queue_redraw()
		return

	if float(mage.get("health")) <= 0.0 or not mage.is_physics_processing():
		clear_orbit_trails()
		queue_redraw()
		return

	var active: Array[Dictionary] = []
	var total: int = 0

	for spell in GameState.selected_spells:
		var spell_id: String = str(spell.get("id", ""))

		if not COLORS.has(spell_id):
			continue

		var level: int = clampi(int(spell.get("level", 1)), 1, 3)
		active.append({"id": spell_id, "level": level})
		total += level

	if total == 0:
		clear_orbit_trails()
		trail_signature = ""
		queue_redraw()
		return

	# При изменении набора сбрасываем старые линии.
	var signature: String = ""

	for spell in active:
		signature += "%s:%d;" % [
			str(spell["id"]),
			int(spell["level"])
		]

	if signature != trail_signature:
		clear_orbit_trails()
		trail_signature = signature

	angle = fposmod(angle + TAU * delta / ROTATION_TIME, TAU)
	var orb_index: int = 0

	for rank in range(3):
		for spell in active:
			if rank >= int(spell["level"]):
				continue

			var spell_id: String = str(spell["id"])
			var orb_angle: float = (
				angle + TAU * float(orb_index) / float(total)
			)
			var point: Vector2 = (
				Vector2.from_angle(orb_angle) * ORBIT_RADIUS
			)
			orb_index += 1

			var trail_key: String = "%s:%d" % [spell_id, rank]

			if not line_clear(to_global(point)):
				if orbit_trails.has(trail_key):
					orbit_trails[trail_key].break_trail()
				continue

			update_orbit_trail(
				trail_key,
				to_global(point),
				COLORS[spell_id]
			)

			visible_orbs.append({
				"position": point,
				"color": COLORS[spell_id]
			})

			try_damage(point, spell_id, rank)

	queue_redraw()


func line_clear(target: Vector2) -> bool:
	var room: Node = get_tree().current_scene

	if room == null or not room.has_method("has_clear_shot"):
		return false

	return bool(room.call(
		"has_clear_shot",
		mage.global_position,
		target
	))


func try_damage(point: Vector2, spell_id: String, rank: int) -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hit_shape
	query.transform = Transform2D(0.0, to_global(point))
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [mage.get_rid()]

	var hits: Array[Dictionary] = (
		get_world_2d().direct_space_state.intersect_shape(query, 64)
	)

	for hit in hits:
		var enemy: Node2D = hit.get("collider") as Node2D

		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue

		if not enemy.is_in_group("enemies"):
			continue

		if not enemy.has_method("take_damage"):
			continue

		if not line_clear(enemy.global_position):
			continue

		var key: String = "%s:%d:%s" % [
			spell_id,
			rank,
			str(enemy.get_instance_id())
		]

		if hit_timers.has(key):
			continue

		hit_timers[key] = HIT_INTERVAL
		enemy.call(
			"take_damage",
			GameState.resolve_spell_damage(spell_id, HIT_DAMAGE)
		)


func _draw() -> void:
	if neutral_texture == null:
		return

	var orb_size: Vector2 = Vector2.ONE * SPHERE_SIZE

	for orb in visible_orbs:
		var point: Vector2 = orb["position"]
		var color: Color = orb["color"]

		draw_texture_rect(
			neutral_texture,
			Rect2(point - orb_size / 2.0, orb_size),
			false,
			color
		)

func update_orbit_trail(
	key: String,
	point: Vector2,
	color: Color
) -> void:
	if not orbit_trails.has(key):
		var trail = TRAIL_SCRIPT.new()
		trail.configure(color, 7.0)
		add_child(trail)
		orbit_trails[key] = trail

	orbit_trails[key].add_sample(point)


func clear_orbit_trails() -> void:
	for trail in orbit_trails.values():
		if is_instance_valid(trail):
			trail.queue_free()

	orbit_trails.clear()
