extends CharacterBody2D

signal projectile_requested(origin: Vector2, direction: Vector2, power: int)
signal defeated

const SPEED := 245.0
const SKILL_COST := 18.0
const SKILL_RECOVERY := 1.15
const DODGE_RECOVERY := 1.05
const DODGE_DURATION := 0.16

@onready var vitals := $Vitals
@onready var art := $Visual
@onready var animation: AnimationPlayer = $Visual/AnimationPlayer
@onready var reach: Area2D = $MeleeRange

var max_mp := 72.0
var mp := 72.0
var attack := 20
var level := 1
var xp := 0
var xp_goal := 30
var facing := Vector2.RIGHT
var touch_move := Vector2.ZERO
var skill_cooldown := 0.0
var dodge_cooldown := 0.0
var swing_cooldown := 0.0
var dodge_time := 0.0
var hurt_time := 0.0
var pending := {}
var mouse_aim := false


func _ready() -> void:
	vitals.damaged.connect(_on_hurt)
	vitals.died.connect(func() -> void: defeated.emit())


func _unhandled_input(event: InputEvent) -> void:
	for action in [&"attack", &"sword_skill", &"dodge"]:
		if event.is_action_pressed(action) and not event.is_echo():
			request(action, event is InputEventMouseButton)


func request(action: StringName, aim_at_mouse := false) -> void:
	pending[action] = true
	if action == &"attack":
		mouse_aim = aim_at_mouse


func _physics_process(delta: float) -> void:
	if vitals.hp <= 0:
		return
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	swing_cooldown = maxf(0.0, swing_cooldown - delta)
	dodge_time = maxf(0.0, dodge_time - delta)
	hurt_time = maxf(0.0, hurt_time - delta)
	mp = minf(max_mp, mp + 5.0 * delta)
	var movement := (Input.get_vector("move_left", "move_right", "move_up", "move_down")
		+ touch_move).limit_length()
	if dodge_time == 0.0:
		if movement.length_squared() > 0.04:
			facing = movement.normalized()
		if pending.has(&"dodge") and dodge_cooldown == 0.0:
			dodge_time = DODGE_DURATION
			dodge_cooldown = DODGE_RECOVERY
		elif pending.has(&"attack") and swing_cooldown == 0.0:
			if mouse_aim and global_position.distance_squared_to(get_global_mouse_position()) > 1.0:
				facing = global_position.direction_to(get_global_mouse_position())
			_swing()
		elif pending.has(&"sword_skill") and skill_cooldown == 0.0 and mp >= SKILL_COST:
			mp -= SKILL_COST
			skill_cooldown = SKILL_RECOVERY
			art.pulse(2)
			projectile_requested.emit(global_position, facing, attack + 13)
	pending.clear()
	vitals.invulnerable = dodge_time > 0.0 or hurt_time > 0.0
	velocity = facing * 690.0 if dodge_time > 0.0 else movement * SPEED
	move_and_slide()
	art.pose(facing, velocity.length() > 1.0, dodge_time > 0.0)


func _swing() -> void:
	swing_cooldown = 0.34
	art.pulse(1)
	for body in reach.get_overlapping_bodies():
		var direction := global_position.direction_to(body.global_position)
		var ray := PhysicsRayQueryParameters2D.create(global_position, body.global_position, 1)
		if facing.dot(direction) >= -0.12 and get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			body.take_hit(attack)


func take_hit(power: int) -> bool:
	return vitals.hurt(power)


func _on_hurt(_amount: int) -> void:
	hurt_time = 0.45
	vitals.invulnerable = true
	animation.stop()
	animation.play("hurt")


func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_goal:
		xp -= xp_goal
		level += 1
		xp_goal += 20
		attack += 5
		vitals.defense += 1
		vitals.max_hp += 15
		vitals.heal(30)
		max_mp += 8.0
		mp = max_mp
