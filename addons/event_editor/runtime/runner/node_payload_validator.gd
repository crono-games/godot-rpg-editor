class_name NodePayloadValidator
extends RefCounted

func validate(node_id: String, node: Dictionary) -> Dictionary:
	if node == null:
		return _error("Node is null")
	var node_type := str(node.get("type", ""))
	if node_type == "":
		return _error("Node type is empty")
	var params = node.get("params", {})
	if not (params is Dictionary):
		return _error("Node params must be Dictionary")
	var normalized := node.duplicate(true)
	var normalized_params: Dictionary = normalized.get("params", {})
	var warnings: Array = []

	match node_type:
		"move":
			var move_result := _normalize_move(normalized_params)
			if not bool(move_result.get("ok", false)):
				return move_result
			warnings.append_array(move_result.get("warnings", []))
		"move_along_path":
			var move_path_result := _normalize_move_along_path(normalized_params)
			if not bool(move_path_result.get("ok", false)):
				return move_path_result
			warnings.append_array(move_path_result.get("warnings", []))
		"set_position":
			var set_pos_result := _normalize_set_position(normalized_params)
			if not bool(set_pos_result.get("ok", false)):
				return set_pos_result
			warnings.append_array(set_pos_result.get("warnings", []))
		"set_followers":
			var followers_result := _normalize_set_followers(normalized_params)
			if not bool(followers_result.get("ok", false)):
				return followers_result
			warnings.append_array(followers_result.get("warnings", []))
		"set_visibility":
			var visibility_result := _normalize_set_visibility(normalized_params)
			if not bool(visibility_result.get("ok", false)):
				return visibility_result
			warnings.append_array(visibility_result.get("warnings", []))
		"change_graphics":
			var change_graphics_result := _normalize_change_graphics(normalized_params)
			if not bool(change_graphics_result.get("ok", false)):
				return change_graphics_result
			warnings.append_array(change_graphics_result.get("warnings", []))
		"set_flag", "set_local_flag":
			var set_flag_result := _normalize_set_flag(normalized_params, node_type)
			if not bool(set_flag_result.get("ok", false)):
				return set_flag_result
			warnings.append_array(set_flag_result.get("warnings", []))
		"set_variable":
			var set_variable_result := _normalize_set_variable(normalized_params)
			if not bool(set_variable_result.get("ok", false)):
				return set_variable_result
			warnings.append_array(set_variable_result.get("warnings", []))
		"variable_operation":
			var variable_op_result := _normalize_variable_operation(normalized_params)
			if not bool(variable_op_result.get("ok", false)):
				return variable_op_result
			warnings.append_array(variable_op_result.get("warnings", []))
		"variable_condition":
			var variable_cond_result := _normalize_variable_condition(normalized_params)
			if not bool(variable_cond_result.get("ok", false)):
				return variable_cond_result
			warnings.append_array(variable_cond_result.get("warnings", []))
		"condition":
			var condition_result := _normalize_condition(normalized_params)
			if not bool(condition_result.get("ok", false)):
				return condition_result
			warnings.append_array(condition_result.get("warnings", []))
		"change_screen_tone":
			var tone_result := _normalize_change_screen_tone(normalized_params)
			if not bool(tone_result.get("ok", false)):
				return tone_result
			warnings.append_array(tone_result.get("warnings", []))
		"teleport_player":
			var tp_result := _normalize_teleport_player(normalized_params)
			if not bool(tp_result.get("ok", false)):
				return tp_result
			warnings.append_array(tp_result.get("warnings", []))
		"play_bgm":
			var bgm_result := _normalize_play_bgm(normalized_params)
			if not bool(bgm_result.get("ok", false)):
				return bgm_result
			warnings.append_array(bgm_result.get("warnings", []))
		"play_se":
			var se_result := _normalize_play_se(normalized_params)
			if not bool(se_result.get("ok", false)):
				return se_result
			warnings.append_array(se_result.get("warnings", []))
		"play_animation":
			var play_anim_result := _normalize_play_animation(normalized_params)
			if not bool(play_anim_result.get("ok", false)):
				return play_anim_result
			warnings.append_array(play_anim_result.get("warnings", []))
		"play_visual_fx":
			var play_fx_result := _normalize_play_visual_fx(normalized_params)
			if not bool(play_fx_result.get("ok", false)):
				return play_fx_result
			warnings.append_array(play_fx_result.get("warnings", []))
		"show_picture":
			var show_picture_result := _normalize_show_picture(normalized_params)
			if not bool(show_picture_result.get("ok", false)):
				return show_picture_result
			warnings.append_array(show_picture_result.get("warnings", []))
		"move_picture":
			var move_picture_result := _normalize_move_picture(normalized_params)
			if not bool(move_picture_result.get("ok", false)):
				return move_picture_result
			warnings.append_array(move_picture_result.get("warnings", []))
		"erase_picture":
			var erase_picture_result := _normalize_erase_picture(normalized_params)
			if not bool(erase_picture_result.get("ok", false)):
				return erase_picture_result
			warnings.append_array(erase_picture_result.get("warnings", []))
		"give_items":
			var give_items_result := _normalize_give_items(normalized_params)
			if not bool(give_items_result.get("ok", false)):
				return give_items_result
			warnings.append_array(give_items_result.get("warnings", []))
		"wait":
			var wait_result := _normalize_wait(normalized_params)
			if not bool(wait_result.get("ok", false)):
				return wait_result
			warnings.append_array(wait_result.get("warnings", []))
		"label":
			var label_result := _normalize_label(normalized_params)
			if not bool(label_result.get("ok", false)):
				return label_result
			warnings.append_array(label_result.get("warnings", []))
		"jump_to_label":
			var jump_label_result := _normalize_jump_to_label(normalized_params)
			if not bool(jump_label_result.get("ok", false)):
				return jump_label_result
			warnings.append_array(jump_label_result.get("warnings", []))
		"screen_shake":
			var shake_result := _normalize_screen_shake(normalized_params)
			if not bool(shake_result.get("ok", false)):
				return shake_result
			warnings.append_array(shake_result.get("warnings", []))
		_:
			pass

	normalized["params"] = normalized_params
	return {
		"ok": true,
		"error": "",
		"warnings": warnings,
		"node": normalized
	}

func _normalize_move(params: Dictionary) -> Dictionary:
	var route = params.get("route", [])
	if not (route is Array):
		return _error("move.params.route must be Array")
	var normalized_route: Array = []
	var warnings: Array = []
	for step in route:
		if not (step is Dictionary):
			return _error("move.route items must be Dictionary")
		var normalized_step: Dictionary = step.duplicate(true)
		var action := str(step.get("action_type", "")).to_lower()
		if action == "wait":
			normalized_step["duration"] = max(0, int(_to_number(step.get("duration", 1), 1)))
			normalized_route.append(normalized_step)
			continue
		var direction = step.get("direction", {})
		if not (direction is Dictionary):
			return _error("move.route.direction must be Dictionary")
		normalized_step["direction"] = {
			"x": _to_number(direction.get("x", 0.0), 0.0),
			"y": _to_number(direction.get("y", 0.0), 0.0),
			"z": _to_number(direction.get("z", 0.0), 0.0)
		}
		if action == "jump":
			normalized_step["jump_height"] = maxf(0.0, _to_number(step.get("jump_height", 0.5), 0.5))
			normalized_step["jump_time"] = maxf(0.01, _to_number(step.get("jump_time", 0.24), 0.24))
		normalized_route.append(normalized_step)
	params["route"] = normalized_route
	params["wait_for_completion"] = _to_bool(params.get("wait_for_completion", true), true)
	return _ok_with_warnings(warnings)

func _normalize_move_along_path(params: Dictionary) -> Dictionary:
	params["target_id"] = str(params.get("target_id", params.get("target", ""))).strip_edges()
	params["target_name"] = str(params.get("target_name", "")).strip_edges()
	var raw_points = params.get("points", [])
	if not (raw_points is Array):
		return _error("move_along_path.params.points must be Array")
	var normalized_points: Array = []
	for p in raw_points:
		if p is Vector2:
			normalized_points.append({"x": p.x, "y": p.y})
		elif p is Vector3:
			normalized_points.append({"x": p.x, "y": p.z if absf(p.z) > 0.0001 else p.y})
		elif p is Dictionary:
			normalized_points.append({
				"x": _to_number(p.get("x", 0.0), 0.0),
				"y": _to_number(p.get("y", p.get("z", 0.0)), 0.0)
			})
		else:
			return _error("move_along_path.params.points contains invalid item")
	params["points"] = normalized_points
	params["speed_px_per_sec"] = maxf(1.0, _to_number(params.get("speed_px_per_sec", params.get("speed", 64.0)), 64.0))
	params["loop"] = _to_bool(params.get("loop", false), false)
	params["wait_for_completion"] = _to_bool(params.get("wait_for_completion", true), true)
	params["return_back_on_finish"] = _to_bool(params.get("return_back_on_finish", false), false)
	params["snap_to_first_point"] = _to_bool(params.get("snap_to_first_point", false), false)
	params["curve_enabled"] = _to_bool(params.get("curve_enabled", false), false)
	params["curve_subdivisions"] = maxi(1, int(_to_number(params.get("curve_subdivisions", 6), 6)))
	params["avoid_player"] = _to_bool(params.get("avoid_player", true), true)
	params["avoid_radius_px"] = maxf(4.0, _to_number(params.get("avoid_radius_px", 14.0), 14.0))
	params["sidestep_px"] = maxf(8.0, _to_number(params.get("sidestep_px", 20.0), 20.0))
	return _ok_with_warnings([])

func _normalize_set_position(params: Dictionary) -> Dictionary:
	var target_position = params.get("target_position", Vector3.ZERO)
	if not _is_position_like(target_position):
		return _error("set_position.params.target_position has invalid type")
	params["target_position"] = _to_position_dict(target_position)
	return _ok_with_warnings([])

func _normalize_set_followers(params: Dictionary) -> Dictionary:
	var action := str(params.get("action", "add")).to_lower()
	if action != "add" and action != "remove" and action != "clear":
		action = "add"
	params["action"] = action
	params["actor_id"] = str(params.get("actor_id", params.get("target_id", ""))).strip_edges()
	params["actor_name"] = str(params.get("actor_name", params.get("target_name", params.get("target", "")))).strip_edges()
	params["slot_index"] = maxi(-1, int(_to_number(params.get("slot_index", -1), -1)))
	params["make_persistent"] = _to_bool(params.get("make_persistent", false), false)
	if action != "clear" and str(params.get("actor_id", "")) == "" and str(params.get("actor_name", "")) == "":
		return _error("set_followers.params.actor_id/actor_name are empty")
	return _ok_with_warnings([])

func _normalize_set_visibility(params: Dictionary) -> Dictionary:
	params["target_id"] = str(params.get("target_id", params.get("target", ""))).strip_edges()
	params["target_name"] = str(params.get("target_name", "")).strip_edges()
	params["visible"] = _to_bool(params.get("visible", true), true)
	params["disable_collision"] = _to_bool(params.get("disable_collision", false), false)
	return _ok_with_warnings([])

func _normalize_change_graphics(params: Dictionary) -> Dictionary:
	var graphics_path := str(params.get("graphics", ""))
	if graphics_path == "":
		return _error("change_graphics.params.graphics is empty")
	params["graphics"] = graphics_path.strip_edges()
	return _ok_with_warnings([])

func _normalize_set_flag(params: Dictionary, node_type: String) -> Dictionary:
	var flag_name := str(params.get("flag_name", ""))
	if flag_name == "":
		return _error("set_flag.params.flag_name is empty")
	params["flag_name"] = flag_name
	params["state"] = _to_bool(params.get("state", false), false)
	var scope := str(params.get("scope", "global")).to_lower()
	if node_type == "set_local_flag":
		scope = "local"
	elif scope != "global" and scope != "local":
		scope = "global"
	params["scope"] = scope
	return _ok_with_warnings([])

func _normalize_set_variable(params: Dictionary) -> Dictionary:
	var variable_name := str(params.get("variable_name", ""))
	if variable_name == "":
		return _error("set_variable.params.variable_name is empty")
	params["variable_name"] = variable_name
	params["value"] = _to_number(params.get("value", 0), 0)
	return _ok_with_warnings([])

func _normalize_variable_operation(params: Dictionary) -> Dictionary:
	var variable_name := str(params.get("variable_name", ""))
	if variable_name == "":
		return _error("variable_operation.params.variable_name is empty")
	params["variable_name"] = variable_name
	params["value"] = _to_number(params.get("value", 0), 0)
	params["operator"] = _normalize_operator(str(params.get("operator", "+")))
	var mode := str(params.get("mode", "ticks")).to_lower()
	if mode != "ticks" and mode != "seconds":
		mode = "ticks"
	params["mode"] = mode
	return _ok_with_warnings([])

func _normalize_variable_condition(params: Dictionary) -> Dictionary:
	var var_name := str(params.get("var_name", ""))
	if var_name == "":
		var_name = str(params.get("variable_name", ""))
	if var_name == "":
		return _error("variable_condition.params.var_name is empty")
	params["var_name"] = var_name
	var condition_param = params.get("condition_param", {})
	if not (condition_param is Dictionary):
		return _error("variable_condition.params.condition_param must be Dictionary")
	var normalized_condition = condition_param.duplicate(true)
	normalized_condition["operator"] = _normalize_comparator(str(condition_param.get("operator", "==")))
	normalized_condition["value"] = _to_number(condition_param.get("value", 0), 0)
	params["condition_param"] = normalized_condition
	return _ok_with_warnings([])

func _normalize_condition(params: Dictionary) -> Dictionary:
	var subject := str(params.get("subject", "player")).strip_edges().to_lower()
	var property_name := str(params.get("property", "facing_dir")).strip_edges().to_lower()
	var operator := _normalize_comparator(str(params.get("operator", "==")))
	var value_text := str(params.get("value", "")).strip_edges()
	var target_id := str(params.get("target_id", "")).strip_edges()
	var target_name := str(params.get("target_name", "")).strip_edges()

	if subject == "":
		subject = "player"
	if property_name == "":
		property_name = "facing_dir"

	if property_name == "facing_dir":
		if operator != "==" and operator != "!=":
			operator = "=="
		if value_text == "":
			value_text = "down"
	elif property_name == "distance_to_event":
		if value_text == "":
			value_text = "0"
		if target_id == "" and target_name == "":
			return _error("condition.params.target_id/target_name required for distance_to_event")

	params["subject"] = subject
	params["property"] = property_name
	params["operator"] = operator
	params["value"] = value_text
	params["target_id"] = target_id
	params["target_name"] = target_name
	return _ok_with_warnings([])

func _normalize_change_screen_tone(params: Dictionary) -> Dictionary:
	var color = params.get("color", {})
	if not (color is Dictionary):
		return _error("change_screen_tone.params.color must be Dictionary")
	params["color"] = {
		"r": clampf(_to_number(color.get("r", 255.0), 255.0), 0.0, 255.0),
		"g": clampf(_to_number(color.get("g", 255.0), 255.0), 0.0, 255.0),
		"b": clampf(_to_number(color.get("b", 255.0), 255.0), 0.0, 255.0),
		"a": clampf(_to_number(color.get("a", 0.0), 0.0), 0.0, 255.0)
	}
	if params.has("duration_frames"):
		params["duration_frames"] = max(0, int(_to_number(params.get("duration_frames", 0), 0)))
	else:
		params["duration_frames"] = max(0, int(_to_number(params.get("duration", 0), 0)))
	return _ok_with_warnings([])

func _normalize_teleport_player(params: Dictionary) -> Dictionary:
	var target_position = params.get("target_position", Vector3.ZERO)
	if not _is_position_like(target_position):
		return _error("teleport_player.params.target_position has invalid type")
	params["target_position"] = _to_position_dict(target_position)
	params["map_id"] = str(params.get("map_id", ""))
	params["auto_fade"] = _to_bool(params.get("auto_fade", true), true)
	params["fade_frames"] = max(0, int(_to_number(params.get("fade_frames", 30), 30)))
	var facing := str(params.get("facing_dir", "keep")).strip_edges().to_lower()
	if facing != "keep" and facing != "down" and facing != "left" and facing != "right" and facing != "up":
		facing = "keep"
	params["facing_dir"] = facing
	return _ok_with_warnings([])

func _normalize_play_bgm(params: Dictionary) -> Dictionary:
	var stream_path := str(params.get("stream_path", "")).strip_edges()
	if stream_path == "":
		return _error("play_bgm.params.stream_path is empty")
	params["stream_path"] = stream_path
	params["volume_db"] = clampf(_to_number(params.get("volume_db", 0.0), 0.0), -80.0, 24.0)
	params["pitch_scale"] = maxf(0.01, _to_number(params.get("pitch_scale", 1.0), 1.0))
	params["loop"] = _to_bool(params.get("loop", true), true)
	return _ok_with_warnings([])

func _normalize_play_se(params: Dictionary) -> Dictionary:
	var stream_path := str(params.get("stream_path", "")).strip_edges()
	if stream_path == "":
		return _error("play_se.params.stream_path is empty")
	params["stream_path"] = stream_path
	params["volume_db"] = clampf(_to_number(params.get("volume_db", 0.0), 0.0), -80.0, 24.0)
	params["pitch_scale"] = maxf(0.01, _to_number(params.get("pitch_scale", 1.0), 1.0))
	return _ok_with_warnings([])

func _normalize_label(params: Dictionary) -> Dictionary:
	params["label_id"] = str(params.get("label_id", "")).strip_edges()
	return _ok_with_warnings([])

func _normalize_jump_to_label(params: Dictionary) -> Dictionary:
	params["target_label"] = str(params.get("target_label", "")).strip_edges()
	return _ok_with_warnings([])

func _normalize_screen_shake(params: Dictionary) -> Dictionary:
	params["duration_frames"] = maxi(0, int(_to_number(params.get("duration_frames", 0), 0)))
	params["strength_x"] = maxf(0.0, _to_number(params.get("strength_x", 0.0), 0.0))
	params["strength_y"] = maxf(0.0, _to_number(params.get("strength_y", 0.0), 0.0))
	params["wait_for_completion"] = _to_bool(params.get("wait_for_completion", false), false)
	return _ok_with_warnings([])

func _normalize_wait(params: Dictionary) -> Dictionary:
	if params.has("duration_frames"):
		params["duration_frames"] = maxi(0, int(_to_number(params.get("duration_frames", 0), 0)))
	elif params.has("duration_seconds"):
		params["duration_frames"] = maxi(0, int(round(_to_number(params.get("duration_seconds", 0.0), 0.0) * 60.0)))
	else:
		params["duration_frames"] = maxi(0, int(_to_number(params.get("duration", 0), 0)))
	return _ok_with_warnings([])

func _normalize_play_animation(params: Dictionary) -> Dictionary:
	params["animation_id"] = str(params.get("animation_id", "")).strip_edges()
	params["fallback_animation"] = str(params.get("fallback_animation", "")).strip_edges()
	params["target_id"] = str(params.get("target_id", "")).strip_edges()
	params["wait_for_completion"] = _to_bool(params.get("wait_for_completion", false), false)
	return _ok_with_warnings([])

func _normalize_play_visual_fx(params: Dictionary) -> Dictionary:
	params["fx_id"] = str(params.get("fx_id", "")).strip_edges()
	params["wait_for_completion"] = _to_bool(params.get("wait_for_completion", false), false)
	var space := str(params.get("space", "event")).to_lower()
	if space != "event" and space != "screen" and space != "world":
		space = "event"
	params["space"] = space
	var world_pos = params.get("world_position", {"x": 0.0, "y": 0.0})
	if world_pos is Vector2:
		params["world_position"] = {"x": world_pos.x, "y": world_pos.y}
	elif world_pos is Vector3:
		params["world_position"] = {"x": world_pos.x, "y": world_pos.z}
	elif world_pos is Dictionary:
		params["world_position"] = {
			"x": _to_number(world_pos.get("x", 0.0), 0.0),
			"y": _to_number(world_pos.get("y", 0.0), 0.0)
		}
	else:
		params["world_position"] = {"x": 0.0, "y": 0.0}
	return _ok_with_warnings([])

func _normalize_show_picture(params: Dictionary) -> Dictionary:
	params["picture_id"] = maxi(1, int(_to_number(params.get("picture_id", 1), 1)))
	params["texture_path"] = str(params.get("texture_path", params.get("texture", ""))).strip_edges()
	var pos = params.get("screen_position", {"x": 0.0, "y": 0.0})
	if pos is Vector2:
		params["screen_position"] = {"x": pos.x, "y": pos.y}
	elif pos is Dictionary:
		params["screen_position"] = {
			"x": _to_number(pos.get("x", 0.0), 0.0),
			"y": _to_number(pos.get("y", 0.0), 0.0)
		}
	elif pos is Array and pos.size() >= 2:
		params["screen_position"] = {
			"x": _to_number(pos[0], 0.0),
			"y": _to_number(pos[1], 0.0)
		}
	else:
		params["screen_position"] = {"x": 0.0, "y": 0.0}
	params["centered"] = _to_bool(params.get("centered", false), false)
	params["z_index"] = int(_to_number(params.get("z_index", params.get("picture_id", 1)), 1))
	return _ok_with_warnings([])

func _normalize_move_picture(params: Dictionary) -> Dictionary:
	params["picture_id"] = maxi(1, int(_to_number(params.get("picture_id", 1), 1)))
	var pos = params.get("target_position", {"x": 0.0, "y": 0.0})
	if pos is Vector2:
		params["target_position"] = {"x": pos.x, "y": pos.y}
	elif pos is Dictionary:
		params["target_position"] = {
			"x": _to_number(pos.get("x", 0.0), 0.0),
			"y": _to_number(pos.get("y", 0.0), 0.0)
		}
	elif pos is Array and pos.size() >= 2:
		params["target_position"] = {
			"x": _to_number(pos[0], 0.0),
			"y": _to_number(pos[1], 0.0)
		}
	else:
		params["target_position"] = {"x": 0.0, "y": 0.0}
	if params.has("duration_frames"):
		params["duration_frames"] = maxi(0, int(_to_number(params.get("duration_frames", 0), 0)))
	else:
		params["duration_frames"] = maxi(0, int(_to_number(params.get("duration", 0), 0)))
	params["wait_for_completion"] = _to_bool(params.get("wait_for_completion", true), true)
	return _ok_with_warnings([])

func _normalize_erase_picture(params: Dictionary) -> Dictionary:
	params["picture_id"] = maxi(1, int(_to_number(params.get("picture_id", 1), 1)))
	return _ok_with_warnings([])

func _normalize_give_items(params: Dictionary) -> Dictionary:
	params["item_id"] = str(params.get("item_id", "")).strip_edges()
	if str(params.get("item_id", "")) == "":
		return _error("give_items.params.item_id is empty")
	var operation := str(params.get("operation", "add")).to_lower()
	if operation != "add" and operation != "remove" and operation != "set":
		operation = "add"
	params["operation"] = operation
	params["amount"] = int(_to_number(params.get("amount", 1), 1))
	params["show_message"] = _to_bool(params.get("show_message", false), false)
	params["inventory_variable"] = str(params.get("inventory_variable", "inventory")).strip_edges()
	if str(params.get("inventory_variable", "")) == "":
		params["inventory_variable"] = "inventory"
	return _ok_with_warnings([])

func _is_position_like(value) -> bool:
	if value is Vector3:
		return true
	if value is Vector2:
		return true
	if value is Dictionary:
		return true
	if value is Array:
		return true
	if value is String:
		return true
	return false

func _ok_with_warnings(warnings: Array) -> Dictionary:
	return {"ok": true, "error": "", "warnings": warnings}

func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func _to_number(value, default_value: float) -> float:
	if value is int or value is float:
		return float(value)
	if value is String:
		var text := (value as String).strip_edges()
		if text.is_valid_float():
			return text.to_float()
		if text.is_valid_int():
			return float(text.to_int())
	return default_value

func _to_bool(value, default_value: bool) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	if value is String:
		var text := (value as String).strip_edges().to_lower()
		if text == "true" or text == "1" or text == "on" or text == "yes":
			return true
		if text == "false" or text == "0" or text == "off" or text == "no":
			return false
	return default_value

func _to_position_dict(value) -> Dictionary:
	if value is Vector3:
		var y = value.y
		var z = value.z
		if absf(z) <= 0.0001:
			z = y
		return {"x": value.x, "y": y, "z": z}
	if value is Vector2:
		return {"x": value.x, "y": value.y, "z": value.y}
	if value is Dictionary:
		var y := _to_number(value.get("y", value.get("z", 0.0)), 0.0)
		return {
			"x": _to_number(value.get("x", 0.0), 0.0),
			"y": y,
			"z": _to_number(value.get("z", y), y)
		}
	if value is Array and value.size() >= 3:
		return {
			"x": _to_number(value[0], 0.0),
			"y": _to_number(value[1], 0.0),
			"z": _to_number(value[2], 0.0)
		}
	if value is String:
		var text := (value as String).strip_edges()
		if text.begins_with("(") and text.ends_with(")"):
			text = text.substr(1, text.length() - 2)
		var parts := text.split(",")
		if parts.size() >= 3:
			return {
				"x": _to_number(parts[0], 0.0),
				"y": _to_number(parts[1], 0.0),
				"z": _to_number(parts[2], 0.0)
			}
	return {"x": 0.0, "y": 0.0, "z": 0.0}

func _normalize_operator(op: String) -> String:
	var token := op.strip_edges()
	match token:
		"+", "-", "*", "/", "=":
			return token
		"add", "Add":
			return "+"
		"sub", "Sub":
			return "-"
		"mul", "Multiply":
			return "*"
		"div", "Divide":
			return "/"
		_:
			return "+"

func _normalize_comparator(op: String) -> String:
	var token := op.strip_edges()
	match token:
		"==", "!=", ">", ">=", "<", "<=":
			return token
		_:
			return "=="
