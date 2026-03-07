@tool
extends PopupPanel

class_name ContextMenuPanel

@export var add_node_button: Button
@export var submenu: ContextSubMenuPanel

var hovering_button := false
var hovering_submenu := false

signal request_create_node(node_type : String)

func _enter_tree() -> void:
	hide()

func _ready() -> void:
	set_popup_menu()

func set_popup_menu():
	submenu.root = self
	populate_submenu()

func populate_submenu():
	submenu.clear_items()
	for event_type in EventNodeRegistry.get_types():
		var entry = EventNodeRegistry.get_entry(event_type)
		var entry_name = entry["name"]
		var category = entry["category"] if entry.has("category") else null
		submenu.add_item(event_type, entry_name, category)

func _on_button_mouse_entered() -> void:
	submenu.position = Vector2i(position.x + size.x, position.y)
	submenu.popup()

func _on_add_state_mouse_entered() -> void:
	submenu.hide()

func _on_add_state_button_pressed() -> void:
	hide()
	emit_signal("request_create_node", "state")
