# NodeData.gd
class_name NodeData
extends RefCounted

var id: String
var type: String
var position: Vector2
var params := {}

var context: EventEditorManager


func _init(
	p_id: String,
	p_type: String,
	p_position: Vector2,
	p_params := {}
):
	id = p_id
	type = p_type
	position = p_position
	params = p_params.duplicate(true)


func get_input_ports() -> Array[int]:
	match type:
		"state":
			return []    
		_:
			return [0]

func get_output_ports() -> Array[int]:
	match type:
		"state":
			return [0]    
		_:
			return [0]

func _to_string() -> String:
	return str(id, type, position, params)
