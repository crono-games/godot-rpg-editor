@tool
extends EventCommandNode
class_name TeleportPlayerNode

@export var position_picker: PositionPickerBase
@export var auto_fade_check: CheckBox
@export var fade_frames_spin: SpinBox
@export var facing_dir_selector: OptionButton


var available_maps: Array[String] = []
var selected_map_id: String = ""
var target_position: Vector3 = Vector3.ZERO
var auto_fade: bool = true
var fade_frames: int = 30
var facing_dir: String = "keep"
var _context: EventEditorManager

const FACING_OPTIONS := [
	{"id": "keep", "label": "Keep"},
	{"id": "down", "label": "Down"},
	{"id": "left", "label": "Left"},
	{"id": "right", "label": "Right"},
	{"id": "up", "label": "Up"}
]

func _ready() -> void:
	super._ready()
	set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)
	if position_picker != null:
		position_picker.position_confirmed.connect(_on_position_confirmed)
		position_picker.map_position_confirmed.connect(_on_map_position_confirmed)
		position_picker.set_show_map_list(true)
	if auto_fade_check != null:
		auto_fade_check.toggled.connect(_on_auto_fade_toggled)
	if fade_frames_spin != null:
		fade_frames_spin.value_changed.connect(_on_fade_frames_changed)
	if facing_dir_selector != null:
		_setup_facing_selector()
		if not facing_dir_selector.item_selected.is_connected(_on_facing_dir_selected):
			facing_dir_selector.item_selected.connect(_on_facing_dir_selected)

func _on_changed() -> void:
	if auto_fade_check != null:
		auto_fade_check.button_pressed = auto_fade
	if fade_frames_spin != null:
		fade_frames_spin.value = fade_frames
	if facing_dir_selector != null:
		_select_facing_option_by_id(facing_dir)

func _on_button_pressed() -> void:
	if position_picker != null:
		position_picker.set_selected_map(selected_map_id)
	if position_picker == null:
		return
	position_picker.update_preview()
	position_picker.popup()

func _on_position_confirmed(pos) -> void:
	set_target_position(_to_vec3(pos))

func _on_map_position_confirmed(map_id: String, pos) -> void:
	if map_id != "":
		selected_map_id = map_id
		request_apply_changes()
	set_target_position(_to_vec3(pos))

func _on_auto_fade_toggled(value: bool) -> void:
	set_auto_fade(value)

func _on_fade_frames_changed(value: float) -> void:
	set_fade_frames(int(value))

func _on_facing_dir_selected(index: int) -> void:
	if facing_dir_selector == null or index < 0 or index >= facing_dir_selector.item_count:
		return
	set_facing_dir(str(facing_dir_selector.get_item_metadata(index)))

func _to_vec3(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector2:
		return Vector3(value.x, value.y, 0.0)
	return Vector3.ZERO

#region User Intention


func import_params(params: Dictionary) -> void:
	selected_map_id = str(params.get("map_id", ""))
	target_position = _parse_target_position(params.get("target_position", Vector3.ZERO))
	auto_fade = bool(params.get("auto_fade", true))
	fade_frames = int(params.get("fade_frames", 30))
	facing_dir = str(params.get("facing_dir", "keep")).to_lower()
	emit_changed()

func export_params() -> Dictionary:
	return {
		"map_id": selected_map_id,
		"target_position": _to_int_position_dict(target_position),
		"auto_fade": auto_fade,
		"fade_frames": fade_frames,
		"facing_dir": facing_dir
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	if EventEditorManager != null:
		_context = EventEditorManager
		if _context != null and not _context.maps_changed.is_connected(_on_maps_changed):
			_context.maps_changed.connect(_on_maps_changed)
		_on_maps_changed()
	else:
		available_maps = []
	import_params(data.params)

func _on_maps_changed() -> void:
	if _context == null:
		return
	available_maps = _context.get_maps()
	if selected_map_id == "" and available_maps.size() > 0:
		selected_map_id = available_maps[0]
		request_apply_changes()
	emit_changed()

func get_map_options() -> Array:
	return available_maps.duplicate(true)

func get_selected_index() -> int:
	if available_maps.is_empty():
		return -1
	var idx := available_maps.find(selected_map_id)
	return idx if idx != -1 else 0

func set_selected_by_index(index: int) -> void:
	if index < 0 or index >= available_maps.size():
		return
	selected_map_id = available_maps[index]
	emit_changed()
	request_apply_changes()

func set_target_position(pos: Vector3) -> void:
	target_position = _quantize_position(pos)
	emit_changed()
	request_apply_changes()

func set_auto_fade(value: bool) -> void:
	if auto_fade == value:
		return
	auto_fade = value
	emit_changed()
	request_apply_changes()

func set_fade_frames(value: int) -> void:
	if fade_frames == value:
		return
	fade_frames = max(0, value)
	emit_changed()
	request_apply_changes()

func set_facing_dir(value: String) -> void:
	var normalized := value.strip_edges().to_lower()
	if normalized == "":
		normalized = "keep"
	if facing_dir == normalized:
		return
	facing_dir = normalized
	emit_changed()
	request_apply_changes()

func _setup_facing_selector() -> void:
	facing_dir_selector.clear()
	for item in FACING_OPTIONS:
		var idx := facing_dir_selector.item_count
		facing_dir_selector.add_item(str(item["label"]))
		facing_dir_selector.set_item_metadata(idx, str(item["id"]))

func _select_facing_option_by_id(id: String) -> void:
	if facing_dir_selector == null:
		return
	var target := id.strip_edges().to_lower()
	if target == "":
		target = "keep"
	for i in range(facing_dir_selector.item_count):
		if str(facing_dir_selector.get_item_metadata(i)).to_lower() == target:
			facing_dir_selector.select(i)
			return
	if facing_dir_selector.item_count > 0:
		facing_dir_selector.select(0)

func _parse_target_position(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector2:
		return Vector3(value.x, value.y, 0)
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		var x := float(value.get("x", 0))
		var y := float(value.get("y", value.get("z", 0)))
		return Vector3(x, y, 0)
	if value is String:
		var parts = value.split(",")
		if parts.size() >= 3:
			return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	return Vector3.ZERO

func _quantize_position(pos: Vector3) -> Vector3:
	return Vector3(round(pos.x), round(pos.y), round(pos.z))

func _to_int_position_dict(pos: Vector3) -> Dictionary:
	var p := _quantize_position(pos)
	return {
		"x": int(p.x),
		"y": int(p.y),
		"z": int(p.y) # legacy mirror for older 3D-oriented payload readers
	}
