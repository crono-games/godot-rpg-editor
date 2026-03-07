@tool
extends EventCommandNode
class_name JumpToLabelNode

@export var target_edit: LineEdit

var target_label := ""

func _on_changed() -> void:
	if target_edit.text != target_label:
		target_edit.text = target_label

func _on_text_changed(new_text: String) -> void:
	set_target_label(new_text)

#region User Intention

func import_params(params: Dictionary) -> void:
	target_label = str(params.get("target_label", ""))
	emit_changed()

func export_params() -> Dictionary:
	return {"target_label": target_label}

func load_from_data(data: NodeData) -> void:
	_data = data
	import_params(data.params)

func set_target_label(value: String) -> void:
	var next := value.strip_edges()
	if target_label == next:
		return
	target_label = next
	emit_changed()
	request_apply_changes()
