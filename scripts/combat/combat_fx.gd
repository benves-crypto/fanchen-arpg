extends RefCounted

enum Clip { SWORD, MAGIC, CLAW, FLAME_CLAW, POISON, FIRE_TRAIL, HIT }

const ATLAS := preload("res://assets/effects/combat_fx.webp")
const CELL := 128
const FRAME_COUNT := 8


static func draw_frame(canvas: CanvasItem, clip: Clip, progress: float, bounds: Rect2,
		tint := Color.WHITE) -> void:
	var frame := clampi(int(progress * FRAME_COUNT), 0, FRAME_COUNT - 1)
	var source := Rect2(frame * CELL, clip * CELL, CELL, CELL)
	canvas.draw_texture_rect_region(ATLAS, bounds, source, tint)
