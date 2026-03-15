class_name GlobalStateRepository
extends RefCounted

## Responsibility: Load/save GlobalState from/to JSON files.
## This is a thin wrapper around GlobalState serialization and file I/O.

func load_global_state(global_state_json_path: String) -> GlobalState:
	if global_state_json_path == "":
		return null
	if not FileAccess.file_exists(global_state_json_path):
		return null
	var gs := GlobalState.new()
	gs.load_from_file(global_state_json_path)
	return gs

func save_global_state(global_state: GlobalState, global_state_json_path: String) -> bool:
	if global_state == null or global_state_json_path == "":
		return false
	var dir_path := global_state_json_path.get_basename().get_basename()
	var dir := DirAccess.open(dir_path)
	if not dir:
		DirAccess.make_dir_recursive_absolute(dir_path)
	global_state.save_to_file(global_state_json_path)
	return true
