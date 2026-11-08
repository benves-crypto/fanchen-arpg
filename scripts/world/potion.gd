extends Area2D

signal collected

const PROPS := preload("res://assets/world/bamboo_props.png")

var item_texture: Texture2D
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
	collected.emit()
	queue_free()


func _process(delta: float) -> void:
	age += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(age * 4.0) * 3.0
	if item_texture:
		var size := item_texture.get_size() * 0.75
		draw_texture_rect(item_texture, Rect2(Vector2(-size.x / 2.0, -size.y + bob), size), false)
		return
	draw_texture_rect_region(PROPS, Rect2(-25, -36 + bob, 50, 50), Rect2(768, 0, 128, 128))
