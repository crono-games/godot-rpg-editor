extends RefCounted
class_name EventIdGenerator

# Simple event ID generator. By default uses ResourceUID.create_id() to
# produce a unique identifier. You can replace or wrap this class if you
# need deterministic IDs.

func generate_id() -> String:
	return str(ResourceUID.create_id())

func ensure_id(existing_id: String) -> String:
	if existing_id == "":
		return generate_id()
	return existing_id
