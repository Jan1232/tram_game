class_name StressBar
extends Control

@export var max_ceiling: float = 110.0
@export var bar_max_width: float = 500.0
@export var bar_height: float = 28.0

var _fill: float = 0.0
var _ceiling: float = 100.0


func _ready() -> void:
	StressSystem.fill_changed.connect(_on_fill_changed)
	StressSystem.ceiling_changed.connect(_on_ceiling_changed)
	_fill = StressSystem.current_fill()
	_ceiling = StressSystem.current_ceiling()
	queue_redraw()


func _on_fill_changed(current: float, ceiling: float) -> void:
	_fill = current
	_ceiling = ceiling
	queue_redraw()


func _on_ceiling_changed(ceiling: float) -> void:
	_ceiling = ceiling
	queue_redraw()


func _draw() -> void:
	var track_w := bar_max_width
	var active_w := (_ceiling / max_ceiling) * track_w
	var ratio := (_fill / _ceiling) if _ceiling > 0.0 else 1.0
	var fill_w := ratio * active_w
	draw_rect(Rect2(Vector2.ZERO, Vector2(track_w, bar_height)), Color(0.10, 0.10, 0.12, 0.5))
	draw_rect(Rect2(Vector2.ZERO, Vector2(active_w, bar_height)), Color(0.20, 0.20, 0.24, 0.9))
	var col := Color(0.40, 0.80, 0.40)
	if ratio >= 0.90:
		col = Color(0.90, 0.20, 0.20)
	elif ratio >= 0.85:
		col = Color(0.95, 0.50, 0.15)
	elif ratio >= 0.65:
		col = Color(0.90, 0.80, 0.20)
	draw_rect(Rect2(Vector2.ZERO, Vector2(fill_w, bar_height)), col)
