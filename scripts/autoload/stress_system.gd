extends Node

signal fill_changed(current: float, ceiling: float)
signal ceiling_changed(ceiling: float)
signal fainted()

@export var balance: StressBalance

var _fill: float = 0.0
var _ceiling: float = 100.0


func _ready() -> void:
	if balance == null and ResourceLoader.exists("res://data/balance.tres"):
		balance = load("res://data/balance.tres") as StressBalance
	if balance == null:
		balance = StressBalance.new()
	_ceiling = balance.ceiling_start
	ceiling_changed.emit(_ceiling)
	fill_changed.emit(_fill, _ceiling)


func add_fill(amount: float) -> void:
	_fill = clampf(_fill + amount, 0.0, _ceiling)
	fill_changed.emit(_fill, _ceiling)
	if _fill >= _ceiling:
		_faint()


func change_ceiling(amount: float) -> void:
	_ceiling = clampf(_ceiling + amount, balance.ceiling_min, balance.ceiling_max)
	if _fill > _ceiling:
		_fill = _ceiling
	ceiling_changed.emit(_ceiling)
	fill_changed.emit(_fill, _ceiling)


func fill_ratio() -> float:
	return _fill / _ceiling if _ceiling > 0.0 else 1.0


func current_fill() -> float:
	return _fill


func current_ceiling() -> float:
	return _ceiling


func _faint() -> void:
	_fill = 0.0
	change_ceiling(-balance.faint_ceiling_loss)
	fainted.emit()
	fill_changed.emit(_fill, _ceiling)


## Только заполнение — потолок (шрам кампании) не трогаем.
func reset_fill() -> void:
	_fill = 0.0
	fill_changed.emit(_fill, _ceiling)


## Полный сброс (debug / не геймплейный поток).
func reset() -> void:
	_fill = 0.0
	_ceiling = balance.ceiling_start
	ceiling_changed.emit(_ceiling)
	fill_changed.emit(_fill, _ceiling)
