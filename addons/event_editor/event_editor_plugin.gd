@tool

extends EditorPlugin

const MapEventPersistenceService = preload("res://addons/event_editor/infraestructure/repositories/map_event_persistence_service.gd")
const EDITOR_SCENE_PATH := "res://addons/event_editor/editor/event_editor.tscn"
const MAP_2D_SCRIPT_PATH := "res://addons/event_editor/runtime/map_2d.gd"
const MAP_2D_TEMPLATE_PATH := "res://assets/templates/maps/map2d_base.tscn"
const MAP_ROOT_2D_ICON_PATH := preload("res://addons/event_editor/icons/Node2D.svg")
const DEFAULT_MAPS_DIR := "res://maps"

var _main: Control
var _event_editor: EventEditor
var _edit_selected_button: Button
var _create_map_button: Button
var _create_map_dialog: ConfirmationDialog
var _map_name_input: LineEdit
var _map_path_preview: Label
var _ctx_plugin : EditorContextMenuPlugin

func _enter_tree():
	_register_custom_nodes()
	_ctx_plugin = preload("res://addons/event_editor/editor_context_menu_plugin.gd").new()
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_2D_EDITOR, _ctx_plugin)
	var scene: PackedScene = load(EDITOR_SCENE_PATH)
	if scene == null:
		push_error("EventEditorPlugin: failed to load %s" % EDITOR_SCENE_PATH)
		return
	_main = scene.instantiate()
	_main.visible = false
	get_editor_interface().get_editor_main_screen().add_child(_main)
	_event_editor = _main as EventEditor
	_edit_selected_button = Button.new()
	_edit_selected_button.text = "Edit Event"
	_edit_selected_button.visible = false
	_edit_selected_button.pressed.connect(_on_edit_selected_pressed)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _edit_selected_button)
	_create_map_button = Button.new()
	_create_map_button.text = "Create 2D Map Scene"
	_create_map_button.visible = false
	_create_map_button.pressed.connect(_on_create_map_button_pressed)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _create_map_button)
	_create_map_dialog = _build_create_map_dialog()
	add_child(_create_map_dialog)

	if get_editor_interface().has_signal("scene_changed"):
		get_editor_interface().scene_changed.connect(_on_scene_changed)
	
	main_screen_changed.connect(_on_main_screen_changed)
	var selection := get_editor_interface().get_selection()
	if selection != null and not selection.selection_changed.is_connected(_on_editor_selection_changed):
		selection.selection_changed.connect(_on_editor_selection_changed)
	_update_create_map_button_visibility()

func _exit_tree() -> void:
	_unregister_custom_nodes()
	remove_context_menu_plugin(_ctx_plugin)
	if _edit_selected_button != null:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _edit_selected_button)
		_edit_selected_button.queue_free()
		_edit_selected_button = null
	if _create_map_button != null:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _create_map_button)
		_create_map_button.queue_free()
		_create_map_button = null
	if _create_map_dialog != null:
		_create_map_dialog.queue_free()
		_create_map_dialog = null
		_map_name_input = null
		_map_path_preview = null
	var selection := get_editor_interface().get_selection()
	if selection != null and selection.selection_changed.is_connected(_on_editor_selection_changed):
		selection.selection_changed.disconnect(_on_editor_selection_changed)

	if _main != null:
		_main.queue_free()
		_main = null

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if _main != null:
		_main.visible = visible
	if visible:
		get_editor_interface().distraction_free_mode = true
		_notify_main_screen_active(true)
	else:
		_notify_main_screen_active(false)
	_update_create_map_button_visibility()

func _get_plugin_name() -> String:
	return "Event Editor"

func _get_plugin_icon() -> Texture2D:
	var base := get_editor_interface().get_base_control()
	if base == null:
		return null
	return base.get_theme_icon("GraphNode", "EditorIcons")

func _on_scene_changed(_root: Node) -> void:
	if EventEditorManager != null and EventEditorManager.has_method("refresh_maps"):
		EventEditorManager.refresh_maps()
	_request_sync_refresh(true, true)
	_on_editor_selection_changed()
	_update_create_map_button_visibility()

func _on_main_screen_changed(screen_name: String) -> void:
	if screen_name != _get_plugin_name():
		_notify_main_screen_active(false)
		return
	_notify_main_screen_active(true)

func _on_editor_selection_changed() -> void:
	if _edit_selected_button == null:
		return
	var selected := _get_selected_event_instance()
	_edit_selected_button.visible = selected != null
	_edit_selected_button.disabled = selected == null
	_update_create_map_button_visibility()

func _get_selected_event_instance() -> Node:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return null
	var nodes := selection.get_selected_nodes()
	if nodes.is_empty():
		return null
	var node := nodes[0] as Node
	if node == null:
		return null
	if node.is_in_group("event_instance") and str(node.get("id")) != "":
		return node
	return null

func _on_edit_selected_pressed() -> void:
	var selected := _get_selected_event_instance()
	if selected == null:
		return
	var event_id = str(selected.get("id")).strip_edges()
	if event_id == "":
		return
	if EventEditorManager == null:
		return
	if get_editor_interface().has_method("set_main_screen_editor"):
		get_editor_interface().set_main_screen_editor("Event Editor")
	var map_id := _resolve_active_map_id(selected)
	if map_id != "":
		EventEditorManager.set_active_map(map_id)
	EventEditorManager.set_active_event(event_id)

func _resolve_active_map_id(node: Node) -> String:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return ""
	var scene_path := str(root.scene_file_path)
	if scene_path == "":
		return ""
	return scene_path.get_file().get_basename()

func _notify_main_screen_active(active: bool) -> void:
	# Main screen active flag handled directly in EventEditor
	pass

func _request_sync_refresh(refresh_previewer: bool, force: bool = false) -> void:
	if _event_editor == null:
		return
	var root := get_editor_interface().get_edited_scene_root()
	if root != null and is_instance_valid(root):
		_event_editor.refresh_events_from_root(root)
	else:
		_event_editor.refresh_events()

func _update_create_map_button_visibility() -> void:
	if _create_map_button == null:
		return
	var root := get_editor_interface().get_edited_scene_root()
	_create_map_button.visible = root == null
	_create_map_button.disabled = root != null

func _register_custom_nodes() -> void:
	var map_script: Script = load(MAP_2D_SCRIPT_PATH)
	if map_script == null:
		push_error("EventEditorPlugin: failed to load %s" % MAP_2D_SCRIPT_PATH)
		return
	var icon: = MAP_ROOT_2D_ICON_PATH
	add_custom_type("Map2D", "Node2D", map_script, icon)

func _unregister_custom_nodes() -> void:
	remove_custom_type("Map2D")

func _on_create_map_button_pressed() -> void:
	if _create_map_dialog == null or _map_name_input == null:
		return
	var default_name := _next_map_scene_path().get_file().get_basename()
	_map_name_input.text = default_name
	_update_map_name_feedback(default_name)
	_create_map_dialog.popup_centered(Vector2i(520, 120))

func _build_create_map_dialog() -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Create 2D Map Scene"
	dialog.ok_button_text = "Create"
	dialog.confirmed.connect(_on_create_map_confirmed)

	var content := VBoxContainer.new()
	dialog.add_child(content)

	var row := HBoxContainer.new()
	content.add_child(row)
	var label := Label.new()
	label.text = "Map Name"
	label.custom_minimum_size = Vector2(80, 0)
	row.add_child(label)

	_map_name_input = LineEdit.new()
	_map_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_name_input.placeholder_text = "map_name"
	_map_name_input.text_changed.connect(_on_map_name_text_changed)
	row.add_child(_map_name_input)

	_map_path_preview = Label.new()
	_map_path_preview.modulate = Color(0.8, 0.8, 0.8, 1.0)
	content.add_child(_map_path_preview)

	return dialog

func _on_map_name_text_changed(new_text: String) -> void:
	_update_map_name_feedback(new_text)

func _update_map_name_feedback(raw_name: String) -> void:
	if _create_map_dialog == null:
		return
	var validation := _validate_map_name(raw_name)
	var ok_btn := _create_map_dialog.get_ok_button()
	if ok_btn != null:
		ok_btn.disabled = not bool(validation.get("ok", false))
	if _map_path_preview != null:
		if bool(validation.get("ok", false)):
			var map_name := str(validation.get("name", ""))
			_map_path_preview.modulate = Color(0.8, 0.8, 0.8, 1.0)
			_map_path_preview.text = "%s/%s.tscn" % [DEFAULT_MAPS_DIR, map_name]
		else:
			_map_path_preview.modulate = Color(1.0, 0.45, 0.45, 1.0)
			_map_path_preview.text = str(validation.get("error", "Invalid name"))

func _on_create_map_confirmed() -> void:
	if _map_name_input == null:
		return
	var validation := _validate_map_name(_map_name_input.text)
	if not bool(validation.get("ok", false)):
		push_warning("EventEditorPlugin: %s" % str(validation.get("error", "Invalid map name")))
		return
	var map_name := str(validation.get("name", ""))
	var save_path := "%s/%s.tscn" % [DEFAULT_MAPS_DIR, map_name]
	_create_map_scene_from_template(save_path, map_name)

func _create_map_scene_from_template(save_path: String, map_name: String) -> void:
	var template_scene := load(MAP_2D_TEMPLATE_PATH) as PackedScene
	if template_scene == null:
		push_error("EventEditorPlugin: failed to load %s" % MAP_2D_TEMPLATE_PATH)
		return
	var root := template_scene.instantiate() as Node2D
	if root == null:
		push_error("EventEditorPlugin: failed to instantiate map template.")
		return
	root.name = map_name
	if root.has_method("set"):
		root.set("map_id", map_name)

	_set_owner_recursive(root, root)

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		push_error("EventEditorPlugin: failed to pack map scene (%s)." % str(pack_err))
		return
	var mk_err := _ensure_maps_dir()
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		push_error("EventEditorPlugin: failed to create maps directory (%s)." % str(mk_err))
		return
	var save_err := ResourceSaver.save(packed, save_path)
	if save_err != OK:
		push_error("EventEditorPlugin: failed to save map scene at %s (%s)." % [save_path, str(save_err)])
		return
	_ensure_map_json_exists(map_name)
	if EventEditorManager != null:
		if EventEditorManager.has_method("ensure_setup"):
			EventEditorManager.ensure_setup()
		if EventEditorManager.has_method("refresh_maps"):
			EventEditorManager.refresh_maps()
		if EventEditorManager.has_method("set_active_map"):
			EventEditorManager.set_active_map(map_name)
	get_editor_interface().open_scene_from_path(save_path)

func _ensure_map_json_exists(map_name: String) -> void:
	var trimmed_name := map_name.strip_edges()
	if trimmed_name == "":
		return
	var persister := MapEventPersistenceService.new()
	if persister.has_map(trimmed_name):
		return
	var default_data := {
		"version": 1,
		"events": {}
	}
	persister.save_map(trimmed_name, default_data)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		if child is Node:
			(child as Node).owner = owner
			_set_owner_recursive(child, owner)

func _ensure_maps_dir() -> int:
	var dir := DirAccess.open("res://")
	if dir == null:
		return ERR_CANT_OPEN
	var maps_dir_rel := DEFAULT_MAPS_DIR.trim_prefix("res://")
	if dir.dir_exists(maps_dir_rel):
		return OK
	return dir.make_dir_recursive(maps_dir_rel)

func _validate_map_name(raw_name: String) -> Dictionary:
	var normalized := raw_name.strip_edges().to_lower()
	normalized = normalized.replace(" ", "_").replace("-", "_")
	var cleaned := ""
	for i in normalized.length():
		var ch := normalized.substr(i, 1)
		var code := ch.unicode_at(0)
		var is_digit := code >= 48 and code <= 57
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_lower or ch == "_":
			cleaned += ch
	if cleaned == "":
		return {"ok": false, "error": "Use letters, numbers or underscore."}
	var path := "%s/%s.tscn" % [DEFAULT_MAPS_DIR, cleaned]
	if ResourceLoader.exists(path):
		return {"ok": false, "error": "Map already exists: %s" % path}
	return {"ok": true, "name": cleaned}

func _next_map_scene_path() -> String:
	var index := 1
	while true:
		var candidate := "%s/map_%03d.tscn" % [DEFAULT_MAPS_DIR, index]
		if not ResourceLoader.exists(candidate):
			return candidate
		index += 1
	return ""
