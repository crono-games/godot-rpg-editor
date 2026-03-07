@tool
extends CanvasLayer
class_name DialogueBox

@export var speed_text := 0.025

@export var label: Label
@export var sound: AudioStreamPlayer
@export var timer: Timer
@export var choices_container: ChoicesPanel
@export var runner: DialogueRunner

var full_text := ""

var choices : Array[String] = []
var current_choice := 0
var selecting := false

var l_settings : = LabelSettings.new()

func _ready() -> void:
	l_settings.font = load("res://assets/fonts/m5x7.ttf")

func show_dialog(pages):
	if pages.size() == 0:
		return
	runner.run(pages)
	await runner.finished

# ---------- Text ----------

func show_page(text: String):
	show()
	selecting = false
	choices_container.hide()
	full_text = text
	label.text = text
	label.visible_characters = 0
	timer.start(speed_text)

func skip_typing():
	label.visible_characters = full_text.length()
	timer.stop()
	runner.state = DialogueRunner.State.WAITING

func _on_timer_timeout():
	label.visible_characters += 1
	if not sound.playing:
		sound.play()

	if label.visible_characters >= full_text.length():
		timer.stop()
		runner.state = DialogueRunner.State.WAITING

# ---------- Choices ----------

func show_choices(c: Array[String]):
	show()
	
	label.visible_characters = 0
	label.text = ""
	choices = c
	current_choice = 0
	selecting = true

	for child in choices_container.get_children():
		child.queue_free()

	for i in choices.size():
		var l := Label.new()
		l.text = choices[i]
		l.label_settings = l_settings
		choices_container.add_child(l)
	choices_container.show()
	_update_choice_visual()

func move_choice(dir: int):
	if not selecting:
		return
	current_choice = wrapi(current_choice + dir, 0, choices.size())
	_update_choice_visual()

func confirm_choice():
	if selecting:
		selecting = false
		runner.choose(current_choice)

func _update_choice_visual():
	for i in choices_container.get_child_count():
		var label := choices_container.get_child(i) as Label
		label.text = ("" if i == current_choice else "  ") + choices[i]

# ---------- Close ----------

func close():
	timer.stop()
	label.hide()
