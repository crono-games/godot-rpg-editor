@tool
extends EventCommandNode
class_name PlayVisualFxNode

@export var fx_selector: OptionButton
@export var wait_completion_check: CheckBox

var fx_id := ""
var wait_for_completion := false
var available_fx: Array = []
var _scene_root_provider: Callable
var debug_logs := true

func _ready() -> void:
	super._ready()
	if fx_selector != null and not fx_selector.item_selected.is_connected(_on_fx_selected):
		fx_selector.item_selected.connect(_on_fx_selected)
	if wait_completion_check != null and not wait_completion_check.toggled.is_connected(_on_wait_toggled):
		wait_completion_check.toggled.connect(_on_wait_toggled)

func _on_changed() -> void:
	if _scene_root_provider != null and _scene_root_provider.is_valid():
		set_scene_root_provider(_scene_root_provider)
		refresh_fx_options()
	_rebuild_fx_selector()
	if wait_completion_check != null:
		wait_completion_check.button_pressed = wait_for_completion
	_refresh_node_size()

func _rebuild_fx_selector() -> void:
	if fx_selector == null:
		return
	fx_selector.clear()
	var options := get_fx_options()
	for name in options:
		fx_selector.add_item(str(name))
	var selected := get_selected_fx_index()
	if selected >= 0 and selected < fx_selector.item_count:
		fx_selector.select(selected)

func _on_fx_selected(index: int) -> void:
	set_fx_by_index(index)

func _on_wait_toggled(value: bool) -> void:
	set_wait_for_completion(value)

func set_scene_root_provider(provider: Callable) -> void:
	_scene_root_provider = provider
	refresh_fx_options()

func _refresh_node_size() -> void:
	size = Vector2.ZERO
	call_deferred("_refresh_node_size_deferred")

func _refresh_node_size_deferred() -> void:
	size = Vector2.ZERO
	if has_method("reset_size"):
		reset_size()

#region User Intention

func import_params(params: Dictionary) -> void:
	fx_id = str(params.get("fx_id", ""))
	wait_for_completion = bool(params.get("wait_for_completion", false))
	emit_changed()

func export_params() -> Dictionary:
	return {
		"fx_id": fx_id,
		"wait_for_completion": wait_for_completion,
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	import_params(data.params)
	refresh_fx_options()
	emit_changed()

func get_fx_options() -> Array:
	return available_fx.duplicate(true)

func get_selected_fx_index() -> int:
	var idx := available_fx.find(fx_id)
	if idx == -1 and available_fx.size() > 0:
		return 0
	return idx

func set_fx_by_index(index: int) -> void:
	if index < 0 or index >= available_fx.size():
		return
	fx_id = str(available_fx[index])
	emit_changed()
	request_apply_changes()

func set_wait_for_completion(value: bool) -> void:
	wait_for_completion = value
	emit_changed()
	request_apply_changes()

func preview_current_fx() -> void:
	if fx_id == "":
		return
	var source := _find_fx_source()
	if source == null:
		return
	if source.has_method("play_fx"):
		source.call("play_fx", fx_id, {"wait_for_completion": false})
	elif source.has_method("play"):
		source.call("play", fx_id)

func get_fx_source() -> Node:
	return _find_fx_source()


func refresh_fx_options() -> void:
	available_fx.clear()
	var source := _find_fx_source()
	if source != null:
		available_fx = _extract_fx_ids_from_node(source)
	if available_fx.is_empty():
		available_fx = ["default_fx"]
	if fx_id == "":
		fx_id = str(available_fx[0])
	elif available_fx.find(fx_id) == -1:
		available_fx.append(fx_id)

func _resolve_scene_root() -> Node:
	if _scene_root_provider != null and _scene_root_provider.is_valid():
		var provided = _scene_root_provider.call()
		if provided is Node:
			return provided
	if Engine.is_editor_hint():
		var edited := EditorInterface.get_edited_scene_root()
		if edited != null:
			return edited
	return null

func _find_fx_source() -> Node:
	var scene_root := _resolve_scene_root()
	if scene_root == null:
		return null
	var by_name := scene_root.get_node_or_null("AnimationContainer")
	
	if by_name != null:
		return by_name
	var tree := scene_root.get_tree() if scene_root.is_inside_tree() else null
	
	if tree != null:
		for n in tree.get_nodes_in_group("AnimationContainer"):
			if n is Node:
				return n

	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n.name == "AnimationContainer":
			return n
		for c in n.get_children():
			if c is Node:
				stack.push_back(c)
	return null

func _extract_fx_ids_from_node(source: Node) -> Array:
	if source == null:
		return []
	if source.has_method("get_available_fx_ids"):
		var from_method = source.call("get_available_fx_ids")
		if from_method is Array:
			return _normalize_fx_ids(from_method)
	var out: Array = []
	var stack: Array[Node] = [source]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is AnimatedSprite2D:
			var sprite := n as AnimatedSprite2D
			if sprite.sprite_frames != null:
				for anim_name in sprite.sprite_frames.get_animation_names():
					var id := str(anim_name).strip_edges()
					if id != "" and not out.has(id):
						out.append(id)
		elif n is AnimationPlayer:
			var player := n as AnimationPlayer
			for anim_name in player.get_animation_list():
				var id := str(anim_name).strip_edges()
				if id != "" and not out.has(id):
					out.append(id)
		for c in n.get_children():
			if c is Node:
				stack.push_back(c)
	out.sort()
	return out

func _normalize_fx_ids(values: Array) -> Array:
	var out: Array = []
	for v in values:
		var id := str(v).strip_edges()
		if id != "" and not out.has(id):
			out.append(id)
	out.sort()
	return out

func _has_animations_in_node(node: Node) -> bool:
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		return sprite.sprite_frames != null and sprite.sprite_frames.get_animation_names().size() > 0
	if node is AnimationPlayer:
		return (node as AnimationPlayer).get_animation_list().size() > 0
	return false
