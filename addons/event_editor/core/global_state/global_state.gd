class_name GlobalState
extends RefCounted

signal changed
signal flags_changed
signal variables_changed

var _flags: Dictionary = {}
var _variables: Dictionary = {}
var _next_flag_id := 0
var _next_var_id := 0


func get_flags() -> Dictionary:
	return _flags


func get_variables() -> Dictionary:
	return _variables


func get_flag_count() -> int:
	return _flags.size()


func get_variable_count() -> int:
	return _variables.size()


func create_flag(name: String, default_value: bool = false) -> String:
	var id := _make_flag_id()
	var entry := GlobalStateEntry.new()
	entry.id = id
	entry.name = name
	entry.kind = GlobalStateEntry.Kind.FLAG
	entry.value_type = "bool"
	entry.value = default_value
	_flags[id] = entry
	_emit_flags_changed()
	return id


func create_variable(name: String = "", default_value: int = 0) -> String:
	var id := _make_variable_id()
	var entry := GlobalStateEntry.new()
	entry.id = id
	entry.name = name if name != "" else "New Variable %d" % _next_var_id
	entry.kind = GlobalStateEntry.Kind.VARIABLE
	entry.value_type = "int"
	entry.value = default_value
	_variables[id] = entry
	_emit_variables_changed()
	return id


func remove_flag(id: String) -> void:
	if _flags.erase(id):
		_emit_flags_changed()


func remove_variable(id: String) -> void:
	if _variables.erase(id):
		_emit_variables_changed()


func set_flag_name(id: String, name: String) -> void:
	var entry: GlobalStateEntry = _flags.get(id)
	if entry == null:
		return
	entry.name = name
	_emit_flags_changed()


func set_flag_value(id: String, value: bool) -> void:
	var entry: GlobalStateEntry = _flags.get(id)
	if entry == null:
		return
	entry.value = value
	_emit_flags_changed()


func set_variable_name(id: String, name: String) -> void:
	var entry: GlobalStateEntry = _variables.get(id)
	if entry == null:
		return
	entry.name = name
	_emit_variables_changed()


func set_variable_value(id: String, value: int) -> void:
	var entry: GlobalStateEntry = _variables.get(id)
	if entry == null:
		return
	entry.value = value
	_emit_variables_changed()


func _make_flag_id() -> String:
	_next_flag_id += 1
	return "flag_%d" % _next_flag_id


func _make_variable_id() -> String:
	_next_var_id += 1
	return "var_%d" % _next_var_id


func _emit_flags_changed() -> void:
	flags_changed.emit()
	changed.emit()


func _emit_variables_changed() -> void:
	variables_changed.emit()
	changed.emit()


func to_dict() -> Dictionary:
	var flags := []
	for entry in _flags.values():
		if entry == null:
			continue
		flags.append({
			"id": entry.id,
			"name": entry.name,
			"value_type": entry.value_type,
			"value": entry.value
		})

	var variables := []
	for entry in _variables.values():
		if entry == null:
			continue
		variables.append({
			"id": entry.id,
			"name": entry.name,
			"value_type": entry.value_type,
			"value": entry.value
		})

	return {
		"version": 1,
		"flags": flags,
		"variables": variables
	}

func load_from_dict(data: Dictionary) -> void:
	_flags.clear()
	_variables.clear()

	for f in data.get("flags", []):
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var entry := GlobalStateEntry.new()
		entry.id = str(f.get("id", ""))
		entry.name = str(f.get("name", ""))
		entry.kind = GlobalStateEntry.Kind.FLAG
		entry.value_type = str(f.get("value_type", "bool"))
		entry.value = bool(f.get("value", false))
		if entry.id != "":
			_flags[entry.id] = entry

	for v in data.get("variables", []):
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var entry := GlobalStateEntry.new()
		entry.id = str(v.get("id", ""))
		entry.name = str(v.get("name", ""))
		entry.kind = GlobalStateEntry.Kind.VARIABLE
		entry.value_type = str(v.get("value_type", "int"))
		entry.value = int(v.get("value", 0))
		if entry.id != "":
			_variables[entry.id] = entry

	_update_next_ids()
	_emit_flags_changed()
	_emit_variables_changed()


func save_to_file(path: String) -> void:
	var dir_path := path.get_base_dir()
	var dir = DirAccess.open(dir_path)
	if not dir:
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()


func load_from_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
		if parsed.error != OK:
			return
		load_from_dict(parsed.result)
		return
	if typeof(parsed) == TYPE_DICTIONARY:
		load_from_dict(parsed)


func _update_next_ids() -> void:
	var max_flag := 0
	for id in _flags.keys():
		var parts := str(id).split("_")
		if parts.size() >= 2 and parts[0] == "flag":
			max_flag = max(max_flag, int(parts[1]))

	var max_var := 0
	for id in _variables.keys():
		var parts := str(id).split("_")
		if parts.size() >= 2 and parts[0] == "var":
			max_var = max(max_var, int(parts[1]))

	_next_flag_id = max_flag
	_next_var_id = max_var
