extends Node2D

var kind := 0
var vitals: Node
var facing := Vector2.RIGHT
var moving := false
var dodging := false
var dormant := false
var charging := false
var warning_radius := 0.0
var phase := 0.0
var effect := 0
var effect_time := 0.0


func _ready() -> void:
	var flash := Animation.new()
	flash.length = 0.23
	var track := flash.add_track(Animation.TYPE_VALUE)
	flash.track_set_path(track, NodePath(".:modulate"))
	flash.track_insert_key(track, 0.0, Color("#ff7958"))
	flash.track_insert_key(track, 0.11, Color("#ffe0a3"))
	flash.track_insert_key(track, 0.23, Color.WHITE)
	var library := AnimationLibrary.new()
	library.add_animation("hurt", flash)
	$AnimationPlayer.add_animation_library("", library)


func pose(direction: Vector2, walking: bool, rolling := false) -> void:
	facing = direction
	moving = walking
	dodging = rolling


func pulse(style: int) -> void:
	effect = style
	effect_time = 0.21


func _process(delta: float) -> void:
	phase += delta
	effect_time = maxf(0.0, effect_time - delta)
	queue_redraw()


func _draw() -> void:
	if warning_radius > 0.0:
		draw_circle(Vector2.ZERO, warning_radius, Color("#ff806032"))
		draw_arc(Vector2.ZERO, warning_radius, 0, TAU, 36, Color("#ff9970ac"), 2.0)
	draw_set_transform(Vector2(0, 5), 0, Vector2(1, 0.48))
	draw_circle(Vector2.ZERO, 23 if kind == 3 else 18, Color("#0b211dc0"))
	draw_set_transform(Vector2.ZERO)
	var bob := roundf(sin(phase * 21.0) * 3.0) if moving else 0.0
	var side := -1.0 if facing.x < -0.15 else 1.0
	var size_factor := 1.42 if kind == 3 else 1.0
	draw_set_transform(Vector2(0, bob), 0, Vector2(side * size_factor, size_factor))
	match kind:
		0: _swordsman()
		1, 3: _wolf()
		2: _spider()
	draw_set_transform(Vector2.ZERO)
	if kind > 0 and is_instance_valid(vitals):
		var width := 62.0 if kind == 3 else 40.0
		var y := -55.0 if kind == 3 else -38.0
		draw_rect(Rect2(-width / 2, y, width, 5), Color("#172622"))
		draw_rect(Rect2(-width / 2, y, width * vitals.hp / vitals.max_hp, 5), Color("#e9915c"))
	if effect_time > 0.0:
		var tint := Color("#caffed") if kind == 0 else Color("#ffc28b")
		tint.a = effect_time / 0.21
		var angle := facing.angle()
		var radius := 51.0 if kind == 0 else 37.0
		draw_arc(Vector2.ZERO, radius, angle - 1.28, angle + 1.28, 22, tint, 5.0 if effect == 1 else 9.0)


func _pixel(x: float, y: float, width: float, height: float, tint: String) -> void:
	draw_rect(Rect2(x, y, width, height), Color(tint))


func _swordsman() -> void:
	_pixel(-12, -23, 24, 27, "#173934")
	_pixel(-9, -24, 17, 24, "#7dd5ba")
	_pixel(-6, -18, 5, 17, "#c5f4db")
	_pixel(-11, -8, 22, 4, "#d6a864")
	_pixel(-10, 0, 7, 8, "#263947")
	_pixel(4, 0, 7, 8, "#263947")
	_pixel(-9, -35, 19, 15, "#272932")
	_pixel(-4, -38, 9, 5, "#383443")
	_pixel(-6, -29, 15, 10, "#f6cd9a")
	if facing.y < -0.55:
		_pixel(-8, -34, 19, 15, "#2b2936")
	else:
		_pixel(5, -26, 3, 3, "#252936")
	draw_line(Vector2(10, -5), facing * Vector2(1 if facing.x >= -0.15 else -1, 1) * 18
		+ Vector2(12, -14), Color("#d6ffeb"), 4.0)
	if dodging:
		draw_arc(Vector2.ZERO, 25, 0.1, 5.8, 24, Color("#8fffe1a0"), 3.0)


func _wolf() -> void:
	var fur := "#9a6651" if kind == 3 else "#898e81"
	if dormant:
		fur = "#63756c"
	_pixel(-22, -9, 9, 6, fur)
	_pixel(-18, -14, 33, 17, "#273d37")
	_pixel(-16, -14, 28, 13, fur)
	_pixel(5, -23, 16, 20, fur)
	_pixel(7, -28, 5, 9, "#3e4038")
	_pixel(17, -26, 4, 8, "#3e4038")
	_pixel(15, -12, 11, 7, "#b7a687")
	_pixel(17, -17, 4, 4, "#fff6a1" if charging else "#e77552")
	_pixel(-13, 0, 6, 8, "#314038")
	_pixel(7, 0, 6, 8, "#314038")
	if kind == 3:
		draw_line(Vector2(-5, -18), Vector2(9, -8), Color("#e2ac59"), 4.0)


func _spider() -> void:
	for index in range(4):
		var x := -16.0 + index * 10
		draw_polyline(PackedVector2Array([Vector2(x * 0.55, -9), Vector2(x, -19), Vector2(x * 1.45, -22)]),
			Color("#a585b2"), 3.0)
		draw_polyline(PackedVector2Array([Vector2(x * 0.6, -5), Vector2(x, 4), Vector2(x * 1.5, 7)]),
			Color("#8a759e"), 3.0)
	_pixel(-15, -15, 23, 18, "#514063")
	_pixel(-11, -17, 15, 10, "#a2739a")
	_pixel(4, -11, 14, 13, "#695378")
	_pixel(12, -8, 5, 5, "#f7e990" if charging else "#c3df72")
