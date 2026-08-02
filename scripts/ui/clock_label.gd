class_name ClockLabel
extends Label

@export var day_manager_path: NodePath = NodePath("../../DayManager")

var _time_text: String = "05:00"
var _band_text: String = ""


func _ready() -> void:
	var dm := get_node_or_null(day_manager_path)
	if dm == null:
		dm = get_tree().get_first_node_in_group("day_manager")
	if dm:
		if dm.has_signal("time_changed"):
			dm.time_changed.connect(_on_time)
		if dm.has_signal("band_changed"):
			dm.band_changed.connect(_on_band)
		if dm.has_method("current_minutes"):
			_on_time(dm.current_minutes())
		if dm.has_method("current_band"):
			_on_band(dm.current_band())
	_refresh()


func _on_time(minutes: int) -> void:
	var h := minutes / 60
	var m := minutes % 60
	_time_text = "%02d:%02d" % [h, m]
	_refresh()


func _on_band(band: DayBand) -> void:
	_band_text = band.label if band else ""
	_refresh()


func _refresh() -> void:
	if _band_text.is_empty():
		text = _time_text
	else:
		text = "%s  ·  %s" % [_time_text, _band_text]
