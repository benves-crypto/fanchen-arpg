extends Node2D

var rock := false
var variant := 0


func _draw() -> void:
	draw_set_transform(Vector2(3, 4), 0, Vector2(1, 0.52))
	draw_circle(Vector2.ZERO, 28, Color("#182f28a0"))
	draw_set_transform(Vector2.ZERO)
	if rock:
		draw_colored_polygon(PackedVector2Array([Vector2(-23, 1), Vector2(-18, -16),
			Vector2(-7, -24), Vector2(13, -22), Vector2(23, -7), Vector2(18, 9), Vector2(-11, 11)]),
			Color("#687c71"))
		draw_colored_polygon(PackedVector2Array([Vector2(-18, -16), Vector2(-7, -24),
			Vector2(13, -22), Vector2(6, -12), Vector2(-9, -7)]), Color("#8c9b7e"))
		draw_rect(Rect2(-12, 3, 23, 5), Color("#43584d"))
		return
	for index in range(3):
		var x := -11.0 + 10 * index
		var top := -63.0 - (index + variant) % 3 * 12.0
		var tip := Vector2(x + (index - 1) * 9, top)
		draw_line(Vector2(x, 4), tip, Color("#213a2d"), 8)
		draw_line(Vector2(x - 1, 3), tip - Vector2(1, 0), Color("#6a905a"), 4)
		for joint in range(1, 5):
			var p := Vector2(x, 4).lerp(tip, joint / 5.0)
			draw_rect(Rect2(p - Vector2(3, 0), Vector2(7, 3)), Color("#36583c"))
		var leaf := Color("#4f8051") if index % 2 == 0 else Color("#396a46")
		for bough in range(2):
			var start := tip + Vector2(0, 9 + bough * 14)
			var side := -1.0 if (index + bough) % 2 == 0 else 1.0
			draw_colored_polygon(PackedVector2Array([start, start + Vector2(24 * side, -10),
				start + Vector2(31 * side, -8), start + Vector2(12 * side, 1)]), leaf)
