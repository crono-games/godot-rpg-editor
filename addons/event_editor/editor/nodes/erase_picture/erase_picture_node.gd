@tool
extends EventCommandNode
class_name ErasePictureNode

@export var picture_id_spin: SpinBox

var picture_id: int = 1

func _ready() -> void:
	super._ready()
	if picture_id_spin != null and not picture_id_spin.value_changed.is_connected(_on_picture_id_changed):
		picture_id_spin.value_changed.connect(_on_picture_id_changed)

func _on_changed() -> void:
	if picture_id_spin != null:
		picture_id_spin.value = picture_id

func _on_picture_id_changed(value: float) -> void:
	set_picture_id(int(round(value)))

#region User Intention

func import_params(params: Dictionary) -> void:
	picture_id = maxi(1, int(params.get("picture_id", 1)))
	emit_changed()

func export_params() -> Dictionary:
	return {
		"picture_id": picture_id
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	import_params(data.params)

func set_picture_id(value: int) -> void:
	var next := maxi(1, value)
	if picture_id == next:
		return
	picture_id = next
	emit_changed()
	request_apply_changes()
