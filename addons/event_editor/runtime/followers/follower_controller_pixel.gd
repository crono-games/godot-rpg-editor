extends Node
class_name FollowerControllerPixel

@export var player_path: NodePath
@export var auto_discover_player := true
@export var player_group := "player"
@export var follower_group := "follower_actor"

@export var sample_distance_min := 1.0
@export var max_history_points := 2048
@export var base_delay_frames := 8
@export var delay_step_frames := 8
@export var min_gap_to_target := 8.0
@export var debug_logs := false

var _player: Node2D = null
var _history: Array[Vector2] = []
var _last_leader_pos := Vector2.ZERO

func _ready() -> void:
	add_to_group("follower_controller")
	_player = _resolve_player()
	if _player != null:
		_history.append(_player.global_position)
		_last_leader_pos = _player.global_position

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _resolve_player()
		if _player == null:
			return

	_record_player_position()
	var followers := _get_followers()
	if followers.is_empty():
		return
	
	for i in range(followers.size()):
		var follower = followers[i]
		if follower == null or not is_instance_valid(follower):
			continue
		var target := Vector2.ZERO
		var avoid_pos := _player.global_position
		var leader_dir := _leader_direction()
		follower.follow_speed = _player.speed
		
		if i == 0:
			var delay = max(1, base_delay_frames)
			var idx = _history.size() - 1 - delay
			if idx < 0 or idx >= _history.size():
				if follower.has_method("stop_follow"):
					follower.call("stop_follow")
				continue
			target = _history[idx]
		else:
			var previous = followers[i - 1]
			if not (previous is Node2D) or not is_instance_valid(previous):
				if follower.has_method("stop_follow"):
					follower.call("stop_follow")
				continue
			avoid_pos = (previous as Node2D).global_position
			if previous.has_method("get_facing_direction_2d"):
				leader_dir = previous.call("get_facing_direction_2d")
			if leader_dir.length_squared() <= 0.000001:
				leader_dir = avoid_pos - (follower as Node2D).global_position
			if leader_dir.length_squared() <= 0.000001:
				leader_dir = Vector2.DOWN
			leader_dir = leader_dir.normalized()
			target = avoid_pos - (leader_dir * min_gap_to_target)

		if follower.has_method("follow_to_world"):
			follower.call("follow_to_world", target, delta, avoid_pos, min_gap_to_target, leader_dir)

func add_follower_actor(actor: Node, requested_slot: int = -1) -> bool:
	if not (actor is Node2D) or not is_instance_valid(actor):
		return false
	if actor == _player:
		return false
	if not actor.is_in_group(follower_group):
		actor.add_to_group(follower_group)
	if actor.has_method("set"):
		actor.set("is_follower", true)
		if actor.get("passability") != null:
			actor.set("passability", "Passable")

	if requested_slot < 0:
		var max_slot := -1
		for f in _get_followers():
			if f == actor:
				continue
			max_slot = max(max_slot, int(f.get("follow_index")) if f.has_method("get") and f.get("follow_index") != null else -1)
		requested_slot = max_slot + 1
	if actor.has_method("set"):
		actor.set("follow_index", max(0, requested_slot))

	_reindex_followers()
	if actor.has_method("stop_follow"):
		actor.call("stop_follow")
	force_resync_after_warp()
	return true

func remove_follower_actor(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if actor.is_in_group(follower_group):
		actor.remove_from_group(follower_group)
	if actor.has_method("set"):
		actor.set("is_follower", false)
	_reindex_followers()
	force_resync_after_warp()
	return true

func remove_follower_actor_by_event_id(event_id: String) -> bool:
	if event_id == "":
		return false
	for follower in _get_followers():
		if follower == null or not is_instance_valid(follower):
			continue
		if str(follower.get("id")) == event_id:
			return remove_follower_actor(follower)
	return false

func clear_followers() -> void:
	var followers := _get_followers()
	for follower in followers:
		if follower == null or not is_instance_valid(follower):
			continue
		if follower.is_in_group(follower_group):
			follower.remove_from_group(follower_group)
		if follower.has_method("set"):
			follower.set("is_follower", false)
		if follower.has_method("stop_follow"):
			follower.call("stop_follow")
	_history.clear()
	if _player != null and is_instance_valid(_player):
		_history.append(_player.global_position)
		_last_leader_pos = _player.global_position

func force_resync_after_warp() -> void:
	_player = _resolve_player()
	if _player == null or not is_instance_valid(_player):
		return

	var followers := _get_followers()
	var facing := Vector2.DOWN
	if _player.has_method("get_facing_direction"):
		var d3 = _player.call("get_facing_direction")
		if d3 is Vector3:
			var f := Vector2(d3.x, d3.z)
			if f.length_squared() > 0.000001:
				facing = f.normalized()
	if facing.length_squared() <= 0.000001:
		facing = Vector2.DOWN

	for i in range(followers.size()):
		var follower = followers[i]
		if not (follower is Node2D) or not is_instance_valid(follower):
			continue
		var slot_distance := min_gap_to_target * float(i + 1)
		(follower as Node2D).global_position = _player.global_position - (facing * slot_distance)
		if follower.has_method("stop_follow"):
			follower.call("stop_follow")
	
	_history.clear()
	var max_delay = max(1, base_delay_frames + max(0, followers.size() - 1) * max(1, delay_step_frames))
	var fill_count = max(2, max_delay + 2)
	for _i in range(fill_count):
		_history.append(_player.global_position)
	_last_leader_pos = _player.global_position

func _record_player_position() -> void:
	if _player == null:
		return
	var current := _player.global_position
	
	if _history.is_empty():
		_history.append(current)
		return
	if _history[_history.size() - 1].distance_to(current) < sample_distance_min:
		return
	_history.append(current)
	while _history.size() > max_history_points:
		_history.pop_front()

func _leader_direction() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.ZERO
	var current := _player.global_position
	var delta := current - _last_leader_pos
	_last_leader_pos = current
	if delta.length_squared() <= 0.000001:
		if _player.has_method("get_facing_direction"):
			var d3 = _player.call("get_facing_direction")
			if d3 is Vector3:
				return Vector2(d3.x, d3.z)
		return Vector2.ZERO
	return delta.normalized()

func _resolve_player() -> Node2D:
	if player_path != NodePath(""):
		var by_path := get_node_or_null(player_path)
		if by_path is Node2D:
			return by_path as Node2D
	if auto_discover_player:
		var players := get_tree().get_nodes_in_group(player_group)
		for n in players:
			if n is Node2D:
				return n as Node2D
	return null

func _get_followers() -> Array:
	var out: Array = []
	var nodes := get_tree().get_nodes_in_group(follower_group)
	for n in nodes:
		if not (n is Node2D):
			continue
		var active := true
		if n.has_method("get") and n.get("is_follower") != null:
			active = bool(n.get("is_follower"))
		if not active:
			continue
		out.append(n)
	out.sort_custom(func(a, b):
		var ai := int(a.get("follow_index")) if a.has_method("get") and a.get("follow_index") != null else 0
		var bi := int(b.get("follow_index")) if b.has_method("get") and b.get("follow_index") != null else 0
		return ai < bi
	)
	return out

func _reindex_followers() -> void:
	var followers := _get_followers()
	for i in range(followers.size()):
		var follower = followers[i]
		if follower == null or not is_instance_valid(follower):
			continue
		if follower.has_method("set"):
			follower.set("follow_index", i)
