@tool
extends EventCommandNode
class_name DialogueNode

@export var dialogue_container: VBoxContainer
@export var add_button: Button
@export var edit_text_dialog: PopupPanel
@export var edit_text_edit: TextEdit
@export var edit_graphics_button: TextureButton
@export var graphics_file_dialog: FileDialog

var dialogues: Array = [] # Array of {id: String, text: String}
var _next_id := 1
var _editing_item_id := ""

func _ready() -> void:
	super._ready()
	if add_button != null and not add_button.pressed.is_connected(_on_add_pressed):
		add_button.pressed.connect(_on_add_pressed)
	if edit_text_dialog != null and not edit_text_dialog.popup_hide.is_connected(_on_edit_popup_hidden):
		edit_text_dialog.popup_hide.connect(_on_edit_popup_hidden)
	if edit_graphics_button != null and not edit_graphics_button.pressed.is_connected(_on_edit_graphics_pressed):
		edit_graphics_button.pressed.connect(_on_edit_graphics_pressed)
	if graphics_file_dialog != null and not graphics_file_dialog.file_selected.is_connected(_on_graphics_file_selected):
		graphics_file_dialog.file_selected.connect(_on_graphics_file_selected)
		if graphics_file_dialog.filters.is_empty():
			graphics_file_dialog.add_filter("*.png,*.jpg,*.jpeg,*.webp,*.bmp;Images")

func _on_changed() -> void:
	_sync_list()
	_refresh_size()

func _rebuild_list() -> void:
	for c in dialogue_container.get_children():
		c.queue_free()

	var items := get_dialogues()
	for i in items.size():
		_add_dialogue_item(items[i])
	dialogue_container.queue_sort()

func _add_dialogue_item(item: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	var item_id := str(item.get("id", ""))
	hbox.set_meta("dialogue_id", item_id)
	var line_edit := LineEdit.new()
	line_edit.text = str(item.get("text", ""))
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.set_meta("dialogue_id", item_id)
	line_edit.connect("text_changed", Callable(self, "_on_line_text_changed").bind(item_id))

	var edit := Button.new()
	edit.icon = load("res://addons/event_editor/icons/Edit.svg")
	edit.set_meta("dialogue_id", item_id)
	edit.pressed.connect(Callable(self, "_on_edit_pressed").bind(item_id))

	var remove := Button.new()
	remove.icon = load("res://addons/event_editor/icons/Remove.svg")
	remove.set_meta("dialogue_id", item_id)
	remove.pressed.connect(Callable(self, "_on_remove_pressed").bind(item_id))

	hbox.add_child(line_edit)
	hbox.add_child(edit)
	hbox.add_child(remove)
	dialogue_container.add_child(hbox)

func _sync_list() -> void:
	var items := get_dialogues()
	var children := dialogue_container.get_children()
	var by_id := {}
	for child in children:
		var hbox := child as HBoxContainer
		if hbox == null:
			continue
		var cid := _get_item_id(hbox)
		if cid != "":
			by_id[cid] = hbox

	for i in items.size():
		var item = items[i]
		var item_id := str(item.get("id", ""))
		if item_id == "":
			continue
		if by_id.has(item_id):
			var hbox = by_id[item_id]
			var line_edit := hbox.get_child(0) as LineEdit
			if line_edit != null and not line_edit.has_focus():
				var text := str(item.get("text", ""))
				if line_edit.text != text:
					line_edit.text = text
		else:
			_add_dialogue_item(item)

	for child in children:
		var hbox := child as HBoxContainer
		if hbox == null:
			continue
		var cid := _get_item_id(hbox)
		if cid == "":
			continue
		if not _items_has_id(items, cid):
			hbox.queue_free()

func _refresh_size() -> void:
	call_deferred("_apply_size")

func _apply_size() -> void:
	var container := dialogue_container.get_parent() as Control
	if container == null:
		container = dialogue_container
	var min_size := container.get_combined_minimum_size()
	custom_minimum_size = Vector2(max(custom_minimum_size.x, min_size.x), min_size.y)
	size = custom_minimum_size

func _get_item_id(hbox: HBoxContainer) -> String:
	if hbox.has_meta("dialogue_id"):
		return str(hbox.get_meta("dialogue_id"))
	return ""

func _items_has_id(items: Array, item_id: String) -> bool:
	for item in items:
		if str(item.get("id", "")) == item_id:
			return true
	return false

func _on_add_pressed() -> void:
	add_dialogue("")


func _on_edit_pressed(item_id: String) -> void:
	edit_dialogue_by_id(item_id)

func _on_remove_pressed(item_id: String) -> void:
	remove_dialogue_by_id(item_id)

func _on_line_text_changed(new_text: String, item_id: String) -> void:
	update_dialogue_by_id(item_id, new_text)

#region User Intention

func load_from_data(data: NodeData) -> void:
	pass

func import_params(params: Dictionary) -> void:
	var raw = params.get("dialogues", [])
	dialogues = _normalize_dialogues(raw)
	emit_changed()

func export_params() -> Dictionary:
	return { "dialogues": dialogues.duplicate(true) }

func add_dialogue(text: String) -> void:
	dialogues = dialogues.duplicate(true)
	dialogues.append({
		"id": _generate_id(),
		"text": text,
		"portrait": ""
	})
	emit_changed()
	request_apply_changes()

func remove_dialogue_by_id(item_id: String) -> void:
	dialogues = dialogues.duplicate(true)
	for i in range(dialogues.size()):
		if str(dialogues[i].get("id", "")) == item_id:
			dialogues.remove_at(i)
			emit_changed()
			request_apply_changes()
			return

func edit_dialogue_by_id(item_id) -> void:
	_editing_item_id = str(item_id)
	if edit_text_dialog == null:
		return
	var item := _find_dialogue(_editing_item_id)
	if edit_text_edit != null:
		edit_text_edit.text = str(item.get("text", ""))
	_apply_portrait_preview(str(item.get("portrait", item.get("graphics", ""))))
	edit_text_dialog.popup_centered()

func update_dialogue_by_id(item_id: String, text: String) -> void:
	dialogues = dialogues.duplicate(true)
	for i in range(dialogues.size()):
		if str(dialogues[i].get("id", "")) == item_id:
			dialogues[i]["text"] = text
			emit_changed()
			request_apply_changes()
			return

func get_dialogues() -> Array:
	return dialogues.duplicate(true)

func _normalize_dialogues(raw: Array) -> Array:
	var result: Array = []
	var max_id := 0

	for item in raw:
		if item is Dictionary and item.has("id"):
			var text := str(item.get("text", ""))
			var id := str(item.get("id"))
			var portrait := str(item.get("portrait", item.get("graphics", "")))
			result.append({"id": id, "text": text, "portrait": portrait})
			var n := _parse_id_number(id)
			if n > max_id:
				max_id = n
		else:
			var id := "dlg_%d" % _next_id
			_next_id += 1
			result.append({"id": id, "text": str(item), "portrait": ""})

	_next_id = max(_next_id, max_id + 1)
	return result

func _generate_id() -> String:
	var id := "dlg_%d" % _next_id
	_next_id += 1
	return id

func _parse_id_number(id: String) -> int:
	if not id.begins_with("dlg_"):
		return 0
	return int(id.replace("dlg_", ""))

func _on_edit_popup_hidden() -> void:
	if _editing_item_id == "":
		return
	var text := ""
	if edit_text_edit != null:
		text = edit_text_edit.text
	dialogues = dialogues.duplicate(true)
	for i in range(dialogues.size()):
		if str(dialogues[i].get("id", "")) != _editing_item_id:
			continue
		dialogues[i]["text"] = text
		emit_changed()
		request_apply_changes()
		_editing_item_id = ""
		return
	_editing_item_id = ""

func _on_edit_graphics_pressed() -> void:
	if graphics_file_dialog == null:
		return
	graphics_file_dialog.popup_centered_ratio()

func _on_graphics_file_selected(path: String) -> void:
	if _editing_item_id == "":
		return
	var normalized_path := str(path)
	dialogues = dialogues.duplicate(true)
	for i in range(dialogues.size()):
		if str(dialogues[i].get("id", "")) != _editing_item_id:
			continue
		dialogues[i]["portrait"] = normalized_path
		_apply_portrait_preview(normalized_path)
		emit_changed()
		request_apply_changes()
		return

func _find_dialogue(item_id: String) -> Dictionary:
	for item in dialogues:
		if str(item.get("id", "")) == item_id:
			return item
	return {}

func _apply_portrait_preview(path: String) -> void:
	if edit_graphics_button == null:
		return
	var texture: Texture2D = null
	if path != "":
		var loaded = load(path)
		if loaded is Texture2D:
			texture = loaded as Texture2D
	edit_graphics_button.texture_normal = texture
