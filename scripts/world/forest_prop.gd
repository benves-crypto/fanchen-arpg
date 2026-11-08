extends Node2D

const PROPS := preload("res://assets/world/bamboo_props.png")
const BUSHES := [
	preload("res://assets/world/bush_green.png"),
	preload("res://assets/world/bush_leafy.png"),
	preload("res://assets/world/bush_flowering.png"),
]

var rock := false
var variant := 0
var bush := false


func _draw() -> void:
	draw_set_transform(Vector2(3, 4), 0, Vector2(1, 0.52))
	draw_circle(Vector2.ZERO, 28, Color("#182f28a0"))
	draw_set_transform(Vector2.ZERO)
	if bush:
		var texture: Texture2D = BUSHES[variant]
		var size := texture.get_size() * 0.64
		draw_texture_rect(texture, Rect2(Vector2(-size.x / 2.0, 8.0 - size.y), size), false)
	elif rock:
		draw_texture_rect_region(PROPS, Rect2(-29, -49, 58, 66), Rect2(128, 0, 128, 128))
	else:
		var height := 87.0 + variant * 7.0
		var width := 63.0 + variant * 4.0
		draw_texture_rect_region(PROPS, Rect2(-width / 2.0, 9.0 - height, width, height),
			Rect2(0, 0, 128, 128))
