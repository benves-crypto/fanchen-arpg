extends Node2D

const PlayerScene := preload("res://scenes/actors/player.tscn")
const EnemyScene := preload("res://scenes/actors/enemy.tscn")
const Enemy := preload("res://scripts/actors/enemy.gd")
const Grove := preload("res://scripts/world/bamboo_grove.gd")
const Shot := preload("res://scripts/combat/projectile.gd")
const Potion := preload("res://scripts/world/potion.gd")
const Progress := preload("res://scripts/world/trial_progress.gd")

@onready var grove := $Grove
@onready var actors := $Grove/Scenery
@onready var hud := $Interface/HUD

var progress := Progress.new()
var player
var elite
var elapsed := 0.0
var potions := 0
var earned_xp := 0
var outcome := ""
var exit_area: Area2D


func _ready() -> void:
	player = PlayerScene.instantiate()
	player.position = Grove.SPAWN
	actors.add_child(player)
	player.projectile_requested.connect(_fire_player)
	player.defeated.connect(_lose)
	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(Grove.WORLD_SIZE.x)
	camera.limit_bottom = int(Grove.WORLD_SIZE.y)
	player.add_child(camera)
	_spawn(Enemy.Kind.WOLF, Vector2(510, 610))
	_spawn(Enemy.Kind.SPIDER, Vector2(820, 505))
	_spawn(Enemy.Kind.WOLF, Vector2(1110, 675))
	_spawn(Enemy.Kind.SPIDER, Vector2(1420, 570))
	elite = _spawn(Enemy.Kind.ELITE, Vector2(1845, 475))
	hud.bind(self)
	exit_area = Area2D.new()
	exit_area.position = Grove.EXIT
	exit_area.collision_layer = 0
	exit_area.collision_mask = 2
	var circle := CircleShape2D.new()
	circle.radius = 33.0
	var shape := CollisionShape2D.new()
	shape.shape = circle
	exit_area.add_child(shape)
	exit_area.body_entered.connect(_enter_exit)
	add_child(exit_area)


func _process(delta: float) -> void:
	elapsed += delta


func _spawn(kind: int, point: Vector2) -> CharacterBody2D:
	var enemy := EnemyScene.instantiate()
	enemy.kind = kind
	enemy.target = player
	enemy.position = point
	actors.add_child(enemy)
	enemy.defeated.connect(_enemy_down)
	enemy.projectile_requested.connect(_fire_poison)
	return enemy


func _fire_player(origin: Vector2, direction: Vector2, power: int) -> void:
	_fire(origin, direction, power, true)


func _fire_poison(origin: Vector2, direction: Vector2, power: int) -> void:
	_fire(origin, direction, power, false)


func _fire(origin: Vector2, direction: Vector2, power: int, friendly: bool) -> void:
	var shot := Shot.new()
	shot.position = origin
	shot.direction = direction
	shot.power = power
	shot.targets = 4 if friendly else 2
	if not friendly:
		shot.color = Color("#d3e98a")
		shot.speed = 270.0
		shot.lifetime = 1.45
	add_child(shot)


func _enemy_down(enemy: CharacterBody2D) -> void:
	var reward: int = enemy.profile.xp
	earned_xp += reward
	player.gain_xp(reward)
	var is_elite: bool = enemy.kind == Enemy.Kind.ELITE
	progress.record_defeat(is_elite)
	if is_elite:
		grove.unlock_exit()
		if exit_area.overlaps_body(player):
			_enter_exit(player)
	elif progress.elite_unlocked():
		elite.awaken()
	var potion := Potion.new()
	potion.position = enemy.global_position
	potion.collected.connect(func() -> void: potions += 1)
	actors.call_deferred("add_child", potion)


func _enter_exit(_body: Node2D) -> void:
	if progress.enter_exit():
		_finish("试炼完成")


func _lose() -> void:
	_finish("试炼失败")


func _finish(result: String) -> void:
	outcome = result
	hud.show_result(result)
	get_tree().paused = true


func restart() -> void:
	get_tree().paused = false
	get_tree().call_deferred("reload_current_scene")
