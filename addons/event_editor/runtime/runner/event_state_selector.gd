class_name EventStateSelector
extends RefCounted

func select_initial_state(graph: EventGraphRuntime, ctx: EventRuntimeContext, event_id: String = "") -> String:
	var states := graph.get_state_nodes()
	if states.size() == 0:
		return ""
	var default_id := ""
	var matched_conditionals := []
	var matched_default := ""
	for entry in states:
		var node_id := str(entry.get("id", ""))
		var node = entry.get("node", {})
		var params = node.get("params", {})
		var conditions = params.get("conditions", {})
		var has_conditions = conditions.size() > 0
		var is_default := bool(params.get("is_default", false)) or str(params.get("state_id", "")) == "default"
		if is_default and default_id == "":
			default_id = node_id
		var ok := _conditions_met(conditions, ctx, event_id)
		if not ok:
			continue
		if has_conditions and not is_default:
			matched_conditionals.append(node_id)
		elif has_conditions and is_default and matched_default == "":
			matched_default = node_id

	# Non-default conditional states can override default.
	if not matched_conditionals.is_empty():
		return str(matched_conditionals[0])
	# Conditional default state (rare) can apply too.
	if matched_default != "":
		return matched_default
	# If no conditions matched, always fallback to default.
	if default_id != "":
		return default_id
	# Last-resort fallback for malformed graphs.
	if states.size() > 0:
		return str(states[0].get("id", ""))
	return ""

func conditions_met(conditions: Dictionary, ctx: EventRuntimeContext, event_id: String = "") -> bool:
	return _conditions_met(conditions, ctx, event_id)

func _conditions_met(conditions: Dictionary, ctx: EventRuntimeContext, event_id: String = "") -> bool:
	if conditions.is_empty():
		return true
	if conditions.has("flags"):
		if not _eval_flags(conditions.get("flags", []), ctx, event_id):
			return false
	if conditions.has("variables"):
		if not _eval_variables(conditions.get("variables", []), ctx):
			return false
	return true

func _eval_flags(flags: Array, ctx: EventRuntimeContext, event_id: String = "") -> bool:
	var scoped_event_id := event_id if event_id != "" else ctx.current_event_id
	for f in flags:
		var name := str(f.get("id", f.get("name", f.get("flag", ""))))
		if name == "":
			continue
		var scope := str(f.get("scope", "global"))
		var expected := bool(f.get("value", true))
		var actual := false
		if scope == "local":
			actual = ctx.get_local_flag(scoped_event_id, name)
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
