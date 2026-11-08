extends SceneTree

const Scores := preload("res://scripts/world/trial_scores.gd")
const MAIN := "res://scenes/main.tscn"
const Fighter := preload("res://scripts/actors/player.gd")
const Enemy := preload("res://scripts/actors/enemy.gd")
const Shot := preload("res://scripts/combat/projectile.gd")
const Grove := preload("res://scripts/world/bamboo_grove.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _trial_entry_and_scoring()
	await _difficulty_progression()
	await _scene_and_combat()
	await _perfect_reactions()
	await _critical_feedback()
	await _basic_combos()
	await _fighter_techniques()
	await _charged_attack()
	await _ranged_mage()
	await _medicine_cooldown()
	await _play_trial()
	await _play_trial(true)
	await _hud_actions()
	await _keyboard_shortcuts()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _trial_entry_and_scoring() -> void:
	if not await _load_trial(false):
		return
	var trial = current_scene
	_check(not trial.started and _enemies(trial).is_empty() and trial.elapsed == 0.0,
		"Opening the game shows the start screen without spawning enemies or running the clock")
	trial.hud.mobile = true
	_touch(0, trial.hud._menu_bounds("排行榜").get_center(), true)
	_check(trial.hud.ranking_open and paused, "The top ranking icon opens the leaderboard before the run")
	_touch(1, trial.hud.rank_back_rect.get_center(), true)
	_check(not paused and not trial.started, "Closing the leaderboard returns to the start screen")
	_touch(2, trial.hud.start_rect.get_center(), true)
	await create_timer(0.08).timeout
	_check(trial.started and _enemies(trial).size() == 5 and trial.elapsed > 0.0,
		"The start button spawns 1-1 and starts the clock")
	var seconds: float = trial.elapsed
	_key(KEY_F2)
	await _wait(0.08)
	_check(paused and trial.elapsed == seconds, "Checking the leaderboard pauses the run clock")
	_key(KEY_F2)
	_check(not paused, "Closing the leaderboard resumes the run")

	var score := Scores.calculate(1068, 5000, 3, 100.0, true)
	_check(score.total == 23680 and score.grade == "S" and score.technique == 4000,
		"Damage, capped technique, stage clears, time and shrine contribute to the grade")
	var failed := Scores.calculate(300, 400, 1, 30.0, false)
	_check(failed.total == 5400 and failed.time == 0 and failed.grade == "未通关",
		"A failed run earns partial points without a time bonus")
	var board := Scores.new("")
	for points in [600, 300, 200, 900, 700, 100]:
		board.record(points, 60000)
	board.record(700, 45000)
	_check(board.records.size() == 5 and board.records[0].points == 900
		and board.records[1].ms == 45000 and board.records.back().points == 300,
		"Leaderboard keeps the five highest scores and breaks ties by faster time")


func _difficulty_progression() -> void:
	var path := "%s/fanchen-difficulty-%d.cfg" % [OS.get_temp_dir(), OS.get_process_id()]
	var legacy := ConfigFile.new()
	legacy.set_value("bamboo", "version", 1)
	legacy.set_value("bamboo", "records", [{"points": 12000, "ms": 90000}])
	var fresh := Scores.new("")
	_check(fresh.highest_unlocked() == 0 and fresh.record(100, 1000, 1) == ERR_INVALID_PARAMETER,
		"A fresh save can only play Normal")
	_check(legacy.save(path) == OK, "Writes a legacy score file")
	var saved := Scores.new(path)
	_check(saved.highest_unlocked() == 1 and saved.records_for(0).size() == 1,
		"A legacy Normal clear unlocks Hard and retains the old leaderboard entry")

	if await _load_trial(false):
		var trial = current_scene
		trial.scores = saved
		trial.difficulty = 0
		_key(KEY_LEFT)
		_check(trial.difficulty == 0, "Keyboard cannot select below Normal")
		trial.hud.mobile = true
		_touch(0, trial.hud._difficulty_button(1).get_center(), true)
		_check(trial.difficulty == 1, "Touch selects the unlocked Hard difficulty")
		_key(KEY_LEFT)
		_check(trial.difficulty == 0, "Keyboard can return to Normal")
		_key(KEY_RIGHT)
		_key(KEY_RIGHT)
		_check(trial.difficulty == 1, "Keyboard cannot skip locked tiers")
		_key(KEY_ENTER)
		await _wait(0.04)
		var wolf = _enemies(trial)[0]
		_check(trial.started and trial.difficulty == 1 and wolf.vitals.max_hp == 46
			and wolf.difficulty_scale.is_equal_approx(Vector3(1.15, 1.10, 0.95)),
			"Starting on Hard applies the enemy scaling")
		trial._lose()
		_check(saved.highest_unlocked() == 1, "Defeat does not unlock another difficulty")

	if await _load_trial(false):
		var trial = current_scene
		trial.scores = saved
		trial.select_difficulty(1)
		trial.start_trial()
		trial._finish("试炼完成")
		_check(trial.unlocked_difficulty == 2 and saved.records_for(1).size() == 1,
			"A Hard win unlocks Challenge 1 and goes on its own board")
		var reloaded := Scores.new(path)
		_check(reloaded.highest_unlocked() == 2 and reloaded.records_for(0).size() == 1,
			"Reload preserves the new unlock and Normal board")
		for tier in range(2, Scores.MAX_DIFFICULTY + 1):
			_check(reloaded.highest_unlocked() == tier and reloaded.record(15000, 90000, tier) == OK,
				"Challenge tiers unlock one at a time")
		_check(Scores.new(path).highest_unlocked() == Scores.MAX_DIFFICULTY
			and reloaded.record(15000, 90000, Scores.MAX_DIFFICULTY + 1) == ERR_INVALID_PARAMETER,
			"Challenge 4 is the final tier even after clearing it")

	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


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

	player.swing_cooldown = 0.08
	player.request(&"attack")
	await _wait(0.13)
	_check(player.swing_cooldown > 0.0 and player.combo_step == 0 and not player.pending.has(&"attack"),
		"One early attack input is consumed when its cooldown ends")
	await _wait(0.36)
	player.request(&"dodge")
	player.request(&"attack")
	await _wait(0.08)
	_check(player.dodge_time > 0.0 and player.swing_cooldown == 0.0,
		"Attack waits while the player is dodging")
	await _wait(0.12)
	_check(player.swing_cooldown > 0.0 and player.combo_step == 0 and not player.pending.has(&"attack"),
		"Attack entered at dodge start survives until the dodge ends")
	player.dodge_cooldown = 0.0
	player.position = Grove.SPAWN

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
	_touch(0, pad + Vector2(49.8, 0) * trial.hud.ui_scale, true)
	_check(player.touch_move.x > 0.5, "Screen touch captures joystick finger")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = pad + Vector2(0, 60) * trial.hud.ui_scale
	root.push_input(drag, true)
	_check(player.touch_move.y > 0.5, "Screen drag updates movement")
	_touch(1, trial.hud.controls[&"dodge"] + Vector2(0, 60) * trial.hud.ui_scale, true)
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
	await _wait(0.24)
	_check(enemies[1].art.charging and enemies[1].art.poison_path.length() > 85.0
		and player.vitals.hp == hp, "Spider draws its locked attack line before firing")
	await _wait(0.90)
	_check(player.vitals.hp < hp, "Spider launches a projectile that damages the player")

	player.position = wolf.position - Vector2(58, 0)
	player.facing = Vector2.RIGHT
	var wolf_hp: int = wolf.vitals.hp
	await _wait(0.05)
	_touch(4, trial.hud.controls[&"attack"], true)
	_touch(4, Vector2.ZERO, false)
	await _wait(0.11)
	_check(is_instance_valid(wolf) and wolf.vitals.hp == wolf_hp - player.attack,
		"Touch attack deals melee damage via the area")
	_check(trial.camera.offset.length() > 0.0, "A confirmed hit moves the camera briefly")
	var mp: float = player.mp
	_touch(5, trial.hud.controls[&"sword_skill"], true)
	await _wait(0.10)
	_check(player.mp < mp - 15.0 and player.skill_cooldown > 0.0, "Skill spends MP and starts cooldown")
	player.request(&"sword_skill")
	mp = player.mp
	await _wait(0.18)
	_check(player.mp >= mp, "Cooldown prevents a second MP charge")
	_check(not player.pending.has(&"sword_skill"), "An early input expires during a long cooldown")
	_check(trial.camera.offset == Vector2.ZERO, "The camera returns to its resting offset")
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
	_check(current_scene != null and current_scene.player.vitals.hp == 100 and not paused
		and not current_scene.started,
		"Restart touch reloads the trial with full health")


func _perfect_reactions() -> void:
	if not await _load_trial():
		return
	var trial = current_scene
	var fighter = trial.player
	var enemies := _enemies(trial)
	for enemy in enemies:
		enemy.set_physics_process(false)
	var wolf = enemies[0]
	wolf.vitals.max_hp = 200
	wolf.vitals.hp = 200
	fighter.position = Vector2(435, 610)
	fighter.facing = Vector2.LEFT
	wolf.position = fighter.position + Vector2(48, 0)
	wolf.state = Enemy.State.WINDUP
	wolf.timer = 0.30
	_key(KEY_SPACE)
	await _wait(0.04)
	_check(fighter.dodge_time > 0.0 and fighter.reaction == Fighter.Reaction.NONE,
		"An early dodge does not unlock a counter")
	await _wait(0.17)
	fighter.position = Vector2(435, 610)
	fighter.dodge_cooldown = 0.0
	wolf.position = fighter.position + Vector2(36, 0)
	wolf.timer = 0.15
	_key(KEY_SPACE)
	await _wait(0.001)
	_check(fighter.dodge_time > 0.0 and fighter.reaction == Fighter.Reaction.NONE,
		"A roll starting outside the dodge window does not immediately earn a counter")
	wolf.timer = 0.10
	wolf.set_physics_process(true)
	await _wait(0.001)
	_check(fighter.reaction == Fighter.Reaction.DODGE and trial.feedback.reactions.size() == 1,
		"An incoming hit entering the window during the first half of a roll grants one counter")
	fighter.swing_cooldown = 0.5
	_key(KEY_J)
	await _wait(0.15)
	_check(fighter.dodge_time == 0.0 and not fighter.take_hit(20),
		"Perfect dodge protection outlasts the regular roll")
	await _wait(0.17)
	_check(wolf.vitals.hp == 164 and fighter.counter_time == 0.0 and fighter.landed_swings == 0,
		"Buffered dodge counter hits once for 1.8x without consuming a basic critical")
	_check(fighter.take_hit(20), "Perfect dodge invulnerability expires")

	if not await _load_trial():
		return
	trial = current_scene
	enemies = _enemies(trial)
	for enemy in enemies:
		enemy.set_physics_process(false)
	fighter = trial.player
	wolf = enemies[0]
	fighter.position = Vector2(435, 610)
	wolf.position = fighter.position + Vector2(48, 0)
	wolf.state = Enemy.State.WINDUP
	wolf.timer = 0.181
	await _wait(0.04)
	_check(not trial.feedback.switch_cue_visible, "The switch cue stays off outside 180 ms")
	wolf.timer = 0.18
	await _wait(0.04)
	_check(trial.feedback.switch_cue_visible, "The switch cue lights at the 180 ms boundary")
	_key(KEY_TAB)
	await _wait(0.04)
	_check(trial.player.is_mage() and trial.player.reaction == Fighter.Reaction.SWITCH
		and not trial.feedback.switch_cue_visible, "Switching at 180 ms grants the counter and clears the cue")

	if not await _load_trial():
		return
	trial = current_scene
	enemies = _enemies(trial)
	for enemy in enemies:
		enemy.set_physics_process(false)
	fighter = trial.player
	var spider = enemies[1]
	fighter.position = Vector2(460, 610)
	spider.position = Vector2(310, 610)
	spider.vitals.max_hp = 200
	spider.vitals.hp = 200
	await _wait(0.04)
	trial._fire_poison(fighter.position - Vector2(36, 24), Vector2.RIGHT, 10, spider)
	_key(KEY_TAB)
	await _wait(0.04)
	_check(trial.player.is_mage() and trial.player.reaction == Fighter.Reaction.NONE,
		"A nearby poison shot that misses does not grant a perfect switch")

	trial.hud.mobile = true
	trial._fire_poison(fighter.position - Vector2(36, 0), Vector2.RIGHT, 10, spider)
	_touch(0, trial.hud.controls[&"switch"], true)
	_touch(0, Vector2.ZERO, false)
	await _wait(0.12)
	_check(trial.player == fighter and fighter.reaction == Fighter.Reaction.SWITCH
		and fighter.vitals.hp == 100 and trial.feedback.reactions.size() == 1,
		"Touch switch protects the incoming fighter from a poison shot and plays its cue")
	_touch(1, trial.hud.controls[&"attack"], true)
	await _wait(0.20)
	_check(spider.vitals.hp == 160 and fighter.counter_time == 0.0,
		"Touch attack fires the 2.0x switch counter on press without charging")
	_touch(1, Vector2.ZERO, false)
	_check(not fighter.pending.has(&"attack") and fighter.take_hit(20),
		"Releasing the counter input queues no extra attack; switch protection expires")

	trial._fire_poison(fighter.position - Vector2(36, 0), Vector2.RIGHT, 10, spider)
	_key(KEY_TAB)
	await _wait(0.12)
	_check(trial.player.is_mage() and trial.player.reaction == Fighter.Reaction.SWITCH,
		"Mage can also earn a switch counter")
	await _wait(0.80)
	_check(trial.player.reaction == Fighter.Reaction.NONE and trial.feedback.reactions.is_empty()
		and spider.vitals.hp == 160, "Unused counter and its effects expire without dealing damage")


func _critical_feedback() -> void:
	if not await _load_trial():
		return
	var trial = current_scene
	var player = trial.player
	var wolf = _enemies(trial)[0]
	wolf.vitals.max_hp = 200
	wolf.vitals.hp = 200
	player.position = wolf.position - Vector2(59, 0)
	player.facing = Vector2.RIGHT
	await _wait(0.05)
	for index in range(2):
		player.request(&"attack")
		await _wait(0.43)
	player.request(&"attack")
	await _wait(0.11)
	_check(wolf.vitals.hp == 128 and player.landed_swings == 0,
		"Every third landed basic attack deals 1.6x damage")
	_check(trial.feedback.impacts.any(func(impact) -> bool:
		return impact.critical and impact.amount == "32!"), "Critical hit displays the actual damage")
	await _wait(0.80)
	_check(not trial.feedback.impacts.any(func(impact) -> bool: return impact.critical),
		"Critical feedback expires after its animation")


func _basic_combos() -> void:
	if not await _load_trial():
		return
	var trial = current_scene
	var sword = trial.player
	var wolf = _enemies(trial)[0]
	for enemy in _enemies(trial):
		enemy.set_physics_process(false)
	sword.position = Vector2(350, 610)
	sword.facing = Vector2.RIGHT
	wolf.position = sword.position + Vector2(55, 0)
	wolf.vitals.max_hp = 300
	wolf.vitals.hp = 300
	await _wait(0.05)
	sword.request(&"attack")
	await _wait(0.03)
	_check(wolf.vitals.hp == 300, "Sword windup precedes damage")
	sword.request(&"attack")
	await _wait(0.34)
	_check(sword.combo_step == 1 and wolf.vitals.hp == 260, "Buffered sword input chains into the sweep")
	sword.request(&"attack")
	await _wait(0.37)
	_check(sword.combo_step == 2 and wolf.vitals.hp == 214 and sword.position.x > 355,
		"Sword finisher steps forward and resolves one heavy critical")
	await _wait(0.52)
	sword.request(&"attack")
	await _wait(0.03)
	_check(sword.combo_step == 0, "Idle time resets the sword combo")
	sword.request(&"dodge")
	await _wait(0.24)
	_check(sword.combo_step == -1 and wolf.vitals.hp == 214, "Dodge cancels an unlanded strike")

	trial.switch_fighter()
	var mage = trial.player
	mage.facing = Vector2.RIGHT
	var forms: Array[Shot.Form] = []
	mage.projectile_requested.connect(func(_origin: Vector2, _direction: Vector2, _power: int,
			form: Shot.Form) -> void: forms.append(form))
	mage.request(&"attack")
	await _wait(0.12)
	mage.request(&"attack")
	await _wait(0.27)
	mage.request(&"attack")
	await _wait(0.35)
	_check(forms == [Shot.Form.BOLT, Shot.Form.TWIN_BOLT, Shot.Form.TWIN_BOLT, Shot.Form.SEAL],
		"Mage chains a bolt, two spread bolts and a seal projectile")


func _fighter_techniques() -> void:
	if not await _load_trial():
		return
	var trial = current_scene
	var wolf = _enemies(trial)[0]
	for enemy in _enemies(trial):
		enemy.set_physics_process(false)
	wolf.vitals.max_hp = 300
	wolf.vitals.hp = 300
	trial.switch_fighter()
	var mage = trial.player
	mage.position = Vector2(350, 610)
	mage.facing = Vector2.RIGHT
	wolf.position = mage.position + Vector2(180, 0)
	mage.begin_attack()
	await _wait(0.80)
	mage.release_attack()
	await _wait(0.35)
	_check(mage.lantern_marks == 1 and wolf.vitals.hp == 256, "Charged magic hit banks one lantern mark")

	trial.switch_fighter()
	var sword = trial.player
	sword.position = wolf.position - Vector2(55, 0)
	sword.facing = Vector2.RIGHT
	await _wait(0.05)
	sword.request(&"attack")
	await _wait(0.35)
	_check(mage.lantern_marks == 0 and wolf.vitals.hp == 222 and sword.sword_momentum == 1,
		"Sword hit banks momentum and spends a reserve mage mark on a delayed follow-up")

	sword.position = wolf.position - Vector2(49, 0)
	wolf.state = Enemy.State.WINDUP
	wolf.timer = 0.10
	wolf.set_physics_process(true)
	var health: int = sword.vitals.hp
	sword.request(&"sword_skill")
	await _wait(0.13)
	_check(sword.vitals.hp == health and sword.parry_follow_up > 0.0 and sword.art.guard_success,
		"Sword skill intercepts an actual incoming hit and opens an empowered follow-up")
	sword.request(&"attack")
	await _wait(0.24)
	_check(sword.combo_step == 2 and sword.parry_follow_up == 0.0 and wolf.vitals.hp == 180,
		"Attack after parry jumps straight to the empowered finisher")


func _ranged_mage() -> void:
	if not await _load_trial():
		return
	var trial = current_scene
	trial.switch_fighter()
	var mage = trial.player
	var wolf = _enemies(trial)[0]
	wolf.set_physics_process(false)
	wolf.vitals.max_hp = 250
	wolf.vitals.hp = 250
	mage.position = Vector2(350, 610)
	wolf.position = mage.position + Vector2(200, 0)
	mage.facing = Vector2.RIGHT
	mage.ultimate = 0.0
	await _wait(0.05)
	mage.request(&"attack")
	await _wait(0.10)
	_check(wolf.vitals.hp == 250 and mage.art.effect == 2,
		"Mage basic attack plays the cast and waits for projectile travel")
	await _wait(0.31)
	_check(wolf.vitals.hp == 230 and mage.ultimate >= 8.0,
		"Mage bolt hits outside melee range and builds ultimate")
	for index in range(2):
		mage.request(&"attack")
		await _wait(0.42)
	_check(wolf.vitals.hp == 178 and mage.landed_swings == 0,
		"Third landed mage bolt deals critical damage")
	mage.begin_attack()
	await _wait(0.80)
	mage.release_attack()
	await _wait(0.34)
	_check(wolf.vitals.hp == 134, "Charged mage attack fires a stronger ranged bolt")

	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 70)
	collider.shape = shape
	wall.add_child(collider)
	trial.add_child(wall)
	wall.global_position = mage.global_position + Vector2(90, 0)
	await _wait(0.20)
	mage.request(&"attack")
	await _wait(0.38)
	_check(wolf.vitals.hp == 134 and mage.landed_swings == 0,
		"Wall blocks the bolt without advancing the critical counter")

	var forms: Array[Shot.Form] = []
	mage.projectile_requested.connect(func(_origin: Vector2, _direction: Vector2, _power: int,
			form: Shot.Form) -> void: forms.append(form))
	mage.skill_two_cooldown = 0.0
	mage.ultimate = mage.MAX_ULTIMATE
	for action in [&"sword_skill", &"skill_two", &"ultimate"]:
		mage.request(action)
		await _wait(0.05)
	_check(forms.count(Shot.Form.LANCE) == 1 and forms.count(Shot.Form.FAN) == 3
		and forms.count(Shot.Form.NOVA) == 8, "Mage skills emit distinct projectile patterns")


func _charged_attack() -> void:
	if not await _load_trial():
		return
	var trial = current_scene
	var player = trial.player
	var wolf = _enemies(trial)[0]
	wolf.set_physics_process(false)
	wolf.vitals.max_hp = 100
	wolf.vitals.hp = 100
	player.position = wolf.position + Vector2(49.0, 0.0)
	player.facing = Vector2.RIGHT
	var hp: int = wolf.vitals.hp
	var completion_count: Array[int] = [0]
	player.charge_completed.connect(func() -> void: completion_count[0] += 1)
	await _wait(0.05)
	_key(KEY_J)
	await _wait(0.25)
	_check(player.art.attack_charge > 0.15 and player.art.attack_charge < 1.0
		and wolf.vitals.hp == hp, "Keyboard hold shows charge progress without attacking")
	await _wait(0.52)
	_check(player.art.attack_charge == 1.0 and player.art.attack_charge_flash > 0.0
		and completion_count[0] == 1 and wolf.vitals.hp == hp,
		"Full charge flashes once and waits for release")
	await _wait(0.36)
	_key(KEY_J, false, false, false)
	await _wait(0.05)
	_check(wolf.vitals.hp == hp - roundi(player.attack * player.CHARGED_POWER)
		and player.art.attack_charge == 0.0 and completion_count[0] == 1,
		"Keyboard release lands one charged hit, even behind the fighter")

	trial.hud.mobile = true
	var button: Vector2 = trial.hud.controls[&"attack"]
	_touch(9, button, true)
	await _wait(0.22)
	var canceled := InputEventScreenTouch.new()
	canceled.index = 9
	canceled.canceled = true
	root.push_input(canceled, true)
	_check(not player.attack_held and not player.pending.has(&"attack"),
		"Canceling an attack touch clears charge without swinging")
	_touch(9, button, true)
	await _wait(0.22)
	_key(KEY_ESCAPE)
	_check(paused and not player.attack_held and player.art.attack_charge == 0.0,
		"Pausing clears held attack and its visual feedback")
	_key(KEY_ESCAPE)
	_touch(9, Vector2.ZERO, false)
	_check(not paused and not player.pending.has(&"attack"), "Release after pause does not attack")
	_touch(9, button, true)
	await _wait(0.78)
	_touch(9, Vector2.ZERO, false)
	await _wait(0.05)
	_check(wolf.vitals.hp == hp - 2 * roundi(player.attack * player.CHARGED_POWER)
		and completion_count[0] == 2, "A full touch hold releases one charged strike outside the button")


func _medicine_cooldown() -> void:
	if not await _load_trial():
		return
	var trial = current_scene
	for enemy in _enemies(trial):
		enemy.set_physics_process(false)
	trial.medicine = 3
	_key(KEY_Q)
	_check(trial.medicine == 3 and trial.medicine_cooldown == 0.0,
		"Medicine at full HP consumes neither stock nor cooldown")
	trial.player.vitals.hp = 40
	_key(KEY_Q)
	_check(trial.medicine == 2 and trial.player.vitals.hp == 68 and trial.medicine_cooldown > 4.9,
		"Successful medicine starts a five-second cooldown")
	_key(KEY_TAB)
	await _wait(0.03)
	trial.player.vitals.hp = 40
	trial.hud.mobile = true
	var button: Vector2 = trial.hud.controls[&"medicine"]
	_touch(3, button, true)
	_touch(3, button, false)
	_check(trial.medicine == 2 and trial.player.vitals.hp == 40,
		"Touch cannot bypass the medicine cooldown by switching fighters")
	await create_timer(5.1, false).timeout
	button = trial.hud.controls[&"medicine"]
	_touch(3, button, true)
	_touch(3, button, false)
	_check(trial.medicine == 1 and trial.player.vitals.hp == 68 and trial.medicine_cooldown > 4.9,
		"Medicine works again after cooldown expires")


func _hud_actions() -> void:
	if not await _load_trial():
		return
	var trial = current_scene
	trial.hud.mobile = true
	var original = trial.player
	var replacement = trial.reserve
	_touch(0, trial.hud.controls[&"switch"], true)
	_touch(5, trial.hud.controls[&"sword_skill"], true)
	_check(trial.hud.held_buttons.get(0) == &"switch" and trial.hud.held_buttons.get(5) == &"sword_skill",
		"Two buttons independently keep their pressed sprites")
	_touch(0, Vector2.ZERO, false)
	_check(not trial.hud.held_buttons.has(0) and trial.hud.held_buttons.has(5),
		"Releasing outside a button restores only that finger's sprite")
	var canceled := InputEventScreenTouch.new()
	canceled.index = 5
	canceled.canceled = true
	root.push_input(canceled, true)
	_check(trial.hud.held_buttons.is_empty(), "Canceled touches clear the held sprite")
	await _wait(0.03)
	replacement.pending.clear()
	_check(trial.player == replacement and trial.reserve == original and trial.camera.get_parent() == replacement,
		"Switch transfers control and camera to the second fighter")
	replacement.take_hit(20)
	var hp: int = replacement.vitals.hp
	_touch(1, trial.hud.controls[&"medicine"], true)
	_check(replacement.vitals.hp > hp and trial.medicine == 0, "Equipped potion heals and consumes inventory")
	_touch(1, Vector2.ZERO, false)
	_check(not trial.hud.held_buttons.has(1) and trial.hud.press_pulses.has(&"medicine"),
		"A quick potion tap leaves a visible pulse after release")
	_touch(2, trial.hud.controls[&"ultimate"], true)
	await _wait(0.05)
	_check(replacement.ultimate < 5.0, "Full ultimate can be spent and begins charging again")
	replacement.skill_two_cooldown = 0.0
	replacement.mp = 0.0
	_touch(3, trial.hud.controls[&"skill_two"], true)
	await _wait(0.05)
	_check(replacement.skill_two_cooldown > 0.0, "Default skill two works below the visual MP midpoint")
	replacement.skill_two_cooldown = 0.0
	replacement.skill_two_mp_cost = 18.0
	replacement.mp = 10.0
	_touch(4, trial.hud.controls[&"skill_two"], true)
	await _wait(0.05)
	_check(replacement.skill_two_cooldown == 0.0, "Skill two respects its configured MP cost")
	replacement.mp = 20.0
	_touch(6, trial.hud.controls[&"skill_two"], true)
	await _wait(0.05)
	_check(replacement.skill_two_cooldown > 0.0 and replacement.mp < 3.0,
		"Skill two spends only its configured MP cost and enters cooldown")
	await _wait(0.20)
	_check(trial.hud.press_pulses.is_empty(), "Combat button pulses expire independently of held touches")


func _keyboard_shortcuts() -> void:
	if not await _load_trial():
		return
	var trial = current_scene
	var reserve = trial.reserve
	_key(KEY_TAB)
	await _wait(0.03)
	_check(trial.player == reserve, "Tab switches the active fighter")
	_key(KEY_TAB, false, true)
	_check(trial.player == reserve, "Holding Tab does not switch again")
	reserve.take_hit(20)
	_key(KEY_Q)
	_check(reserve.vitals.hp == reserve.vitals.max_hp and trial.medicine == 0, "Q uses a potion")
	_key(KEY_E)
	_key(KEY_R)
	_check(reserve.pending.has(&"skill_two") and reserve.pending.has(&"ultimate"),
		"E and R queue skill two and ultimate")
	_key(KEY_P)
	_check(paused and trial.hud.menu == "队伍信息", "P opens the party panel")
	_key(KEY_C)
	_check(paused and trial.hud.menu == "人物状态", "C switches to character status while paused")
	_key(KEY_I)
	_check(paused and trial.hud.menu == "背包", "I switches to inventory while paused")
	_key(KEY_E)
	_key(KEY_R)
	_check(paused and reserve.pending.is_empty(), "Combat shortcuts are ignored while paused")
	_key(KEY_I)
	_check(not paused, "Pressing the current panel shortcut again resumes the trial")
	_key(KEY_ESCAPE)
	_check(paused and trial.hud.menu == "设置", "Escape opens settings")
	_key(KEY_ENTER)
	_check(not paused, "Enter resumes the trial from the pause panel")
	_key(KEY_R, true)
	_check(not reserve.pending.has(&"ultimate"), "Shift+R does not trigger the ultimate")
	var trial_id: int = trial.get_instance_id()
	trial._finish("试炼失败")
	_key(KEY_R)
	_check(paused, "Plain R does not restart from results")
	_key(KEY_R, true)
	_check(not paused, "Shift+R restarts from results")
	if not paused:
		await scene_changed
		_check(current_scene.get_instance_id() != trial_id and current_scene.outcome.is_empty(),
			"Restart loads a fresh trial")


func _key(code: Key, shifted := false, echo := false, pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.shift_pressed = shifted
	event.pressed = pressed
	event.echo = echo
	root.push_input(event, true)


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
		var viewport := root.get_visible_rect()
		var scale := viewport.size.y / 849.0
		var positions := {
			&"medicine": Vector2(0.102, 0.782),
			&"skill_two": Vector2(0.333, 0.451),
			&"sword_skill": Vector2(0.336, 0.811),
			&"attack": Vector2(0.582, 0.645),
			&"dodge": Vector2(0.812, 0.806),
			&"switch": Vector2(0.859, 0.477),
			&"ultimate": Vector2(0.830, 0.134),
		}
		var combat_size := Vector2(650, 480) * scale
		var matches_reference: bool = hud.pad.is_equal_approx(viewport.size * Vector2(0.177, 0.751))
		for action in positions:
			var expected: Vector2 = safe.end - combat_size + combat_size * positions[action]
			matches_reference = matches_reference and expected.is_equal_approx(hud.controls[action])
		_check(matches_reference,
			"Reference positions match at %s" % window_size)
		_check(is_equal_approx(hud.ui_scale, scale)
			and safe.grow(-157.0 * scale).has_point(hud.pad)
			and safe.grow(-74.0 * scale).has_point(attack)
			and safe.grow(-60.0 * scale).has_point(sword)
			and attack.distance_to(dodge) >= 134.0 * scale,
			"Reference sizes scale by height and stay on screen at %s" % window_size)
	root.size = original_size
	await process_frame
	await process_frame


func _play_trial(challenge := false) -> void:
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
	_check(trial.sealed_jars == 0, "Regular enemies do not drop sealed jars")
	await _fight(trial, trial.elite, Vector2(1845, 475))
	_check(trial.sealed_jars == 1, "Walking to the wolf demon drop collects one sealed jar")
	_key(KEY_I)
	await process_frame
	_check(paused and trial.hud.menu == "背包" and trial.sealed_jars == 1,
		"Inventory opens with the collected sealed jar")
	_key(KEY_I)
	_check(trial.progress.elite_defeated and trial.grove.portal_open, "Elite combat opens the gate")
	_check(not trial.progress.complete, "Elite death alone does not finish the trial")
	if challenge:
		_check(trial.grove.shrine_lit, "Collecting the jar reveals the optional shrine")
		for step in range(35):
			if trial.shrine_started or not trial.outcome.is_empty():
				break
			player.touch_move = player.position.direction_to(Grove.SHRINE)
			await _wait(0.10)
		player.touch_move = Vector2.ZERO
		var ambush := _enemies(trial)
		_check(trial.shrine_started and trial.sealed_jars == 0 and not trial.grove.shrine_lit
			and ambush.size() == 2, "Entering the shrine spends one jar and spawns two enemies")
		for enemy in ambush:
			trial.use_medicine()
			await _fight(trial, enemy, Grove.SHRINE)
		_check(trial.shrine_defeats == 2 and trial.progress.defeated_regular == 4,
			"Ambush completion is tracked separately from the main trial")
	for step in range(44):
		if trial.stage != 1 or not trial.outcome.is_empty():
			break
		player.touch_move = player.position.direction_to(Grove.EXIT)
		await _wait(0.10)
	player.touch_move = Vector2.ZERO
	_check(trial.stage == 2 and trial.outcome.is_empty() and not paused and trial.player == player,
		"Walking into the first gate continues the run with the same fighter")
	if not challenge:
		_check(not trial.shrine_started and trial.sealed_jars == 1,
			"Direct exit leaves the optional shrine untouched")
	if challenge or trial.stage != 2:
		return

	var enemies_two := _enemies(trial)
	_check(enemies_two.size() == 9 and trial.elite.state == Enemy.State.DORMANT
		and not trial.grove.portal_open, "1-2 starts with eight regular enemies and a locked elite")
	player.position = Grove.EXIT
	await _wait(0.07)
	_check(trial.stage == 2 and not trial.elite.take_hit(999), "The second gate and elite stay locked before clearing the pack")
	for enemy in enemies_two:
		if enemy != trial.elite:
			enemy.take_hit(999)
	_check(trial.progress.defeated_regular == 8 and trial.elite.state != Enemy.State.DORMANT,
		"Clearing all eight enemies awakens the elite in 1-2")
	var medicine_before: int = trial.medicine
	trial.elite.take_hit(999)
	await _wait(0.09)
	var boss = trial.elite
	_check(trial.stage == 3 and _enemies(trial).size() == 1 and boss.kind == Enemy.Kind.BOSS
		and trial.medicine == medicine_before and not trial.grove.portal_open,
		"The second gate leads to a solo boss and preserves medicine")
	if trial.stage != 3:
		return

	player.position = boss.position + Vector2(-245, 0)
	await _wait(0.12)
	_check(boss.state == Enemy.State.WINDUP and boss.boss_fan_paths.size() == 5
		and is_equal_approx(trial.boss_health(), 1.0), "Boss starts with a visible five-shot fan and full health bar")
	boss.take_hit(225)
	_check(boss._boss_enraged(), "Boss enters its faster phase below half health")
	player.position = Grove.EXIT
	await _wait(0.07)
	_check(trial.outcome.is_empty(), "The boss gate stays locked during combat")
	boss.take_hit(999)
	_check(trial.outcome == "试炼完成" and paused and trial.defeated_total == 15
		and trial.scores.records.size() == 1 and trial.final_score.damage == 10680,
		"Only the final gate completes the trial and reports the cumulative defeat count")
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


func _load_trial(start := true) -> bool:
	paused = false
	var loaded := change_scene_to_file(MAIN) == OK
	_check(loaded, "Main scene loads")
	if loaded:
		await scene_changed
		current_scene.scores = Scores.new("")
		current_scene.difficulty = 0
		if start:
			current_scene.start_trial()
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
