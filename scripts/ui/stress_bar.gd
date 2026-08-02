class_name StressBar
extends Control

## Иконка + 4 деления по 25% (fill/ceiling). Стороны деления 3.2 : 1, обводка #EEEEEE.

const SEG_COUNT := 4
const ASPECT := 3.2
const OUTLINE := Color("eeeeee")
const EMPTY := Color(0, 0, 0, 0) # прозрачно по умолчанию
const FILL := Color(0.95, 0.82, 0.2, 1.0) # жёлтый при накоплении

@export var icon: Texture2D = preload("res://assets/icons/stress.svg")
@export var segment_height: float = 18.667 # было 28, в 1.5 раза ниже
@export var gap: float = 6.0
@export var icon_height: float = 36.0
@export var outline_width: float = 2.0

var _fill: float = 0.0
var _ceiling: float = 100.0
var _stress: Node = null


func _ready() -> void:
	_stress = get_node("/root/StressSystem")
	_stress.fill_changed.connect(_on_fill_changed)
	_stress.ceiling_changed.connect(_on_ceiling_changed)
	_fill = _stress.current_fill()
	_ceiling = _stress.current_ceiling()
	_update_min_size()
	queue_redraw()


func _update_min_size() -> void:
	var seg_w := segment_height * ASPECT
	var icon_w := 0.0
	if icon:
		var aspect := float(icon.get_width()) / maxf(float(icon.get_height()), 1.0)
		icon_w = icon_height * aspect
	var total_w := icon_w + gap + SEG_COUNT * seg_w + (SEG_COUNT - 1) * gap
	custom_minimum_size = Vector2(total_w, maxf(segment_height, icon_height))
	size = custom_minimum_size


func _on_fill_changed(current: float, ceiling: float) -> void:
	_fill = current
	_ceiling = ceiling
	queue_redraw()


func _on_ceiling_changed(ceiling: float) -> void:
	_ceiling = ceiling
	queue_redraw()


func _draw() -> void:
	var ratio := (_fill / _ceiling) if _ceiling > 0.0 else 1.0
	ratio = clampf(ratio, 0.0, 1.0)

	var x := 0.0
	var bar_y := maxf((icon_height - segment_height) * 0.5, 0.0)

	if icon:
		var aspect := float(icon.get_width()) / maxf(float(icon.get_height()), 1.0)
		var iw := icon_height * aspect
		var iy := maxf((segment_height - icon_height) * 0.5, 0.0)
		draw_texture_rect(icon, Rect2(0.0, iy, iw, icon_height), false)
		x = iw + gap

	var seg_w := segment_height * ASPECT
	for i in SEG_COUNT:
		var seg_start := float(i) / float(SEG_COUNT)
		var local := clampf((ratio - seg_start) * float(SEG_COUNT), 0.0, 1.0)
		var r := Rect2(x, bar_y, seg_w, segment_height)
		if EMPTY.a > 0.0:
			draw_rect(r, EMPTY)
		if local > 0.0:
			draw_rect(Rect2(x, bar_y, seg_w * local, segment_height), FILL)
		draw_rect(r, OUTLINE, false, outline_width)
		x += seg_w + gap
