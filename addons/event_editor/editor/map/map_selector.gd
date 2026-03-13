@tool
extends Control
class_name MapSelector

signal map_selected(map_id: String)
signal event_selected(event_id: String)

@export var maps_list: ItemList
@export var events_list: ItemList

var _context: EventEditorManager

# ==================================================
# UI → Intent
# ==================================================

func _ready() -> void:
	maps_list.item_selected.connect(_on_map_selected)
	events_list.item_selected.connect(_on_event_selected)
	if _context == null:
		var ctx := _get_context()
		if ctx != null:
			set_context(ctx)

func _on_map_selected(index: int) -> void:
	var map_id = maps_list.get_item_metadata(index)
	emit_signal("map_selected", map_id)

func _on_event_selected(index: int) -> void:
	var event_id := str(events_list.get_item_metadata(index))
	emit_signal("event_selected", event_id)


# ==================================================
# Context → UI
# ==================================================

func set_context(ctx: EventEditorManager) -> void:
	if _context == ctx and _context != null:
		_connect_context()
		_rebuild_maps()
		_rebuild_events()
		_ensure_active_map_and_event()
		return

	if _context != null:
		_disconnect_context()

	_context = ctx
	if _context == null:
		maps_list.clear()
		events_list.clear()
		return
	_connect_context()

	_rebuild_maps()
	_rebuild_events()
	_ensure_active_map_and_event()

func _get_context() -> EventEditorManager:
	if _context != null:
		return _context
	if EventEditorManager != null:
		return EventEditorManager
	return null

func _connect_context() -> void:
	if not _context.active_map_changed.is_connected(_on_active_map_changed):
		_context.active_map_changed.connect(_on_active_map_changed)
	if not _context.events_changed.is_connected(_on_available_events_changed):
		_context.events_changed.connect(_on_available_events_changed)
	if not _context.active_event_changed.is_connected(_on_active_event_changed):
		_context.active_event_changed.connect(_on_active_event_changed)
	# Defensive: clean stale legacy connection
	if _context.active_event_changed.is_connected(_on_available_events_changed):
		_context.active_event_changed.disconnect(_on_available_events_changed)


func _disconnect_context() -> void:
	if _context.active_map_changed.is_connected(_on_active_map_changed):
		_context.active_map_changed.disconnect(_on_active_map_changed)
	if _context.events_changed.is_connected(_on_available_events_changed):
		_context.events_changed.disconnect(_on_available_events_changed)
	if _context.active_event_changed.is_connected(_on_available_events_changed):
		_context.active_event_changed.disconnect(_on_available_events_changed)
	if _context.active_event_changed.is_connected(_on_active_event_changed):
		_context.active_event_changed.disconnect(_on_active_event_changed)


func _on_active_map_changed(_map_id: String) -> void:
	_rebuild_maps()
	_rebuild_events()
	_ensure_active_map_and_event()

func _on_available_events_changed(_events: Array) -> void:
	_rebuild_maps()
	_rebuild_events()
	_ensure_active_map_and_event()

func _on_active_event_changed(_event_id: String) -> void:
	_select_active_event_in_list()


# ==================================================
# Rebuild helpers
# ==================================================

func _rebuild_maps() -> void:
	maps_list.clear()

	var ctx := _get_context()
	if not ctx:
		return
	for map_id in ctx.get_maps():
		var idx := maps_list.add_item(map_id)
		maps_list.set_item_metadata(idx, map_id)

		if map_id == ctx.active_map_id:
			maps_list.select(idx)

func _rebuild_events() -> void:
	events_list.clear()

	var ctx := _get_context()
	if not ctx or ctx.active_map_id == "":
		return
	var events := ctx.get_events_for_map_selector()
	var selected_index := -1

	for ev in events:
		var id := str(ev.get("id", ""))
		var label := str(ev.get("name", id))
		if id == "":
			continue

		var idx := events_list.add_item(label)
		events_list.set_item_metadata(idx, id)

		if id == ctx.active_event_id:
			selected_index = idx

	if selected_index >= 0:
		events_list.select(selected_index)
	else:
		events_list.deselect_all()

func _select_active_event_in_list() -> void:
	var ctx := _get_context()
	if ctx == null or events_list == null:
		return
	for i in events_list.item_count:
		var item_id := str(events_list.get_item_metadata(i))
		if item_id == ctx.active_event_id:
			events_list.select(i)
			return
	events_list.deselect_all()

func _ensure_active_map_and_event() -> void:
	var ctx := _get_context()
	if ctx == null:
		return

	var maps := ctx.get_maps()
	if maps.is_empty():
		return

	# Always keep an active map.
	if ctx.active_map_id == "":
		ctx.set_active_map(str(maps[0]))
		return

	var events := ctx.get_events_for_map_selector()
	if events.is_empty():
		return

	# Always keep an active event if the map has events.
	if ctx.active_event_id == "":
		ctx.set_active_event(str(events[0].get("id", "")))
		return

	# If active_event_id is stale (deleted/changed), fallback to first.
	for ev in events:
		if str(ev.get("id", "")) == ctx.active_event_id:
			return
	ctx.set_active_event(str(events[0].get("id", "")))
