extends Line2D

const POINT_LIFETIME: float = 0.16
const MAX_POINTS: int = 24
const MAX_STEP: float = 64.0

var sample_positions: Array[Vector2] = []
var sample_ages: Array[float] = []



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	top_level = true
	global_transform = Transform2D.IDENTITY
	z_as_relative = false
	z_index = -1
	antialiased = false
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	joint_mode = Line2D.LINE_JOINT_ROUND


func configure(color: Color, thickness: float) -> void:
	width = thickness

	var fade := Gradient.new()
	fade.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.0),
		Color(color.r, color.g, color.b, 0.65)
	])
	gradient = fade


func add_sample(point: Vector2) -> void:
	if not sample_positions.is_empty():
		var distance: float = sample_positions.back().distance_to(point)

		if distance > MAX_STEP:
			break_trail()
		elif distance < 1.5:
			return

	sample_positions.append(point)
	sample_ages.append(0.0)

	while sample_positions.size() > MAX_POINTS:
		sample_positions.pop_front()
		sample_ages.pop_front()

	points = PackedVector2Array(sample_positions)


func _physics_process(delta: float) -> void:
	for index in range(sample_ages.size()):
		sample_ages[index] += delta

	while not sample_ages.is_empty():
		if sample_ages[0] < POINT_LIFETIME:
			break

		sample_ages.pop_front()
		sample_positions.pop_front()

	points = PackedVector2Array(sample_positions)


func break_trail() -> void:
	sample_positions.clear()
	sample_ages.clear()
	clear_points()
