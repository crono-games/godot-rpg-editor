class_name ChoiceExecutor
extends RefCounted

const DIALOGUE_SCENE := "res://addons/event_editor/runtime/dialog/dialogue_base.tscn"

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, _ctx: EventRuntimeContext, scene_root: Node) -> String:
	if scene_root == null:
		return graph.get_next(node_id, 0)

	var params = node.get("params", {})
	var raw_choices = params.get("choices", [])
	var choices: Array[String] = []
	for item in raw_choices:
		var text := str(item)
		if text != "":
			choices.append(text)

	if choices.is_empty():
		return graph.get_next(node_id, 0)

	var scene := load(DIALOGUE_SCENE)
	if scene == null:
		return graph.get_next(node_id, 0)

	var dialog = scene.instantiate()
	scene_root.add_child(dialog)

	var runner = dialog.get_node_or_null("DialogueRunner")
	if runner == null:
		dialog.queue_free()
		return graph.get_next(node_id, 0)

	runner.start_choices(choices)
	var index = await runner.choice_selected

	dialog.queue_free()
	return graph.get_next(node_id, int(index))
