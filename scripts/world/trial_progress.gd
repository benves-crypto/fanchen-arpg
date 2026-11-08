extends RefCounted

const REQUIRED := 4

var defeated_regular := 0
var elite_defeated := false
var complete := false


func record_defeat(elite: bool) -> void:
	if elite:
		elite_defeated = elite_unlocked()
	else:
		defeated_regular = mini(REQUIRED, defeated_regular + 1)


func elite_unlocked() -> bool:
	return defeated_regular >= REQUIRED


func enter_exit() -> bool:
	if not elite_defeated or complete:
		return false
	complete = true
	return true


func objective() -> String:
	if not elite_unlocked():
		return "清理竹径  %d/%d  ·  沿路向东" % [defeated_regular, REQUIRED]
	if not elite_defeated:
		return "前往东侧石环，击败狼妖"
	return "穿过东侧试炼门"
