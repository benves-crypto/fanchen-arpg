extends Node2D

const WORLD_SIZE := Vector2(2304, 1152)
const SPAWN := Vector2(225, 638)
const EXIT := Vector2(2150, 455)
const SHRINE := Vector2(1940, 355)
const SHRINE_RADIUS := 38.0
const PATH := [Vector2(105, 655), Vector2(380, 635), Vector2(645, 560),
	Vector2(960, 565), Vector2(1200, 660), Vector2(1480, 620),
	Vector2(1780, 478), EXIT, Vector2(2220, 455)]

const GROUND := preload("res://assets/world/bamboo_ground.webp")
const PROPS := preload("res://assets/world/bamboo_props.png")
const PROP_SIZE := Vector2(128, 128)

var stage := 1
var portal_open := false
var shrine_lit := false:
	set(value):
		shrine_lit = value
		queue_redraw()
var obstacles: Array[Vector3] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7139
	# Keep the original obstacle sequence after moving ground details into the texture.
	for index in range(2000):
		rng.randi_range(12, 2290)
		rng.randi_range(12, 1138)
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
		ornament.bush = not rock and index % 5 < 3
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


func set_stage(value: int) -> void:
	stage = value
	portal_open = false
	self_modulate = [Color.WHITE, Color("#b9ccd7"), Color("#ead1b9")][stage - 1]
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(GROUND, Rect2(Vector2.ZERO, WORLD_SIZE), false)
	_draw_landmark(2, Rect2(SPAWN - Vector2(28, 28), Vector2(56, 56)))
	var ring_size := 250.0 if stage == 3 else 140.0
	_draw_landmark(3, Rect2(Vector2(1845, 475) - Vector2.ONE * ring_size / 2.0, Vector2.ONE * ring_size))
	_draw_landmark(5 if portal_open else 4, Rect2(EXIT - Vector2(74, 139), Vector2(148, 162)))
	if shrine_lit:
		draw_circle(SHRINE, SHRINE_RADIUS, Color("#193b34cc"), true, -1.0, true)
		draw_arc(SHRINE, SHRINE_RADIUS, 0.0, TAU, 48, Color("#efd590"), 2.0, true)
		_draw_landmark(2, Rect2(SHRINE - Vector2(24, 24), Vector2(48, 48)))


func _draw_landmark(index: int, bounds: Rect2) -> void:
	draw_texture_rect_region(PROPS, bounds, Rect2(Vector2(index * PROP_SIZE.x, 0), PROP_SIZE))
