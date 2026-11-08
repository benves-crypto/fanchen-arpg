extends Node

const SAVE_PATH := "user://keyboard.cfg"
const ACTIONS := {
	&"move_up": "向上移动", &"move_down": "向下移动",
	&"move_left": "向左移动", &"move_right": "向右移动",
	&"attack": "普攻", &"sword_skill": "技能一", &"skill_two": "技能二",
	&"ultimate": "绝招", &"dodge": "闪避", &"switch": "切换角色", &"medicine": "使用血瓶",
	&"party_menu": "队伍信息", &"character_menu": "人物状态", &"inventory_menu": "背包",
	&"pause": "设置 / 暂停", &"resume_trial": "继续试炼", &"restart_trial": "重新开始",
}
const IGNORE_MODIFIERS := [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"attack", &"sword_skill", &"dodge", &"pause",
]

signal bindings_changed

var _factory := {}
var _saved := {}
var _alternates := {}
var _current := {}
var _labels := {}


func _ready() -> void:
	for action in ACTIONS:
		var events := InputMap.action_get_events(action)
		_factory[action] = _binding_code(events.pop_front())
		_alternates[action] = events
	_saved = _factory.duplicate()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		var stored: Variant = config.get_value("keyboard", "bindings", {})
		if stored is Dictionary and stored.size() == ACTIONS.size():
			var valid := true
			for action in ACTIONS:
				var code: Variant = stored.get(action)
				if not code is Vector2i or not _binding_error(action, code, stored).is_empty():
					valid = false
					break
			if valid:
				_saved = stored
	_apply(_saved)


func label_for(action: StringName, include_alternates := false) -> String:
	var label: String = _labels[action]
	if include_alternates:
		for event in _alternates[action]:
			var alternate := _format_key(_binding_code(event)) if event is InputEventKey else "鼠标左键"
			label += " / " + alternate
	return label


func rebind(action: StringName, event: InputEventKey) -> String:
	if event.alt_pressed or event.ctrl_pressed or event.meta_pressed:
		return "请使用单键，重新开始使用 Shift + 键。"
	var code := _binding_code(event)
	var error := _binding_error(action, code, _current)
	if not error.is_empty():
		return error
	var updated := _current.duplicate()
	updated[action] = code
	_apply(updated)
	return ""


func save_default() -> Error:
	var config := ConfigFile.new()
	config.set_value("keyboard", "bindings", _current)
	var temporary := SAVE_PATH + ".tmp"
	var error := config.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, SAVE_PATH)
	if error == OK:
		_saved = _current.duplicate()
	return error


func restore_saved() -> void:
	_apply(_saved)


func restore_factory() -> void:
	_apply(_factory)


func _apply(bindings: Dictionary) -> void:
	for action in ACTIONS:
		var code: Vector2i = bindings[action]
		if code == _current.get(action):
			continue
		Input.action_release(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = code.x
		event.shift_pressed = code.y == 1
		InputMap.action_add_event(action, event)
		_labels[action] = _format_key(code)
		for alternate in _alternates[action]:
			InputMap.action_add_event(action, alternate)
	_current = bindings.duplicate()
	bindings_changed.emit()


func _binding_error(action: StringName, code: Vector2i, bindings: Dictionary) -> String:
	if code.x in [KEY_NONE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META] or OS.get_keycode_string(code.x).is_empty():
		return "请按一个有效的键。"
	if code.x == KEY_ESCAPE and action != &"pause":
		return "Esc 保留用于取消和返回。"
	var required_shift := int(action == &"restart_trial")
	if code.y != required_shift:
		return "请按 Shift + 键。" if required_shift else "请按单键，无需 Shift。"
	for other in ACTIONS:
		if other == action:
			continue
		var other_code: Variant = bindings.get(other)
		if other_code is Vector2i and _overlaps(action, code, other, other_code):
			return "与「%s」冲突，请换一个键。" % ACTIONS[other]
		for alternate in _alternates[other]:
			if alternate is InputEventKey and _overlaps(action, code, other, _binding_code(alternate)):
				return "与「%s」的备用键冲突，请换一个键。" % ACTIONS[other]
	return ""


func _overlaps(action: StringName, code: Vector2i, other: StringName, other_code: Vector2i) -> bool:
	return code.x == other_code.x and (
		code.y == other_code.y or action in IGNORE_MODIFIERS or other in IGNORE_MODIFIERS)


func _binding_code(event: InputEventKey) -> Vector2i:
	return Vector2i(event.physical_keycode, int(event.shift_pressed))


func _format_key(code: Vector2i) -> String:
	var key: Key = code.x
	if DisplayServer.get_name() != "headless":
		var layout_key := DisplayServer.keyboard_get_label_from_physical(key)
		if layout_key != KEY_NONE:
			key = layout_key
	return ("Shift+" if code.y == 1 else "") + OS.get_keycode_string(key)
