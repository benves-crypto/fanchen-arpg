extends Area2D

signal collected

var age := 0.0
var taken := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	var collision := CollisionShape2D.new()
	collision.shape = circle
	add_child(collision)
	body_entered.connect(_collect)


func _collect(player: Node2D) -> void:
	if taken or player.vitals.hp <= 0:
		return
	taken = true
	player.vitals.heal(28)
	player.mp = minf(player.max_mp, player.mp + 12.0)
	collected.emit()
	queue_free()


func _process(delta: float) -> void:
	age += delta
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 18, Color("#e2b46d40"))
	var y := sin(age * 4.0) * 3.0
	draw_rect(Rect2(-8, y - 10, 16, 20), Color("#3d3a35"))
	draw_rect(Rect2(-6, y - 4, 12, 12), Color("#e39968"))
	draw_rect(Rect2(-4, y - 13, 8, 5), Color("#e7cb86"))
	draw_rect(Rect2(-4, y - 2, 3, 6), Color("#ffe9bb"))
