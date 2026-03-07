@tool
extends PopupPanel

class_name ContextSubMenuPanel

var root : ContextMenuPanel

@export var movement_items: VBoxContainer
@export var message_items: VBoxContainer
@export var progression_items: VBoxContainer
@export var actor_items: VBoxContainer
@export var flow_control_items: VBoxContainer
@export var pictures_items: VBoxContainer
@export var screen_items: VBoxContainer
@export var content: VBoxContainer


@onready var list_for_category = {
	"movement": movement_items,
	"progression": progression_items,
	"flow_control": flow_control_items,
	"message": message_items,
	"actor": actor_items,
	"pictures": pictures_items,
	"screen": screen_items
}

func _on_search_text_changed(text: String) -> void:
	text = text.to_lower()
	_filter_recursive(content, text)

func _filter_recursive(node: Node, text: String) -> bool:
	var has_visible_child := false

	for child in node.get_children():
		if child is Button:
			var match = text == "" or child.text.to_lower().contains(text)
			child.visible = match
			has_visible_child = has_visible_child or match

		else:
			var child_has_match := _filter_recursive(child, text)

			if child is Control:
				child.visible = child_has_match

			has_visible_child = has_visible_child or child_has_match

	return has_visible_child


func add_item(event_type : String, item : String, category : Variant):
	if not category:
		return
	var button = Button.new()
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.set_text("    " + item)
	var current_item_list = list_for_category.get(category)
	button.pressed.connect(_on_item_pressed.bind(event_type))
	current_item_list.add_child(button)

func clear_items() -> void:
	for key in list_for_category.keys():
		var list = list_for_category[key]
		if list == null:
			continue
		for child in list.get_children():
			child.queue_free()

func _on_item_pressed(event_type: String) -> void:
	root.emit_signal("request_create_node", event_type)
	root.hide()
	hide()
