@tool
extends EventCommandNode
class_name SetLocalFlagEventCommandNode

@export var flag_selector: OptionButton
@export var state_check_box: CheckBox

const LOCAL_FLAGS := ["A", "B", "C", "D"]

var selected_flag: String = "A"
var state: bool = false

func _ready() -> void:
	super._ready()
	flag_selector.connect("item_selected", Callable(self, "_on_flag_selected"))
	state_check_box.connect("toggled", Callable(self, "_on_state_toggled"))

func _on_changed() -> void:
	flag_selector.clear()
	var items := get_flag_options()
	for i in items.size():
		flag_selector.add_item(items[i])

	var idx := get_selected_index()
	if idx >= 0 and idx < flag_selector.get_item_count():
		flag_selector.select(idx)

	state_check_box.button_pressed = state

func _on_flag_selected(id: int) -> void:
	set_selected_by_index(id)

func _on_state_toggled(toggled: bool) -> void:
	set_state(toggled)

#region User Intention


func import_params(params: Dictionary) -> void:
	selected_flag = params.get("flag_name", "A")
	state = params.get("state", false)
	emit_changed()

func export_params() -> Dictionary:
	return {
		"flag_name": selected_flag,
		"state": state,
		"scope": "local"
	}

func load_from_data(data: NodeData) -> void:
	_data = data
	emit_changed()

func get_flag_options() -> Array:
	return LOCAL_FLAGS.duplicate(true)

func get_selected_index() -> int:
	var idx = LOCAL_FLAGS.find(selected_flag)
	if idx == -1 and LOCAL_FLAGS.size() > 0:
		return 0
	return idx

func set_selected_by_index(index: int) -> void:
	if index < 0 or index >= LOCAL_FLAGS.size():
		return
	selected_flag = LOCAL_FLAGS[index]
	emit_changed()
	request_apply_changes()

func set_state(s: bool) -> void:
	state = s
	emit_changed()
	request_apply_changes()
