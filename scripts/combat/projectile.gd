extends Node2D

var direction := Vector2.RIGHT
var speed := 440.0
var power := 28
var targets := 4
var lifetime := 1.05
var color := Color("#a8fff1")


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var next_position := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next_position, 1 | targets)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = next_position
		return
	var body: Object = hit.collider
	if body.has_method("take_hit"):
		body.take_hit(power)
	queue_free()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, direction.angle())
	draw_colored_polygon(PackedVector2Array([Vector2(-24, -5), Vector2(6, -8),
		Vector2(21, 0), Vector2(6, 8), Vector2(-24, 5), Vector2(-11, 0)]), color.darkened(0.4))
	draw_rect(Rect2(-9, -3, 23, 6), color)
