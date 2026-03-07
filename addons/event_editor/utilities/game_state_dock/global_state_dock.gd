@tool
extends Control
class_name GameStateDock

var _expanded_button_pos : Vector2

@export var folded := true
@export var flags_list: FlagList
@export var variables_list: VariableList

var _global_state: GlobalState

func _ready():
	_apply_global_state()

func update_icon():
	pass

func set_global_state(state: GlobalState) -> void:
	_global_state = state
	_apply_global_state()

func _apply_global_state() -> void:
	if _global_state == null:
		return

	if flags_list != null:
		flags_list.set_global_state(_global_state)

	if variables_list != null:
		variables_list.set_global_state(_global_state)
