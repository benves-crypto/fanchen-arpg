extends Node

signal damaged(amount: int)
signal died

@export var max_hp := 100
@export var defense := 0
@onready var hp := max_hp
var invulnerable := false


func hurt(power: int) -> bool:
	if hp <= 0 or invulnerable or power <= 0:
		return false
	var amount := mini(hp, maxi(1, power - defense))
	hp -= amount
	damaged.emit(amount)
	if hp == 0:
		died.emit()
	return true


func heal(amount: int) -> void:
	if hp > 0:
		hp = mini(max_hp, hp + maxi(0, amount))
