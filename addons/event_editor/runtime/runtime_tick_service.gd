class_name RuntimeTickService
extends RefCounted

var _interval := 1.0 / 60.0
var _use_delta := false
var _auto_timer: Timer = null
var _accum := 0.0
var _tick_callback: Callable

func configure(owner: Node, interval: float, use_delta: bool, tick_callback: Callable) -> void:
	_interval = max(0.0001, interval)
	_use_delta = use_delta
	_tick_callback = tick_callback
	_accum = 0.0
	_setup_timer(owner)

func set_enabled(owner: Node, enabled: bool) -> void:
	if _use_delta:
		if owner != null:
			owner.set_process(enabled)
		return
	if _auto_timer == null:
		return
	if enabled:
		_auto_timer.start()
	else:
		_auto_timer.stop()

func process(delta: float) -> void:
	if not _use_delta:
		return
	if _tick_callback.is_null():
		return
	_accum += delta
	if _accum < _interval:
		return
	var step := _accum
	_accum = 0.0
	_tick_callback.call(step)

func _setup_timer(owner: Node) -> void:
	if _use_delta:
		if owner != null:
			owner.set_process(true)
		return
	if owner == null:
		return
	if _auto_timer != null and is_instance_valid(_auto_timer):
		_auto_timer.queue_free()
	_auto_timer = Timer.new()
	_auto_timer.wait_time = _interval
	_auto_timer.one_shot = false
	owner.add_child(_auto_timer)
	_auto_timer.timeout.connect(_on_timer_timeout)
	_auto_timer.start()

func _on_timer_timeout() -> void:
	if _tick_callback.is_null():
		return
	_tick_callback.call(_interval)
