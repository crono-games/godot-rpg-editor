@tool
extends GraphNode
class_name EventCommandNode

signal changed
signal request_apply(vm)

var _node_id: String
var _data: NodeData
var _event_manager: EventEditorManager

func _ready() -> void:
	changed.connect(_on_changed)
	_bind_event_manager()
	_on_changed()

func _on_changed() -> void:
	pass

func bind_data(data: NodeData, node_id: String) -> void:
	_data = data
	_node_id = node_id
	import_params(data.params)
	emit_changed()

func get_node_id() -> String:
	return _node_id

## Signals

func emit_changed():
	emit_signal("changed")

func request_apply_changes():
	emit_signal("request_apply", self)

func emit_apply() -> void:
	request_apply_changes()

## Contract

func export_params() -> Dictionary:
	return {}

func import_params(params: Dictionary) -> void:
	pass

func load_from_data(_data: NodeData) -> void:
	push_error("load_from_data not implemented")

func apply_to_data(_data: NodeData) -> void:
	push_error("apply_to_data not implemented")

func get_display_items() -> Array:
	return []

## Helpers

## Event manager binding (optional)

func _bind_event_manager() -> void:
	if EventEditorManager == null:
		return
	_event_manager = EventEditorManager
	_connect_manager_signal("events_changed", "_on_events_changed")
	_connect_manager_signal("active_map_changed", "_on_active_map_changed")
	_reload_events_if_available()

func _connect_manager_signal(signal_name: String, method_name: String) -> void:
	if _event_manager == null:
		return
	if not _event_manager.has_signal(signal_name):
		return
	if not has_method(method_name):
		return
	if not _event_manager.is_connected(signal_name, Callable(self, method_name)):
		_event_manager.connect(signal_name, Callable(self, method_name))

func _reload_events_if_available() -> void:
	if has_method("_reload_events"):
		call("_reload_events")
		return
	if has_method("_on_available_events_changed"):
		var refs: Array = []
		if EventEditorManager != null:
			refs = EventEditorManager.get_event_refs_for_active_map()
		call("_on_available_events_changed", refs)
		return
	if has_method("_on_event_refs_changed"):
		var refs2: Array = []
		if EventEditorManager != null:
			refs2 = EventEditorManager.get_event_refs_for_active_map()
		call("_on_event_refs_changed", refs2)

func _on_events_changed(events: Array) -> void:
	if has_method("_on_available_events_changed"):
		call("_on_available_events_changed", events)
		return
	if has_method("_on_event_refs_changed"):
		call("_on_event_refs_changed", events)
		return
	if has_method("_reload_events"):
		call("_reload_events")

func rebuild_option_button(
	option: OptionButton,
	items: Array,
	selected_id: String = "",
	include_empty: bool = false,
	empty_label: String = "(None)"
) -> String:
	if option == null:
		return selected_id

	var was_blocked := option.is_blocking_signals()
	option.set_block_signals(true)
	option.clear()
	if include_empty:
		option.add_item(empty_label)
		option.set_item_metadata(0, "")

	var offset := 1 if include_empty else 0
	for i in items.size():
		var row = items[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var row_dict := row as Dictionary
		var id := str(row_dict.get("id", ""))
		var label := str(row_dict.get("name", row_dict.get("label", id)))
		option.add_item(label)
		option.set_item_metadata(i + offset, id)

	var selected_idx := _find_option_index_by_id(option, selected_id)
	if selected_idx < 0 and option.item_count > 0:
		selected_idx = 0
	if selected_idx >= 0:
		option.select(selected_idx)
	option.set_block_signals(was_blocked)
	return get_selected_option_id(option)

func rebuild_event_selector(option: OptionButton, selected_id: String = "", include_empty: bool = false, empty_label: String = "(None)") -> String:
	return rebuild_option_button(option, get_event_items_for_active_map(), selected_id, include_empty, empty_label)

func get_selected_option_id(option: OptionButton) -> String:
	if option == null:
		return ""
	if option.item_count == 0:
		return ""
	var idx := option.selected
	if idx < 0 or idx >= option.item_count:
		return ""
	return str(option.get_item_metadata(idx))

func _find_option_index_by_id(option: OptionButton, target_id: String) -> int:
	if option == null:
		return -1
	for i in option.item_count:
		if str(option.get_item_metadata(i)) == target_id:
			return i
	return -1

func get_event_items_for_active_map() -> Array:
	if EventEditorManager == null:
		return []
	var refs := EventEditorManager.get_event_refs_for_active_map()
	var out: Array = []
	for row in refs:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var item := row as Dictionary
		out.append({
			"id": str(item.get("id", "")),
			"name": str(item.get("name", ""))
		})
	return out
