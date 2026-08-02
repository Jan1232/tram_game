extends Node

## Автолоад FatigueSystem. Усталость 0..1 — не трогает стресс.
## Доступ: get_node("/root/FatigueSystem")

signal fatigue_changed(level: float)

@export var grace_sec: float = 40.0 ## секунд на ногах до начала накопления
@export var ramp_up_sec: float = 60.0 ## секунд стояния сверх буфера: 0→1
@export var recover_sec: float = 30.0 ## секунд сидя: 1→0
@export var min_speed_mult: float = 0.5 ## скорость при полной усталости
@export var vignette_from: float = 0.5 ## виньетка начинается с этого уровня

var _level: float = 0.0
var _standing_time: float = 0.0


func tick(delta: float, seated: bool) -> void:
	if seated:
		_standing_time = 0.0
		if recover_sec > 0.0:
			_set_level(_level - delta / recover_sec)
	else:
		_standing_time += delta
		if _standing_time >= grace_sec and ramp_up_sec > 0.0:
			_set_level(_level + delta / ramp_up_sec)


func speed_multiplier() -> float:
	return lerpf(1.0, min_speed_mult, _level)


func vignette_intensity() -> float:
	if _level < vignette_from:
		return 0.0
	return (_level - vignette_from) / maxf(1.0 - vignette_from, 0.001)


func level() -> float:
	return _level


func reset() -> void:
	_standing_time = 0.0
	_set_level(0.0)


func _set_level(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, _level):
		_level = next
		return
	_level = next
	fatigue_changed.emit(_level)
