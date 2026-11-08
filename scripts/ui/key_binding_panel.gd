extends Control

const PANEL_TEXTURE := preload("res://assets/ui/jade_panel.png")
const GOLD := Color("#d9b777")
const MINT := Color("#e2f0d1")

var _buttons: Dictionary[StringName, Button] = {}
var _capture: StringName
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("#0b1c17de")
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var skin := StyleBoxTexture.new()
	skin.texture = PANEL_TEXTURE
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		skin.set_texture_margin(side, 12.0)
	skin.content_margin_left = 24.0
	skin.content_margin_right = 24.0
	skin.content_margin_top = 20.0
	skin.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", skin)
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)

	var title := Label.new()
	title.text = "键位设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 30)
	body.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 5)
	body.add_child(grid)
	for action in KeyBindings.ACTIONS:
		var button := _add_button(grid, "", _begin_capture.bind(action))
		button.custom_minimum_size = Vector2(326, 34)
		_buttons[action] = button

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", GOLD)
	body.add_child(_status)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	body.add_child(footer)
	_add_button(footer, "保存为默认", _save)
	_add_button(footer, "恢复已保存", _restore_saved)
	_add_button(footer, "出厂键位", _restore_factory)
	_add_button(footer, "返回", close)
	KeyBindings.bindings_changed.connect(_refresh)
	_refresh()
	hide()


func open() -> void:
	_status.text = "选择操作后按下新键。斜线后的备用输入会保留。"
	show()
	_buttons[&"move_up"].grab_focus()


func close() -> void:
	_capture = &""
	_refresh()
	hide()


func handle_key(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return not _capture.is_empty()
	if event.physical_keycode == KEY_ESCAPE:
		if _capture.is_empty():
			close()
		else:
			_capture = &""
			_status.text = "已取消改键。"
			_refresh()
		return true
	if _capture.is_empty():
		return false
	if event.physical_keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return true
	var error := KeyBindings.rebind(_capture, event)
	if error.is_empty():
		_capture = &""
		_status.text = "已生效。选择「保存为默认」可在下次启动时使用。"
		_refresh()
	else:
		_status.text = error + "  Esc 取消"
	return true


func _add_button(parent: Container, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 38
	button.add_theme_color_override("font_color", MINT)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _begin_capture(action: StringName) -> void:
	_capture = action
	_status.text = "按下新键，Esc 取消。" if action != &"restart_trial" else "按 Shift + 新键，Esc 取消。"
	_refresh()


func _refresh() -> void:
	for action in _buttons:
		var binding := "等待输入…" if action == _capture else KeyBindings.label_for(action, true)
		_buttons[action].text = "%s   %s" % [KeyBindings.ACTIONS[action], binding]


func _save() -> void:
	_capture = &""
	_status.text = "已保存为默认键位。" if KeyBindings.save_default() == OK else "保存失败，请检查存储空间后重试。"
	_refresh()


func _restore_saved() -> void:
	_capture = &""
	KeyBindings.restore_saved()
	_status.text = "已恢复保存的默认键位。"


func _restore_factory() -> void:
	_capture = &""
	KeyBindings.restore_factory()
	_status.text = "已恢复出厂键位。选择「保存为默认」可保留此方案。"
