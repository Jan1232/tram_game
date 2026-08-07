class_name DayManager
extends Node

## Оркестратор смены: часы, полосы наплыва, обморок → пропуск времени, сводка.

signal time_changed(minutes: int)
signal band_changed(band: DayBand)
signal shift_ended(reason: String)
signal date_changed(year: int, month: int, day: int)

@export var config: DayConfig
@export var faint_layer_path: NodePath = NodePath("../FaintLayer")
@export var summary_layer_path: NodePath = NodePath("../ShiftSummaryLayer")
@export var director_path: NodePath = NodePath("../PassengerDirector")
## Стартовая календарная дата кампании (дата первой смены).
@export var start_year: int = 2026
@export var start_month: int = 6
@export var start_day: int = 1

var _minutes: float = 0.0
var _running: bool = false
var _current_band: DayBand = null
var _faints_this_shift: int = 0
var _fainting: bool = false
var _shifts_started: int = 0
var _cal_year: int = 2026
var _cal_month: int = 6
var _cal_day: int = 1

var _faint_layer: CanvasLayer = null
var _summary_layer: CanvasLayer = null
var _summary_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("day_manager")
	_cal_year = start_year
	_cal_month = start_month
	_cal_day = start_day
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
	var ss := get_node("/root/StressSystem")
	ss.fainted.connect(on_faint)
	var eco := get_node("/root/EconomySystem")
	eco.fired.connect(_on_fired)
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


func current_date_parts() -> Array:
	return [_cal_year, _cal_month, _cal_day]


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
	var eco := get_node("/root/EconomySystem")
	if eco.is_fired():
		_show_fired_summary()
		return
	if _shifts_started > 0:
		_advance_calendar_day()
		# Штрафы за упущенных вчера — утром (GDD §2.9).
		eco.apply_morning_fines()
		if eco.last_morning_fine > 0:
			var flow := get_tree().get_first_node_in_group("game_flow")
			if flow and flow.has_method("show_notice"):
				flow.show_notice(
					"Вчера проехало зайцем: %d, штраф −%d ₽"
					% [eco.last_morning_dodgers, eco.last_morning_fine]
				)
	_shifts_started += 1
	_minutes = float(config.start_min)
	_faints_this_shift = 0
	_current_band = null
	_fainting = false
	get_node("/root/StressSystem").reset_fill()
	get_node("/root/FatigueSystem").reset()
	_hide_summary()
	_show_blackout(false)
	var cond := get_tree().get_first_node_in_group("conductor")
	if cond and cond.has_method("on_shift_start"):
		cond.on_shift_start()
	get_tree().paused = false
	_running = true
	time_changed.emit(int(_minutes))
	date_changed.emit(_cal_year, _cal_month, _cal_day)
	_update_band()
	_reinit_director()


func _end_shift(reason: String) -> void:
	if not _running and _summary_visible():
		return
	_running = false
	get_tree().paused = true
	get_node("/root/EconomySystem").settle_shift_end()
	shift_ended.emit(reason)
	_show_summary(reason)


func _unhandled_input(event: InputEvent) -> void:
	if _running or _fainting:
		return
	var eco := get_node("/root/EconomySystem")
	if eco.is_fired():
		return
	if _summary_visible() and event.is_action_pressed("ui_accept"):
		_start_shift()
		get_viewport().set_input_as_handled()


func _on_fired() -> void:
	_running = false
	get_tree().paused = true
	_show_fired_summary()


func _show_fired_summary() -> void:
	if _summary_layer == null:
		return
	var body := "УВОЛЕН\n3 выговора за 2 дня.\nЛето потрачено впустую.\n\n(Экран концовки — позже)"
	if _summary_label:
		_summary_label.text = body
	_summary_layer.visible = true


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
	var eco := get_node("/root/EconomySystem")
	var title := "Смена окончена — 17:00"
	if reason == "faint":
		title = "Смена окончена досрочно"
	var pending := eco.pending_dodger_escapes()
	var pending_fine := pending * int(eco.balance.fine_dodger_escaped)
	var lines: PackedStringArray = [
		title,
		"Обмороки: %d" % _faints_this_shift,
		"Потолок стресса: %.0f" % get_node("/root/StressSystem").current_ceiling(),
		"",
		"Еда: −%d ₽" % eco.last_food,
	]
	if eco.last_salary > 0:
		lines.append("Зарплата: +%d ₽" % eco.last_salary)
	if pending > 0:
		lines.append("Зайцев упущено: %d → штраф утром −%d ₽" % [pending, pending_fine])
	lines.append("Баланс: %d ₽" % eco.current_money())
	if eco.reprimand_count() > 0:
		lines.append("Выговоры (окно 2 дня): %d/3" % eco.reprimand_count())
	lines.append("")
	lines.append("Enter — следующая смена")
	if _summary_label:
		_summary_label.text = "\n".join(lines)
	_summary_layer.visible = true


func _hide_summary() -> void:
	if _summary_layer:
		_summary_layer.visible = false


func _summary_visible() -> bool:
	return _summary_layer != null and _summary_layer.visible


func _build_default_bands() -> Array[DayBand]:
	# Цель: ~35–50 пассажиров за смену (калибровка плейтестом).
	var out: Array[DayBand] = []
	out.append(_make_band("Утро тихое", 300, 420, 1, 2, 18.0, 25.0))
	out.append(_make_band("Час пик", 420, 600, 3, 5, 8.0, 12.0))
	out.append(_make_band("День", 600, 900, 2, 3, 14.0, 20.0))
	out.append(_make_band("Вечерний пик", 900, 1020, 3, 5, 8.0, 12.0))
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


func _advance_calendar_day() -> void:
	_cal_day += 1
	var dim := _days_in_month(_cal_year, _cal_month)
	if _cal_day > dim:
		_cal_day = 1
		_cal_month += 1
		if _cal_month > 12:
			_cal_month = 1
			_cal_year += 1


func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			var leap := (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
			return 29 if leap else 28
		_:
			return 30
