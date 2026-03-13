@tool
extends Node
class_name EventEditorSyncService

const DEFAULT_REFRESH_DELAY := 0.05

var _event_manager: EventEditorManager
var _map_repo: MapRepository
var _event_previewer: EventPreviewer
var _scene_root_provider: Callable
var _preview_root_provider: Callable
var _refresh_timer: Timer

var _is_main_screen_active := false
var _pending_refresh := false
var _pending_refresh_previewer := false
var _pending_root: Node

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_refresh_timer = Timer.new()
	_refresh_timer.one_shot = true
	_refresh_timer.wait_time = DEFAULT_REFRESH_DELAY
	add_child(_refresh_timer)
	_refresh_timer.timeout.connect(_flush_refresh)

	var tree := get_tree()
	if tree == null:
		return
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	if not tree.node_removed.is_connected(_on_node_removed):
		tree.node_removed.connect(_on_node_removed)
	if tree.has_signal("node_renamed") and not tree.node_renamed.is_connected(_on_node_renamed):
		tree.node_renamed.connect(_on_node_renamed)

func set_event_manager(manager: EventEditorManager) -> void:
	_event_manager = manager

func set_map_repo(repo: MapRepository) -> void:
	_map_repo = repo

func set_event_previewer(previewer: EventPreviewer) -> void:
	_event_previewer = previewer

func set_scene_root_provider(provider: Callable) -> void:
	_scene_root_provider = provider

func set_preview_root_provider(provider: Callable) -> void:
	_preview_root_provider = provider

func set_main_screen_active(value: bool) -> void:
	_is_main_screen_active = value
	if value:
		queue_refresh(true, true)

func handle_active_map_changed(map_id: String) -> void:
	if _event_previewer != null:
		_event_previewer.set_map_id(map_id)
	queue_refresh(true, true)

func handle_active_event_changed(_event_id: String) -> void:
	queue_refresh(true, true)

func queue_refresh(refresh_previewer: bool = false, force: bool = false, root: Node = null) -> void:
	if not force and _is_main_screen_active:
		return
	_pending_refresh = true
	_pending_refresh_previewer = _pending_refresh_previewer or refresh_previewer
	if root != null:
		_pending_root = root
	if _refresh_timer != null:
		_refresh_timer.start()

func refresh_now(root: Node = null, refresh_previewer: bool = false) -> void:
	var scene_root := root
	if scene_root == null:
		scene_root = _get_scene_root()
	_refresh_events_from_root(scene_root)
	if refresh_previewer:
		_refresh_previewer_from_active_map()

func _flush_refresh() -> void:
	if not _pending_refresh:
		return
	var root := _pending_root
	_pending_root = null
	_pending_refresh = false
	var refresh_previewer := _pending_refresh_previewer
	_pending_refresh_previewer = false
	refresh_now(root, refresh_previewer)

func _refresh_events_from_root(root: Node) -> void:
	if _event_manager == null:
		return
	_event_manager.refresh_events_for_active_map()

func _refresh_previewer_from_active_map() -> void:
	if _event_previewer == null or not is_instance_valid(_event_previewer):
		return
	if _event_manager == null:
		return
	var map_id := _event_manager.active_map_id
	if map_id == "":
		return
	var preview_root := _build_preview_root_for_active_map(map_id)
	if preview_root == null:
		return
	var event_id := _event_manager.active_event_id
	_event_previewer.refresh_from_scene_root(preview_root, event_id)

func _build_preview_root_for_active_map(_map_id: String) -> Node:
	if _preview_root_provider != null and _preview_root_provider.is_valid():
		return _preview_root_provider.call()
	if _map_repo == null or _event_manager == null:
		return null
	var map_id := _event_manager.active_map_id
	if map_id == "":
		return null
	var root := _map_repo.instantiate_map(map_id)
	if root == null:
		return null
	root.set_meta("preview_temp_root", true)
	return root

func _get_scene_root() -> Node:
	if _scene_root_provider != null and _scene_root_provider.is_valid():
		return _scene_root_provider.call()
	if Engine.is_editor_hint():
		return EditorInterface.get_edited_scene_root()
	return null

func _resolve_map_id_from_root(root: Node) -> String:
	return ""

func _on_node_added(node: Node) -> void:
	if _is_event_node(node):
		queue_refresh(false, false)

func _on_node_removed(node: Node) -> void:
	if _is_event_node(node):
		queue_refresh(false, false)

func _on_node_renamed(node: Node) -> void:
	if _is_event_node(node):
		queue_refresh(false, false)

func _is_event_node(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("event_instance"):
		return true
	return node.get("id") != null
