@tool
extends CanvasLayer
class_name TextBox

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

func bind_runner(r: DialogueRunner):
	runner = r
	runner.page_started.connect(show_page)
	runner.choices_started.connect(show_choices)
	runner.finished.connect(close)

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
	choices = c
	current_choice = 0
	selecting = true

	for child in choices_container.get_children():
		child.queue_free()

	for i in choices.size():
		var l := Label.new()
		l.text = choices[i]
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
		label.text = ("> " if i == current_choice else "  ") + choices[i]

# ---------- Close ----------

func close():
	timer.stop()
	label.hide()
