extends Node2D

const DOOR_CLOSED = preload("res://assets/environment/door_closed.png")
const DOOR_OPEN = preload("res://assets/environment/door_open.png")

@export_file("*.tscn") var next_room_path: String = ""

@onready var exit_area: Area2D = $Exit
@onready var upgrade_panel: PanelContainer = $HUD/UpgradePanel
@onready var damage_button: Button = $HUD/UpgradePanel/Options/DamageButton
@onready var speed_button: Button = $HUD/UpgradePanel/Options/SpeedButton
@onready var heal_button: Button = $HUD/UpgradePanel/Options/HealButton
@onready var exit_sprite: Sprite2D = $Exit/Sprite2D

var room_cleared: bool = false
var reward_chosen: bool = false
var transitioning: bool = false


func _ready() -> void:
	exit_area.show()
	exit_sprite.texture = DOOR_CLOSED
	exit_sprite.modulate = Color.WHITE
	exit_area.monitoring = false
	upgrade_panel.hide()

	exit_area.body_entered.connect(_on_exit_body_entered)

	damage_button.pressed.connect(choose_upgrade.bind("damage"))
	speed_button.pressed.connect(choose_upgrade.bind("speed"))
	heal_button.pressed.connect(choose_upgrade.bind("heal"))


func _process(_delta: float) -> void:
	if room_cleared:
		return

	if get_tree().get_nodes_in_group("enemies").is_empty():
		room_cleared = true
		upgrade_panel.show()


func choose_upgrade(kind: String) -> void:
	if reward_chosen:
		return

	var player = get_tree().get_first_node_in_group("player")

	if not is_instance_valid(player):
		return

	match kind:
		"damage":
			GameState.damage += 1

		"speed":
			GameState.attack_interval = maxf(
				0.15,
				GameState.attack_interval * 0.85
			)
			player.attack_interval = GameState.attack_interval

		"heal":
			player.health = mini(
				player.health + 2,
				player.max_health
			)
			GameState.health = player.health

	reward_chosen = true
	upgrade_panel.hide()
	open_exit()


func open_exit() -> void:
	exit_sprite.texture = DOOR_OPEN
	exit_area.show()
	exit_area.monitoring = true
	print("Выход открыт!")


func _on_exit_body_entered(body: Node2D) -> void:
	if not reward_chosen or transitioning:
		return

	if not body.is_in_group("player"):
		return

	if next_room_path.is_empty():
		transitioning = true
		GameState.result = "Победа! Все комнаты пройдены!"

		get_tree().call_deferred(
			"change_scene_to_file",
			"res://main_menu.tscn"
		)
		return

	transitioning = true
	go_to_next_room.call_deferred()


func go_to_next_room() -> void:
	get_tree().change_scene_to_file(next_room_path)
