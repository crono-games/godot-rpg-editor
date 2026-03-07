class_name SetFlagExecutor
extends RefCounted

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, _scene_root: Node) -> String:
	var params = node.get("params", {})
	var flag_name := str(params.get("flag_name", ""))
	var value := bool(params.get("state", false))
	var scope := str(params.get("scope", "global"))
	var event_id := ctx.current_event_id

	if flag_name != "":
		if scope == "local":
			ctx.set_local_flag(event_id, flag_name, value)
		else:
			ctx.set_flag(flag_name, value)
	var selected = _select_matching_state(graph, ctx, event_id)
	if selected != null:
		var jump_id := str(selected.get("id", ""))
		var trigger := str(selected.get("trigger", "")).to_lower()
		if jump_id != "":
			ctx.set_current_state(event_id, jump_id)
			if trigger == "auto" or trigger == "parallel":
				return jump_id
			if trigger == "touch" or trigger == "player_touch" or trigger == "event_touch" or trigger == "touch_overlap" or trigger == "touch_bump":
				var last := ctx.get_last_trigger_for_event(event_id)
				if last == "touch" or last == "player_touch" or last == "event_touch" or last == "touch_overlap" or last == "touch_bump":
					return jump_id
				return ""
			# action: enter state node so properties apply, but state executor will stop flow
			return jump_id
	return graph.get_next(node_id, 0)

func _select_matching_state(graph: EventGraphRuntime, ctx: EventRuntimeContext, event_id: String):
	var states := graph.get_state_nodes()
	if states.size() == 0:
		return null
	var candidates := []
	var default_candidate = null
	for entry in states:
		var node_id := str(entry.get("id", ""))
		var node = entry.get("node", {})
		var params = node.get("params", {})
		var trigger := str(params.get("trigger_mode", "action")).to_lower()
		var conditions = params.get("conditions", {})
		var ok := _conditions_met(conditions, ctx, event_id)
		var has_conditions = conditions.size() > 0
		var is_default := bool(params.get("is_default", false)) or str(params.get("state_id", "")) == "default"
		if is_default and default_candidate == null:
			default_candidate = {
				"id": node_id,
				"trigger": trigger,
				"has_conditions": has_conditions,
				"is_default": is_default
			}
		if ok:
			candidates.append({
				"id": node_id,
				"trigger": trigger,
				"has_conditions": has_conditions,
				"is_default": is_default
			})

	# Prefer non-default conditional matches. If none, fallback to default.
	for c in candidates:
		if c["has_conditions"] and not c["is_default"]:
			return c
	for c in candidates:
		if c["has_conditions"] and c["is_default"]:
			return c
	if default_candidate != null:
		return default_candidate
	if candidates.size() > 0:
		return candidates[0]
	return null

func _conditions_met(conditions: Dictionary, ctx: EventRuntimeContext, event_id: String) -> bool:
	if conditions.is_empty():
		return true
	if conditions.has("flags"):
		if not _eval_flags(conditions.get("flags", []), ctx, event_id):
			return false
	if conditions.has("variables"):
		if not _eval_variables(conditions.get("variables", []), ctx):
			return false
	return true

func _eval_flags(flags: Array, ctx: EventRuntimeContext, event_id: String) -> bool:
	for f in flags:
		var name := str(f.get("id", f.get("name", f.get("flag", ""))))
		if name == "":
			continue
		var scope := str(f.get("scope", "global"))
		var expected := bool(f.get("value", true))
		var actual := false
		if scope == "local":
			actual = ctx.get_local_flag(event_id, name)
		else:
			actual = ctx.get_flag(name)
		if actual != expected:
			return false
	return true

func _eval_variables(vars: Array, ctx: EventRuntimeContext) -> bool:
	for v in vars:
		var name := str(v.get("id", v.get("name", v.get("var", ""))))
		if name == "":
			continue
		var op := str(v.get("op", "=="))
		var expected = v.get("value", null)
		var actual = ctx.get_variable(name, null)
		if not _compare(actual, expected, op):
			return false
	return true

func _compare(a, b, op: String) -> bool:
	match op:
		"==": return a == b
		"!=": return a != b
		">": return a > b
		">=": return a >= b
		"<": return a < b
		"<=": return a <= b
		_: return false
