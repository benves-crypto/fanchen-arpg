extends Control

const KEY_BINDING_PANEL := preload("res://scripts/ui/key_binding_panel.gd")
const MINT := Color("#e2f0d1")
const GOLD := Color("#efd08b")
const MUTED := Color("#a3b49b")
const JADE := Color("#89e2be")
const VERMILION := Color("#f49443")
const PORTRAITS := preload("res://assets/actors/fighter_portraits.webp")
const CULTIVATION_PORTRAITS := preload("res://assets/actors/cultivation_portraits.png")
const HUD_ART := preload("res://assets/ui/cultivation_hud_art.png")
const RANKING_ICON := preload("res://assets/ui/cultivation_ranking.svg")
const SCORES := preload("res://scripts/world/trial_scores.gd")
const MEDICINE_ART := preload("res://assets/ui/cultivation_medicine.png")
const SEALED_JAR_ICON := preload("res://assets/items/sealed_jar_icon.png")
const COOLDOWN_ART := preload("res://assets/ui/cultivation_cooldown.png")
const ACTIVE_ART := preload("res://assets/ui/cultivation_active.png")
const JADE_HUD := preload("res://assets/ui/jade_hud.png")
const PANEL_TEXTURE := preload("res://assets/ui/jade_panel.png")
const MINIMAP := preload("res://assets/ui/bamboo_minimap.webp")
const ACTION_ART := {&"attack": 0, &"skill_two": 1, &"sword_skill": 2, &"dodge": 3}
const MENU_ART := {"队伍信息": 7, "人物状态": 8, "背包": 9, "设置": 10}
const SEALS := preload("res://assets/ui/cultivation_seals.svg")
const SWITCH_ICON := preload("res://assets/ui/cultivation_switch.png")
const SWORD_ULTIMATE_ICON := preload("res://assets/ui/cultivation_sword_ultimate.png")
const MAGE_ULTIMATE_ICON := preload("res://assets/ui/cultivation_mage_ultimate.png")
const GROVE := preload("res://scripts/world/bamboo_grove.gd")
const WHEEL_RADIUS := 157.0
const FIGHTER_TITLES := ["剑修", "远程法师"]
const MAGE_ICON_ART := preload("res://assets/ui/cultivation_mage_icons.png")
const MAGE_ICON_SIZE := 256
const MAGE_SPELLS := {
	&"attack": [0, "灵弹"],
	&"sword_skill": [1, "破空灵光"],
	&"skill_two": [2, "三才灵弹"],
}
const PRESS_PULSE_DURATION := 0.18
const SEAL_INDEX := {&"dodge": 3, &"skill_two": 5}
# Positions are fractions of the right-hand combat area in the layout reference.
const COMBAT_AREA_SIZE := Vector2(650, 480)
const ATTACK_DIAMETER := 148.0
const SECONDARY_DIAMETER := 120.0
const BUTTONS := {
	&"attack": [Vector2(0.582, 0.645), Vector2.ONE * ATTACK_DIAMETER],
	&"switch": [Vector2(0.859, 0.477), Vector2.ONE * SECONDARY_DIAMETER],
	&"sword_skill": [Vector2(0.336, 0.811), Vector2.ONE * SECONDARY_DIAMETER],
	&"dodge": [Vector2(0.812, 0.806), Vector2.ONE * SECONDARY_DIAMETER],
	&"ultimate": [Vector2(0.830, 0.134), Vector2.ONE * SECONDARY_DIAMETER],
	&"skill_two": [Vector2(0.333, 0.451), Vector2.ONE * SECONDARY_DIAMETER],
	&"medicine": [Vector2(0.102, 0.782), Vector2(90, 90)],
}
const EXTRA_COMBAT_ACTIONS := [&"switch", &"skill_two", &"ultimate", &"medicine"]
const MENU_ACTIONS := {
	"队伍信息": &"party_menu",
	"人物状态": &"character_menu",
	"背包": &"inventory_menu",
	"设置": &"pause",
}
const MENUS := {
	"排行榜": [Vector2(0.641, 0.072), Vector2(76, 76)],
	"队伍信息": [Vector2(0.719, 0.072), Vector2(76, 76)],
	"人物状态": [Vector2(0.797, 0.072), Vector2(76, 76)],
	"背包": [Vector2(0.875, 0.072), Vector2(76, 76)],
	"设置": [Vector2(0.952, 0.072), Vector2(76, 76)],
}

var trial
var mobile := false
var paused := false
var menu := "设置"
var ui_scale := 1.0
var result := ""
var ranking_open := false
var ranking_difficulty := 0
var card_scale := 1.0
var trial_card := Rect2()
var start_rect := Rect2()
var rank_back_rect := Rect2()
var joystick_finger := -1
var attack_finger := -3
var stick := Vector2.ZERO
var safe := Rect2()
var pad := Vector2.ZERO
var controls := {}
var held_buttons: Dictionary[int, StringName] = {}
var press_pulses: Dictionary[StringName, float] = {}
var key_binding_panel: Control
var key_settings_rect := Rect2()
var skin_settings_rect := Rect2()
var music_settings_rect := Rect2()
var effects_settings_rect := Rect2()
var pause_rect := Rect2()
var restart_rect := Rect2()
var resume_rect := Rect2()
var modal := Rect2()
var font := ThemeDB.fallback_font
var panel_skin := StyleBoxTexture.new()


func bind(game: Node2D) -> void:
	trial = game
	panel_skin.texture = PANEL_TEXTURE
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		panel_skin.set_texture_margin(side, 12.0)
	mobile = OS.has_feature("mobile")
	if not mobile:
		key_binding_panel = KEY_BINDING_PANEL.new()
		add_child(key_binding_panel)
	_layout()


func _process(delta: float) -> void:
	if is_instance_valid(trial):
		for action in press_pulses.keys():
			press_pulses[action] -= delta
			if press_pulses[action] <= 0.0:
				press_pulses.erase(action)
		_layout()
		queue_redraw()


func _layout() -> void:
	safe = get_viewport_rect()
	if OS.has_feature("mobile"):
		var physical := Rect2(DisplayServer.get_display_safe_area())
		var inset := safe.intersection(get_viewport().get_screen_transform().affine_inverse() * physical)
		if inset.has_area():
			safe = inset
	# Keep the two control groups apart when the window is narrower than landscape.
	ui_scale = minf(get_viewport_rect().size.y / 849.0, safe.size.x / 1200.0)
	pad = _anchor(Vector2(0.177, 0.751), Vector2.ONE * WHEEL_RADIUS * ui_scale)
	var combat_size := COMBAT_AREA_SIZE * ui_scale
	var combat_origin := safe.end - combat_size
	for action in BUTTONS:
		var spec: Array = BUTTONS[action]
		var fraction: Vector2 = spec[0]
		var inset: Vector2 = spec[1] * ui_scale / 2.0
		controls[action] = (combat_origin + combat_size * fraction).clamp(
			safe.position + inset, safe.end - inset)
	card_scale = minf(1.0, minf(safe.size.x / 560.0, safe.size.y / 470.0))
	var card_size := Vector2(510, 386) * card_scale
	trial_card = Rect2(safe.get_center() - card_size / 2.0, card_size)
	start_rect = Rect2(_card_point(255, 260) - Vector2(94, 0) * card_scale, Vector2(188, 48) * card_scale)
	rank_back_rect = Rect2(_card_point(255, 319) - Vector2(86, 0) * card_scale, Vector2(172, 42) * card_scale)
	pause_rect = _menu_bounds("设置")
	var settings_open := paused and menu == "设置"
	var modal_size := Vector2(496, 334 if settings_open or (paused and menu == "背包") else 290)
	modal = Rect2(safe.get_center() - modal_size / 2.0, modal_size)
	var buttons_y := modal_size.y - 72.0
	restart_rect = Rect2(modal.position + Vector2(261, buttons_y), Vector2(174, 46))
	if not result.is_empty():
		restart_rect = rank_back_rect
	resume_rect = Rect2(modal.position + Vector2(60, buttons_y), Vector2(174, 46))
	key_settings_rect = Rect2(modal.position + Vector2(60, 119), Vector2(174, 37))
	skin_settings_rect = Rect2(modal.position + Vector2(161 if mobile else 261, 119),
		Vector2(174, 37))
	music_settings_rect = Rect2(modal.position + Vector2(60, 163), Vector2(174, 42))
	effects_settings_rect = Rect2(modal.position + Vector2(261, 163), Vector2(174, 42))


func _anchor(fraction: Vector2, inset := Vector2.ZERO) -> Vector2:
	var viewport := get_viewport_rect()
	return (viewport.position + viewport.size * fraction).clamp(safe.position + inset, safe.end - inset)


func _menu_bounds(label: String) -> Rect2:
	var spec: Array = MENUS[label]
	var extent: Vector2 = spec[1] * ui_scale
	return Rect2(_anchor(spec[0], extent / 2.0) - extent / 2.0, extent)


func _input(event: InputEvent) -> void:
	if not is_instance_valid(trial):
		return
	if is_instance_valid(key_binding_panel) and key_binding_panel.visible:
		if event is InputEventKey and key_binding_panel.handle_key(event):
			get_viewport().set_input_as_handled()
		return
	if ranking_open or not trial.started:
		if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
			_change_difficulty(-1 if event.is_action_pressed(&"ui_left") else 1)
			get_viewport().set_input_as_handled()
			return
	var confirm := event.is_action_pressed(&"resume_trial", false, true) or (
		event is InputEventJoypadButton and event.is_action_pressed(&"ui_accept"))
	if confirm and (ranking_open or not trial.started):
		if ranking_open:
			_toggle_ranking()
		else:
			trial.start_trial()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		if _handle_shortcut(event):
			get_viewport().set_input_as_handled()
		elif trial.started and not ranking_open and not paused and result.is_empty():
			for action in [&"attack", &"dodge", &"sword_skill"]:
				if event.is_action_pressed(action, false, true):
					press_pulses[action] = PRESS_PULSE_DURATION
	elif event is InputEventScreenTouch and mobile:
		if not event.pressed or event.canceled:
			if _release(event.index, event.canceled):
				get_viewport().set_input_as_handled()
		elif _press(event.position, event.index):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and mobile and event.index == joystick_finger:
		_move_stick(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not event.canceled and _press(event.position, -2):
			get_viewport().set_input_as_handled()
		elif (not event.pressed or event.canceled) and _release(-2, event.canceled):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and joystick_finger == -2:
		_move_stick(event.position)
		get_viewport().set_input_as_handled()


func _handle_shortcut(event: InputEventKey) -> bool:
	if event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		_toggle_ranking()
		return true
	if ranking_open:
		if event.is_action_pressed(&"ui_cancel"):
			_toggle_ranking()
		return true
	if not trial.started:
		return true
	if (paused or not result.is_empty()) and event.is_action_pressed(&"restart_trial", false, true):
		trial.restart()
		return true
	if not result.is_empty():
		return false
	if event.is_action_pressed(&"pause") or (
			paused and event.is_action_pressed(&"resume_trial", false, true)):
		if not paused:
			menu = "设置"
		_toggle_pause()
		return true
	for label in MENU_ACTIONS:
		if label != "设置" and event.is_action_pressed(MENU_ACTIONS[label], false, true):
			if not paused or menu == label:
				_toggle_pause()
			menu = label
			return true
	if not paused:
		for action in EXTRA_COMBAT_ACTIONS:
			if event.is_action_pressed(action, false, true):
				_activate_combat(action)
				return true
	return false


func _press(point: Vector2, finger: int) -> bool:
	if ranking_open:
		if rank_back_rect.has_point(point) or _menu_bounds("排行榜").has_point(point):
			_toggle_ranking()
		else:
			_press_difficulty(point)
		return true
	if _menu_bounds("排行榜").has_point(point):
		_toggle_ranking()
		return true
	if not trial.started:
		if start_rect.has_point(point):
			trial.start_trial()
		else:
			_press_difficulty(point)
		return true
	if paused or not result.is_empty():
		if restart_rect.has_point(point):
			trial.restart()
		elif paused and menu == "设置" and not mobile and key_settings_rect.has_point(point):
			key_binding_panel.open()
		elif paused and menu == "设置" and skin_settings_rect.has_point(point):
			trial.toggle_skin()
		elif paused and menu == "设置" and music_settings_rect.has_point(point):
			trial.audio.toggle_music()
		elif paused and menu == "设置" and effects_settings_rect.has_point(point):
			trial.audio.toggle_effects()
		elif paused and resume_rect.has_point(point):
			_toggle_pause()
		return true
	for label in MENUS:
		if _menu_bounds(label).has_point(point):
			menu = label
			_toggle_pause()
			return true
	if joystick_finger == -1 and pad.distance_to(point) <= WHEEL_RADIUS * ui_scale:
		joystick_finger = finger
		_move_stick(point)
		return true
	var chosen: StringName = &""
	var best := INF
	for action in controls:
		var radius: float = BUTTONS[action][1].x * ui_scale / 2.0
		var distance: float = point.distance_to(controls[action]) / (radius + 4.0)
		if distance <= 1.0 and distance < best:
			best = distance
			chosen = action
	if chosen.is_empty():
		return false
	held_buttons[finger] = chosen
	press_pulses[chosen] = PRESS_PULSE_DURATION
	if chosen == &"attack":
		if trial.player.begin_attack():
			attack_finger = finger
	else:
		_activate_combat(chosen)
	return true


func _activate_combat(action: StringName) -> void:
	press_pulses[action] = PRESS_PULSE_DURATION
	match action:
		&"switch":
			trial.request_switch()
		&"medicine":
			trial.use_medicine()
		_:
			trial.player.request(action)


func _move_stick(point: Vector2) -> void:
	stick = ((point - pad) / (83.0 * ui_scale)).limit_length()
	trial.player.touch_move = stick if stick.length() >= 0.17 else Vector2.ZERO


func _release(finger: int, canceled := false) -> bool:
	if finger == attack_finger:
		attack_finger = -3
		if trial.player.attack_input == null:
			if canceled:
				trial.player.cancel_attack()
			else:
				trial.player.release_attack()
	if finger == joystick_finger:
		_reset_stick()
		return true
	return held_buttons.erase(finger)


func _reset_touch() -> void:
	attack_finger = -3
	trial.player.cancel_attack()
	trial.switch_requested = false
	held_buttons.clear()
	press_pulses.clear()
	_reset_stick()


func _reset_stick() -> void:
	joystick_finger = -1
	stick = Vector2.ZERO
	trial.player.touch_move = Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(trial):
		_reset_touch()


func _toggle_pause() -> void:
	paused = not paused
	_reset_touch()
	trial.player.pending.clear()
	get_tree().paused = paused


func show_result(value: String) -> void:
	result = value
	_layout()
	paused = false
	_reset_touch()


func _toggle_ranking() -> void:
	ranking_open = not ranking_open
	if ranking_open:
		ranking_difficulty = trial.difficulty
	_reset_touch()
	trial.player.pending.clear()
	get_tree().paused = ranking_open or paused or not result.is_empty()


func _draw() -> void:
	if not is_instance_valid(trial):
		return
	if ranking_open or not trial.started or not result.is_empty():
		if ranking_open:
			_draw_ranking()
		elif not trial.started:
			_draw_start()
		else:
			_draw_score_result()
		_draw_ranking_icon()
		return
	var player = trial.player
	_draw_fighter(player, safe.position + Vector2(23, 22) * ui_scale, true)
	_draw_fighter(trial.reserve, safe.position + Vector2(399, 29) * ui_scale, false)
	var objective := safe.position + Vector2(81, 234) * ui_scale
	var title: String = trial.stage_title()
	var quest: String = trial.objective()
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(18)).x
	var quest_width := font.get_string_size(quest, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(22)).x
	var text_width := maxf(title_width, quest_width)
	var tablet := Rect2(objective + Vector2(-17, -27) * ui_scale,
		Vector2(maxf(178.0 * ui_scale, text_width + 38.0 * ui_scale), 65.0 * ui_scale))
	_panel(tablet)
	_hud_art(11, objective + Vector2(-24, -4) * ui_scale, 64.0 * ui_scale)
	_text(title, objective + Vector2(8, -3) * ui_scale, _px(18), GOLD)
	_text(quest, objective + Vector2(8, 24) * ui_scale, _px(22), MINT)
	for label in MENU_ART:
		var bounds := _menu_bounds(label)
		_hud_art(MENU_ART[label], bounds.get_center(), bounds.size.x)
		_draw_key_hint(MENU_ACTIONS[label], Vector2(bounds.get_center().x, bounds.end.y))
	_draw_ranking_icon()
	_draw_map()
	_draw_boss_health()
	_draw_touch(player)
	if paused:
		_draw_modal()


func _draw_ranking_icon() -> void:
	var bounds := _menu_bounds("排行榜")
	draw_texture_rect(RANKING_ICON, bounds, false)
	_center("排行榜", Vector2(bounds.get_center().x, bounds.end.y), _px(15), GOLD)


func _card_point(x: float, y: float) -> Vector2:
	return trial_card.position + Vector2(x, y) * card_scale


func _card_line(value: String, y: float, size_px: int, color: Color) -> void:
	_center(value, _card_point(255, y), maxi(1, roundi(size_px * card_scale)), color)


func _card_button(bounds: Rect2, label: String) -> void:
	_panel(bounds)
	_center(label, bounds.get_center() + Vector2(0, 7) * card_scale,
		maxi(1, roundi(20 * card_scale)), MINT)


func _draw_trial_card(kicker: String, title: String) -> void:
	draw_rect(get_viewport_rect(), Color("#0b1c17b8"))
	_panel(trial_card)
	_card_line(kicker, 46, 18, GOLD)
	_card_line(title, 102, 40, MINT)


func _difficulty_button(step: int) -> Rect2:
	var center := _card_point(255 + 112 * step, 137 if ranking_open else 187)
	var extent := Vector2(46, 40) * card_scale
	return Rect2(center - extent / 2.0, extent)


func _change_difficulty(step: int) -> void:
	if ranking_open:
		ranking_difficulty = clampi(ranking_difficulty + step, 0, trial.scores.highest_unlocked())
	else:
		trial.select_difficulty(step)


func _press_difficulty(point: Vector2) -> void:
	for step in [-1, 1]:
		if _difficulty_button(step).has_point(point):
			_change_difficulty(step)
			return


func _draw_difficulty(difficulty: int, baseline: float) -> void:
	_card_line(SCORES.DIFFICULTY_NAMES[difficulty], baseline, 23, MINT)
	if difficulty > 0:
		_card_button(_difficulty_button(-1), "‹")
	if difficulty < trial.scores.highest_unlocked():
		_card_button(_difficulty_button(1), "›")


func _draw_start() -> void:
	_draw_trial_card("凡尘修仙录  ·  1-1 至 1-3", "竹林试炼")
	_card_line("清竹径  ·  战精英  ·  斩兽王", 145, 21, GOLD)
	_draw_difficulty(trial.difficulty, 194)
	if trial.difficulty < SCORES.MAX_DIFFICULTY:
		var next: String = SCORES.DIFFICULTY_NAMES[trial.difficulty + 1]
		var hint := "可重玩已解锁的难度"
		if trial.difficulty == trial.scores.highest_unlocked():
			hint = "通关后解锁%s" % next
		_card_line(hint, 234, 16, MUTED)
	_card_button(start_rect, "开始试炼")
	if not mobile:
		var bindings := get_node_or_null("/root/KeyBindings")
		var key: String = bindings.label_for(&"resume_trial") if bindings else "Enter"
		_card_line("← → 难度    /    %s 开始    /    F2 排行榜" % key, 343, 16, MUTED)


func _draw_score_result() -> void:
	var difficulty: String = SCORES.DIFFICULTY_NAMES[trial.difficulty]
	_draw_trial_card("竹林试炼  ·  %s  ·  %s" % [difficulty, result],
		"%d 分  ·  %s" % [trial.final_score.total, trial.final_score.grade])
	var score: Dictionary = trial.final_score
	_card_line("伤害 %d    操作 %d    过关 %d" % [score.damage, score.technique, score.progress],
		155, 20, MINT)
	_card_line("用时奖励 %d    %s %d" % [score.time, "祭坛 · 破阵" if score.shrine > 0 else "祭坛奖励", score.shrine], 192, 20, MINT)
	_card_line("用时 %s    击败 %d" % [_format_time(floori(trial.elapsed)), trial.defeated_total],
		235, 17, MUTED)
	if trial.score_save_error != OK:
		_card_line("存档写入失败，本局成绩和进度未保存", 276, 16, VERMILION)
	elif trial.unlocked_difficulty >= 0:
		_card_line("已解锁%s" % SCORES.DIFFICULTY_NAMES[trial.unlocked_difficulty], 276, 19, GOLD)
	elif result == "试炼完成" and trial.difficulty == SCORES.MAX_DIFFICULTY:
		_card_line("已完成最高难度", 276, 19, GOLD)
	elif result == "试炼完成":
		_card_line("已与本机前五名比较", 276, 16, GOLD)
	else:
		_card_line("通关成绩可进入排行榜", 276, 16, MUTED)
	_card_button(restart_rect, "继续挑战" if trial.unlocked_difficulty >= 0 else "重新开始")


func _draw_ranking() -> void:
	_draw_trial_card("竹林试炼  ·  本机前五名", "试炼排行榜")
	_draw_difficulty(ranking_difficulty, 144)
	var records: Array[Dictionary] = trial.scores.records_for(ranking_difficulty)
	if records.is_empty():
		_card_line("还没有通关成绩", 225, 22, MUTED)
	for index in range(records.size()):
		var entry: Dictionary = records[index]
		var y := 180.0 + index * 28.0
		var size_px := maxi(1, roundi(19 * card_scale))
		var tint := GOLD if index == 0 else MINT
		_text("%02d" % (index + 1), _card_point(85, y), size_px, tint)
		_center("%s  ·  %d 分" % [SCORES.grade(entry.points), entry.points],
			_card_point(255, y), size_px, tint)
		_text(_format_time(floori(entry.ms / 1000.0)), _card_point(370, y), size_px, MUTED)
	_card_button(rank_back_rect, "返回")


func _format_time(seconds: int) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), seconds % 60]


func _draw_boss_health() -> void:
	var ratio: float = trial.boss_health()
	if ratio < 0.0:
		return
	var width := 320.0 * ui_scale
	var center := Vector2(safe.get_center().x, safe.end.y - 39.0 * ui_scale)
	var bar := Rect2(center - Vector2(width / 2.0, 0), Vector2(width, 10.0 * ui_scale))
	_panel(bar.grow(4.0 * ui_scale))
	draw_rect(Rect2(bar.position, Vector2(width * ratio, bar.size.y)), Color("#db794c"))
	_center(trial.BOSS_NAME, center - Vector2(0, 13.0 * ui_scale), _px(20), GOLD)


func _seal(key, center: Vector2, extent: float, tint: Color) -> void:
	var size := Vector2.ONE * extent
	var source := Rect2(SEAL_INDEX[key] * 64, 0, 64, 64)
	draw_texture_rect_region(SEALS, Rect2(center - size / 2.0, size), source, tint)


func _px(reference: float) -> int:
	return maxi(1, roundi(reference * ui_scale))


func _draw_fighter(fighter: CharacterBody2D, origin: Vector2, primary: bool) -> void:
	var unit := ui_scale * (1.0 if primary else 0.65)
	var portrait_box := Rect2(origin, Vector2(138, 109) * unit)
	var plate := Rect2(origin + Vector2(115, 9) * unit, Vector2(250, 87) * unit)
	_panel(plate)
	_panel(portrait_box)
	var portraits := CULTIVATION_PORTRAITS if trial.cultivation_skin else PORTRAITS
	var source := Rect2(fighter.portrait * 192, 0, 192, 139)
	var picture := portrait_box.grow(-6.0 * unit)
	draw_texture_rect_region(portraits, picture, source)
	var gauge_x := origin.x + 247.0 * unit
	var mp_at := Vector2(gauge_x, origin.y + 48.0 * unit)
	var hp_at := Vector2(gauge_x, origin.y + 73.0 * unit)
	_center("%s  Lv.%d" % [FIGHTER_TITLES[fighter.portrait], fighter.level],
		Vector2(gauge_x, origin.y + 33.0 * unit), maxi(1, roundi(22.0 * unit)), GOLD)
	_gauge(mp_at, Vector2(211, 15) * unit, fighter.mp / fighter.max_mp, true, primary)
	_gauge(hp_at, Vector2(211, 23) * unit, float(fighter.vitals.hp) / fighter.vitals.max_hp)
	if primary:
		_center("%d/%d" % [fighter.vitals.hp, fighter.vitals.max_hp],
			hp_at + Vector2(0, 6) * unit, _px(17), Color.WHITE)
	var ult_ratio: float = fighter.ultimate / fighter.MAX_ULTIMATE
	var ult_at := origin + Vector2(161, 115) * unit
	var ult_size := Vector2(104, 34) * unit
	_panel(Rect2(ult_at - ult_size / 2.0 + Vector2(35, 0) * unit, ult_size))
	var ult_bounds := Rect2(ult_at - Vector2.ONE * 13.0 * unit, Vector2.ONE * 26.0 * unit)
	var ult_tint := Color.WHITE if ult_ratio >= 1.0 else Color(0.53, 0.53, 0.53)
	draw_texture_rect(_ultimate_icon(fighter), ult_bounds, false, ult_tint)
	for index in range(3):
		var bead := ult_at + Vector2(19 + index * 18, 0) * unit
		var charge := clampf(ult_ratio * 3.0 - index, 0.0, 1.0)
		_diamond(bead, 6.0 * unit, Color("#59432a").lerp(VERMILION, charge))
	var technique_at := ult_at + Vector2(143, 0) * unit
	var technique_ready: bool = fighter.parry_follow_up > 0.0
	var marks: int = fighter.lantern_marks if fighter.is_mage() else fighter.sword_momentum
	var technique_color := Color("#b6f4ff") if fighter.is_mage() else GOLD
	var label := "灯印" if fighter.is_mage() else ("振刀" if technique_ready else "剑势")
	_center(label, technique_at + Vector2(-20, 5) * unit, maxi(1, roundi(14.0 * unit)), technique_color)
	for index in range(3):
		var bead := technique_at + Vector2(index * 13 + 5, 0) * unit
		_diamond(bead, 4.0 * unit, technique_color if technique_ready or index < marks else Color("#59432a"))
	if primary and fighter.dodge_time > 0.0:
		_seal(&"dodge", ult_at + Vector2(102, 0) * unit, 28.0 * unit, JADE)
	elif primary and fighter.hurt_time > 0.0:
		_seal(&"skill_two", ult_at + Vector2(102, 0) * unit, 28.0 * unit, VERMILION)


func _gauge(center: Vector2, extent: Vector2, ratio: float, mana := false, split := false) -> void:
	var start := center - extent / 2.0
	draw_texture_rect_region(JADE_HUD, Rect2(start, extent), Rect2(0, 256, 256, 32))
	var fraction := clampf(ratio, 0.0, 1.0)
	var inner := extent - Vector2.ONE * 3.0 * ui_scale
	if fraction > 0.0:
		var bounds := Rect2(start + Vector2.ONE * 1.5 * ui_scale,
			Vector2(inner.x * fraction, inner.y))
		var source := Rect2(256 if mana else 0, 768, 256 * fraction, 32)
		draw_texture_rect_region(HUD_ART, bounds, source)
	if split:
		var half_height := Vector2(0.0, extent.y / 2.0)
		draw_line(center - half_height, center + half_height, Color("#14352c"), 3.0 * ui_scale)
		_diamond(center, 2.7 * ui_scale, GOLD)


func _draw_map() -> void:
	var radius := 116.0 * ui_scale
	var center := _anchor(Vector2(0.852, 0.275), Vector2.ONE * radius)
	var map_radius := radius * 0.88
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for index in range(48):
		var edge := Vector2.from_angle(index * TAU / 48.0)
		points.append(center + edge * map_radius)
		uvs.append(Vector2(0.5, 0.5) + edge * 0.5)
	draw_colored_polygon(points, Color.WHITE, uvs, MINIMAP)
	_hud_art(6, center, radius * 2.0)
	var exit_at := center + (GROVE.EXIT / GROVE.WORLD_SIZE - Vector2(0.5, 0.5)).limit_length(0.46) * map_radius * 2.0
	var player_position: Vector2 = trial.player.position
	var player_at := center + (player_position / GROVE.WORLD_SIZE - Vector2(0.5, 0.5)).limit_length(0.46) * map_radius * 2.0
	_diamond(exit_at, 5.0 * ui_scale, GOLD)
	if trial.grove.shrine_lit:
		var shrine_at := center + (GROVE.SHRINE / GROVE.WORLD_SIZE - Vector2(0.5, 0.5)).limit_length(0.46) * map_radius * 2.0
		_diamond(shrine_at, 5.0 * ui_scale, MINT)
	_diamond(player_at, 6.0 * ui_scale, JADE)
	var nameplate := Rect2(center + Vector2(-60, 104) * ui_scale, Vector2(120, 33) * ui_scale)
	_panel(nameplate)
	_center("竹林", nameplate.get_center() + Vector2(0, 7) * ui_scale, _px(22), GOLD)


func _draw_touch(player: CharacterBody2D) -> void:
	_draw_joystick()
	_touch_button(&"attack", player.swing_cooldown)
	var charge: float = player.attack_charge
	var attack_radius := ATTACK_DIAMETER * 0.5
	if player.counter_time > 0.0:
		var center: Vector2 = controls[&"attack"]
		var swap: bool = player.reaction == player.Reaction.SWITCH
		var tint := GOLD if swap else MINT
		var remaining: float = player.counter_time / player.COUNTER_WINDOW
		draw_arc(center, (attack_radius + 1.0) * ui_scale, -PI / 2.0, TAU * remaining - PI / 2.0,
			48, tint, 4.0 * ui_scale, true)
		var baseline := center - Vector2(0, attack_radius + 13.0) * ui_scale
		var label := "换人反击" if swap else "闪避反击"
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(22)).x
		_panel(Rect2(baseline - Vector2(width * 0.5 + 12.0 * ui_scale, 24.0 * ui_scale),
			Vector2(width + 24.0 * ui_scale, 34.0 * ui_scale)))
		_center(label, baseline, _px(22), tint)
	elif charge >= 0.15:
		var attack_center: Vector2 = controls[&"attack"]
		var edge := (attack_radius + 4.0) * ui_scale
		var tint := GOLD if charge >= 1.0 else MINT
		draw_arc(attack_center, edge, -PI / 2.0, TAU * charge - PI / 2.0,
			48, tint, 4.0 * ui_scale, true)
		_center("松手释放" if charge >= 1.0 else "蓄力中",
			attack_center - Vector2(0, attack_radius + 13.0) * ui_scale, _px(20), tint)
	_touch_button(&"switch", 0.0, trial.reserve.vitals.hp > 0)
	_touch_button(&"sword_skill", player.skill_cooldown, player.mp >= player.SKILL_COST, player.SKILL_RECOVERY)
	_touch_button(&"dodge", player.dodge_cooldown, true, player.DODGE_RECOVERY)
	_touch_button(&"ultimate", 0.0, player.ultimate >= player.MAX_ULTIMATE)
	_touch_button(&"skill_two", player.skill_two_cooldown, player.can_use_skill_two(), player.SKILL_TWO_RECOVERY)
	_touch_button(&"medicine", trial.medicine_cooldown, trial.medicine > 0, trial.MEDICINE_RECOVERY)
	var center: Vector2 = controls[&"medicine"]
	var badge := center + Vector2(31, 23) * ui_scale
	draw_circle(badge, 11.0 * ui_scale, Color("#122d29"), true, -1.0, true)
	draw_arc(badge, 11.0 * ui_scale, 0.0, TAU, 24, GOLD, 1.5 * ui_scale, true)
	_center(str(trial.medicine), badge + Vector2(0, 5) * ui_scale, _px(15), MINT)


func _draw_joystick() -> void:
	var radius := WHEEL_RADIUS * ui_scale
	var engaged := stick.length() >= 0.17
	_hud_art(4, pad, radius * 2.0)
	# Cover the cap baked into the atlas with a recessed center. The cap sprite
	# below is the only moving layer, including when the stick is at rest.
	draw_circle(pad + Vector2(0, 4) * ui_scale, 74.0 * ui_scale, Color("#345650"), true, -1.0, true)
	draw_circle(pad, 67.0 * ui_scale, Color("#264942"), true, -1.0, true)
	draw_circle(pad, 61.0 * ui_scale, Color("#365d53"), true, -1.0, true)
	draw_arc(pad, 67.0 * ui_scale, 0.0, PI, 32, Color("#63887a"), 2.0 * ui_scale, true)
	if engaged:
		# Light both directional arrows when the stick crosses both axis thresholds.
		for index in range(4):
			var angle := index * TAU / 4.0
			var direction := Vector2.from_angle(angle)
			if stick.dot(direction) < 0.27:
				continue
			draw_set_transform(pad + direction * radius * 0.71, angle + PI / 2.0,
				Vector2.ONE * ui_scale)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -12), Vector2(14, 11), Vector2(-14, 11)
			]), Color("#ff9c27"))
			draw_set_transform(Vector2.ZERO)
	var offset := stick * 83.0 * ui_scale if engaged else Vector2.ZERO
	_hud_art(5, pad + offset, 114.0 * ui_scale)


func _hud_art(cell: int, center: Vector2, diameter: float, tint := Color.WHITE) -> void:
	var extent := Vector2.ONE * diameter
	var source := Rect2(Vector2(cell % 4, floori(float(cell) / 4.0)) * 256.0, Vector2.ONE * 256.0)
	draw_texture_rect_region(HUD_ART, Rect2(center - extent / 2.0, extent), source, tint)


func _ultimate_icon(fighter: CharacterBody2D) -> Texture2D:
	return MAGE_ULTIMATE_ICON if fighter.is_mage() else SWORD_ULTIMATE_ICON


func _touch_button(action: StringName, cooldown: float, available := true, recovery := 0.0) -> void:
	var center: Vector2 = controls[action]
	var footprint: Vector2 = BUTTONS[action][1]
	var radius := footprint.x * ui_scale / 2.0
	var held := action in held_buttons.values()
	var pulse: float = press_pulses.get(action, 0.0) / PRESS_PULSE_DURATION
	var press_scale := 1.0 - 0.10 * pulse * pulse
	var extent := footprint * ui_scale * press_scale
	var bounds := Rect2(center - extent / 2.0, extent)
	var cooling := recovery > 0.0 and cooldown > 0.0
	var tint := Color.WHITE if available or cooling else Color(0.48, 0.53, 0.52, 0.88)
	if action == &"switch":
		draw_texture_rect(SWITCH_ICON, bounds, false, tint)
	elif action == &"ultimate":
		draw_texture_rect(_ultimate_icon(trial.player), bounds, false, tint)
		if trial.player.is_mage():
			_draw_spell_label("八方灯阵", bounds, tint)
	elif trial.player.is_mage() and action in MAGE_SPELLS:
		_draw_mage_spell(action, bounds, tint)
	elif action == &"medicine":
		draw_texture_rect(MEDICINE_ART, bounds, false, tint)
	elif action in ACTION_ART:
		_hud_art(ACTION_ART[action], center, extent.x, tint)
	if cooling:
		draw_texture_rect(COOLDOWN_ART, bounds, false, Color(1, 1, 1, 0.78))
		var remaining := clampf(cooldown / recovery, 0.0, 1.0)
		draw_arc(center, extent.x * 0.45, -PI / 2.0, TAU * remaining - PI / 2.0,
			48, GOLD, 3.0 * ui_scale, true)
		_center("%.1f" % cooldown, center + Vector2(0, 8) * ui_scale, _px(26), Color.WHITE)
	var active := held or pulse > 0.0
	var charged := action == &"ultimate" and available
	if active or charged:
		var opacity := maxf(0.84 if held else 0.0, pulse)
		var glow_size := Vector2.ONE * (radius * 2.12 + 6.0 * ui_scale)
		draw_texture_rect(ACTIVE_ART, Rect2(center - glow_size / 2.0, glow_size), false,
			Color(1, 1, 1, maxf(opacity, 0.52 if charged else 0.0)))
	_draw_key_hint(action, center + Vector2(0, footprint.y / 2.0 - 4.0) * ui_scale)


func _draw_mage_spell(action: StringName, bounds: Rect2, tint: Color) -> void:
	var spell: Array = MAGE_SPELLS[action]
	var index: int = spell[0]
	var cell := Vector2(index % 2, index >> 1) * MAGE_ICON_SIZE
	draw_texture_rect_region(MAGE_ICON_ART, bounds, Rect2(cell, Vector2.ONE * MAGE_ICON_SIZE), tint)
	_draw_spell_label(spell[1], bounds, tint)


func _draw_spell_label(label: String, bounds: Rect2, tint: Color) -> void:
	var size := _px(15)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := bounds.get_center() + Vector2(-width / 2.0, bounds.size.y * 0.30)
	draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _px(3),
		Color("#0b1c17") * tint)
	_text(label, baseline, size, MINT * tint)


func _draw_key_hint(action: StringName, baseline: Vector2) -> void:
	if mobile:
		return
	var label := KeyBindings.label_for(action)
	var size := _px(16)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var padding := 5.0 * ui_scale
	draw_rect(Rect2(baseline.x - width / 2.0 - padding, baseline.y - size,
		width + padding * 2.0, size + padding), Color("#0b1c17e8"))
	_center(label, baseline, size, MINT)


func _diamond(center: Vector2, radius: float, tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2.UP * radius,
		center + Vector2.RIGHT * radius, center + Vector2.DOWN * radius,
		center + Vector2.LEFT * radius]), tint)


func _draw_modal() -> void:
	draw_rect(get_viewport_rect(), Color("#0b1c17b8"))
	_panel(modal)
	var center := modal.get_center()
	_center("凡尘修仙录  ·  竹林试炼", Vector2(center.x, modal.position.y + 43), 18, GOLD)
	_center(menu, Vector2(center.x, modal.position.y + 103), 39, MINT)
	var seconds := int(trial.elapsed)
	var stats_y := modal.end.y - (105.0 if paused and menu == "设置" else 120.0)
	_center("等级 %d   击败 %d   经验 +%d   药品 %d   用时 %02d:%02d" % [
		trial.player.level, trial.defeated_total,
		trial.earned_xp, trial.potions, floori(seconds / 60.0), seconds % 60],
		Vector2(center.x, stats_y), 18, MUTED)
	if paused:
		var detail := ""
		match menu:
			"队伍信息":
				detail = "出战 Lv.%d   /   替补 Lv.%d" % [trial.player.level, trial.reserve.level]
			"人物状态":
				var player = trial.player
				detail = "攻击 %d   防御 %d   经验 %d/%d" % [
					player.attack, player.vitals.defense, player.xp, player.xp_goal]
			"背包":
				detail = "已装备  血瓶 × %d" % trial.medicine
				if trial.sealed_jars > 0:
					var label := "封口丹罐 × %d" % trial.sealed_jars
					var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
					var left := center.x - (width + 40.0) / 2.0
					draw_texture_rect(SEALED_JAR_ICON,
						Rect2(left, modal.position.y + 150, 32, 32), false)
					_text(label, Vector2(left + 40.0, modal.position.y + 173), 18, MINT)
			"设置":
				if not mobile:
					_button(key_settings_rect, "键位设置")
				_button(skin_settings_rect, "皮肤  %s" % ("修仙" if trial.cultivation_skin else "原始"))
				_button(music_settings_rect, "音乐  %s" % ("8-bit" if trial.audio.retro_music else "标准"))
				_button(effects_settings_rect, "音效  %s" % ("8-bit" if trial.audio.retro_effects else "标准"))
		_center(detail, Vector2(center.x, modal.position.y + 138), 17, MINT)
	if paused:
		_button(resume_rect, "继续试炼")
		_draw_key_hint(&"resume_trial", Vector2(resume_rect.get_center().x, resume_rect.end.y))
	_button(restart_rect, "重新开始")
	_draw_key_hint(&"restart_trial", Vector2(restart_rect.get_center().x, restart_rect.end.y))


func _panel(bounds: Rect2) -> void:
	draw_style_box(panel_skin, bounds)

func _button(bounds: Rect2, label: String) -> void:
	_panel(bounds)
	_center(label, bounds.get_center() + Vector2(0, 7), 20, MINT)


func _center(value: String, anchor: Vector2, size_px: int, color: Color) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	_text(value, anchor - Vector2(width / 2.0, 0), size_px, color)


func _text(value: String, anchor: Vector2, size_px: int, color: Color) -> void:
	draw_string(font, anchor, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
