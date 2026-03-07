@tool
extends EventCommandNode
class_name ChoicesNode

@export var choice: LineEdit
@export var choice_2: LineEdit
@export var choice_3: LineEdit
@export var choice_4: LineEdit

var _syncing := false
var _choice_edits: Array = []

var choices: Array = []

func _ready() -> void:
	super._ready()
	_choice_edits = [choice, choice_2, choice_3, choice_4]
	_choice_edits.sort_custom(func(a, b): return a.position.y < b.position.y)
	for i in range(_choice_edits.size()):
		var edit = _choice_edits[i]
		if edit == null:
			continue
		edit.text_changed.connect(_on_choice_changed.bind(i))


func _on_changed() -> void:
	_syncing = true
	var items = get_choices()
	for i in range(min(items.size(), _choice_edits.size())):
		var edit = _choice_edits[i]
		if edit != null:
			if edit.text != items[i]:
				var caret = edit.caret_column
				edit.text = items[i]
				if edit.has_focus():
					edit.caret_column = min(caret, edit.text.length())
	_syncing = false

func _on_choice_changed(new_text: String, index: int) -> void:
	if _syncing:
		return
	set_choice_text(index, new_text)

#region User Intention

func load_from_data(data: NodeData) -> void:
	pass

func import_params(params: Dictionary) -> void:
	var raw = params.get("choices", [])
	choices = _normalize_choices(raw)
	emit_changed()

func export_params() -> Dictionary:
	return {
		"choices": choices.duplicate(true)
	}

func get_choices() -> Array:
	return choices.duplicate(true)

func set_choice_text(index: int, text: String) -> void:
	if index < 0 or index >= choices.size():
		return
	if choices[index] == text:
		return
	choices = choices.duplicate(true)
	choices[index] = text
	emit_changed()
	request_apply_changes()

func _normalize_choices(raw: Array) -> Array:
	var result: Array = ["", "", "", ""]
	for i in range(min(raw.size(), 4)):
		var v = raw[i]
		result[i] = v if v is String else ""
	return result
