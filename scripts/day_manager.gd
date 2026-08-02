class_name DayManager
extends Node

## Оркестратор смены: часы, полосы наплыва, обморок → пропуск времени, сводка.

signal time_changed(minutes: int)
signal band_changed(band: DayBand)
signal shift_ended(reason: String)

@export var config: DayConfig
@export var faint_layer_path: NodePath = NodePath("../FaintLayer")
@export var summary_layer_path: NodePath = NodePath("../ShiftSummaryLayer")
@export var director_path: NodePath = NodePath("../PassengerDirector")

var _minutes: float = 0.0
var _running: bool = false
var _current_band: DayBand = null
var _faints_this_shift: int = 0
var _fainting: bool = false

var _faint_layer: CanvasLayer = null
var _summary_layer: CanvasLayer = null
var _summary_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("day_manager")
	if config == null:
		config = DayConfig.new()
	if config.bands.is_empty():
		config.bands = _build_default_bands()
	_faint_layer = get_node_or_null(faint_layer_path) as CanvasLayer
	_summary_layer = get_node_or_null(summary_layer_path) as CanvasLayer
	if _summary_layer:
		_summary_label = _summary_layer.get_node_or_null("Center/Panel/Label") as Label
	if _faint_layer:
		_faint_layer.visible = false
	if _summary_layer:
		_summary_layer.visible = false
	StressSystem.fainted.connect(on_faint)
	call_deferred("_start_shift")


func _process(delta: float) -> void:
	if not _running:
		return
	var prev := int(_minutes)
	_minutes += delta * _min_per_real_sec()
	if int(_minutes) != prev:
		time_changed.emit(int(_minutes))
		_update_band()
	if _minutes >= float(config.end_min):
		_end_shift("full")


func _min_per_real_sec() -> float:
	return float(config.end_min - config.start_min) / maxf(config.shift_real_seconds, 1.0)


func current_band() -> DayBand:
	return _current_band


func current_minutes() -> int:
	return int(_minutes)


func _update_band() -> void:
	var b := _band_at(int(_minutes))
	if b != _current_band:
		_current_band = b
		band_changed.emit(b)


func _band_at(m: int) -> DayBand:
	for band in config.bands:
		if m >= band.start_min and m < band.end_min:
			return band
	return config.bands.back() if not config.bands.is_empty() else null


func on_faint() -> void:
	if _fainting or not _running:
		return
	_fainting = true
	_running = false
	_faints_this_shift += 1
	get_tree().paused = true
	_show_blackout(true)
	print(">>> ОБМОРОК — пропуск времени + потолок уже снижен StressSystem")
	await get_tree().create_timer(1.4, true, false, true).timeout
	_minutes = minf(_minutes + float(config.faint_time_skip_min), float(config.end_min))
	time_changed.emit(int(_minutes))
	_update_band()
	_show_blackout(false)
	_fainting = false
	if _minutes >= float(config.end_min):
		_end_shift("faint")
	else:
		get_tree().paused = false
		_running = true


func _start_shift() -> void:
	_minutes = float(config.start_min)
	_faints_this_shift = 0
	_current_band = null
	_fainting = false
	StressSystem.reset_fill()
	_hide_summary()
	_show_blackout(false)
	var cond := get_tree().get_first_node_in_group("conductor")
	if cond and cond.has_method("on_shift_start"):
		cond.on_shift_start()
	get_tree().paused = false
	_running = true
	time_changed.emit(int(_minutes))
	_update_band()
	_reinit_director()


func _end_shift(reason: String) -> void:
	if not _running and _summary_visible():
		return
	_running = false
	get_tree().paused = true
	shift_ended.emit(reason)
	_show_summary(reason)


func _unhandled_input(event: InputEvent) -> void:
	if _running or _fainting:
		return
	if _summary_visible() and event.is_action_pressed("ui_accept"):
		_start_shift()
		get_viewport().set_input_as_handled()


func _reinit_director() -> void:
	var dir := get_node_or_null(director_path)
	if dir and dir.has_method("reinit_for_shift"):
		dir.reinit_for_shift()
	else:
		_clear_passengers_fallback()


func _clear_passengers_fallback() -> void:
	for node in get_tree().get_nodes_in_group("passengers"):
		if is_instance_valid(node) and node.has_method("despawn"):
			node.despawn(false)
		elif is_instance_valid(node):
			node.queue_free()


func _show_blackout(on: bool) -> void:
	if _faint_layer:
		_faint_layer.visible = on


func _show_summary(reason: String) -> void:
	if _summary_layer == null:
		return
	var title := "Смена окончена — 17:00"
	if reason == "faint":
		title = "Смена окончена досрочно"
	var body := "%s\nОбмороки: %d\nПотолок стресса: %.0f\n\nEnter — следующая смена" % [
		title,
		_faints_this_shift,
		StressSystem.current_ceiling(),
	]
	if _summary_label:
		_summary_label.text = body
	_summary_layer.visible = true


func _hide_summary() -> void:
	if _summary_layer:
		_summary_layer.visible = false


func _summary_visible() -> bool:
	return _summary_layer != null and _summary_layer.visible


func _build_default_bands() -> Array[DayBand]:
	var out: Array[DayBand] = []
	out.append(_make_band("Утро тихое", 300, 420, 1, 3, 12.0, 18.0))
	out.append(_make_band("Час пик", 420, 600, 5, 8, 3.0, 6.0))
	out.append(_make_band("День", 600, 900, 2, 4, 10.0, 16.0))
	out.append(_make_band("Вечерний пик", 900, 1020, 5, 8, 3.0, 6.0))
	return out


func _make_band(
	label: String,
	start_m: int,
	end_m: int,
	min_p: int,
	max_p: int,
	r_min: float,
	r_max: float
) -> DayBand:
	var b := DayBand.new()
	b.label = label
	b.start_min = start_m
	b.end_min = end_m
	b.min_passengers = min_p
	b.max_passengers = max_p
	b.respawn_min = r_min
	b.respawn_max = r_max
	return b
