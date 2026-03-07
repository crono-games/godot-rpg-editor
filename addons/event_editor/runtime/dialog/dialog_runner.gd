@tool
extends Node
class_name DialogueRunner

signal page_started(text: String)
signal choices_started(choices: Array[String])
signal finished
signal choice_selected(index: int)

enum State {
	IDLE,
	TYPING,
	WAITING,
	CHOOSING
}

var state : State = State.IDLE
var pages : Array = []
var page_index := 0

func _enter_tree() -> void:
	add_to_group("dialogue_runner")

func run(pages_in: Array) -> void:
	pages = pages_in
	page_index = 0
	state = State.TYPING
	emit_signal("page_started", pages[0])

func next():
	match state:
		State.TYPING:
			state = State.WAITING

		State.WAITING:
			page_index += 1
			if page_index < pages.size():
				state = State.TYPING
				emit_signal("page_started", pages[page_index])
			else:
				_finish()

func start_choices(choices: Array):
	state = State.CHOOSING
	emit_signal("choices_started", choices)

func choose(index: int):
	emit_signal("choice_selected", index)
	_finish()

func _finish():
	state = State.IDLE
	emit_signal("finished")
