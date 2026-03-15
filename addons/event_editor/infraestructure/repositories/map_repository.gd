class_name MapRepository

extends RefCounted

var maps_path := "res://maps/"
var runtime_maps_path := "res://addons/event_editor/data/runtime/maps/"
var _scene_changed := false
var _seen_event_ids := {}

# ID Generation for events (using ResourceUID)
func _generate_event_id() -> String:
	return str(ResourceUID.create_id())

func _ensure_event_id(existing_id: String) -> String:
	if existing_id == "":
		return _generate_event_id()
	return existing_id

func get_maps() -> Array[String]:
	var result: Array[String] = []
	var dir = DirAccess.open(maps_path)
	if not dir:
		return result

	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".tscn"):
			result.append(file.get_basename())
		file = dir.get_next()

	return result

func resolve_map_json_path(scene_root: Node, fallback_map_json_path: String) -> String:
	var map_id := resolve_map_id_from_scene(scene_root, "")
	if map_id == "":
		return fallback_map_json_path
	return map_json_path_from_map_id(map_id)

func resolve_map_id_from_scene(scene_root: Node, fallback_map_id: String = "") -> String:
	if scene_root == null:
		return fallback_map_id
	var explicit_map_id := _extract_map_id_from_node(scene_root)
	if explicit_map_id != "":
		return explicit_map_id
	var nested := _find_map_id_in_subtree(scene_root)
	if nested != "":
		return nested
	var path := ""
	if scene_root is Node:
		path = str(scene_root.get("scene_file_path"))
		if path == "" and scene_root.has_method("get_scene_file_path"):
			path = str(scene_root.get_scene_file_path())
	if path == "":
		return fallback_map_id
	return path.get_file().get_basename()

func map_json_path_from_map_id(map_id: String) -> String:
	var normalized := map_id.strip_edges()
	if normalized == "":
		return ""
	return "%s%s.json" % [runtime_maps_path, normalized]

func load_map_data(map_json_path: String) -> Dictionary:
	if map_json_path == "":
		return {}
	if not FileAccess.file_exists(map_json_path):
		return {}
	var file := FileAccess.open(map_json_path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

func load_map_data_by_map_id(map_id: String) -> Dictionary:
	var path := map_json_path_from_map_id(map_id)
	return load_map_data(path)


func get_events_for_map(map_id: String) -> Array:
	var scene_path := maps_path + map_id + ".tscn"
	var packed := load(scene_path)
	if not packed:
		return []
	var scene = packed.instantiate()
	var result: Array = []

	_scene_changed = false
	_seen_event_ids.clear()
	_collect_events(scene, result)

	if _scene_changed:
		var new_packed := PackedScene.new()
		new_packed.pack(scene)
		var err := ResourceSaver.save(new_packed, scene_path)
		if err != OK:
			printerr("MapRepository: failed to save updated scene %s (err=%s)" % [scene_path, str(err)])
	
	scene.free()
	return result

func get_events_from_root(root: Node) -> Array:
	if root == null:
		return []
	var result: Array = []

	_scene_changed = false
	_seen_event_ids.clear()
	_collect_events(root, result)
	return result

func instantiate_map(map_id: String) -> Node:
	var scene_path := maps_path + map_id + ".tscn"
	var packed := load(scene_path)
	if not packed:
		return null
	return packed.instantiate()

func instantiate_map_2d(map_id: String) -> Node2D:
	var scene := instantiate_map(map_id)
	return scene as Node2D

func instantiate_map_3d(map_id: String) -> Node3D:
	var scene := instantiate_map(map_id)
	return scene as Node3D

func get_map_dimension(map_id: String) -> String:
	var scene := instantiate_map(map_id)
	if scene == null:
		return ""
	var dimension := ""
	if scene is Node2D:
		dimension = "2d"
	elif scene is Node3D:
		dimension = "3d"
	if scene is Node:
		(scene as Node).free()
	return dimension

	# safer traversal: iterate children recursively
func _collect_events(n: Node, out: Array) -> void:
	if _is_event_node(n):
		var eid := str(n.get("id"))
		var needs_new_id := false
		if eid == "":
			needs_new_id = true
		elif _seen_event_ids.has(eid):
			# duplicate id detected; regenerate to keep events distinct
			needs_new_id = true

		if needs_new_id:
			eid = _ensure_event_id("")
			n.set("id", eid)
			_scene_changed = true

		_seen_event_ids[eid] = true
		var is_player := _is_player_node(n)
		var is_follower := false
		if n.is_in_group("follower_actor"):
			is_follower = true
		out.append({
			"id": eid,
			"name": n.name,
			"is_player": is_player,
			"is_follower": is_follower
		})
	for child in n.get_children():
		_collect_events(child, out)

func _is_event_node(n: Node) -> bool:
	if n.is_in_group("event_instance"):
		return true
	# 2D/3D event nodes share exported `id` property.
	for prop in n.get_property_list():
		if str(prop.get("name", "")) == "id":
			return true
	return false

func _is_player_node(n: Node) -> bool:
	if n == null:
		return false
	if n.is_in_group("player"):
		return true
	# In repository scans nodes are instantiated but often not inside SceneTree yet,
	# so group membership added in _enter_tree/_ready might not be present.
	if n is PlayerActor2DBase:
		return true
	var script := n.get_script()
	if script is Script:
		var path := str((script as Script).resource_path).to_lower()
		if path.find("player_instance") >= 0:
			return true
	return false

func _extract_map_id_from_node(node: Node) -> String:
	if node == null:
		return ""
	if node.has_method("get"):
		var raw := node.get("map_id")
		var map_id := str(raw).strip_edges()
		if map_id != "" and map_id != "Null":
			return map_id
	return ""

func _find_map_id_in_subtree(root: Node) -> String:
	if root == null:
		return ""
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node := stack.pop_back()
		var map_id := _extract_map_id_from_node(node)
		if map_id != "":
			return map_id
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)
	return ""
