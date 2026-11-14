extends Node

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://profile.json"
const BACKUP_PATH: String = "user://profile_backup.json"
const TEMP_PATH: String = "user://profile.tmp"

var coins: int = 0
var best_cleared_room: int = 0
var element_levels: Dictionary = {}
var owned_robe_ids: Array[String] = []
var equipped_robe_id: String = ""

var _saving_allowed: bool = true


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	var data: Dictionary = _read_data(SAVE_PATH)

	if not _saving_allowed:
		return

	if not data.is_empty():
		_apply_data(data)
		print(
			"Профиль загружен. Валюта: ",
			coins,
			". Рекорд: ",
			best_cleared_room
		)
		return

	data = _read_data(BACKUP_PATH)

	if not _saving_allowed:
		return

	if not data.is_empty():
		_apply_data(data)
		push_warning("Профиль восстановлен из резервной копии.")
		save_profile()
		return

	if (
		FileAccess.file_exists(SAVE_PATH)
		or FileAccess.file_exists(BACKUP_PATH)
	):
		_saving_allowed = false
		push_error(
			"Не удалось прочитать профиль. "
			+ "Файлы сохранены без изменений."
		)
		return

	if save_profile():
		print("Создан новый профиль.")


func save_profile() -> bool:
	if not _saving_allowed:
		push_error(
			"Запись профиля заблокирована: "
			+ "сначала нужно восстановить данные."
		)
		return false

	var data: Dictionary = {
		"version": SAVE_VERSION,
		"coins": coins,
		"best_cleared_room": best_cleared_room,
		"element_levels": element_levels,
		"owned_robe_ids": owned_robe_ids,
		"equipped_robe_id": equipped_robe_id
	}

	if not _valid_data(data):
		push_error(
			"Некорректные данные профиля: сохранение отменено."
		)
		return false

	var previous: Dictionary = _read_data(SAVE_PATH)

	if not _saving_allowed:
		return false

	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)

	if file == null:
		push_error("Не удалось создать временный файл профиля.")
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.flush()

	var write_error: Error = file.get_error()
	file.close()

	if write_error != OK or _read_data(TEMP_PATH).is_empty():
		push_error(
			"Не удалось записать профиль. "
			+ "Основной файл не изменён."
		)
		return false

	if not previous.is_empty():
		var backup_error: Error = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(SAVE_PATH),
			ProjectSettings.globalize_path(BACKUP_PATH)
		)

		if backup_error != OK:
			push_error(
				"Не удалось создать резервную копию. "
				+ "Сохранение отменено."
			)
			return false

	var replace_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(TEMP_PATH),
		ProjectSettings.globalize_path(SAVE_PATH)
	)

	if replace_error != OK:
		push_error("Не удалось заменить файл профиля.")
		return false

	return true


func _read_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed is Dictionary:
		return {}

	var data: Dictionary = parsed

	if (
		_whole_number(data.get("version"))
		and int(data["version"]) > SAVE_VERSION
	):
		_saving_allowed = false
		push_error(
			"Это профиль из более новой версии игры. "
			+ "Он не будет перезаписан."
		)
		return {}

	if not _valid_data(data):
		return {}

	return data


func _whole_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false

	var number: float = float(value)

	return (
		is_finite(number)
		and number >= 0.0
		and number <= 9007199254740991.0
		and number == floorf(number)
	)


func _valid_data(data: Dictionary) -> bool:
	if not _whole_number(data.get("version")):
		return false

	if int(data["version"]) != SAVE_VERSION:
		return false

	if not _whole_number(data.get("coins")):
		return false

	if not _whole_number(data.get("best_cleared_room")):
		return false

	var levels: Variant = data.get("element_levels")

	if not levels is Dictionary:
		return false

	for id in levels:
		if (
			not id is String
			or id.is_empty()
			or not _whole_number(levels[id])
		):
			return false

	var robes: Variant = data.get("owned_robe_ids")

	if not robes is Array:
		return false

	var unique: Array[String] = []

	for id in robes:
		if not id is String or id.is_empty() or unique.has(id):
			return false

		unique.append(id)

	var equipped: Variant = data.get("equipped_robe_id")

	if not equipped is String:
		return false

	return equipped.is_empty() or robes.has(equipped)


func _apply_data(data: Dictionary) -> void:
	coins = int(data["coins"])
	best_cleared_room = int(data["best_cleared_room"])

	element_levels = {}

	for id in data["element_levels"]:
		element_levels[id] = int(data["element_levels"][id])

	owned_robe_ids.assign(data["owned_robe_ids"])
	equipped_robe_id = data["equipped_robe_id"]
	
	
func record_cleared_room(room_number: int) -> bool:
	if room_number < 1:
		return false

	if room_number <= best_cleared_room:
		return true

	var previous_record: int = best_cleared_room
	best_cleared_room = room_number

	if not save_profile():
		best_cleared_room = previous_record
		push_warning("Новый рекорд не удалось сохранить.")
		return false

	print("Новый рекорд: комната ", best_cleared_room)
	return true

func try_add_coins(amount: int) -> bool:
	const MAX_SAFE_COINS: int = 9007199254740991

	if amount <= 0 or amount > MAX_SAFE_COINS:
		return false

	if coins < 0 or coins > MAX_SAFE_COINS - amount:
		return false

	var previous_coins: int = coins
	coins += amount

	if save_profile():
		return true

	coins = previous_coins
	return false

func fire_level() -> int:
	# Отсутствующий или прежний нулевой уровень — начальный.
	var stored: Variant = element_levels.get("fire", 0)

	if not _whole_number(stored):
		return -1

	var level: int = int(stored)

	if level == 0:
		return 1

	if level < 1 or level > 10:
		return -1

	return level


func fire_upgrade_cost() -> int:
	var level: int = fire_level()

	if level < 1 or level >= 10:
		return -1

	# Уровень 1 → 2 стоит 50, 2 → 3 стоит 100 и т. д.
	return level * 50


func try_upgrade_fire() -> String:
	var level: int = fire_level()

	if level < 1:
		return "invalid"

	if level >= 10:
		return "max"

	var cost: int = fire_upgrade_cost()

	if cost <= 0:
		return "invalid"

	if coins < cost:
		return "insufficient"

	# Запоминаем состояние на случай ошибки сохранения.
	var previous_coins: int = coins
	var had_fire_level: bool = element_levels.has("fire")
	var previous_fire_level: Variant = element_levels.get("fire")

	coins -= cost
	element_levels["fire"] = level + 1

	if save_profile():
		return "ok"

	# Если запись не удалась, возвращаем и деньги, и уровень.
	coins = previous_coins

	if had_fire_level:
		element_levels["fire"] = previous_fire_level
	else:
		element_levels.erase("fire")

	return "save_error"

func ice_level() -> int:
	var stored: Variant = element_levels.get("ice", 0)

	if not _whole_number(stored):
		return -1

	var level: int = int(stored)

	if level == 0:
		return 1

	if level < 1 or level > 10:
		return -1

	return level


func ice_upgrade_cost() -> int:
	var level: int = ice_level()

	if level < 1 or level >= 10:
		return -1

	return level * 50


func try_upgrade_ice() -> String:
	var level: int = ice_level()

	if level < 1:
		return "invalid"

	if level >= 10:
		return "max"

	var cost: int = ice_upgrade_cost()

	if cost <= 0:
		return "invalid"

	if coins < cost:
		return "insufficient"

	var previous_coins: int = coins
	var had_ice_level: bool = element_levels.has("ice")
	var previous_ice_level: Variant = element_levels.get("ice")

	coins -= cost
	element_levels["ice"] = level + 1

	if save_profile():
		return "ok"

	# При ошибке сохранения возвращаем прежние значения.
	coins = previous_coins

	if had_ice_level:
		element_levels["ice"] = previous_ice_level
	else:
		element_levels.erase("ice")

	return "save_error"

func water_level() -> int:
	var stored: Variant = element_levels.get("water", 0)

	if not _whole_number(stored):
		return -1

	var level: int = int(stored)

	if level == 0:
		return 1

	if level < 1 or level > 10:
		return -1

	return level


func water_upgrade_cost() -> int:
	var level: int = water_level()

	if level < 1 or level >= 10:
		return -1

	return level * 50


func try_upgrade_water() -> String:
	var level: int = water_level()

	if level < 1:
		return "invalid"

	if level >= 10:
		return "max"

	var cost: int = water_upgrade_cost()

	if cost <= 0:
		return "invalid"

	if coins < cost:
		return "insufficient"

	var previous_coins: int = coins
	var had_water_level: bool = element_levels.has("water")
	var previous_water_level: Variant = element_levels.get("water")

	coins -= cost
	element_levels["water"] = level + 1

	if save_profile():
		return "ok"

	# Если сохранение не удалось, возвращаем прежнее состояние.
	coins = previous_coins

	if had_water_level:
		element_levels["water"] = previous_water_level
	else:
		element_levels.erase("water")

	return "save_error"

func wind_level() -> int:
	var stored: Variant = element_levels.get("wind", 0)

	if not _whole_number(stored):
		return -1

	var level: int = int(stored)

	if level == 0:
		return 1

	if level < 1 or level > 10:
		return -1

	return level


func wind_upgrade_cost() -> int:
	var level: int = wind_level()

	if level < 1 or level >= 10:
		return -1

	return level * 50


func try_upgrade_wind() -> String:
	var level: int = wind_level()

	if level < 1:
		return "invalid"

	if level >= 10:
		return "max"

	var cost: int = wind_upgrade_cost()

	if cost <= 0:
		return "invalid"

	if coins < cost:
		return "insufficient"

	var previous_coins: int = coins
	var had_wind_level: bool = element_levels.has("wind")
	var previous_wind_level: Variant = element_levels.get("wind")

	coins -= cost
	element_levels["wind"] = level + 1

	if save_profile():
		return "ok"

	# При ошибке сохранения возвращаем монеты и уровень.
	coins = previous_coins

	if had_wind_level:
		element_levels["wind"] = previous_wind_level
	else:
		element_levels.erase("wind")

	return "save_error"

func dark_level() -> int:
	var stored: Variant = element_levels.get("dark", 0)

	if not _whole_number(stored):
		return -1

	var level: int = int(stored)

	if level == 0:
		return 1

	if level < 1 or level > 10:
		return -1

	return level


func dark_upgrade_cost() -> int:
	var level: int = dark_level()

	if level < 1 or level >= 10:
		return -1

	return level * 50


func try_upgrade_dark() -> String:
	var level: int = dark_level()

	if level < 1:
		return "invalid"

	if level >= 10:
		return "max"

	var cost: int = dark_upgrade_cost()

	if cost <= 0:
		return "invalid"

	if coins < cost:
		return "insufficient"

	var previous_coins: int = coins
	var had_dark_level: bool = element_levels.has("dark")
	var previous_dark_level: Variant = element_levels.get("dark")

	coins -= cost
	element_levels["dark"] = level + 1

	if save_profile():
		return "ok"

	# При ошибке сохранения возвращаем монеты и уровень.
	coins = previous_coins

	if had_dark_level:
		element_levels["dark"] = previous_dark_level
	else:
		element_levels.erase("dark")

	return "save_error"

func light_level() -> int:
	var stored: Variant = element_levels.get("light", 0)

	if not _whole_number(stored):
		return -1

	var level: int = int(stored)

	if level == 0:
		return 1

	if level < 1 or level > 10:
		return -1

	return level


func light_upgrade_cost() -> int:
	var level: int = light_level()

	if level < 1 or level >= 10:
		return -1

	return level * 50


func try_upgrade_light() -> String:
	var level: int = light_level()

	if level < 1:
		return "invalid"

	if level >= 10:
		return "max"

	var cost: int = light_upgrade_cost()

	if cost <= 0:
		return "invalid"

	if coins < cost:
		return "insufficient"

	var previous_coins: int = coins
	var had_light_level: bool = element_levels.has("light")
	var previous_light_level: Variant = element_levels.get("light")

	coins -= cost
	element_levels["light"] = level + 1

	if save_profile():
		return "ok"

	# При ошибке сохранения возвращаем монеты и уровень.
	coins = previous_coins

	if had_light_level:
		element_levels["light"] = previous_light_level
	else:
		element_levels.erase("light")

	return "save_error"

func try_buy_robe(id: String) -> String:
	const ROBES = preload("res://robe_catalog.gd")

	if not ROBES.DATA.has(id):
		return "invalid"

	if owned_robe_ids.has(id):
		return "owned"

	if coins < ROBES.PRICE:
		return "not_enough"

	var previous_coins: int = coins
	coins -= ROBES.PRICE
	owned_robe_ids.append(id)

	if not save_profile():
		coins = previous_coins
		owned_robe_ids.erase(id)
		return "save_failed"

	return "bought"


func try_equip_robe(id: String) -> String:
	const ROBES = preload("res://robe_catalog.gd")

	if not id.is_empty() and (
		not ROBES.DATA.has(id)
		or not owned_robe_ids.has(id)
	):
		return "invalid"

	if equipped_robe_id == id:
		return "equipped"

	var previous: String = equipped_robe_id
	equipped_robe_id = id

	if not save_profile():
		equipped_robe_id = previous
		return "save_failed"

	return "equipped"
