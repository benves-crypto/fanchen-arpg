extends Control

const INK := Color("#152b26eb")
const MINT := Color("#c8f4d8")
const GOLD := Color("#f0c686")
const MUTED := Color("#adcbba")
const PAD_RADIUS := 130.0
const STICK_TRAVEL := 76.0
const STICK_KNOB_RADIUS := 44.0
const BUTTON_RADII := {&"attack": 74.0, &"sword_skill": 60.0, &"dodge": 60.0}
const BUTTON_HIT_MARGIN := 4.0

var trial
var mobile := false
var paused := false
var result := ""
var joystick_finger := -1
var stick := Vector2.ZERO
var safe := Rect2()
var pad := Vector2.ZERO
var controls := {}
var pause_rect := Rect2()
var restart_rect := Rect2()
var resume_rect := Rect2()
var modal := Rect2()
var font := ThemeDB.fallback_font


func bind(game: Node2D) -> void:
	trial = game
	mobile = OS.has_feature("mobile")
	_layout()


func _process(_delta: float) -> void:
	if is_instance_valid(trial):
		_layout()
		queue_redraw()


func _layout() -> void:
	safe = get_viewport_rect()
	if OS.has_feature("mobile"):
		var physical := Rect2(DisplayServer.get_display_safe_area())
		var inset := safe.intersection(get_viewport().get_screen_transform().affine_inverse() * physical)
		if inset.has_area():
			safe = inset
	safe = safe.grow(-22)
	pad = Vector2(safe.position.x + clampf(safe.size.x * 0.18, 205.0, 295.0), safe.end.y - 180.0)
	var corner := safe.end
	var attack := corner - Vector2(clampf(safe.size.x * 0.17, 220.0, 280.0), 164.0)
	controls = {
		&"attack": attack,
		&"sword_skill": attack + Vector2(125, -84),
		&"dodge": attack + Vector2(125, 87),
	}
	var pause_size := Vector2(92, 52) if mobile else Vector2(76, 42)
	pause_rect = Rect2(Vector2(corner.x - pause_size.x, safe.position.y), pause_size)
	modal = Rect2(safe.get_center() - Vector2(248, 145), Vector2(496, 290))
	restart_rect = Rect2(modal.position + Vector2(261, 218), Vector2(174, 46))
	resume_rect = Rect2(modal.position + Vector2(60, 218), Vector2(174, 46))


func _input(event: InputEvent) -> void:
	if not is_instance_valid(trial):
		return
	if event.is_action_pressed("pause") and not event.is_echo() and result.is_empty():
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and mobile:
		if event.index == joystick_finger and (not event.pressed or event.canceled):
			_reset_touch()
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.canceled and _press(event.position, event.index):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and mobile and event.index == joystick_finger:
		_move_stick(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _press(event.position):
			get_viewport().set_input_as_handled()


func _press(point: Vector2, finger := -1) -> bool:
	if paused or not result.is_empty():
		if restart_rect.has_point(point):
			trial.restart()
		elif paused and resume_rect.has_point(point):
			_toggle_pause()
		return true
	if pause_rect.has_point(point):
		_toggle_pause()
		return true
	if finger < 0:
		return false
	if joystick_finger < 0 and pad.distance_to(point) <= PAD_RADIUS + 12.0:
		joystick_finger = finger
		_move_stick(point)
		return true
	for action in controls:
		var radius: float = BUTTON_RADII[action] + BUTTON_HIT_MARGIN
		if point.distance_to(controls[action]) <= radius:
			trial.player.request(action)
			return true
	return false


func _move_stick(point: Vector2) -> void:
	stick = ((point - pad) / STICK_TRAVEL).limit_length()
	trial.player.touch_move = stick if stick.length() >= 0.17 else Vector2.ZERO


func _reset_touch() -> void:
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
	paused = false
	_reset_touch()


func _draw() -> void:
	if not is_instance_valid(trial):
		return
	var player = trial.player
	var origin := safe.position
	_panel(Rect2(origin, Vector2(304, 118)))
	_text("剑修  Lv.%d   攻 %d  防 %d" % [player.level, player.attack, player.vitals.defense],
		origin + Vector2(14, 26), 21, MINT)
	_bar(origin + Vector2(14, 37), 276, player.vitals.hp, player.vitals.max_hp, Color("#a45450"), "HP")
	_bar(origin + Vector2(14, 62), 276, player.mp, player.max_mp, Color("#477a86"), "MP")
	_bar(origin + Vector2(14, 87), 276, player.xp, player.xp_goal, Color("#8d794c"), "EXP")
	var objective := Rect2(origin + Vector2(323, 0), Vector2(358, 65))
	_panel(objective)
	_text("竹林试炼  /  当前目标", objective.position + Vector2(14, 23), 16, GOLD)
	_text(trial.progress.objective(), objective.position + Vector2(14, 48), 20, MINT)
	_button(pause_rect, "暂停")
	if mobile:
		_draw_touch(player)
	else:
		var footer := Rect2(Vector2(origin.x, safe.end.y - 42), Vector2(662, 42))
		_panel(footer)
		_text("WASD / 方向键 移动    左键 / J 普攻    K 御剑 %s    空格 闪避 %s"
			% [_cooldown(player.skill_cooldown), _cooldown(player.dodge_cooldown)],
			footer.position + Vector2(13, 27), 17, MUTED)
	if paused or not result.is_empty():
		_draw_modal()


func _draw_touch(player: CharacterBody2D) -> void:
	draw_circle(pad, PAD_RADIUS, Color("#142d27b4"))
	draw_arc(pad, PAD_RADIUS, 0, TAU, 64, Color("#96bfaa9c"), 3.0, true)
	draw_arc(pad, PAD_RADIUS - 15.0, 0, TAU, 64, Color("#96bfaa50"), 2.0, true)
	var knob := pad + stick * STICK_TRAVEL
	draw_circle(knob, STICK_KNOB_RADIUS, Color("#42775fee"), true, -1.0, true)
	draw_arc(knob, STICK_KNOB_RADIUS, 0, TAU, 48, MINT, 2.0, true)
	_touch_button(&"attack", "攻击", true)
	_touch_button(&"sword_skill", "御剑 " + _cooldown(player.skill_cooldown),
		player.skill_cooldown == 0.0 and player.mp >= player.SKILL_COST)
	_touch_button(&"dodge", "闪避 " + _cooldown(player.dodge_cooldown),
		player.dodge_cooldown == 0.0)


func _touch_button(action: StringName, label: String, available: bool) -> void:
	var center: Vector2 = controls[action]
	var radius: float = BUTTON_RADII[action]
	var primary := action == &"attack"
	var rim := GOLD if available else Color("#777c6e")
	draw_circle(center, radius, Color("#493a24e0") if primary else Color("#182c24e0"), true, -1.0, true)
	draw_arc(center, radius, 0, TAU, 48, rim, 4.0 if primary else 3.0, true)
	var font_size := 30 if primary else 24
	_center(label.strip_edges(), center + Vector2(0, font_size / 3.0), font_size, MINT if available else MUTED)


func _draw_modal() -> void:
	draw_rect(get_viewport_rect(), Color("#0b1c17b8"))
	_panel(modal)
	var center := modal.get_center()
	_center("凡尘修仙录  ·  竹林试炼", Vector2(center.x, modal.position.y + 43), 18, GOLD)
	_center("试炼暂停" if paused else result, Vector2(center.x, modal.position.y + 103), 39, MINT)
	var seconds := int(trial.elapsed)
	_center("等级 %d   击败 %d   经验 +%d   药品 %d   用时 %02d:%02d" % [
		trial.player.level, trial.progress.defeated_regular + int(trial.progress.elite_defeated),
		trial.earned_xp, trial.potions, floori(seconds / 60.0), seconds % 60],
		Vector2(center.x, modal.position.y + 170), 18, MUTED)
	if paused:
		_button(resume_rect, "继续试炼")
	_button(restart_rect, "重新开始")


func _cooldown(value: float) -> String:
	return "%.1fs" % value if value > 0.0 else ""


func _panel(bounds: Rect2) -> void:
	draw_rect(bounds, INK)
	draw_rect(bounds, Color("#729680"), false, 1.0)


func _button(bounds: Rect2, label: String) -> void:
	_panel(bounds)
	_center(label, bounds.get_center() + Vector2(0, 7), 20, MINT)


func _bar(origin: Vector2, width: float, value: float, maximum: float, color: Color, label: String) -> void:
	draw_rect(Rect2(origin, Vector2(width, 19)), Color("#31453d"))
	draw_rect(Rect2(origin, Vector2(width * clampf(value / maximum, 0.0, 1.0), 19)), color)
	_text("%s  %d / %d" % [label, int(value), int(maximum)], origin + Vector2(7, 15), 14, Color.WHITE)


func _center(value: String, anchor: Vector2, size_px: int, color: Color) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	_text(value, anchor - Vector2(width / 2.0, 0), size_px, color)


func _text(value: String, anchor: Vector2, size_px: int, color: Color) -> void:
	draw_string(font, anchor, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
