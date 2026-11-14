extends RefCounted

const NORMAL_AMOUNTS: Array[int] = [3, 4, 5, 6, 7]
const NORMAL_WEIGHTS: Array[int] = [50, 25, 15, 8, 2]

const BOSS_AMOUNTS: Array[int] = [7, 8, 9, 10]
const BOSS_WEIGHTS: Array[int] = [50, 30, 18, 2]


static func make_plan(
	room_number: int,
	is_boss: bool,
	run_seed: int
) -> Dictionary:
	var has_book: bool = room_number % 3 == 0
	var has_chest: bool = is_boss or not has_book

	var book_rng := RandomNumberGenerator.new()
	book_rng.seed = run_seed + room_number * 8191 + 557

	if is_boss and not has_book:
		has_book = book_rng.randi_range(0, 1) == 1

	var amount: int = 0

	if has_chest:
		var coin_rng := RandomNumberGenerator.new()
		coin_rng.seed = run_seed + room_number * 8191 + 991

		if is_boss:
			amount = roll_amount(
				coin_rng, BOSS_AMOUNTS, BOSS_WEIGHTS
			)
		else:
			amount = roll_amount(
				coin_rng, NORMAL_AMOUNTS, NORMAL_WEIGHTS
			)

	return {
		"book": has_book,
		"chest": has_chest,
		"coins": amount
	}


static func roll_amount(
	random: RandomNumberGenerator,
	amounts: Array[int],
	weights: Array[int]
) -> int:
	var roll: int = random.randi_range(1, 100)
	var threshold: int = 0

	for index in range(amounts.size()):
		threshold += weights[index]

		if roll <= threshold:
			return amounts[index]

	return amounts[0]
