extends Node2D

const FX := preload("res://scripts/combat/combat_fx.gd")


class Impact:
	var point: Vector2
	var label_height: float
	var amount: String
	var critical: bool
	var color: Color
	var angle: float
	var age := 0.0


class ReactionBurst:
	var point: Vector2
	var direction: Vector2
	var swap: bool
	var follow_up: bool
	var age := 0.0


const REACTION_DURATION := 0.38

var impacts: Array[Impact] = []
var reactions: Array[ReactionBurst] = []
@onready var font := ThemeDB.fallback_font


func show_hit(point: Vector2, height: float, amount: int, critical: bool, player_hurt: bool) -> void:
	var impact := Impact.new()
	impact.point = to_local(point)
	impact.label_height = height
	impact.amount = "%d!" % amount if critical else str(amount)
	impact.critical = critical
	impact.color = Color("#ffe36b") if critical else Color("#ff8f7e") if player_hurt else Color("#fff4d5")
	impact.angle = randf_range(-0.55, 0.55)
	if impacts.size() >= 32:
		impacts.pop_front()
	impacts.append(impact)
	queue_redraw()


func show_reaction(point: Vector2, direction: Vector2, swap: bool, follow_up: bool) -> void:
	var burst := ReactionBurst.new()
	burst.point = to_local(point)
	burst.direction = direction
	burst.swap = swap
	burst.follow_up = follow_up
	reactions.append(burst)
	queue_redraw()


func _process(delta: float) -> void:
	if impacts.is_empty() and reactions.is_empty():
		return
	for index in range(impacts.size() - 1, -1, -1):
		var impact := impacts[index]
		impact.age += delta
		if impact.age >= (0.75 if impact.critical else 0.58):
			impacts.remove_at(index)
	for index in range(reactions.size() - 1, -1, -1):
		reactions[index].age += delta
		if reactions[index].age >= REACTION_DURATION:
			reactions.remove_at(index)
	queue_redraw()


func _draw() -> void:
	for burst in reactions:
		_draw_reaction(burst)
	for impact in impacts:
		if impact.age < 0.25:
			_draw_sparks(impact)
		var t := impact.age / (0.75 if impact.critical else 0.58)
		var rise := 1.0 - (1.0 - t) * (1.0 - t)
		var center := impact.point + Vector2(impact.angle * 34.0 * rise,
			-impact.label_height - 34.0 * rise)
		var size := roundi((34.0 if impact.critical else 24.0) * (1.0 + 0.32 * sin(PI * minf(t * 5.0, 1.0))))
		var alpha := 1.0 - smoothstep(0.58, 1.0, t)
		var width := font.get_string_size(impact.amount, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var baseline := center - Vector2(width * 0.5, 0.0)
		draw_string_outline(font, baseline, impact.amount, HORIZONTAL_ALIGNMENT_LEFT, -1,
			size, 7, Color(0.12, 0.07, 0.09, alpha))
		draw_string(font, baseline, impact.amount, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(impact.color, alpha))


func _draw_reaction(burst: ReactionBurst) -> void:
	var t := burst.age / REACTION_DURATION
	var travel := 1.0 - (1.0 - t) ** 3
	var fade := 1.0 - smoothstep(0.10, 1.0, t)
	var center := burst.point + Vector2(0, -31)
	var tint := Color("#ffcf71") if burst.swap else Color("#82ffde")
	var radius := lerpf(18.0, 86.0 if burst.follow_up else 69.0, travel)
	var angle := burst.direction.angle()
	if burst.swap and not burst.follow_up:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-10, 27),
			center + Vector2(-23, -92), center + Vector2(23, -92), center + Vector2(10, 27)]),
			Color(tint, fade * 0.21))
		draw_line(center + Vector2(0, -82), center + Vector2(0, 23),
			Color("#fff2c7", fade), 3.0, true)
	if burst.follow_up:
		draw_arc(center, radius, angle - 0.92, angle + 0.92, 24, Color(tint, fade), 5.0, true)
	else:
		draw_arc(center, radius, angle + 0.15, angle + TAU - 0.15, 36, Color(tint, fade), 3.0, true)
	for index in range(8):
		var ray := Vector2.from_angle(index * TAU / 8.0 + angle)
		if burst.follow_up and ray.dot(burst.direction) < 0.4:
			continue
		var spark := center + ray * radius
		draw_line(spark, spark + ray * (15.0 * fade), Color(tint, fade), 2.0, true)
	if not burst.swap and not burst.follow_up:
		for index in range(3):
			var start := center + Vector2(0, index * 13 - 12) - burst.direction * (20.0 + travel * 28.0)
			draw_line(start, start - burst.direction * (35.0 * fade), Color(tint, fade * 0.78), 3.0, true)


func _draw_sparks(impact: Impact) -> void:
	var t := impact.age / 0.25
	var alpha := 1.0 - t
	var center := impact.point + Vector2(0.0, -28.0)
	var size := 124.0 if impact.critical else 84.0
	FX.draw_frame(self, FX.Clip.HIT, t, Rect2(center - Vector2.ONE * size * 0.5,
		Vector2.ONE * size), Color(impact.color, alpha))
	var count := 10 if impact.critical else 5
	var distance := lerpf(10.0, size * 0.53, t)
	for index in range(count):
		var direction := Vector2.from_angle(index * TAU / count + impact.angle)
		var length := (18.0 if impact.critical else 9.0) * alpha
		draw_line(center + direction * distance, center + direction * (distance + length),
			Color(impact.color, alpha), 3.0 if impact.critical else 2.0, true)
	if impact.critical:
		draw_arc(center, lerpf(13.0, 58.0, t), 0.0, TAU, 28, Color(impact.color, alpha * 0.85), 3.0, true)
