extends Node2D

const PlayerScene := preload("res://scenes/actors/player.tscn")
const EnemyScene := preload("res://scenes/actors/enemy.tscn")
const Fighter := preload("res://scripts/actors/player.gd")
const Enemy := preload("res://scripts/actors/enemy.gd")
const Grove := preload("res://scripts/world/bamboo_grove.gd")
const Shot := preload("res://scripts/combat/projectile.gd")
const Potion := preload("res://scripts/world/potion.gd")
const SEALED_JAR := preload("res://assets/items/sealed_jar.png")
const Scores := preload("res://scripts/world/trial_scores.gd")
const Progress := preload("res://scripts/world/trial_progress.gd")
const CombatFeedback := preload("res://scripts/combat/combat_feedback.gd")
const SKIN_SETTINGS_PATH := "user://skin.cfg"
const SKIN_SETTING := "combat_skin"
const MEDICINE_RECOVERY := 5.0
const IMPACT_DURATION := 0.13
const SHRINE_FOES := 2
const STAGE_NAMES := ["竹径初试", "竹影围猎", "兽王石环"]
const BOSS_NAME := "熔甲兽王"
const BOSS_SPAWN := Vector2(1845, 475)
const FIRST_PACK := [Vector2(510, 610), Vector2(820, 505), Vector2(1110, 675), Vector2(1420, 570)]
const SECOND_PACK := [Vector2(580, 545), Vector2(885, 625), Vector2(1190, 590), Vector2(1515, 643)]

@onready var grove := $Grove
@onready var actors := $Grove/Scenery
@onready var hud := $Interface/HUD
@onready var audio := $Audio

var cultivation_skin := true
var started := false
var stage := 1
var scores := Scores.new()
var final_score := {}
var score_save_error := OK
var damage_dealt := 0
var technique_points := 0
var progress: RefCounted
var defeated_total := 0
var charge_cue := AudioStreamPlayer.new()
var player
var reserve
var switch_requested := false
var camera: Camera2D
var medicine := 1
var sealed_jars := 0
var shrine_defeats := 0
var shrine_started := false
var medicine_cooldown := 0.0
var elite
var elapsed := 0.0
var potions := 0
var earned_xp := 0
var outcome := ""
var exit_area: Area2D
var impact_time := 0.0
var impact_strength := 0.0
var feedback := CombatFeedback.new()


func _ready() -> void:
	feedback.z_index = 8
	add_child(feedback)
	charge_cue.pitch_scale = 1.35
	charge_cue.volume_db = -9.0
	audio.add_child(charge_cue)
	var settings := ConfigFile.new()
	if settings.load(SKIN_SETTINGS_PATH) == OK:
		cultivation_skin = settings.get_value("appearance", SKIN_SETTING, "cultivation") != "original"
	player = _create_fighter(0)
	reserve = _create_fighter(1)
	reserve.hide()
	reserve.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(Grove.WORLD_SIZE.x)
	camera.limit_bottom = int(Grove.WORLD_SIZE.y)
	player.add_child(camera)
	actors.process_mode = Node.PROCESS_MODE_DISABLED
	hud.bind(self)
	exit_area = Area2D.new()
	exit_area.position = Grove.EXIT
	exit_area.collision_layer = 0
	exit_area.collision_mask = 2
	var circle := CircleShape2D.new()
	circle.radius = 33.0
	var shape := CollisionShape2D.new()
	shape.shape = circle
	exit_area.add_child(shape)
	exit_area.body_entered.connect(_enter_exit)
	add_child(exit_area)


func start_trial() -> void:
	if started:
		return
	started = true
	actors.process_mode = Node.PROCESS_MODE_INHERIT
	_start_stage()


func _start_stage() -> void:
	grove.set_stage(stage)
	if stage == 3:
		progress = Progress.new(0)
		elite = _spawn(Enemy.Kind.BOSS, BOSS_SPAWN)
		return
	progress = Progress.new(FIRST_PACK.size() if stage == 1 else FIRST_PACK.size() + SECOND_PACK.size())
	for index in range(FIRST_PACK.size()):
		_spawn(Enemy.Kind.WOLF if index % 2 == 0 else Enemy.Kind.SPIDER, FIRST_PACK[index])
	if stage == 2:
		for index in range(SECOND_PACK.size()):
			_spawn(Enemy.Kind.SPIDER if index % 2 == 0 else Enemy.Kind.WOLF, SECOND_PACK[index])
	elite = _spawn(Enemy.Kind.ELITE, BOSS_SPAWN)


func _advance_stage() -> void:
	if not outcome.is_empty():
		return
	for actor in actors.get_children():
		if actor is Enemy or actor is Potion:
			actors.remove_child(actor)
			actor.queue_free()
	for child in get_children():
		if child is Shot:
			remove_child(child)
			child.queue_free()
	stage += 1
	grove.shrine_lit = false
	hud._reset_touch()
	var entrance := Vector2(1530, 590) if stage == 3 else Grove.SPAWN
	for fighter in [player, reserve]:
		fighter.position = entrance
		fighter.velocity = Vector2.ZERO
		fighter.dodge_time = 0.0
		fighter.pending.clear()
		fighter.clear_counter()
		fighter.clear_parry()
		fighter.interrupt_combo()
	camera.reset_smoothing()
	_start_stage()


func stage_title() -> String:
	return "1-%d  %s" % [stage, STAGE_NAMES[stage - 1]]


func boss_health() -> float:
	if stage != 3 or not is_instance_valid(elite) or elite.state in [Enemy.State.IDLE, Enemy.State.DEAD]:
		return -1.0
	return float(elite.vitals.hp) / elite.vitals.max_hp


func _create_fighter(portrait: int) -> CharacterBody2D:
	var fighter := PlayerScene.instantiate()
	fighter.position = Grove.SPAWN
	fighter.portrait = portrait
	actors.add_child(fighter)
	fighter.art.set_cultivation_skin(cultivation_skin)
	fighter.projectile_requested.connect(_fire_player.bind(fighter))
	fighter.defeated.connect(_lose)
	fighter.swung.connect($Audio/Slash.play)
	fighter.charge_completed.connect(_play_charge_cue)
	fighter.dodged.connect($Audio/Dodge.play)
	fighter.find_threat = _find_threat
	fighter.reaction_effect.connect(_on_reaction)
	fighter.parried.connect(_on_parry)
	fighter.sword_hit.connect(_lantern_follow_up.bind(fighter))
	fighter.spell_cast.connect($Audio/Cast.play)
	fighter.stepped.connect($Audio/Footstep.play)
	fighter.vitals.damaged.connect(_on_combat_hit.bind(fighter, 5.0, 90.0, true))
	return fighter


func toggle_skin() -> void:
	cultivation_skin = not cultivation_skin
	player.art.set_cultivation_skin(cultivation_skin)
	reserve.art.set_cultivation_skin(cultivation_skin)
	var settings := ConfigFile.new()
	settings.set_value("appearance", SKIN_SETTING, "cultivation" if cultivation_skin else "original")
	var error := settings.save(SKIN_SETTINGS_PATH)
	if error != OK:
		push_warning("Unable to save skin settings: %s" % error_string(error))


func _play_charge_cue() -> void:
	charge_cue.stream = $Audio/Cast.stream
	charge_cue.play()


func request_switch() -> void:
	switch_requested = true


func _physics_process(_delta: float) -> void:
	if switch_requested:
		switch_requested = false
		switch_fighter()


func _find_threat(fighter: CharacterBody2D) -> Node2D:
	if fighter != player:
		return null
	var best: Node2D
	var earliest := Fighter.PERFECT_WINDOW
	for threat in actors.get_children():
		if threat is Enemy:
			var eta: float = threat.reaction_eta(fighter, earliest)
			if eta <= earliest:
				earliest = eta
				best = threat
	for threat in get_children():
		if threat is Shot:
			var eta: float = threat.reaction_eta(fighter, earliest)
			if eta <= earliest:
				earliest = eta
				best = threat
	return best


func switch_fighter() -> void:
	if not outcome.is_empty() or reserve.vitals.hp <= 0 or player.dodge_time > 0.0:
		return
	var outgoing = player
	var threat := _find_threat(outgoing)
	var touch_move: Vector2 = outgoing.touch_move
	outgoing.pending.clear()
	outgoing.clear_counter()
	outgoing.clear_parry()
	outgoing.reaction_guard = 0.0
	outgoing.vitals.invulnerable = outgoing.hurt_time > 0.0
	hud.attack_finger = -3
	outgoing.cancel_attack()
	outgoing.interrupt_combo()
	outgoing.touch_move = Vector2.ZERO
	outgoing.hide()
	outgoing.process_mode = Node.PROCESS_MODE_DISABLED
	player = reserve
	reserve = outgoing
	player.position = outgoing.position
	player.facing = outgoing.facing
	player.velocity = Vector2.ZERO
	player.touch_move = touch_move
	player.show()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	camera.reparent(player, false)
	$Audio/Switch.play()
	if threat != null:
		player.arm_counter(Fighter.Reaction.SWITCH, threat)
	for actor in actors.get_children():
		if actor is Enemy:
			actor.target = player
	if progress.elite_defeated and exit_area.overlaps_body(outgoing):
		_enter_exit(player)


func use_medicine() -> void:
	if medicine_cooldown == 0.0 and medicine > 0 and player.vitals.hp > 0 and player.vitals.hp < player.vitals.max_hp:
		medicine -= 1
		medicine_cooldown = MEDICINE_RECOVERY
		player.vitals.heal(28)
		$Audio/Heal.play()


func _process(delta: float) -> void:
	if not started:
		return
	elapsed += delta
	medicine_cooldown = maxf(0.0, medicine_cooldown - delta)
	if grove.shrine_lit and player.position.distance_squared_to(Grove.SHRINE) <= Grove.SHRINE_RADIUS ** 2:
		_start_shrine()
	if impact_time > 0.0:
		impact_time = maxf(0.0, impact_time - delta)
		var remaining := impact_time / IMPACT_DURATION
		var phase := (1.0 - remaining) * TAU
		camera.offset = Vector2(1.0, 0.35) * sin(phase) * impact_strength * remaining


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and is_instance_valid(camera):
		impact_time = 0.0
		camera.offset = Vector2.ZERO


func _on_reaction(point: Vector2, direction: Vector2, kind: Fighter.Reaction, follow_up: bool) -> void:
	if not follow_up:
		technique_points = mini(Scores.TECHNIQUE_LIMIT, technique_points + 400)
	var swap := kind == Fighter.Reaction.SWITCH
	feedback.show_reaction(point, direction, swap, follow_up)
	impact_strength = 5.0 if follow_up else 3.0
	impact_time = IMPACT_DURATION


func _on_parry(point: Vector2, direction: Vector2) -> void:
	technique_points = mini(Scores.TECHNIQUE_LIMIT, technique_points + 500)
	feedback.show_reaction(point, direction, false, true)
	$Audio/Hit.play()
	impact_strength = 6.0
	impact_time = IMPACT_DURATION


func _on_combat_hit(damage: int, critical: bool, target: Node2D, strength: float,
		label_height: float, player_hurt: bool) -> void:
	if not player_hurt:
		damage_dealt += damage
	feedback.show_hit(target.global_position, label_height, damage, critical, player_hurt)
	$Audio/Hit.play()
	if critical:
		strength = 9.0
	# A burst hitting several enemies should feel like one impact.
	if impact_time == 0.0 or strength > impact_strength:
		impact_strength = strength
		impact_time = IMPACT_DURATION


func _start_shrine() -> void:
	shrine_started = true
	sealed_jars -= 1
	grove.shrine_lit = false
	$Audio/Gate.play()
	_spawn(Enemy.Kind.WOLF, Grove.SHRINE + Vector2(-100, 45), true)
	_spawn(Enemy.Kind.SPIDER, Grove.SHRINE + Vector2(100, 20), true)


func objective() -> String:
	if grove.shrine_lit:
		return "前往 1-2，或去北侧祭坛献罐"
	if stage == 1 and shrine_started:
		if shrine_defeats < SHRINE_FOES:
			return "破除伏击 %d/%d · 可直接出门" % [shrine_defeats, SHRINE_FOES]
		return "伏击已破 · 穿过试炼门"
	if progress.elite_defeated and stage < 3:
		return "穿过东侧试炼门，前往 1-%d" % (stage + 1)
	if stage == 3 and not progress.elite_defeated:
		return "击败%s" % BOSS_NAME
	return progress.objective("精英熔甲兽" if stage == 2 else "熔甲兽")


func _spawn(kind: int, point: Vector2, shrine_enemy := false) -> CharacterBody2D:
	var enemy := EnemyScene.instantiate()
	enemy.kind = kind
	enemy.target = player
	enemy.position = point
	actors.add_child(enemy)
	enemy.defeated.connect(_enemy_down.bind(shrine_enemy))
	enemy.projectile_requested.connect(_fire_poison.bind(enemy))
	var attack_sound: AudioStreamPlayer = $Audio/SpiderAttack if kind == Enemy.Kind.SPIDER else $Audio/WolfAttack
	enemy.attacked.connect(attack_sound.play)
	var is_elite := kind in [Enemy.Kind.ELITE, Enemy.Kind.BOSS]
	enemy.vitals.damaged.connect(_on_combat_hit.bind(enemy, 4.0 if is_elite else 2.5,
		128.0 if is_elite else 94.0, false))
	return enemy


func _fire_player(origin: Vector2, direction: Vector2, power: int, form: Shot.Form,
		fighter: CharacterBody2D) -> void:
	var shot := _fire(origin, direction, power, true)
	if fighter.is_mage():
		shot.configure_magic(form, cultivation_skin)
		if form in [Shot.Form.BOLT, Shot.Form.TWIN_BOLT, Shot.Form.SEAL]:
			shot.resolve_hit = fighter.land_magic_bolt
		elif form == Shot.Form.CHARGED:
			shot.resolve_hit = fighter.land_lantern_shot
	else:
		shot.resolve_hit = _land_sword_projectile.bind(fighter, fighter.sword_cast_assist_claim)
	if form == Shot.Form.COUNTER and not fighter.is_mage():
		shot.form = form
		shot.speed = 880.0
		shot.lifetime = 0.56
		shot.z_index = 2
	shot.hit_target.connect(fighter.charge_ultimate.bind(8.0))


func _land_sword_projectile(target: Node2D, power: int, fighter: CharacterBody2D,
		claim: Array[bool]) -> bool:
	if not target.take_hit(power):
		return false
	if not claim[0] and not target.is_queued_for_deletion():
		claim[0] = _lantern_follow_up(target, fighter)
	return true


func _lantern_follow_up(target: Node2D, fighter: CharacterBody2D) -> bool:
	if (fighter != player or not reserve.is_mage() or reserve.lantern_marks == 0
			or reserve.vitals.hp <= 0 or not outcome.is_empty()):
		return false
	var heading := fighter.global_position.direction_to(target.global_position)
	if heading.is_zero_approx():
		heading = fighter.facing
	var origin := fighter.global_position - heading * 45.0 + heading.orthogonal() * 44.0
	var query := PhysicsRayQueryParameters2D.create(fighter.global_position, origin, 1)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		origin = fighter.global_position
	reserve.lantern_marks -= 1
	var direction := origin.direction_to(target.global_position)
	var shot := _fire(origin, direction, roundi(reserve.attack * 0.72), true)
	shot.configure_magic(Shot.Form.LANTERN_ASSIST, cultivation_skin)
	shot.launch_delay = 0.09
	$Audio/Cast.play()
	return true


func _fire_poison(origin: Vector2, direction: Vector2, power: int, caster: CharacterBody2D) -> void:
	var shot := _fire(origin, direction, power, false)
	shot.caster = caster
	shot.reaction_claimed = caster.reaction_claimed


func _fire(origin: Vector2, direction: Vector2, power: int, friendly: bool) -> Node2D:
	var shot := Shot.new()
	shot.position = origin
	shot.direction = direction
	shot.power = power
	shot.targets = 4 if friendly else 2
	if not friendly:
		shot.poison = true
		shot.speed = Shot.POISON_SPEED
		shot.lifetime = Shot.POISON_LIFETIME
	add_child(shot)
	return shot


func _enemy_down(enemy: CharacterBody2D, shrine_enemy: bool) -> void:
	var reward: int = enemy.profile.xp
	earned_xp += reward
	player.gain_xp(reward)
	var is_elite: bool = enemy == elite
	defeated_total += 1
	if shrine_enemy:
		shrine_defeats += 1
	else:
		progress.record_defeat(is_elite)
	if is_elite:
		grove.unlock_exit()
		$Audio/Gate.play()
	elif not shrine_enemy and progress.elite_unlocked():
		elite.awaken()
	var potion := Potion.new()
	potion.position = enemy.global_position
	potion.collected.connect(func() -> void:
		potions += 1
		medicine += 1
		$Audio/Pickup.play()
	)
	actors.call_deferred("add_child", potion)
	if is_elite and stage == 1:
		var jar := Potion.new()
		jar.item_texture = SEALED_JAR
		jar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		jar.position = potion.position + Vector2(-54, 0)
		jar.collected.connect(func() -> void:
			sealed_jars += 1
			grove.shrine_lit = true
			$Audio/Pickup.play()
		)
		actors.call_deferred("add_child", jar)

	if is_elite and exit_area.overlaps_body(player):
		_enter_exit(player)


func _enter_exit(body: Node2D) -> void:
	if not started or body != player or not outcome.is_empty() or not progress.enter_exit():
		return
	if stage < 3:
		_advance_stage.call_deferred()
	else:
		_finish("试炼完成")


func _lose() -> void:
	_finish("试炼失败")


func _finish(result: String) -> void:
	if not started or not outcome.is_empty():
		return
	outcome = result
	var won := result == "试炼完成"
	final_score = Scores.calculate(damage_dealt, technique_points, 3 if won else stage - 1,
		elapsed, shrine_defeats == SHRINE_FOES)
	if won:
		score_save_error = scores.record(final_score.total, roundi(elapsed * 1000.0))
	var cue: AudioStreamPlayer = $Audio/Victory if won else $Audio/Defeat
	cue.play()
	hud.show_result(result)
	get_tree().paused = true


func restart() -> void:
	get_tree().paused = false
	get_tree().call_deferred("reload_current_scene")
