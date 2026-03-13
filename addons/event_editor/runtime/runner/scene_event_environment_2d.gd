class_name SceneEventEnvironment2D
extends EventEnvironment

var _root: Node = null
var _events_by_id: Dictionary = {}
var _events_by_name: Dictionary = {}
var _dirty := true
var _warned_missing_id: Dictionary = {}

func _init(scene_root: Node) -> void:
	_root = scene_root
	reindex()

func get_root() -> Node:
	return _root

func set_root(scene_root: Node) -> void:
	if _root == scene_root and is_instance_valid(_root):
		return
	_root = scene_root
	_dirty = true
	reindex()

func mark_dirty() -> void:
	_dirty = true

func reindex() -> void:
	_events_by_id.clear()
	_events_by_name.clear()
	_warned_missing_id.clear()
	_dirty = false
	if _root == null or not is_instance_valid(_root):
		return

	var stack: Array[Node] = [_root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node.is_in_group("event_instance"):
			var event_id := str(node.get("id"))
			if event_id != "":
				_events_by_id[event_id] = node
			elif not _warned_missing_id.has(str(node.get_instance_id())):
				_warned_missing_id[str(node.get_instance_id())] = true
				push_warning("SceneEventEnvironment2D: event_instance without id skipped: %s" % [node.name])
			if node.name != "":
				_events_by_name[node.name] = node
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)

func get_event_by_id(event_id: String) -> Node:
	_ensure_index()
	if event_id == "":
		return null
	var event = _events_by_id.get(event_id, null)
	if event == null or not is_instance_valid(event):
		return null
	return event

func get_event_by_name(name: String) -> Node:
	_ensure_index()
	if name == "":
		return null
	var event = _events_by_name.get(name, null)
	if event == null or not is_instance_valid(event):
		return null
	return event

func _ensure_index() -> void:
	if _dirty:
		reindex()

func get_player(player_group: String = "player") -> Node:
	_ensure_index()
	if _root == null or not is_instance_valid(_root):
		return null
	var stack: Array[Node] = [_root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is Node2D and node.is_in_group(player_group):
			return node as Node2D
		for child in node.get_children():
			if child is Node:
				stack.push_back(child)
	return null

func set_event_texture(event_id: String, texture_path: String) -> void:
	set_event_graphics(event_id, {"texture": texture_path})

func set_event_graphics(event_id: String, graphics: Dictionary) -> void:
	var event := get_event_by_id(event_id)
	if event == null:
		return
	var texture_path := str(graphics.get("texture", "")).strip_edges()
	var hframes := maxi(1, int(graphics.get("hframes", 1)))
	var vframes := maxi(1, int(graphics.get("vframes", 1)))
	var total := maxi(1, hframes * vframes)
	var frame := clampi(int(graphics.get("frame", 0)), 0, total - 1)
	var offset_x := float(graphics.get("offset_x", 0.0))
	var offset_y := float(graphics.get("offset_y", 0.0))
	var offset := Vector2(offset_x, offset_y)
	var offset_value = graphics.get("offset", null)
	if offset_value is Vector2:
		offset = offset_value
	elif offset_value is Dictionary:
		var od := offset_value as Dictionary
		offset = Vector2(float(od.get("x", offset_x)), float(od.get("y", offset_y)))

	var sprite_node: Node = null
	if event.has_node("Sprite2D"):
		sprite_node = event.get_node("Sprite2D")
	elif event.has_node("Sprite2D"):
		sprite_node = event.get_node("Sprite2D")
	else:
		sprite_node = event.get("sprite")

	if sprite_node == null:
		return
	if texture_path == "":
		if sprite_node is Sprite2D:
			(sprite_node as Sprite2D).texture = null
			(sprite_node as Sprite2D).visible = false
			(sprite_node as Sprite2D).hframes = hframes
			(sprite_node as Sprite2D).vframes = vframes
			(sprite_node as Sprite2D).frame = frame
			(sprite_node as Sprite2D).offset = offset
		elif sprite_node is Sprite2D:
			(sprite_node as Sprite2D).texture = null
			(sprite_node as Sprite2D).visible = false
			(sprite_node as Sprite2D).hframes = hframes
			(sprite_node as Sprite2D).vframes = vframes
			(sprite_node as Sprite2D).frame = frame
			(sprite_node as Sprite2D).offset = offset
		return

	var tex := load(texture_path)
	if tex is Texture2D:
		if sprite_node is Sprite2D:
			(sprite_node as Sprite2D).texture = tex
			(sprite_node as Sprite2D).visible = true
			(sprite_node as Sprite2D).hframes = hframes
			(sprite_node as Sprite2D).vframes = vframes
			(sprite_node as Sprite2D).frame = frame
			(sprite_node as Sprite2D).offset = offset
		elif sprite_node is Sprite2D:
			(sprite_node as Sprite2D).texture = tex
			(sprite_node as Sprite2D).visible = true
			(sprite_node as Sprite2D).hframes = hframes
			(sprite_node as Sprite2D).vframes = vframes
			(sprite_node as Sprite2D).frame = frame
			(sprite_node as Sprite2D).offset = offset

func set_event_position(event_id: String, position: Vector3) -> bool:
	var event := get_event_by_id(event_id)
	if event == null:
		return false
	if event is Node2D:
		(event as Node2D).position = _to_2d_position(position)
		return true
	return false

func _to_2d_position(position: Vector3) -> Vector2:
	# Pixel-first 2D: use x/y directly (legacy z values are handled by parsers upstream).
	return Vector2(position.x, position.y)

func set_event_passability(event_id: String, passability: String) -> void:
	var event := get_event_by_id(event_id)
	if event == null:
		return
	var normalized := "Block" if passability.to_lower() == "block" else "Passable"
	if event.has_method("set"):
		event.set("passability", normalized)

func set_event_animation_timing(event_id: String, anim_step_time: float, max_cycles_per_step: float) -> void:
	var event := get_event_by_id(event_id)
	if event == null:
		return
	if event.has_method("set"):
		event.set("_anim_step_time", maxf(0.01, anim_step_time))
		event.set("max_anim_cycles_per_step", maxf(0.0, max_cycles_per_step))

func set_event_behavior(event_id: String, template_id: String, params: Dictionary = {}) -> void:
	var event := get_event_by_id(event_id)
	if event == null:
		return
	if event.has_method("apply_behavior_template"):
		event.call("apply_behavior_template", template_id, params)
		return
	if event.has_method("set"):
		event.set("behavior_template_id", template_id)
		event.set("behavior_params", params.duplicate(true))

func set_event_actor_definition(event_id: String, actor_props: Dictionary) -> void:
	var event := get_event_by_id(event_id)
	if event == null:
		return
	if event.has_method("apply_actor_definition"):
		event.call("apply_actor_definition", actor_props)
