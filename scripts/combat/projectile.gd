extends Node2D

signal hit_target

enum Form { BOLT, CHARGED, LANCE, FAN, NOVA, COUNTER, TWIN_BOLT, SEAL, LANTERN_ASSIST }

const FX := preload("res://scripts/combat/combat_fx.gd")
const PUMPKIN_TEXTURE := preload("res://assets/actors/pumpkin_shot.webp")
const POISON_SPEED := 270.0
const POISON_LIFETIME := 1.45
const IMPACT_DURATION := 0.19

var reaction_claimed := false
var caster: Node2D
var direction := Vector2.RIGHT
var speed := 440.0
var power := 28
var targets := 4
var lifetime := 1.05
var age := 0.0
var poison := false
var pumpkin := false
var magic := false
var form := Form.BOLT
var resolve_hit: Callable
var impact_time := 0.0
var launch_delay := 0.0


func configure_magic(spell: Form, cultivation: bool) -> void:
	form = spell
	magic = cultivation
	pumpkin = not cultivation
	match form:
		Form.LANTERN_ASSIST:
			speed = 1150.0
			lifetime = 0.35
		Form.BOLT:
			speed = 640.0
			lifetime = 0.52
		Form.TWIN_BOLT:
			speed = 695.0
			lifetime = 0.5
		Form.SEAL:
			speed = 530.0
			lifetime = 0.68
		Form.CHARGED:
			speed = 760.0
			lifetime = 0.67
		Form.LANCE:
			speed = 760.0
			lifetime = 0.72
		Form.FAN:
			speed = 590.0
			lifetime = 0.70
		Form.COUNTER:
			speed = 880.0
			lifetime = 0.56
		Form.NOVA:
			speed = 540.0
			lifetime = 0.85
	if magic:
		z_index = 2


func reaction_eta(fighter: CharacterBody2D, window: float) -> float:
	if not poison or reaction_claimed or is_queued_for_deletion() or impact_time > 0.0:
		return INF
	return poison_eta(get_world_2d(), global_position, direction, fighter, 0.0, minf(lifetime, window))


func reaction_source() -> Node2D:
	return caster if is_instance_valid(caster) else null


static func poison_eta(world: World2D, origin: Vector2, heading: Vector2,
		fighter: CharacterBody2D, delay: float, window: float) -> float:
	if delay >= window:
		return INF
	var query := PhysicsRayQueryParameters2D.create(origin,
		origin + heading * POISON_SPEED * (window - delay), 3)
	query.hit_from_inside = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != fighter:
		return INF
	return delay + origin.distance_to(hit.position) / POISON_SPEED


func _physics_process(delta: float) -> void:
	if launch_delay > 0.0:
		launch_delay = maxf(0.0, launch_delay - delta)
		queue_redraw()
		return
	if impact_time > 0.0:
		impact_time -= delta
		if impact_time <= 0.0:
			queue_free()
		queue_redraw()
		return
	age += delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var next_position := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next_position, 1 | targets)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = next_position
		queue_redraw()
		return
	var body: Object = hit.collider
	if body.has_method("take_hit"):
		var damaged: bool
		if poison:
			damaged = body.take_hit(power, -direction)
		else:
			damaged = resolve_hit.call(body, power) if resolve_hit.is_valid() else body.take_hit(power)
		if damaged:
			hit_target.emit()
	if magic:
		global_position = hit.position
		impact_time = IMPACT_DURATION
		queue_redraw()
	else:
		queue_free()


func _draw() -> void:
	var progress := fposmod(age, 0.36) / 0.36
	var center := Vector2(0, -12)
	draw_set_transform(center, direction.angle())
	if launch_delay > 0.0:
		draw_arc(Vector2.ZERO, lerpf(4.0, 13.0, launch_delay / 0.09), 0, TAU, 24,
			Color("#b6f4ff"), 2.0, true)
	elif poison:
		draw_colored_polygon(PackedVector2Array([Vector2(-48, 0), Vector2(-8, -9),
			Vector2(12, 0), Vector2(-8, 9)]), Color("#88e72ca0"))
		FX.draw_frame(self, FX.Clip.POISON, progress, Rect2(-29, -29, 58, 58))
		draw_circle(Vector2.ZERO, 5.0, Color("#ecffae"))
	elif form == Form.COUNTER and not (magic or pumpkin):
		draw_colored_polygon(PackedVector2Array([Vector2(-65, 0), Vector2(-7, -9),
			Vector2(20, 0), Vector2(-7, 9)]), Color("#a8ffeb"))
		draw_line(Vector2(-40, 0), Vector2(16, 0), Color("#fff6d8"), 3.0, true)
	elif magic:
		_draw_magic()
	elif pumpkin:
		FX.draw_frame(self, FX.Clip.FIRE_TRAIL, progress, Rect2(-50, -32, 64, 64))
		draw_set_transform(center, age * 9.0)
		draw_texture_rect(PUMPKIN_TEXTURE, Rect2(-16, -15, 32, 30), false)
	else:
		FX.draw_frame(self, FX.Clip.SWORD, progress, Rect2(-59, -54, 108, 108))


func _draw_magic() -> void:
	var tint := magic_color(form)
	if impact_time > 0.0:
		var fade := impact_time / IMPACT_DURATION
		var radius := lerpf(45.0 if form == Form.SEAL else 29.0, 5.0, fade)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(tint, fade), 2.0, true)
		for index in range(5):
			var spark := Vector2.from_angle(index * TAU / 5.0) * radius
			draw_line(spark * 0.7, spark * 1.3, Color(tint, fade), 2.0, true)
		if form == Form.SEAL:
			draw_arc(Vector2.ZERO, radius * 0.72, PI / 4.0, TAU + PI / 4.0, 4,
				Color("#fff3cb", fade), 2.5, true)
		return
	if form == Form.SEAL:
		draw_colored_polygon(PackedVector2Array([Vector2(-55, 0), Vector2(-8, -12),
			Vector2(16, 0), Vector2(-8, 12)]), Color(tint, 0.38))
		draw_arc(Vector2.ZERO, 12.0, age * 9.0, TAU + age * 9.0, 4, tint, 2.8, true)
		draw_circle(Vector2.ZERO, 4.0, Color("#fff4da"), true, -1.0, true)
		return
	var length := 34.0
	var width := 7.0
	match form:
		Form.LANTERN_ASSIST:
			length = 86.0
			width = 3.5
		Form.TWIN_BOLT:
			length = 43.0
			width = 4.0
		Form.CHARGED:
			length = 74.0
			width = 6.0
		Form.NOVA:
			length = 48.0
			width = 12.0
		Form.LANCE, Form.COUNTER:
			length = 76.0
			width = 9.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-length, 0), Vector2(-5, -width), Vector2(14, 0), Vector2(-5, width)
	]), Color(tint, 0.42))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-length * 0.55, 0), Vector2(-3, -width * 0.62), Vector2(11, 0),
		Vector2(-3, width * 0.62)
	]), tint)
	draw_circle(Vector2(3, 0), width * 0.36, Color("#fff4da"), true, -1.0, true)
	for index in range(2):
		var phase := age * 15.0 + PI * index
		draw_circle(Vector2(-length * 0.45, sin(phase) * width), 2.0, tint, true, -1.0, true)


static func magic_color(spell: Form) -> Color:
	match spell:
		Form.LANTERN_ASSIST, Form.CHARGED:
			return Color("#b6f4ff")
		Form.TWIN_BOLT:
			return Color("#b6d4ff")
		Form.SEAL:
			return Color("#ffd18a")
		Form.NOVA:
			return Color("#ffc877")
		Form.LANCE:
			return Color("#a2efff")
		Form.COUNTER:
			return Color("#ffe3a0")
		Form.FAN:
			return Color("#d4afff")
	return Color("#f3b4ff")
