@tool
extends EditorContextMenuPlugin

const SCENE := preload("res://assets/templates/events/2d/event_instance_2d.tscn")
const GRID_PLAYER_SCENE := preload("res://assets/templates/events/2d/player_instance_grid.tscn")
const PIXEL_PLAYER_SCENE := preload("res://assets/templates/events/2d/player_instance_pixel.tscn")
const ICON := preload("res://addons/event_editor/icons/Add.svg")
const CHARACTER_ICON := preload("res://addons/event_editor/icons/CharacterBody2D.svg")
const DEFAULT_EVENT_BASE_NAME := "Event"

var last_click_pos: Vector2 = Vector2.ZERO

signal added

func _popup_menu(paths: PackedStringArray) -> void:
	last_click_pos = _resolve_world_mouse_position()
	add_context_menu_item(
		"Add EventInstance",
			_on_add_event_instance.bind(SCENE)
		, ICON)

	var submenu := PopupMenu.new()
	
	submenu.add_item("Grid Movement", 0)
	submenu.add_item("Pixel Movement", 1)
	submenu.id_pressed.connect(_on_submenu_item_pressed.bind(paths))

	add_context_submenu_item("Add PlayerInstance", submenu, CHARACTER_ICON)


func _on_submenu_item_pressed(id: int, nodes) -> void:
	match id:
		0:
			_on_add_event_instance(nodes, GRID_PLAYER_SCENE)
		1:
			_on_add_event_instance(nodes, PIXEL_PLAYER_SCENE)

func _on_add_event_instance(nodes, _scene):
	var inst = _scene.instantiate()
	var scene = EditorInterface.get_edited_scene_root()
	if scene == null or not scene is Map2D:
		return
	if scene.event_container != null:
		scene.event_container.add_child(inst)
	else:
		scene.add_child(inst)
	inst.owner = scene
	if inst.is_in_group("PlayerInstance"):
		inst.name = _make_unique_name(scene, "Player")
	else:
		_assign_event_defaults(inst, scene)
	if inst is Node2D:
		(inst as Node2D).position = last_click_pos
	if EventEditorManager != null:
		EventEditorManager.refresh_events_for_active_map(scene)

func _resolve_world_mouse_position() -> Vector2:
	var view := EditorInterface.get_editor_viewport_2d()
	if view is SubViewport:
		var v := view as SubViewport
		var screen_pos := v.get_mouse_position()
		if screen_pos == Vector2.ZERO and last_click_pos != Vector2.ZERO:
			screen_pos = last_click_pos
		return v.canvas_transform.affine_inverse() * screen_pos
	return last_click_pos

func _assign_event_defaults(inst: Node, scene_root: Node) -> void:
	if inst == null:
		return
	inst.name = _make_unique_name(scene_root, DEFAULT_EVENT_BASE_NAME)
	if inst.has_method("get") and inst.has_method("set"):
		var current_id := str(inst.get("id")).strip_edges()
		if current_id == "":
			inst.set("id", "evt_" + str(ResourceUID.create_id()))

func _make_unique_name(root: Node, base_name: String) -> String:
	if root == null:
		return base_name
	var used: Dictionary = {}
	for child in root.get_children():
		if child is Node:
			used[(child as Node).name] = true
	if not used.has(base_name):
		return base_name
	var idx := 1
	while true:
		var candidate := "%s_%d" % [base_name, idx]
		if not used.has(candidate):
			return candidate
		idx += 1
	return ""
