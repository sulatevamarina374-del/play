extends "res://enemy_grunt_animated.gd"

# Radius 11 plus a small safety margin; other actors retain the existing 48.
const FAST_NAV_CLEARANCE: float = 14.0

func navigation_clearance() -> float:
	return FAST_NAV_CLEARANCE


const FAST_SHEET = preload(
	"res://assets/characters/enemy_fast_animations.png"
)


func grunt_animation_texture() -> Texture2D:
	return FAST_SHEET


func grunt_animation_walk_fps() -> float:
	return 12.0


func grunt_animation_prepare_time() -> float:
	return 0.25
