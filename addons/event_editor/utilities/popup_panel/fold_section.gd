@tool
extends Button
class_name FoldSection

var icon_expanded = preload("res://addons/event_editor/icons/GuiTreeArrowDown.svg")
var icon_collapsed = preload("res://addons/event_editor/icons/GuiTreeArrowRight.svg")

@export var folded := true
@export var content : Control

func _ready():
	toggle_mode = true
	var font = get_theme_font("bold", "EditorFonts")
	add_theme_font_override("font", font)
	button_pressed = not folded
	content.visible = not folded
	update_icon()

func _toggled(pressed):
	folded = not pressed
	update_icon()
	content.visible = not folded

func update_icon():
	icon = icon_collapsed if folded else icon_expanded
