## Helper class used by EventTriggerService to resolve event nodes and trigger areas.

class_name EventNodeResolver
extends RefCounted


static func node_matches_group(node: Node, group: String) -> bool:
	if node == null:
		return false

	var n := node
	while n != null:
		if n.is_in_group(group):
			return true
		n = n.get_parent()

	return false


static func resolve_group_node(node: Node, group: String) -> Node:
	if node == null:
		return null

	var n := node
	while n != null:
		if n.is_in_group(group):
			return n
		n = n.get_parent()

	return null


static func resolve_event_from_area(area: Node) -> Node:
	if area == null:
		return null

	var n := area

	while n != null:
		if n is EventInstance2D or n is EventInstance3D:
			return n
		n = n.get_parent()

	return null


static func resolve_touch_area(event_instance: Node) -> Node:
	if event_instance == null:
		return null

	if event_instance is Area2D or event_instance is Area3D:
		var resolved := _call_trigger_method(event_instance)
		return resolved if resolved != null else event_instance

	var method_area := _call_trigger_method(event_instance)
	if method_area != null:
		return method_area

	for prop in ["trigger_area", "area"]:
		if event_instance.has_method("get"):
			var ref = event_instance.get(prop)
			if ref is Area2D or ref is Area3D:
				return ref

	for child in event_instance.get_children():
		if child is Area2D or child is Area3D:
			return child

	return null


static func _call_trigger_method(node: Node) -> Node:
	if node.has_method("get_trigger_area"):
		var result = node.call("get_trigger_area")
		if result is Area2D or result is Area3D:
			return result
	return null


static func area_in_front(
	player: Node2D,
	direction: Vector2,
	grid_size: float,
	mask := 0
) -> Area2D:

	if player == null:
		return null

	var pos3 := Vector3(player.global_position.x, 0.0, player.global_position.y)

	var cell := GridUtils.world_to_cell(pos3, grid_size, true)

	var next_cell := cell + Vector2i(direction)

	return area_at_cell(player.get_world_2d(), next_cell, grid_size, mask)


static func area_under_player(
	player: Node2D,
	grid_size: float,
	mask := 0
) -> Area2D:

	if player == null:
		return null

	var pos3 := Vector3(player.global_position.x, 0.0, player.global_position.y)

	var cell := GridUtils.world_to_cell(pos3, grid_size, true)

	return area_at_cell(player.get_world_2d(), cell, grid_size, mask)


static func area_at_cell(
	world: World2D,
	cell: Vector2i,
	grid_size: float,
	mask := 0
) -> Area2D:

	if world == null:
		return null

	var space_state := world.direct_space_state

	var world_pos := (Vector2(cell) * grid_size) + Vector2(grid_size * 0.5, grid_size * 0.5)

	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false

	if mask != 0:
		query.collision_mask = mask

	var result := space_state.intersect_point(query)

	for hit in result:

		var collider = hit.collider

		var event := resolve_event_from_area(collider)

		if event != null:
			return collider

	return null


static func node_to_pos3(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).position
	if node is Node2D:
		var p := (node as Node2D).position
		return Vector3(p.x, 0.0, p.y)
	return Vector3.ZERO

static func pos3_to_node_value(node: Node, pos3: Vector3):
	if node is Node3D:
		return pos3
	return Vector2(pos3.x, pos3.z)

static func dir3_to_animation_dir(node: Node, dir3: Vector3):
	if node is Node2D:
		return Vector2(dir3.x, dir3.z)
	return dir3


static func resolve_grid_size(event: Node) -> float:
	if event.has_method("get") and event.get("grid_size") != null:
		return maxf(0.01, float(event.get("grid_size")))
	return 1.0

static func resolve_grid_centered(event: Node) -> bool:
	if event.has_method("get") and event.get("grid_centered") != null:
		return bool(event.get("grid_centered"))
	return true

static func resolve_hitbox_shape(hitbox_area: Area2D) -> CollisionShape2D:
	if hitbox_area == null:
		return null
	var direct := hitbox_area.get_node_or_null("HitboxShape")
	if direct is CollisionShape2D:
		return direct
	var generic := hitbox_area.get_node_or_null("CollisionShape2D")
	if generic is CollisionShape2D:
		return generic
	for child in hitbox_area.get_children():
		if child is CollisionShape2D:
			return child
	return null

static func is_player_node(node: Node, player_group: String, player_ref: Node) -> bool:
	if node == null:
		return false
	if player_ref != null and node == player_ref:
		return true
	if node.is_in_group(player_group):
		return true
	var name_l := String(node.name).to_lower()
	if name_l.contains("player"):
		return true
	if node.has_method("get"):
		var node_id := str(node.get("id"))
		if player_ref != null and player_ref.has_method("get") and node_id != "" and node_id == str(player_ref.get("id")):
			return true
	return false
