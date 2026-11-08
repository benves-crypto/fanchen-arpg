extends CharacterBody2D

signal projectile_requested(origin: Vector2, direction: Vector2, power: int)
signal defeated(enemy: CharacterBody2D)
signal attacked

enum Kind { WOLF, SPIDER, ELITE, BOSS }
enum State { DORMANT, IDLE, CHASE, WINDUP, RECOVER, DEAD }

const Shot := preload("res://scripts/combat/projectile.gd")

const BOSS_VISUAL_SCALE := 1.35
const BOSS_FAN_STEP := 0.24
const BOSS_FAN_RANGE := 320.0

const PROFILES := [
	{"hp": 40, "defense": 0, "damage": 13, "speed": 151.0, "range": 56.0, "xp": 14},
	{"hp": 32, "defense": 0, "damage": 10, "speed": 105.0, "range": 270.0, "xp": 18},
	{"hp": 128, "defense": 3, "damage": 25, "speed": 176.0, "range": 91.0, "xp": 45},
	{"hp": 380, "defense": 4, "damage": 28, "speed": 142.0, "range": 122.0, "xp": 120},
]

@export var kind: Kind
@onready var vitals := $Vitals
@onready var art := $Visual
@onready var animation: AnimationPlayer = $Visual/AnimationPlayer
@onready var reach: Area2D = $AttackRange

var reaction_claimed := false
var target: CharacterBody2D
var state := State.IDLE
var timer := 0.0
var facing := Vector2.LEFT
var profile: Dictionary
var boss_fan_next := true
var boss_fan_paths := PackedVector2Array()


func _ready() -> void:
	profile = PROFILES[kind]
	vitals.max_hp = profile.hp
	vitals.hp = profile.hp
	vitals.defense = profile.defense
	vitals.damaged.connect(_on_hurt)
	vitals.died.connect(_die)
	art.kind = mini(kind, Kind.ELITE) + 1
	if kind == Kind.BOSS:
		art.scale *= BOSS_VISUAL_SCALE
		art.modulate = Color("#ffd4a3")
	art.vitals = vitals
	if kind == Kind.ELITE:
		state = State.DORMANT
	art.dormant = state == State.DORMANT
	var shape := CircleShape2D.new()
	shape.radius = profile.range
	$AttackRange/CollisionShape2D.shape = shape


func awaken() -> void:
	if state == State.DORMANT:
		state = State.IDLE
		art.dormant = false


func _physics_process(delta: float) -> void:
	if state == State.DEAD or state == State.DORMANT or not is_instance_valid(target):
		return
	if target.vitals.hp <= 0:
		return
	var distance := global_position.distance_to(target.global_position)
	var heading := global_position.direction_to(target.global_position)
	velocity = Vector2.ZERO
	match state:
		State.IDLE:
			if distance < 390.0:
				state = State.CHASE
		State.CHASE:
			facing = heading
			var attack_range := BOSS_FAN_RANGE if kind == Kind.BOSS and boss_fan_next else float(profile.range)
			if distance <= attack_range and _can_see_target():
				reaction_claimed = false
				state = State.WINDUP
				timer = 0.58 if kind != Kind.WOLF else 0.36
				if kind == Kind.BOSS:
					timer = 0.64 if _boss_enraged() else 0.9
					if boss_fan_next:
						_prepare_boss_fan()
				art.begin_windup(timer)
				if kind == Kind.SPIDER:
					var endpoint := global_position + facing * Shot.POISON_SPEED * Shot.POISON_LIFETIME
					var ray := PhysicsRayQueryParameters2D.create(global_position, endpoint, 1)
					var wall := get_world_2d().direct_space_state.intersect_ray(ray)
					art.poison_path = to_local(wall.get("position", endpoint))
			else:
				velocity = _route(heading) * float(profile.speed)
		State.WINDUP:
			timer -= delta
			if timer <= 0.0:
				_strike()
				state = State.RECOVER
				timer = 0.87 if kind == Kind.ELITE else 0.79
				if kind == Kind.BOSS:
					boss_fan_next = not boss_fan_next
					boss_fan_paths.clear()
					timer = 0.68 if _boss_enraged() else 1.05
					queue_redraw()
		State.RECOVER:
			timer -= delta
			if timer <= 0.0:
				state = State.CHASE
	art.warning_radius = 0.0
	if state == State.WINDUP and kind != Kind.SPIDER and boss_fan_paths.is_empty():
		art.warning_radius = float(profile.range)
		if kind == Kind.BOSS:
			art.warning_radius /= BOSS_VISUAL_SCALE
	art.charging = state == State.WINDUP
	move_and_slide()
	art.pose(facing, velocity.length() > 1.0)


func _can_see_target() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _route(heading: Vector2) -> Vector2:
	for turn in [0.0, 0.85, -0.85, 1.45, -1.45]:
		var step := heading.rotated(turn)
		if not test_move(global_transform, step * 24.0):
			return step
	return Vector2.ZERO


func _strike() -> void:
	art.pulse(1)
	attacked.emit()
	if not boss_fan_paths.is_empty():
		for index in range(boss_fan_paths.size()):
			projectile_requested.emit(global_position, _boss_fan_heading(index), 18)
	elif kind == Kind.SPIDER:
		projectile_requested.emit(global_position, facing, profile.damage)
	elif _melee_hits(target):
		target.take_hit(profile.damage, target.global_position.direction_to(global_position))


func _boss_enraged() -> bool:
	return vitals.hp * 2 <= vitals.max_hp


func _boss_fan_heading(index: int) -> Vector2:
	return facing.rotated((index - (boss_fan_paths.size() - 1) / 2.0) * BOSS_FAN_STEP)


func _prepare_boss_fan() -> void:
	boss_fan_paths.resize(7 if _boss_enraged() else 5)
	for index in range(boss_fan_paths.size()):
		var end := global_position + _boss_fan_heading(index) * Shot.POISON_SPEED * Shot.POISON_LIFETIME
		var query := PhysicsRayQueryParameters2D.create(global_position, end, 1)
		var wall := get_world_2d().direct_space_state.intersect_ray(query)
		boss_fan_paths[index] = to_local(wall.get("position", end))
	queue_redraw()


func _draw() -> void:
	for end in boss_fan_paths:
		draw_line(Vector2.ZERO, end, Color("#ef8b4970"), 9.0, true)
		draw_line(Vector2.ZERO, end, Color("#ffd28cba"), 2.0, true)


func _melee_hits(fighter: CharacterBody2D) -> bool:
	var radius: float = fighter.body_radius()
	if global_position.distance_squared_to(fighter.global_position) > (float(profile.range) + radius) ** 2:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, fighter.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func reaction_eta(fighter: CharacterBody2D, window: float) -> float:
	if reaction_claimed or state != State.WINDUP or target != fighter or timer > window:
		return INF
	if not boss_fan_paths.is_empty():
		var earliest := INF
		for index in range(boss_fan_paths.size()):
			earliest = minf(earliest, Shot.poison_eta(get_world_2d(), global_position,
				_boss_fan_heading(index), fighter, maxf(timer, 0.0), window))
		return earliest
	if kind == Kind.SPIDER:
		return Shot.poison_eta(get_world_2d(), global_position, facing, fighter, maxf(timer, 0.0), window)
	return maxf(timer, 0.0) if _melee_hits(fighter) else INF


func reaction_source() -> Node2D:
	return self


func take_hit(power: int, critical := false) -> bool:
	if state == State.DORMANT or state == State.DEAD:
		return false
	return vitals.hurt(power, critical)


func _on_hurt(_amount: int, _critical: bool) -> void:
	if state == State.IDLE:
		state = State.CHASE
	art.flinch()
	animation.stop()
	animation.play("hurt")


func _die() -> void:
	state = State.DEAD
	defeated.emit(self)
	queue_free()
