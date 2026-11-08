extends CharacterBody2D

signal projectile_requested(origin: Vector2, direction: Vector2, power: int, form: Shot.Form)
signal defeated
signal swung
signal charge_completed
signal dodged
signal reaction_effect(point: Vector2, direction: Vector2, kind: Reaction, follow_up: bool)
signal spell_cast
signal stepped
signal sword_hit(target: Node2D)
signal parried(point: Vector2, direction: Vector2)

const Shot := preload("res://scripts/combat/projectile.gd")
enum Reaction { NONE, DODGE, SWITCH }

const PERFECT_WINDOW := 0.12
const PERFECT_SWITCH_WINDOW := 0.18
const DODGE_REACTION_SCAN := 0.08
const PERFECT_DODGE_IFRAMES := 0.30
const PERFECT_SWITCH_IFRAMES := 0.24
const COUNTER_WINDOW := 0.85
const DODGE_COUNTER_POWER := 1.8
const SWITCH_COUNTER_POWER := 2.0

const SPEED := 245.0
const STEP_DISTANCE := 72.0
const WALK_CYCLE_DISTANCE := 108.0
const SKILL_COST := 18.0
const SKILL_RECOVERY := 1.15
const DODGE_RECOVERY := 1.05
const DODGE_DURATION := 0.16
const SKILL_TWO_RECOVERY := 4.0
const MAX_ULTIMATE := 100.0
const INPUT_BUFFER_TIME := 0.12
const ATTACK_CHARGE_TIME := 0.72
const CHARGED_POWER := 2.2
const COMBO_GRACE := 0.13
const SWORD_WINDUP := [0.067, 0.10, 0.17]
const MAGE_WINDUP := [0.075, 0.11, 0.16]
const COMBO_RECOVERY := [0.24, 0.28, 0.43]
const SWORD_POWER := [1.0, 1.0, 1.45]
const SWORD_HALF_ANGLE := [55.0, 100.0, 48.0]
const MAX_SWORD_MOMENTUM := 3
const MAX_LANTERN_MARKS := 3
const PARRY_WINDOW := 0.16
const PARRY_FOLLOW_UP := 1.15
const CRITICAL_EVERY := 3
const CRITICAL_MULTIPLIER := 1.6

@onready var vitals := $Vitals
@onready var art := $Visual
@onready var animation: AnimationPlayer = $Visual/AnimationPlayer
@onready var reach: Area2D = $MeleeRange

@export var skill_two_mp_cost := 0.0

var skill_two_cooldown := SKILL_TWO_RECOVERY
var ultimate := MAX_ULTIMATE
var portrait := 0
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
var reaction := Reaction.NONE
var counter_time := 0.0
var reaction_guard := 0.0
var counter_target: Node2D
var counter_direction := Vector2.ZERO
var find_threat: Callable
var pending: Dictionary[StringName, float] = {}
var mouse_aim := false
var charged_swing := false
var attack_held := false
var attack_charge := 0.0
var attack_input: InputEvent
var charge_mouse_aim := false
var step_distance := 0.0
var landed_swings := 0
var combo_step := -1
var combo_time := 0.0
var strike_time := 0.0
var strike_direction := Vector2.RIGHT
var finisher_pause := 0.0
var sword_momentum := 0
# Projectiles from one cast share a claim, even if they land on different ticks.
var sword_cast_assist_claim: Array[bool] = [false]
var lantern_marks := 0
var parry_time := 0.0
var parry_follow_up := 0.0
var empowered_finisher := false


func _ready() -> void:
	art.fighter_style = portrait
	vitals.damaged.connect(_on_hurt)
	vitals.died.connect(func() -> void: defeated.emit())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack") and not event.is_echo():
		if begin_attack(event is InputEventMouseButton):
			attack_input = event
	elif attack_input != null and attack_input.is_match(event, false):
		if event.is_canceled():
			cancel_attack()
		elif event.is_action_released(&"attack"):
			release_attack()
	for action in [&"sword_skill", &"dodge"]:
		if event.is_action_pressed(action) and not event.is_echo():
			request(action, event is InputEventMouseButton)


func begin_attack(aim_at_mouse := false) -> bool:
	if attack_held or vitals.hp <= 0:
		return false
	if counter_time > 0.0:
		request(&"attack", aim_at_mouse)
		return false
	attack_held = true
	attack_charge = 0.0
	charge_mouse_aim = aim_at_mouse
	return true


func release_attack() -> void:
	if not attack_held:
		return
	var full := attack_charge >= 1.0
	var aim := charge_mouse_aim
	cancel_attack()
	request(&"attack", aim)
	charged_swing = full


func cancel_attack() -> void:
	attack_held = false
	attack_charge = 0.0
	attack_input = null
	art.clear_attack_charge()


func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED) and is_node_ready():
		cancel_attack()
		interrupt_combo()
		clear_parry()
		pending.erase(&"attack")


func request(action: StringName, aim_at_mouse := false) -> void:
	pending[action] = INPUT_BUFFER_TIME
	if action == &"attack":
		charged_swing = false
		mouse_aim = aim_at_mouse
		# Keep an attack entered during a dodge until its first actionable tick.
		var wait := maxf(dodge_time, parry_time)
		if combo_step >= 0:
			wait = maxf(wait, swing_cooldown + (0.05 if combo_step == 2 else 0.0))
		pending[action] = maxf(INPUT_BUFFER_TIME, wait + get_physics_process_delta_time())


func _physics_process(delta: float) -> void:
	if vitals.hp <= 0:
		return
	skill_two_cooldown = maxf(0.0, skill_two_cooldown - delta)
	ultimate = minf(MAX_ULTIMATE, ultimate + 2.0 * delta)
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	if finisher_pause > 0.0:
		finisher_pause = maxf(0.0, finisher_pause - delta)
	else:
		swing_cooldown = maxf(0.0, swing_cooldown - delta)
		combo_time = maxf(0.0, combo_time - delta)
		if combo_time == 0.0:
			combo_step = -1
	dodge_time = maxf(0.0, dodge_time - delta)
	hurt_time = maxf(0.0, hurt_time - delta)
	reaction_guard = maxf(0.0, reaction_guard - delta)
	counter_time = maxf(0.0, counter_time - delta)
	parry_time = maxf(0.0, parry_time - delta)
	parry_follow_up = maxf(0.0, parry_follow_up - delta)
	if counter_time == 0.0 and reaction != Reaction.NONE:
		clear_counter()
	mp = minf(max_mp, mp + 5.0 * delta)
	var movement := (Input.get_vector("move_left", "move_right", "move_up", "move_down")
		+ touch_move).limit_length()
	if dodge_time == 0.0:
		if movement.length_squared() > 0.04:
			facing = movement.normalized()
		if attack_held:
			if charge_mouse_aim:
				_aim_at_cursor()
			var was_full := attack_charge >= 1.0
			attack_charge = minf(1.0, attack_charge + delta / ATTACK_CHARGE_TIME)
			art.attack_charge = attack_charge
			if not was_full and attack_charge >= 1.0:
				art.attack_charge_flash = 0.30
				charge_completed.emit()
		art.facing = facing
		if pending.has(&"dodge") and dodge_cooldown == 0.0:
			pending.erase(&"dodge")
			cancel_attack()
			clear_parry()
			if combo_step >= 0:
				interrupt_combo()
			dodge_time = DODGE_DURATION
			if pending.has(&"attack"):
				pending[&"attack"] = dodge_time + delta
			dodge_cooldown = DODGE_RECOVERY
			dodged.emit()
		elif pending.has(&"attack") and parry_time == 0.0 and (counter_time > 0.0 or swing_cooldown == 0.0):
			pending.erase(&"attack")
			if mouse_aim:
				_aim_at_cursor()
			if counter_time > 0.0:
				_counter_attack()
			else:
				if charged_swing:
					interrupt_combo()
					_swing_charged()
				else:
					_begin_combo_strike()
		elif pending.has(&"sword_skill") and skill_cooldown == 0.0 and mp >= SKILL_COST:
			pending.erase(&"sword_skill")
			cancel_attack()
			interrupt_combo()
			mp -= SKILL_COST
			skill_cooldown = SKILL_RECOVERY
			var threat: Node2D = find_threat.call(self) if not is_mage() and find_threat.is_valid() else null
			if threat == null:
				_cast(Shot.Form.LANCE, attack + 13)
			else:
				var direction := global_position.direction_to(threat.global_position)
				if not direction.is_zero_approx():
					facing = direction
				parry_time = PARRY_WINDOW
				art.show_guard(facing, parry_time, false)
		elif pending.has(&"skill_two") and can_use_skill_two():
			pending.erase(&"skill_two")
			cancel_attack()
			interrupt_combo()
			clear_parry()
			mp -= skill_two_mp_cost
			skill_two_cooldown = SKILL_TWO_RECOVERY
			_cast(Shot.Form.FAN, attack + 18, 3, 0.24)
		elif pending.has(&"ultimate") and ultimate >= MAX_ULTIMATE:
			pending.erase(&"ultimate")
			cancel_attack()
			interrupt_combo()
			clear_parry()
			ultimate = 0.0
			_cast(Shot.Form.NOVA, attack + 45, 8, TAU / 8.0)
	# Check before moving this tick, while the incoming attack can still reach us.
	if dodge_time > 0.0 and DODGE_DURATION - dodge_time <= DODGE_REACTION_SCAN:
		if reaction != Reaction.DODGE and find_threat.is_valid():
			var threat: Node2D = find_threat.call(self)
			if threat != null:
				arm_counter(Reaction.DODGE, threat)
	if strike_time > 0.0:
		strike_time = maxf(0.0, strike_time - delta)
		if strike_time == 0.0:
			_resolve_combo_strike()
	for action in pending.keys():
		var remaining := pending[action] - delta
		if remaining > 0.0:
			pending[action] = remaining
		else:
			pending.erase(action)
	vitals.invulnerable = dodge_time > 0.0 or hurt_time > 0.0 or reaction_guard > 0.0
	velocity = facing * 690.0 if dodge_time > 0.0 else movement * SPEED * (0.62 if attack_charge >= 0.15 else 1.0)
	if combo_step == 2 and not is_mage() and strike_time > 0.0:
		velocity = strike_direction * 110.0
	elif finisher_pause > 0.0 or parry_time > 0.0:
		velocity = Vector2.ZERO
	move_and_slide()
	var displacement := get_position_delta()
	var travel := displacement.length()
	if dodge_time == 0.0:
		art.walk_progress = fposmod(art.walk_progress + travel / WALK_CYCLE_DISTANCE, 1.0)
		step_distance += travel
		if step_distance >= STEP_DISTANCE:
			step_distance -= STEP_DISTANCE
			stepped.emit()
	var walking := travel > 0.01 if art.cultivation_skin else velocity.length() > 1.0
	var visual_direction := facing
	if art.cultivation_skin and walking and dodge_time == 0.0:
		visual_direction = displacement.normalized()
	art.pose(visual_direction, walking, dodge_time > 0.0)


func arm_counter(kind: Reaction, threat: Node2D) -> void:
	threat.reaction_claimed = true
	reaction = kind
	counter_time = COUNTER_WINDOW
	reaction_guard = PERFECT_DODGE_IFRAMES if kind == Reaction.DODGE else PERFECT_SWITCH_IFRAMES
	vitals.invulnerable = true
	counter_target = threat.reaction_source()
	counter_direction = global_position.direction_to(threat.global_position)
	if counter_direction.is_zero_approx():
		counter_direction = -threat.direction if threat is Shot else facing
	reaction_effect.emit(global_position, facing, kind, false)


func clear_counter() -> void:
	counter_time = 0.0
	reaction = Reaction.NONE
	counter_target = null


func _counter_attack() -> void:
	var kind := reaction
	var aim := counter_direction
	if is_instance_valid(counter_target) and not counter_target.is_queued_for_deletion():
		var target_aim := global_position.direction_to(counter_target.global_position)
		if not target_aim.is_zero_approx():
			aim = target_aim
	clear_counter()
	cancel_attack()
	interrupt_combo()
	facing = aim
	swing_cooldown = 0.42
	var power := roundi(attack * (DODGE_COUNTER_POWER if kind == Reaction.DODGE else SWITCH_COUNTER_POWER))
	if is_mage():
		_cast(Shot.Form.COUNTER, power)
	else:
		art.facing = facing
		art.pulse(4)
		swung.emit()
		sword_cast_assist_claim = [false]
		projectile_requested.emit(global_position, facing, power, Shot.Form.COUNTER)
	reaction_effect.emit(global_position, facing, kind, true)


func is_mage() -> bool:
	return portrait == 1


func _cast(form: Shot.Form, power: int, count := 1, spacing := 0.0) -> void:
	if not is_mage():
		sword_cast_assist_claim = [false]
	art.facing = facing
	art.pulse(3 if form == Shot.Form.NOVA else 2, Shot.magic_color(form))
	spell_cast.emit()
	for index in range(count):
		var angle := (index - floorf(count / 2.0)) * spacing
		projectile_requested.emit(global_position, facing.rotated(angle), power, form)


func land_magic_bolt(body: Node2D, power: int) -> bool:
	var critical := landed_swings == CRITICAL_EVERY - 1
	if not body.take_hit(roundi(power * CRITICAL_MULTIPLIER) if critical else power, critical):
		return false
	landed_swings = (landed_swings + 1) % CRITICAL_EVERY
	return true


func can_use_skill_two() -> bool:
	return skill_two_cooldown == 0.0 and mp >= skill_two_mp_cost


func _aim_at_cursor() -> void:
	if global_position.distance_squared_to(get_global_mouse_position()) > 1.0:
		facing = global_position.direction_to(get_global_mouse_position())


func _begin_combo_strike() -> void:
	empowered_finisher = parry_follow_up > 0.0
	if empowered_finisher:
		parry_follow_up = 0.0
		art.guard_time = 0.0
		combo_step = 2
	else:
		combo_step = (combo_step + 1) % 3
	strike_direction = facing
	strike_time = MAGE_WINDUP[combo_step] if is_mage() else SWORD_WINDUP[combo_step]
	swing_cooldown = COMBO_RECOVERY[combo_step]
	combo_time = swing_cooldown + COMBO_GRACE
	art.begin_combo_pose(combo_step, strike_direction, strike_time)


func interrupt_combo() -> void:
	empowered_finisher = false
	if combo_step >= 0:
		swing_cooldown = 0.0
		pending.erase(&"attack")
	combo_step = -1
	combo_time = 0.0
	strike_time = 0.0
	finisher_pause = 0.0
	art.clear_combo_pose()


func _resolve_combo_strike() -> void:
	art.facing = strike_direction
	if is_mage():
		var form := [Shot.Form.BOLT, Shot.Form.TWIN_BOLT, Shot.Form.SEAL][combo_step] as Shot.Form
		art.pulse(2, Shot.magic_color(form), combo_step)
		spell_cast.emit()
		var power := roundi(attack * [1.0, 0.58, 1.45][combo_step])
		if form == Shot.Form.TWIN_BOLT:
			for angle in [-0.14, 0.14]:
				projectile_requested.emit(global_position, strike_direction.rotated(angle), power, form)
		else:
			projectile_requested.emit(global_position, strike_direction, power, form)
		return
	art.pulse(1, Color("#fff4b0") if empowered_finisher else Color.WHITE, combo_step)
	swung.emit()
	var multiplier := 2.1 if empowered_finisher else float(SWORD_POWER[combo_step])
	var landed := _hit_with_sword(strike_direction, multiplier,
		cos(deg_to_rad(SWORD_HALF_ANGLE[combo_step])))
	if landed and combo_step == 2:
		finisher_pause = 0.05
		art.combo_hold = finisher_pause


func _swing_charged() -> void:
	swing_cooldown = 0.52
	if is_mage():
		_cast(Shot.Form.CHARGED, roundi(attack * CHARGED_POWER))
		return
	art.facing = facing
	art.pulse(4)
	swung.emit()
	var multiplier := CHARGED_POWER
	if sword_momentum == MAX_SWORD_MOMENTUM:
		sword_momentum = 0
		multiplier = 2.8
		art.spell_color = Color("#fff4b0")
	_hit_with_sword(facing, multiplier, -1.0, true)


func _hit_with_sword(heading: Vector2, multiplier: float, threshold: float, charged := false) -> bool:
	var critical := not charged and landed_swings == CRITICAL_EVERY - 1
	var power := roundi(attack * multiplier * (CRITICAL_MULTIPLIER if critical else 1.0))
	var landed := false
	var assist_target: Node2D
	for body in reach.get_overlapping_bodies():
		var direction := global_position.direction_to(body.global_position)
		var ray := PhysicsRayQueryParameters2D.create(global_position, body.global_position, 1)
		if heading.dot(direction) >= threshold and get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			if body.take_hit(power, critical):
				landed = true
				if not body.is_queued_for_deletion() and (assist_target == null or
						global_position.distance_squared_to(body.global_position) <
						global_position.distance_squared_to(assist_target.global_position)):
					assist_target = body
				charge_ultimate(8.0)
	if landed and not charged:
		landed_swings = (landed_swings + 1) % CRITICAL_EVERY
		if not empowered_finisher:
			sword_momentum = mini(MAX_SWORD_MOMENTUM, sword_momentum + 1)
	if assist_target != null:
		sword_hit.emit(assist_target)
	return landed


func body_radius() -> float:
	var shape: CircleShape2D = $CollisionShape2D.shape
	return shape.radius


func take_hit(power: int, source_direction := Vector2.ZERO) -> bool:
	if parry_time > 0.0 and not vitals.invulnerable and not source_direction.is_zero_approx():
		parry_time = 0.0
		parry_follow_up = PARRY_FOLLOW_UP
		clear_counter()
		swing_cooldown = 0.0
		facing = source_direction
		art.show_guard(facing, 0.20, true)
		parried.emit(global_position, facing)
		return false
	return vitals.hurt(power)


func clear_parry() -> void:
	parry_time = 0.0
	parry_follow_up = 0.0
	art.guard_time = 0.0


func land_lantern_shot(body: Node2D, power: int) -> bool:
	if not body.take_hit(power):
		return false
	lantern_marks = mini(MAX_LANTERN_MARKS, lantern_marks + 1)
	return true


func charge_ultimate(amount: float) -> void:
	ultimate = minf(MAX_ULTIMATE, ultimate + amount)


func _on_hurt(amount: int, _critical: bool) -> void:
	clear_parry()
	cancel_attack()
	interrupt_combo()
	clear_counter()
	charge_ultimate(amount * 0.6)
	hurt_time = 0.45
	vitals.invulnerable = true
	art.flinch()
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
