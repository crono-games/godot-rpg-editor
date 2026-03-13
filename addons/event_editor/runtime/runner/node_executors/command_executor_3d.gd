class_name CommandExecutor2D
extends RefCounted

var _handlers := {}

func _init() -> void:
	_handlers = {
		"move": MoveExecutor.new(),
		"move_along_path": MoveAlongPathExecutor.new(),
		"flag_condition": FlagConditionExecutor.new(),
		"set_flag": SetFlagExecutor.new(),
		"set_local_flag": SetFlagExecutor.new(),
		"set_variable": SetVariableExecutor.new(),
		"variable_operation": VariableOperationExecutor.new(),
		"variable_condition": VariableConditionExecutor.new(),
		"condition": ConditionExecutor.new(),
		"change_graphics": ChangeGraphicsExecutor.new(),
		"set_visibility": SetVisibilityExecutor.new(),
		"change_screen_tone": ChangeScreenToneExecutor.new(),
		"teleport_player": TeleportPlayerExecutor.new(),
		"set_position": SetPositionExecutor.new(),
		"set_followers": SetFollowersExecutor.new(),
		"show_dialogue": DialogueExecutor.new(),
		"choice": ChoiceExecutor.new(),
		"wait": WaitExecutor.new(),
		"play_bgm": PlayBGMExecutor.new(),
		"play_se": PlaySEExecutor.new(),
		"play_animation": PlayAnimationExecutor.new(),
		"play_visual_fx": PlayVisualFxExecutor.new(),
		"show_picture": ShowPictureExecutor.new(),
		"move_picture": MovePictureExecutor.new(),
		"erase_picture": ErasePictureExecutor.new(),
		"give_items": GiveItemsExecutor.new(),
		"label": LabelExecutor.new(),
		"jump_to_label": JumpToLabelExecutor.new(),
		"screen_shake": ScreenShakeExecutor.new()
	}

func set_handler(node_type: String, handler: RefCounted) -> void:
	if node_type == "" or handler == null:
		return
	_handlers[node_type] = handler

func has_handler(node_type: String) -> bool:
	return _handlers.has(node_type)

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, scene_root: Node) -> String:
	var node_type := str(node.get("type", ""))
	var handler: RefCounted = _handlers.get(node_type, null)
	if handler == null:
		return graph.get_next(node_id, 0)
	return await handler.run(node_id, node, graph, ctx, scene_root)
