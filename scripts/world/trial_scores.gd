extends RefCounted

const SAVE_PATH := "user://bamboo_scores.cfg"
const VERSION := 1
const LIMIT := 5
const DIFFICULTY_NAMES := ["普通", "困难", "挑战 1", "挑战 2", "挑战 3", "挑战 4"]
const MAX_DIFFICULTY := 5
const TECHNIQUE_LIMIT := 4000

var records: Array[Dictionary] = []
var highest_cleared := -1
var _path: String


func _init(path := SAVE_PATH) -> void:
	_path = path
	if not _path.is_empty() and not _read(_path):
		_read(_path + ".bak")


static func calculate(damage: int, technique: int, cleared: int, seconds: float,
		shrine_cleared: bool) -> Dictionary:
	var score := {
		"damage": damage * 10,
		"technique": mini(TECHNIQUE_LIMIT, technique),
		"progress": cleared * 2000,
		"time": maxi(0, 3500 - floori(seconds * 15.0)) if cleared == 3 else 0,
		"shrine": 1000 if shrine_cleared else 0,
	}
	score.total = score.damage + score.technique + score.progress + score.time + score.shrine
	score.grade = grade(score.total) if cleared == 3 else "未通关"
	return score


static func grade(points: int) -> String:
	if points >= 20000:
		return "S"
	if points >= 16000:
		return "A"
	if points >= 12000:
		return "B"
	return "C"


func highest_unlocked() -> int:
	return mini(highest_cleared + 1, MAX_DIFFICULTY)


func records_for(difficulty: int) -> Array[Dictionary]:
	return records.filter(func(entry: Dictionary) -> bool: return entry.difficulty == difficulty)


func record(points: int, milliseconds: int, difficulty := 0) -> Error:
	if difficulty < 0 or difficulty > highest_unlocked():
		return ERR_INVALID_PARAMETER
	var previous_records := records.duplicate()
	var previous_clear := highest_cleared
	highest_cleared = maxi(highest_cleared, difficulty)
	records.append({"points": points, "ms": milliseconds, "difficulty": difficulty})
	_sort()
	if _path.is_empty():
		return OK
	var error := _save()
	if error != OK:
		records = previous_records
		highest_cleared = previous_clear
	return error


func _save() -> Error:
	var config := ConfigFile.new()
	config.set_value("bamboo", "version", VERSION)
	config.set_value("bamboo", "highest_cleared", highest_cleared)
	config.set_value("bamboo", "records", records)
	var temporary := _path + ".tmp"
	var error := config.save(temporary)
	if error != OK:
		return error
	var previous := ConfigFile.new()
	if previous.load(_path) == OK and previous.get_value("bamboo", "version", 0) == VERSION:
		error = DirAccess.rename_absolute(_path, _path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(temporary, _path)


func _read(path: String) -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK or config.get_value("bamboo", "version", 0) != VERSION:
		return false
	var stored: Variant = config.get_value("bamboo", "records", null)
	if not stored is Array:
		return false
	for entry in stored:
		if not entry is Dictionary:
			continue
		var points: Variant = entry.get("points")
		var milliseconds: Variant = entry.get("ms")
		var difficulty: Variant = entry.get("difficulty", 0)
		if (points is int and milliseconds is int and points > 0 and milliseconds >= 0
				and difficulty is int and difficulty >= 0 and difficulty <= MAX_DIFFICULTY):
			records.append({"points": points, "ms": milliseconds, "difficulty": difficulty})
			highest_cleared = maxi(highest_cleared, difficulty)
	var stored_clear: Variant = config.get_value("bamboo", "highest_cleared", -1)
	if stored_clear is int and stored_clear >= -1 and stored_clear <= MAX_DIFFICULTY:
		highest_cleared = maxi(highest_cleared, stored_clear)
	_sort()
	return true


func _sort() -> void:
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.ms < b.ms if a.points == b.points else a.points > b.points
	)
	var counts: Array[int] = []
	counts.resize(DIFFICULTY_NAMES.size())
	for difficulty in range(counts.size()):
		counts[difficulty] = 0
	records = records.filter(func(entry: Dictionary) -> bool:
		counts[entry.difficulty] += 1
		return counts[entry.difficulty] <= LIMIT
	)
