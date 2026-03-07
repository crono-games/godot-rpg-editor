class_name EventTypes

const MOVE = "move"
const MOVE_ALONG_PATH = "move_along_path"
const SET_POSITION = "set_position"
const SET_FOLLOWERS = "set_followers"
const SET_FLAG = "set_flag"
const SET_LOCAL_FLAG = "set_local_flag"
const SET_VARIABLE = "set_variable"
const FLAG_CONDITION = "flag_condition"
const VARIABLE_CONDITION = "variable_condition"
const CONDITION = "condition"
const VARIABLE_OPERATION = "variable_operation"
const SHOW_DIALOGUE = "show_dialogue"
const CHOICE = "choice"
const WAIT = "wait"
const STATE = "state"
const JUMP_TO_STATE = "jump_to_state"
const CHANGE_GRAPHICS = "change_graphics"
const SET_VISIBILITY = "set_visibility"
const CHANGE_SCREEN_TONE = "change_screen_tone"
const TELEPORT_PLAYER = "teleport_player"
const PLAY_BGM = "play_bgm"
const PLAY_SE = "play_se"
const PLAY_ANIMATION = "play_animation"
const PLAY_VISUAL_FX = "play_visual_fx"
const SHOW_PICTURE = "show_picture"
const MOVE_PICTURE = "move_picture"
const ERASE_PICTURE = "erase_picture"
const GIVE_ITEMS = "give_items"
const LABEL = "label"
const JUMP_TO_LABEL = "jump_to_label"
const SCREEN_SHAKE = "screen_shake"

const ALL := [
	MOVE,
	MOVE_ALONG_PATH,
	SET_POSITION,
	SET_FOLLOWERS,
	SET_FLAG,
	SET_LOCAL_FLAG,
	SET_VARIABLE,
	FLAG_CONDITION,
	VARIABLE_CONDITION,
	CONDITION,
	VARIABLE_OPERATION,
	SHOW_DIALOGUE,
	CHOICE,
	WAIT,
	STATE,
	JUMP_TO_STATE,
	CHANGE_GRAPHICS,
	SET_VISIBILITY,
	CHANGE_SCREEN_TONE,
	TELEPORT_PLAYER,
	PLAY_BGM,
	PLAY_SE,
	PLAY_ANIMATION,
	PLAY_VISUAL_FX,
	SHOW_PICTURE,
	MOVE_PICTURE,
	ERASE_PICTURE,
	GIVE_ITEMS,
	LABEL,
	JUMP_TO_LABEL,
	SCREEN_SHAKE
]

static func is_valid(type: String) -> bool:
	return type in ALL
