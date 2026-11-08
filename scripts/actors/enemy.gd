extends CharacterBody2D

signal projectile_requested(origin: Vector2, direction: Vector2, power: int)
signal defeated(enemy: CharacterBody2D)

enum Kind { WOLF, SPIDER, ELITE }
enum State { DORMANT, IDLE, CHASE, WINDUP, RECOVER, DEAD }

const PROFILES := [
	{"hp": 40, "defense": 0, "damage": 13, "speed": 151.0, "range": 56.0, "xp": 14},
	{"hp": 32, "defense": 0, "damage": 10, "speed": 105.0, "range": 270.0, "xp": 18},
	{"hp": 128, "defense": 3, "damage": 25, "speed": 176.0, "range": 91.0, "xp": 45},
]

@export var kind: Kind
@onready var vitals := $Vitals
@onready var art := $Visual
@onready var animation: AnimationPlayer = $Visual/AnimationPlayer
@onready var reach: Area2D = $AttackRange

var target: CharacterBody2D
var state := State.IDLE
var timer := 0.0
var facing := Vector2.LEFT
var profile: Dictionary


func _ready() -> void:
	profile = PROFILES[kind]
	vitals.max_hp = profile.hp
	vitals.hp = profile.hp
	vitals.defense = profile.defense
	vitals.damaged.connect(_on_hurt)
	vitals.died.connect(_die)
	art.kind = kind + 1
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
			if distance <= float(profile.range) and _can_see_target():
				state = State.WINDUP
				timer = 0.58 if kind == Kind.ELITE else 0.36
			else:
				velocity = _route(heading) * float(profile.speed)
		State.WINDUP:
			timer -= delta
			if timer <= 0.0:
				_strike()
				state = State.RECOVER
				timer = 0.87 if kind == Kind.ELITE else 0.79
		State.RECOVER:
			timer -= delta
			if timer <= 0.0:
				state = State.CHASE
	art.warning_radius = float(profile.range) if state == State.WINDUP and kind != Kind.SPIDER else 0.0
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
	if kind == Kind.SPIDER:
		projectile_requested.emit(global_position, facing, profile.damage)
	elif reach.overlaps_body(target) and _can_see_target():
		target.take_hit(profile.damage)


func take_hit(power: int) -> bool:
	if state == State.DORMANT or state == State.DEAD:
		return false
	return vitals.hurt(power)


func _on_hurt(_amount: int) -> void:
	if state == State.IDLE:
		state = State.CHASE
	animation.stop()
	animation.play("hurt")


func _die() -> void:
	state = State.DEAD
	defeated.emit(self)
	queue_free()
