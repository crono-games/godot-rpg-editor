@tool
extends Control
class_name EventEditor

@export var map_selector: MapSelector
@export var graph_controller: GraphController
@export var event_previewer: EventPreviewer
@export var game_state_dock: GameStateDock
@export var autosave_enabled: bool = true
@export var autosave_delay: float = 0.5

var _event_editor_manager : EventEditorManager
var _map_repo: MapRepository
var _global_state: GlobalState
var _event_runner: EventGraphRunner
var _autosave_timer: Timer
var _global_state_save_timer: Timer

const GLOBAL_STATE_SAVE_DELAY := 0.5
const GLOBAL_STATE_PATH = "res://addons/event_editor/data/runtime/global_state.json"

func _ready():
	_setup_event_manager()
	_setup_dependencies()
	_setup_event_previewer()
	_setup_context_and_graph()
	_setup_map_selector()
	_setup_game_state()
	_setup_global_state_persistence()
	_setup_graph_autosave()
	_connect_context_events()
	_connect_scene_change_signals()
	_sync_initial_selection_state()


func _setup_dependencies() -> void:
	var graph_id_gen := GraphIdGenerator.new()
	graph_controller.set_id_generator(graph_id_gen)

func _setup_event_manager() -> void:
	if EventEditorManager != null:
		EventEditorManager.initialize()
		_event_editor_manager = EventEditorManager
		_map_repo = EventEditorManager.get_map_repository()

func _setup_context_and_graph() -> void:
	if _event_editor_manager == null:
		return
	map_selector.set_context(_event_editor_manager)
	graph_controller.set_context(_event_editor_manager)
	graph_controller.set_scene_root_provider(
		func():
			return _instantiate_preview_root()
	)
	graph_controller.state_properties_updated.connect(_on_state_properties_updated)

func _setup_map_selector() -> void:
	if _event_editor_manager == null:
		return
	map_selector.map_selected.connect(_event_editor_manager.set_active_map)
	map_selector.event_selected.connect(_on_map_event_selected)

func _setup_event_previewer() -> void:
	if event_previewer == null or _event_editor_manager == null:
		return
	_event_runner = EventGraphRunner.new()
	event_previewer.set_event_runner(_event_runner)
	event_previewer.set_map_id(_event_editor_manager.active_map_id)
	event_previewer.set_map_data_provider(
		func():
			var persistence := GraphPersistenceService.new()
			return persistence.load_map(_event_editor_manager.active_map_id)
	)
	event_previewer.set_scene_root_provider(
		func():
			return _instantiate_preview_root()
	)
	event_previewer.set_selected_node_provider(
		func():
			return graph_controller.get_selected_node_snapshot()
	)
	if not event_previewer.play_requested.is_connected(_on_preview_play_requested):
		event_previewer.play_requested.connect(_on_preview_play_requested)

func _setup_game_state() -> void:
	_global_state = EventEditorManager.get_global_state()
	if _global_state == null:
		_global_state = GlobalState.new()
		EventEditorManager._set_global_state(_global_state)
	game_state_dock.set_global_state(_global_state)

func _setup_global_state_persistence() -> void:
	if _global_state == null:
		return
	_global_state.load_from_file(GLOBAL_STATE_PATH)
	_global_state_save_timer = Timer.new()
	_global_state_save_timer.one_shot = true
	_global_state_save_timer.wait_time = GLOBAL_STATE_SAVE_DELAY
	add_child(_global_state_save_timer)
	_global_state_save_timer.timeout.connect(_on_global_state_save_timeout)
	if not _global_state.changed.is_connected(_on_global_state_changed):
		_global_state.changed.connect(_on_global_state_changed)

func _setup_graph_autosave() -> void:
	if graph_controller == null:
		return
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = autosave_delay
	add_child(_autosave_timer)
	_autosave_timer.timeout.connect(_on_graph_autosave_timeout)
	if not graph_controller.graph_dirty.is_connected(_on_graph_dirty):
		graph_controller.graph_dirty.connect(_on_graph_dirty)

func _connect_context_events() -> void:
	if _event_editor_manager == null:
		return
	_event_editor_manager.active_map_changed.connect(_on_active_map_changed)
	_event_editor_manager.active_event_changed.connect(_on_active_event_changed)

func _sync_initial_selection_state() -> void:
	if _event_editor_manager == null:
		return
	if _event_editor_manager.active_map_id != "":
		_on_active_map_changed(_event_editor_manager.active_map_id)
	if _event_editor_manager.active_event_id != "":
		if graph_controller != null and graph_controller.has_method("reload_graph"):
			graph_controller.reload_graph(_event_editor_manager.active_event_id)
		_on_active_event_changed(_event_editor_manager.active_event_id)

func _connect_scene_change_signals() -> void:
	if _event_editor_manager == null:
		return
	if not Engine.is_editor_hint():
		return
	var tree := get_tree()
	if tree == null:
		return
	if not tree.node_added.is_connected(_on_editor_tree_node_added):
		tree.node_added.connect(_on_editor_tree_node_added)
	if not tree.node_removed.is_connected(_on_editor_tree_node_removed):
		tree.node_removed.connect(_on_editor_tree_node_removed)
	if tree.has_signal("node_renamed") and not tree.node_renamed.is_connected(_on_editor_tree_node_renamed):
		tree.node_renamed.connect(_on_editor_tree_node_renamed)

func refresh_events() -> void:
	if _event_editor_manager != null:
		_event_editor_manager.refresh_events_for_active_map()

func refresh_events_from_root(root: Node) -> void:
	if _event_editor_manager != null:
		_event_editor_manager.refresh_events_for_active_map(root)

##Signals

func _on_map_event_selected(event_id: String) -> void:
	_event_editor_manager.set_active_event(event_id)
	_on_active_event_changed(event_id)

func _on_active_map_changed(map_id: String) -> void:
	var root := _get_editor_scene_root()
	if root != null:
		_event_editor_manager.refresh_events_for_active_map(root)
	else:
		_event_editor_manager.refresh_events_for_active_map()
	if event_previewer != null:
		event_previewer.set_map_id(map_id)

func _on_active_event_changed(event_id: String) -> void:
	if event_previewer == null:
		return
	var root := _instantiate_preview_root()
	if root == null:
		return
	event_previewer.refresh_from_scene_root(root, event_id)

func _on_preview_play_requested(_map_id: String, _event_id: String, _scene_root: Node) -> void:
	_save_graph_now()

func _on_state_properties_updated(event_id: String, state_id: String, params: Dictionary) -> void:
	var is_default_state := state_id == "default" or bool(params.get("is_default", false))
	if not is_default_state:
		return
	_apply_state_properties_to_editor_scene(event_id, params)
	if event_previewer != null and event_previewer.has_method("apply_state_properties"):
		event_previewer.apply_state_properties(event_id, params)

func _instantiate_preview_root() -> Node:
	if _map_repo == null or _event_editor_manager == null:
		return null
	var map_id := _event_editor_manager.active_map_id
	if map_id == "":
		return null
	var root := _map_repo.instantiate_map(map_id)
	if root == null:
		return null
	root.set_meta("preview_temp_root", true)
	return root

func _save_graph_now() -> void:
	if graph_controller == null:
		return
	graph_controller.save_current_graph()


func _on_graph_dirty() -> void:
	if not autosave_enabled:
		return
	if _autosave_timer != null:
		_autosave_timer.start()

func _on_graph_autosave_timeout() -> void:
	_save_graph_now()

func _on_global_state_changed() -> void:
	if _global_state_save_timer != null:
		_global_state_save_timer.start()

func _on_global_state_save_timeout() -> void:
	if _global_state == null:
		return
	_global_state.save_to_file(GLOBAL_STATE_PATH)

func _on_editor_tree_node_added(node: Node) -> void:
	if _is_editor_event_node(node):
		call_deferred("refresh_events")

func _on_editor_tree_node_removed(node: Node) -> void:
	if _is_editor_event_node(node):
		call_deferred("refresh_events")

func _on_editor_tree_node_renamed(node: Node) -> void:
	if _is_editor_event_node(node):
		call_deferred("refresh_events")

func _is_editor_event_node(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("event_instance"):
		return true
	return node.get("id") != null

func _apply_state_properties_to_editor_scene(event_id: String, params: Dictionary) -> void:
	if event_id == "":
		return
	var root := _get_editor_scene_root()
	if root == null:
		return
	var props = params.get("properties", {})
	if typeof(props) != TYPE_DICTIONARY:
		return
	var graphics = props.get("graphics", {})
	if typeof(graphics) != TYPE_DICTIONARY:
		return
	var target := _find_event_instance_by_id(root, event_id)
	if target == null:
		return
	var sprite_node: Node = null
	if target.has_node("Sprite2D"):
		sprite_node = target.get_node("Sprite2D")
	elif target.has_node("Sprite3D"):
		sprite_node = target.get_node("Sprite3D")
	else:
		sprite_node = target.get("sprite")
	if sprite_node == null:
		return
	var texture_path := str(graphics.get("texture", "")).strip_edges()
	var hframes := maxi(1, int(graphics.get("hframes", 1)))
	var vframes := maxi(1, int(graphics.get("vframes", 1)))
	var total := maxi(1, hframes * vframes)
	var frame := clampi(int(graphics.get("frame", 0)), 0, total - 1)

	var tex: Texture2D = null
	if texture_path != "":
		var loaded := load(texture_path)
		if loaded is Texture2D:
			tex = loaded

	if sprite_node is Sprite2D:
		var s2 := sprite_node as Sprite2D
		s2.texture = tex
		s2.visible = tex != null
		s2.hframes = hframes
		s2.vframes = vframes
		s2.frame = frame
	elif sprite_node is Sprite3D:
		var s3 := sprite_node as Sprite3D
		s3.texture = tex
		s3.visible = tex != null
		s3.hframes = hframes
		s3.vframes = vframes
		s3.frame = frame

func _find_event_instance_by_id(root: Node, event_id: String) -> Node:
	var tree := root.get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group("event_instance"):
		if not (node is Node):
			continue
		var node_id := str(node.get("id"))
		if node_id != event_id:
			continue
		if node == root or root.is_ancestor_of(node):
			return node
	return null

func _get_editor_scene_root() -> Node:
	return EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_S and key_event.ctrl_pressed:
			_save_graph_now()
			get_viewport().set_input_as_handled()
