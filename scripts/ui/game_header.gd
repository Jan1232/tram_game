class_name GameHeader
extends Control

## Верхняя планка в духе TITP: стресс слева; деньги / время / дата справа.

const TIME_COLOR := Color(1.0, 0.18, 0.18, 1.0)
const TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const BAR_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const MONTHS_RU := [
	"",
	"января",
	"февраля",
	"марта",
	"апреля",
	"мая",
	"июня",
	"июля",
	"августа",
	"сентября",
	"октября",
	"ноября",
	"декабря",
]

@export var day_manager_path: NodePath = NodePath("../../DayManager")
@export var starting_money: int = 0
@export var bar_height: float = 56.0
@export var font_size: int = 32
@export var right_separation: int = 36

var _money_amount: int = 0
var _money_label: Label
var _time_label: Label
var _date_label: Label


func _ready() -> void:
	_money_amount = starting_money
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_bottom = bar_height
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_bind_day_manager()
	_refresh_money()


func set_money(amount: int) -> void:
	_money_amount = amount
	_refresh_money()


func add_money(delta: int) -> void:
	set_money(_money_amount + delta)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BAR_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var stress := StressBar.new()
	stress.name = "StressBar"
	stress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stress)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", right_separation)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)

	_money_label = _make_label("$0", TEXT_COLOR, true)
	_time_label = _make_label("05:00", TIME_COLOR, true)
	_date_label = _make_label("1 января", TEXT_COLOR, false)
	right.add_child(_money_label)
	right.add_child(_time_label)
	right.add_child(_date_label)


func _make_label(text: String, color: Color, bold_feel: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size if bold_feel else int(font_size * 0.9))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _bind_day_manager() -> void:
	var dm := get_node_or_null(day_manager_path)
	if dm == null:
		dm = get_tree().get_first_node_in_group("day_manager")
	if dm == null:
		return
	if dm.has_signal("time_changed"):
		dm.time_changed.connect(_on_time)
	if dm.has_signal("date_changed"):
		dm.date_changed.connect(_on_date)
	if dm.has_method("current_minutes"):
		_on_time(dm.current_minutes())
	if dm.has_method("current_date_parts"):
		var parts: Array = dm.current_date_parts()
		if parts.size() >= 3:
			_on_date(int(parts[0]), int(parts[1]), int(parts[2]))


func _on_time(minutes: int) -> void:
	var h := minutes / 60
	var m := minutes % 60
	_time_label.text = "%02d:%02d" % [h, m]


func _on_date(_year: int, month: int, day: int) -> void:
	var month_name: String = MONTHS_RU[month] if month >= 1 and month <= 12 else str(month)
	_date_label.text = "%d %s" % [day, month_name]


func _refresh_money() -> void:
	if _money_label:
		_money_label.text = _format_money(_money_amount)


func _format_money(amount: int) -> String:
	var neg := amount < 0
	var n := absi(amount)
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-$" if neg else "$") + out
