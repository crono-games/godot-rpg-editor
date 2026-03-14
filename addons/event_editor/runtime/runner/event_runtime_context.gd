class_name EventRuntimeContext
extends RefCounted

signal changed
signal flags_changed
signal variables_changed
signal local_flags_changed(event_id: String)

var flags := {}
var variables := {}
var current_state_by_event := {}
var current_event_id: String = ""
var last_trigger: String = ""
var last_trigger_by_event := {}
var local_flags_by_event := {}
var last_delta := 0.0
static var scene_event_environment: EventEnvironment = null

func apply_global_state(state: GlobalState) -> void:
	if state == null:
		return
	flags.clear()
	variables.clear()
	for entry in state.get_flags().values():
		if entry == null:
			continue
		var name := str(entry.name)
		if name == "":
			continue
		flags[name] = bool(entry.value)
	for entry in state.get_variables().values():
		if entry == null:
			continue
		var name := str(entry.name)
		if name == "":
			continue
		variables[name] = entry.value
	flags_changed.emit()
	variables_changed.emit()
	changed.emit()

func set_flag(name: String, value: bool) -> void:
	flags[name] = value
	flags_changed.emit()
	changed.emit()

func get_flag(name: String) -> bool:
	return bool(flags.get(name, false))

func set_variable(name: String, value) -> void:
	variables[name] = value
	variables_changed.emit()
	changed.emit()

func get_variable(name: String, default_value = null):
	return variables.get(name, default_value)

func set_local_flag(event_id: String, name: String, value: bool) -> void:
	if event_id == "":
		return
	if not local_flags_by_event.has(event_id):
		local_flags_by_event[event_id] = {}
	local_flags_by_event[event_id][name] = value
	local_flags_changed.emit(event_id)

func get_local_flag(event_id: String, name: String) -> bool:
	if event_id == "":
		return false
	var map = local_flags_by_event.get(event_id, {})
	return bool(map.get(name, false))

func set_current_state(event_id: String, state_id: String) -> void:
	if event_id == "":
		return
	current_state_by_event[event_id] = state_id

func get_current_state(event_id: String) -> String:
	if event_id == "":
		return ""
	return str(current_state_by_event.get(event_id, ""))

func set_current_event(event_id: String) -> void:
	current_event_id = event_id

func set_last_trigger(trigger: String) -> void:
	last_trigger = trigger

func set_last_trigger_for_event(event_id: String, trigger: String) -> void:
	if event_id == "":
		return
	last_trigger_by_event[event_id] = trigger
	last_trigger = trigger

func set_last_delta(delta: float) -> void:
	last_delta = delta

func set_scene_event_environment(env: EventEnvironment) -> void:
	scene_event_environment = env

static func get_scene_event_environment() -> EventEnvironment:
	return scene_event_environment

static func get_event_by_id(event_id: String) -> Node:
	if scene_event_environment == null:
		return null
	return scene_event_environment.get_event_by_id(event_id)

static func get_event_by_name(name: String) -> Node:
	if scene_event_environment == null:
		return null
	return scene_event_environment.get_event_by_name(name)

func get_last_trigger_for_event(event_id: String) -> String:
	if event_id == "":
		return ""
	return str(last_trigger_by_event.get(event_id, ""))
