extends Control
class_name ChoicesPanel

signal choice_selected(index: int)

@export var choice_scene : PackedScene

var buttons : Array[Button] = []

func show_choices(choices: Array[String]):
	clear()

	for i in choices.size():
		var btn := choice_scene.instantiate() as Button
		btn.text = choices[i]
		btn.pressed.connect(func(): emit_signal("choice_selected", i))
		add_child(btn)
		buttons.append(btn)

	show()
	buttons[0].grab_focus()

func clear():
	for b in buttons:
		b.queue_free()
	buttons.clear()
	hide()
