class_name StateExecutor
extends RefCounted

func run(node_id: String, _node: Dictionary, graph: EventGraphRuntime, _ctx: EventRuntimeContext, _scene_root: Node) -> String:
	var params = _node.get("params", {})
	var trigger := str(params.get("trigger_mode", "action")).to_lower()
	var event_id := _ctx.current_event_id
	# Only auto/parallel run immediately. Action waits for external trigger.
	# Touch states run when the event was triggered by touch.
	if trigger != "auto" and trigger != "parallel":
		if trigger == "touch" or trigger == "player_touch" or trigger == "event_touch" or trigger == "touch_overlap" or trigger == "touch_bump":
			if event_id == "":
				return ""
			var last := _ctx.get_last_trigger_for_event(event_id)
			if last == "":
				return ""
			if last != "player_touch" and last != "event_touch" and last != "touch" and last != "touch_overlap" and last != "touch_bump":
				return ""
		elif trigger == "action":
			# Action states are executed when the event run is explicitly requested
			# (input/system/manual). Do not gate by previous trigger residue.
			pass
		else:
			return ""
	var conditions = params.get("conditions", {})
	if not _conditions_met(conditions, _ctx, event_id):
		return ""

	# TODO: apply state properties (graphics, movement, priority, etc.) to EventInstance(s)
	# For now, just continue through flow port 0.
	return graph.get_next(node_id, 0)

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
	if a == null or b == null:
		return false
	match op:
		"==": return a == b
		"!=": return a != b
		">": return a > b
		">=": return a >= b
		"<": return a < b
		"<=": return a <= b
		_: return false
