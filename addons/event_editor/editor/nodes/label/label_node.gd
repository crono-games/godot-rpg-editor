@tool
extends EventCommandNode
class_name LabelNode

@export var label_edit: LineEdit

var label_id := ""

func _on_changed() -> void:
	if label_edit.text != label_id:
		label_edit.text = label_id

func _on_text_changed(new_text: String) -> void:
	set_label_id(new_text)


func import_params(params: Dictionary) -> void:
	label_id = str(params.get("label_id", ""))
	emit_changed()

func export_params() -> Dictionary:
	return {"label_id": label_id}

func load_from_data(data: NodeData) -> void:
	_data = data
	import_params(data.params)

func set_label_id(value: String) -> void:
	var next := value.strip_edges()
	if label_id == next:
		return
	label_id = next
	emit_changed()
	request_apply_changes()
