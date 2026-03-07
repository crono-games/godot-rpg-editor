class_name EdgeData
extends RefCounted

var from_node: String
var from_port: int
var to_node: String
var to_port: int

func _init(f: String, fp: int, t: String, to: int): 
	from_node = f
	from_port = fp
	to_node = t
	to_port = to

func _to_string() -> String:
	return str(from_node, from_port,
		to_node, to_port)
