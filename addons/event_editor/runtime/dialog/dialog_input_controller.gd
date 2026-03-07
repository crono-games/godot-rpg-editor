@tool
extends Node
class_name DialogueInputController

@export var runner : DialogueRunner
@export var dialog_box : DialogueBox
@export var accept_action := "ui_accept"

var _accept_armed := false
var _was_idle := true

func _process(delta: float) -> void:
	_update_accept_arm()
	if runner.state == DialogueRunner.State.WAITING:
		if Engine.is_editor_hint():
			runner.next()

func _unhandled_input(event):
	if runner.state == DialogueRunner.State.IDLE:
		return
	if not _is_accept_allowed(event):
		return

	if runner.state == DialogueRunner.State.TYPING:
		if event.is_action_pressed(accept_action):
			dialog_box.skip_typing()

	elif runner.state == DialogueRunner.State.WAITING:
		if Engine.is_editor_hint():
			runner.next()
		if event.is_action_pressed(accept_action):
			runner.next()

	elif runner.state == DialogueRunner.State.CHOOSING:
		if event.is_action_pressed("ui_down"):
			dialog_box.move_choice(+1)
		elif event.is_action_pressed("ui_up"):
			dialog_box.move_choice(-1)
		elif event.is_action_pressed(accept_action):
			dialog_box.confirm_choice()

func _update_accept_arm() -> void:
	if runner == null:
		return
	var is_idle := runner.state == DialogueRunner.State.IDLE
	if _was_idle and not is_idle:
		_accept_armed = false
	_was_idle = is_idle
	if is_idle:
		_accept_armed = true
		return
	if not Input.is_action_pressed(accept_action):
		_accept_armed = true

func _is_accept_allowed(event: InputEvent) -> bool:
	if event == null:
		return false
	if event.is_action_released(accept_action):
		_accept_armed = true
		return false
	if event.is_action_pressed(accept_action):
		return _accept_armed
	return true
