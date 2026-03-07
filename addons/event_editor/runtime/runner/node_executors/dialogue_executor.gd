class_name DialogueExecutor
extends RefCounted

const DIALOGUE_SCENE := "res://addons/event_editor/runtime/dialog/dialogue_base.tscn"

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, _ctx: EventRuntimeContext, scene_root: Node) -> String:
	if scene_root == null:
		return graph.get_next(node_id, 0)
	
	var params = node.get("params", {})
	var raw_pages = params.get("dialogues", [])
	var pages: Array = []
	for item in raw_pages:
		if typeof(item) == TYPE_DICTIONARY:
			pages.append(str(item.get("text", "")))
		elif item is String:
			pages.append(item)

	if pages.is_empty():
		return graph.get_next(node_id, 0)

	var scene := load(DIALOGUE_SCENE)
	if scene == null:
		return graph.get_next(node_id, 0)

	var dialog = scene.instantiate()
	scene_root.add_child(dialog)
	if dialog.has_method("show_dialog"):
		await dialog.show_dialog(pages)
	dialog.queue_free()
	return graph.get_next(node_id, 0)
