extends RefCounted

var required_regular: int

var defeated_regular := 0
var elite_defeated := false
var complete := false


func _init(required := 4) -> void:
	required_regular = required


func record_defeat(elite: bool) -> void:
	if elite:
		elite_defeated = elite_unlocked()
	else:
		defeated_regular = mini(required_regular, defeated_regular + 1)


func elite_unlocked() -> bool:
	return defeated_regular >= required_regular


func enter_exit() -> bool:
	if not elite_defeated or complete:
		return false
	complete = true
	return true


func objective(guardian := "熔甲兽") -> String:
	if not elite_unlocked():
		return "清理竹径  %d/%d  ·  沿路向东" % [defeated_regular, required_regular]
	if not elite_defeated:
		return "前往东侧石环，击败%s" % guardian
	return "穿过东侧试炼门"
