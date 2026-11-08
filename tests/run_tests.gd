extends SceneTree

const MAIN := "res://scenes/main.tscn"
const Enemy := preload("res://scripts/actors/enemy.gd")
const Grove := preload("res://scripts/world/bamboo_grove.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _scene_and_combat()
	await _play_trial()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _scene_and_combat() -> void:
	if not await _load_trial():
		return
	var trial = current_scene
	var player = trial.player
	var enemies := _enemies(trial)
	_check(player is CharacterBody2D and player.vitals.hp == 100, "Player scene has a live CharacterBody2D")
	_check(enemies.size() == 5 and trial.elite.state == Enemy.State.DORMANT,
		"Trial spawns four regular enemies and a locked elite")
	if enemies.size() != 5:
		return
	_check(_has_key("move_left", KEY_LEFT) and _has_key("move_up", KEY_UP)
		and _has_key("move_right", KEY_RIGHT) and _has_key("move_down", KEY_DOWN),
		"All four physical arrow keys are bound")
	_check(not trial.elite.take_hit(999) and not trial.progress.enter_exit(),
		"Elite and trial gate cannot be bypassed")

	var old_position: Vector2 = player.position
	Input.action_press("move_right")
	Input.action_press("move_up")
	await _wait(0.12)
	Input.action_release("move_right")
	Input.action_release("move_up")
	_check(player.position.x > old_position.x and player.position.y < old_position.y
		and is_equal_approx(player.velocity.length(), player.SPEED), "Diagonal movement is normalized")

	trial.hud.mobile = true
	await _touch_layout(trial.hud)
	var pad: Vector2 = trial.hud.pad
	_touch(0, pad + Vector2(39, 0), true)
	_check(player.touch_move.x > 0.5, "Screen touch captures joystick finger")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = pad + Vector2(0, 35)
	root.push_input(drag, true)
	_check(player.touch_move.y > 0.5, "Screen drag updates movement")
	_touch(1, trial.hud.controls[&"dodge"] + Vector2(0, 52), true)
	await _wait(0.05)
	_check(player.dodge_cooldown > 0.0 and not player.take_hit(20),
		"Second touch triggers dodge and dodge grants brief invulnerability")
	_touch(0, pad, false)
	_check(player.touch_move == Vector2.ZERO, "Joystick release clears input")
	_touch(2, trial.hud.pause_rect.get_center(), true)
	_check(paused and trial.hud.paused, "Pause button handles screen touch")
	_touch(3, trial.hud.resume_rect.get_center(), true)
	_check(not paused, "Resume button handles screen touch")
	await _wait(0.20)

	var wolf = enemies[0]
	player.position = wolf.position - Vector2(47, 0)
	var hp: int = player.vitals.hp
	await _wait(0.52)
	_check(player.vitals.hp == hp - 10, "Wolf chases and deals melee damage reduced by defense")
	player.position = Vector2(735, 505)
	hp = player.vitals.hp
	await _wait(1.0)
	_check(player.vitals.hp < hp, "Spider launches a projectile that damages the player")

	player.position = wolf.position - Vector2(58, 0)
	player.facing = Vector2.RIGHT
	var wolf_hp: int = wolf.vitals.hp
	await _wait(0.05)
	_touch(4, trial.hud.controls[&"attack"], true)
	await _wait(0.05)
	_check(is_instance_valid(wolf) and wolf.vitals.hp == wolf_hp - player.attack,
		"Touch attack deals melee damage via the area")
	var mp: float = player.mp
	_touch(5, trial.hud.controls[&"sword_skill"], true)
	await _wait(0.10)
	_check(player.mp < mp - 15.0 and player.skill_cooldown > 0.0, "Skill spends MP and starts cooldown")
	player.request(&"sword_skill")
	mp = player.mp
	await _wait(0.18)
	_check(player.mp >= mp, "Cooldown prevents a second MP charge")
	_check(not is_instance_valid(wolf) and player.xp >= 14, "Sword wave kills and awards XP")
	player.position = Vector2(225, 638)
	await _wait(1.05)
	_check(player.skill_cooldown == 0.0, "Skill becomes available again")
	player.take_hit(999)
	_check(player.vitals.hp == 0 and trial.outcome == "试炼失败" and paused,
		"Death opens a defeat result")
	_touch(6, trial.hud.restart_rect.get_center(), true)
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.player.vitals.hp == 100 and not paused,
		"Restart touch reloads the trial with full health")


func _touch_layout(hud: Control) -> void:
	var original_size := root.size
	for window_size in [Vector2i(1280, 720), Vector2i(2772, 1272), Vector2i(2635, 1106)]:
		root.size = window_size
		await process_frame
		await process_frame
		var safe: Rect2 = hud.safe
		var attack: Vector2 = hud.controls[&"attack"]
		var sword: Vector2 = hud.controls[&"sword_skill"]
		var dodge: Vector2 = hud.controls[&"dodge"]
		_check(is_equal_approx(root.get_visible_rect().size.y, 720.0)
			and absf(root.get_visible_rect().size.x - 720.0 * window_size.aspect()) < 2.0,
			"Viewport expands to match %s" % window_size)
		_check(safe.grow(-110).has_point(hud.pad) and safe.grow(-95).has_point(attack)
			and safe.grow(-95).has_point(sword) and safe.grow(-95).has_point(dodge),
			"Touch controls stay inset at %s" % window_size)
		_check(attack.distance_to(sword) > 116.0 and attack.distance_to(dodge) > 116.0
			and sword.distance_to(dodge) > 108.0 and sword.y < attack.y and dodge.x < attack.x,
			"Combat hit areas are distinct at %s" % window_size)
	root.size = original_size
	await process_frame
	await process_frame


func _play_trial() -> void:
	if not await _load_trial():
		return
	var trial = current_scene
	var player = trial.player
	var points := [Vector2(510, 610), Vector2(820, 505), Vector2(1110, 675), Vector2(1420, 570)]
	var enemies := _enemies(trial)
	if enemies.size() != 5:
		return
	for index in range(points.size()):
		await _fight(trial, enemies[index], points[index])
		if not trial.outcome.is_empty():
			break
	_check(trial.progress.defeated_regular == 4 and player.level >= 2,
		"Four fights award XP and level up the player")
	_check(trial.potions >= 1, "Dropped medicine is picked up during exploration")
	_check(not trial.progress.elite_defeated and not trial.progress.enter_exit(),
		"Regular enemies alone do not finish the trial")
	if not is_instance_valid(trial.elite) or not trial.outcome.is_empty():
		return
	_check(trial.elite.state != Enemy.State.DORMANT, "Fourth kill awakens elite")
	await _fight(trial, trial.elite, Vector2(1845, 475))
	_check(trial.progress.elite_defeated and trial.grove.portal_open, "Elite combat opens the gate")
	_check(not trial.progress.complete, "Elite death alone does not finish the trial")
	for step in range(44):
		if not trial.outcome.is_empty():
			break
		player.touch_move = player.position.direction_to(Grove.EXIT)
		await _wait(0.10)
	player.touch_move = Vector2.ZERO
	_check(trial.progress.complete and trial.outcome == "试炼完成" and paused,
		"Walking into the gate opens the victory result")
	paused = false


func _fight(trial: Node, enemy: Node2D, landmark: Vector2) -> void:
	var player = trial.player
	for step in range(75):
		if not is_instance_valid(enemy) or not trial.outcome.is_empty():
			break
		var target_position := enemy.position
		var direction: Vector2 = player.position.direction_to(target_position)
		var distance: float = player.position.distance_to(target_position)
		player.touch_move = direction if distance > 48.0 else Vector2.ZERO
		player.facing = direction
		if distance < 67.0:
			player.request(&"attack")
		elif distance < 330.0 and player.skill_cooldown == 0.0:
			player.request(&"sword_skill")
		await _wait(0.09)
	player.touch_move = Vector2.ZERO
	var drops: Array = trial.actors.get_children().filter(
		func(node: Node) -> bool: return node is Area2D and node.position.distance_to(landmark) < 380.0)
	if not drops.is_empty():
		var drop: Node2D = drops.back()
		for step in range(20):
			if not is_instance_valid(drop) or not trial.outcome.is_empty():
				break
			player.touch_move = player.position.direction_to(drop.position)
			await _wait(0.09)
	player.touch_move = Vector2.ZERO


func _load_trial() -> bool:
	paused = false
	var loaded := change_scene_to_file(MAIN) == OK
	_check(loaded, "Main scene loads")
	if loaded:
		await scene_changed
		await _wait(0.04)
	return loaded


func _enemies(trial: Node) -> Array:
	return trial.actors.get_children().filter(func(node: Node) -> bool: return node is Enemy)


func _has_key(action: StringName, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false


func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, true).timeout


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", message)
	else:
		failures += 1
		printerr("FAIL  ", message)
