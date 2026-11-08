extends Node2D

const WORLD_SIZE := Vector2(2304, 1152)
const SPAWN := Vector2(225, 638)
const EXIT := Vector2(2150, 455)
const PATH := [Vector2(105, 655), Vector2(380, 635), Vector2(645, 560),
	Vector2(960, 565), Vector2(1200, 660), Vector2(1480, 620),
	Vector2(1780, 478), EXIT, Vector2(2220, 455)]

var portal_open := false
var grass := PackedVector2Array()
var obstacles: Array[Vector3] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7139
	for index in range(2000):
		grass.append(Vector2(rng.randi_range(12, 2290), rng.randi_range(12, 1138)))
	for index in range(145):
		var point := Vector2(rng.randi_range(35, 2265), rng.randi_range(55, 1100))
		if _road_distance(point) < 140 or _near_obstacle(point):
			continue
		var rock := index % 4 == 0
		var radius := 21.0 if rock else 15.0
		obstacles.append(Vector3(point.x, point.y, 1.0 if rock else 0.0))
		_collider(point, Vector2.ZERO, radius)
		var ornament := Node2D.new()
		ornament.set_script(preload("res://scripts/world/forest_prop.gd"))
		ornament.position = point
		ornament.rock = rock
		ornament.variant = index % 3
		$Scenery.add_child(ornament)
	_collider(Vector2(1152, -16), Vector2(2368, 32))
	_collider(Vector2(1152, 1168), Vector2(2368, 32))
	_collider(Vector2(-16, 576), Vector2(32, 1152))
	_collider(Vector2(2320, 576), Vector2(32, 1152))


func _road_distance(point: Vector2) -> float:
	var nearest := INF
	for index in range(PATH.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(point, PATH[index], PATH[index + 1])
		nearest = minf(nearest, point.distance_to(closest))
	return nearest


func _near_obstacle(point: Vector2) -> bool:
	for obstacle in obstacles:
		if point.distance_squared_to(Vector2(obstacle.x, obstacle.y)) < 2100.0:
			return true
	return false


func _collider(point: Vector2, size: Vector2, radius := 0.0) -> void:
	var body := StaticBody2D.new()
	body.position = point
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	if radius > 0.0:
		var circle := CircleShape2D.new()
		circle.radius = radius
		collision.shape = circle
	else:
		var box := RectangleShape2D.new()
		box.size = size
		collision.shape = box
	body.add_child(collision)
	add_child(body)


func unlock_exit() -> void:
	portal_open = true
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#254439"))
	_paint_road(141.0, Color("#3a5743"))
	_paint_road(110.0, Color("#53644a"))
	_paint_road(91.0, Color("#59694e"))
	_paint_road(54.0, Color("#627056"))
	for point in grass:
		var near_road := _road_distance(point) < 55.0
		var color := Color("#798061") if near_road else Color("#365644")
		draw_rect(Rect2(point, Vector2(4, 2) if near_road else Vector2(3, 7)), color)
		if not near_road:
			draw_rect(Rect2(point + Vector2(4, 4), Vector2(4, 3)), Color("#4a6650"))
	_marker(SPAWN, Color("#9ac9a1"), 27)
	_marker(Vector2(1845, 475), Color("#a88559"), 68)
	var portal := Color("#a3ffe0") if portal_open else Color("#8d8e75")
	_marker(EXIT, portal, 34)
	draw_rect(Rect2(EXIT + Vector2(-30, -59), Vector2(8, 66)), portal.darkened(0.25))
	draw_rect(Rect2(EXIT + Vector2(22, -59), Vector2(8, 66)), portal.darkened(0.25))
	draw_rect(Rect2(EXIT + Vector2(-38, -59), Vector2(76, 8)), portal)
	draw_rect(Rect2(EXIT + Vector2(-29, -72), Vector2(58, 9)), Color("#252f2a"))
	if portal_open:
		draw_rect(Rect2(EXIT + Vector2(-22, -50), Vector2(44, 51)), Color("#a3ffe062"))


func _paint_road(width: float, color: Color) -> void:
	for index in range(PATH.size() - 1):
		draw_line(PATH[index], PATH[index + 1], color, width)
		draw_circle(PATH[index], width / 2.0, color)
	draw_circle(PATH[-1], width / 2.0, color)


func _marker(point: Vector2, tint: Color, radius: int) -> void:
	draw_arc(point, radius, 0, TAU, 36, tint, 2.0)
	for index in range(8):
		var spoke := point + Vector2.from_angle(index * TAU / 8.0) * radius
		draw_rect(Rect2(spoke - Vector2(3, 3), Vector2(6, 6)), tint)
