extends RefCounted
class_name EventIdGenerator

func generate_id() -> String:
	return str(ResourceUID.create_id())

func ensure_id(existing_id: String) -> String:
	if existing_id == "":
		return generate_id()
	return existing_id
