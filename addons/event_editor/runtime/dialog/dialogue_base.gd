@tool
extends CanvasLayer
class_name DialogueBox

const MAX_CHARS := 220


@export var speed_text := 0.025

@export var label: Label
@export var sound: AudioStreamPlayer
@export var timer: Timer
@export var choices_container: ChoicesPanel
@export var runner: DialogueRunner
@export var scroll: ScrollContainer

var full_text := ""

var choices : Array[String] = []
var current_choice := 0
var selecting := false

var l_settings : = LabelSettings.new()

func _ready() -> void:
	l_settings.font = load("res://assets/fonts/m5x7.ttf")

func show_dialog(pages):
	if pages.is_empty():
		return

	var normalized := []

	for p in pages:
		normalized.append_array(split_page(p))

	runner.run(normalized)
	await runner.finished
	
# ---------- Text ----------

func normalize_pages(pages:Array) -> Array:
	var result := []

	for page in pages:
		result.append_array(split_page(page))

	return result

func split_page(text:String) -> Array:
	var pages := []
	var current := ""

	for c in text:
		current += c
		label.text = current		
		if label.get_line_count() > label.get_visible_line_count():
			
			var cut := current.rfind(" ")
			
			if cut == -1:
				cut = current.length() - 1
			
			var page := current.substr(0, cut)
			pages.append(page.strip_edges())
			
			current = current.substr(cut + 1)

	if current != "":
		pages.append(current.strip_edges())

	return pages


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
