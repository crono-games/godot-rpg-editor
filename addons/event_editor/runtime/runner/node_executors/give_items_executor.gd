class_name GiveItemsExecutor
extends RefCounted

const OP_ADD := "add"
const OP_REMOVE := "remove"
const OP_SET := "set"
const DEFAULT_INVENTORY_VARIABLE := "inventory"

func run(node_id: String, node: Dictionary, graph: EventGraphRuntime, ctx: EventRuntimeContext, _scene_root: Node) -> String:
	var params: Dictionary = node.get("params", {})
	var item_id := str(params.get("item_id", "")).strip_edges()
	if item_id == "":
		return graph.get_next(node_id, 0)

	var operation := str(params.get("operation", OP_ADD)).to_lower()
	if operation != OP_ADD and operation != OP_REMOVE and operation != OP_SET:
		operation = OP_ADD

	var amount := int(params.get("amount", 1))
	var inventory_variable := str(params.get("inventory_variable", DEFAULT_INVENTORY_VARIABLE)).strip_edges()
	if inventory_variable == "":
		inventory_variable = DEFAULT_INVENTORY_VARIABLE

	var inventory := _read_inventory(ctx, inventory_variable)
	var current := int(inventory.get(item_id, 0))
	var next_value := current

	match operation:
		OP_ADD:
			next_value = current + max(0, amount)
		OP_REMOVE:
			next_value = max(0, current - max(0, amount))
		OP_SET:
			next_value = max(0, amount)
		_:
			next_value = current + max(0, amount)

	if next_value <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = next_value

	ctx.set_variable(inventory_variable, inventory)
	return graph.get_next(node_id, 0)

func _read_inventory(ctx: EventRuntimeContext, inventory_variable: String) -> Dictionary:
	var raw = ctx.get_variable(inventory_variable, {})
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return {}
