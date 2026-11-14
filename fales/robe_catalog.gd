extends RefCounted

const PRICE: int = 100
const IDS: Array[String] = ["green", "blue", "red"]

const DATA: Dictionary = {
	"green": {
		"name": "Зелёная мантия",
		"bonus": "+8% к скорости передвижения",
		"idle_body": preload("res://assets/characters/robes/green/mage_idle_body.png"),
		"walk_body": preload("res://assets/characters/robes/green/mage_walk_body.png"),
		"idle_arm": preload("res://assets/characters/robes/green/mage_idle_arm_shot.png"),
		"walk_arm": preload("res://assets/characters/robes/green/mage_walk_arm_shot.png"),
		"scale": 1.212,
		"flash": Vector2(18, 11)
	},
	"blue": {
		"name": "Синяя мантия",
		"bonus": "+1 к максимальному здоровью",
		"idle_body": preload("res://assets/characters/robes/blue/mage_idle_body.png"),
		"walk_body": preload("res://assets/characters/robes/blue/mage_walk_body.png"),
		"idle_arm": preload("res://assets/characters/robes/blue/mage_idle_arm_shot.png"),
		"walk_arm": preload("res://assets/characters/robes/blue/mage_walk_arm_shot.png"),
		"scale": 1.121,
		"flash": Vector2(19, 11)
	},
	"red": {
		"name": "Красная мантия",
		"bonus": "+10% к урону обычного выстрела",
		"idle_body": preload("res://assets/characters/robes/red/mage_idle_body.png"),
		"walk_body": preload("res://assets/characters/robes/red/mage_walk_body.png"),
		"idle_arm": preload("res://assets/characters/robes/red/mage_idle_arm_shot.png"),
		"walk_arm": preload("res://assets/characters/robes/red/mage_walk_arm_shot.png"),
		"scale": 1.165,
		"flash": Vector2(19, 11)
	}
}
