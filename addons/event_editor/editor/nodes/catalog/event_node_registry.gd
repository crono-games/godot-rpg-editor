class_name EventNodeRegistry

const DATA := {
	EventTypes.CHANGE_GRAPHICS: {
		"name": "Change Graphics",
		"scene": preload("res://addons/event_editor/editor/nodes/change_graphics/change_graphics_node.tscn"),
		"category": "actor",
	},
	EventTypes.SET_VISIBILITY: {
		"name": "Set Visibility",
		"scene": preload("res://addons/event_editor/editor/nodes/set_visibility/set_visibility_node.tscn"),
		"category": "actor",
	},
	EventTypes.CHANGE_SCREEN_TONE: {
		"name": "Change Screen Tone",
		"scene": preload("res://addons/event_editor/editor/nodes/change_screen_tone/change_screen_tone_node.tscn"),
		"category": "screen",
	},
	EventTypes.PLAY_BGM: {
		"name": "Play BGM",
		"scene": preload("res://addons/event_editor/editor/nodes/play_bgm/play_bgm_node.tscn"),
		"category": "screen",
	},
	EventTypes.PLAY_SE: {
		"name": "Play SE",
		"scene": preload("res://addons/event_editor/editor/nodes/play_se/play_se_node.tscn"),
		"category": "screen",
	},
	EventTypes.PLAY_ANIMATION: {
		"name": "Play Animation",
		"scene": preload("res://addons/event_editor/editor/nodes/play_animation/play_animation_node.tscn"),
		"category": "actor",
	},
	EventTypes.PLAY_VISUAL_FX: {
		"name": "Play Visual FX",
		"scene": preload("res://addons/event_editor/editor/nodes/play_visual_fx/play_visual_fx_node.tscn"),
		"category": "screen",
	},
	EventTypes.SHOW_PICTURE: {
		"name": "Show Picture",
		"scene": preload("res://addons/event_editor/editor/nodes/show_picture/show_picture_node.tscn"),
		"category": "pictures",
	},
	EventTypes.MOVE_PICTURE: {
		"name": "Move Picture",
		"scene": preload("res://addons/event_editor/editor/nodes/move_picture/move_picture_node.tscn"),
		"category": "pictures",
	},
	EventTypes.ERASE_PICTURE: {
		"name": "Erase Picture",
		"scene": preload("res://addons/event_editor/editor/nodes/erase_picture/erase_picture_node.tscn"),
		"category": "pictures",
	},
	EventTypes.GIVE_ITEMS: {
		"name": "Give Items",
		"scene": preload("res://addons/event_editor/editor/nodes/give_items/give_items_node.tscn"),
		"category": "progression",
	},
	EventTypes.LABEL: {
		"name": "Label",
		"scene": preload("res://addons/event_editor/editor/nodes/label/label_node.tscn"),
		"category": "flow_control",
	},
	EventTypes.JUMP_TO_LABEL: {
		"name": "Jump To Label",
		"scene": preload("res://addons/event_editor/editor/nodes/jump_to_label/jump_to_label_node.tscn"),
		"category": "flow_control",
	},
	EventTypes.SCREEN_SHAKE: {
		"name": "Screen Shake",
		"scene": preload("res://addons/event_editor/editor/nodes/screen_shake/screen_shake_node.tscn"),
		"category": "screen",
	},
	EventTypes.TELEPORT_PLAYER: {
		"name": "Teleport Player",
		"scene": preload("res://addons/event_editor/editor/nodes/teleport_player/teleport_player_node.tscn"),
		"category": "movement",
	},
	EventTypes.MOVE: {
		"name": "Move",
		"scene": preload("res://addons/event_editor/editor/nodes/move/move_node.tscn"),
		"category": "movement",
	},
	EventTypes.MOVE_ALONG_PATH: {
		"name": "Move Along Path",
		"scene": preload("res://addons/event_editor/editor/nodes/move_along_path/move_along_path_node.tscn"),
		"category": "movement",
	},
	EventTypes.SET_POSITION: {
		"name": "Set Position",
		"scene": preload("res://addons/event_editor/editor/nodes/set_position/set_position_node.tscn"),
		"category": "movement",
	},
	EventTypes.SET_FOLLOWERS: {
		"name": "Set Followers",
		"scene": preload("res://addons/event_editor/editor/nodes/set_followers/set_followers_node.tscn"),
		"category": "movement",
	},
	EventTypes.SET_FLAG: {
		"name": "Set Flag",
		"scene": preload("res://addons/event_editor/editor/nodes/set_flag/set_flag_node.tscn"),
		"category": "progression",
	},
	EventTypes.SET_LOCAL_FLAG: {
		"name": "Set Local Flag",
		"scene": preload("res://addons/event_editor/editor/nodes/set_local_flag/set_local_flag_node.tscn"),
		"category": "progression",
	},
	EventTypes.SET_VARIABLE: {
		"name": "Set Variable",
		"scene": preload("res://addons/event_editor/editor/nodes/set_variable/set_variable_node.tscn"),
		"category": "progression",
	},
	EventTypes.VARIABLE_OPERATION: {
		"name": "Variable Operation",
		"scene": preload("res://addons/event_editor/editor/nodes/variable_operation/variable_operation_node.tscn"),
		"category": "progression",
	},
	EventTypes.VARIABLE_CONDITION: {
		"name": "Variable Condition",
		"scene": preload("res://addons/event_editor/editor/nodes/variable_condition/variable_condition_node.tscn"),
		"category": "flow_control",
	},
	EventTypes.CONDITION: {
		"name": "Condition",
		"scene": preload("res://addons/event_editor/editor/nodes/condition/condition_node.tscn"),
		"category": "flow_control",
	},
	EventTypes.STATE: {
		"name": "State",
		"scene": preload("res://addons/event_editor/editor/nodes/state/state_node.tscn"),
	},
	EventTypes.FLAG_CONDITION: {
		"name": "Flag Condition",
		"scene": preload("res://addons/event_editor/editor/nodes/flag_condition/flag_condition_node.tscn"),
		"category": "flow_control",
	},
	EventTypes.SHOW_DIALOGUE: {
		"name": "Show Dialogue",
		"scene": preload("res://addons/event_editor/editor/nodes/dialogue/dialogue_node.tscn"),
		"category": "message",
	},
	EventTypes.CHOICE: {
		"name": "Show Choices",
		"scene": preload("res://addons/event_editor/editor/nodes/choices/choices_node.tscn"),
		"category": "message",
	},
	EventTypes.WAIT: {
		"name": "Wait",
		"scene": preload("res://addons/event_editor/editor/nodes/wait/wait_node.tscn"),
		"category": "flow_control",
	},
}

static func get_types() -> Array:
	return DATA.keys()

static func get_entry(type: String) -> Dictionary:
	if not DATA.has(type):
		return {}
	return DATA[type]

static func get_scene_for_type(type: String) -> PackedScene:
	var entry := get_entry(type)
	return entry.get("scene", null)

static func get_state_script(type: String) -> Script:
	var entry := get_entry(type)
	return entry.get("state", null)
