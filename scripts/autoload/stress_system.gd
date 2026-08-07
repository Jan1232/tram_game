extends Node

## Autoload StressSystem. Доступ из кода: get_node("/root/StressSystem")
## (глобальное имя при hot-reload иногда пропадает — путь надёжнее).

signal fill_changed(current: float, ceiling: float)
signal ceiling_changed(ceiling: float)
signal fainted()

const _BalanceScript = preload("res://resources/stress_balance.gd")

@export var balance: Resource

var _fill: float = 0.0
var _ceiling: float = 100.0
## Счётчик обмороков за кампанию (шрам). Не сбрасывается между сменами.
var _faint_count: int = 0
var _faint_pending: bool = false
## Упущенные зайцы в текущей смене (прогрессивный стресс).
var _missed_this_shift: int = 0


func _ready() -> void:
	if balance == null and ResourceLoader.exists("res://data/balance.tres"):
		balance = load("res://data/balance.tres")
	if balance == null:
		balance = _BalanceScript.new()
	_ceiling = balance.ceiling_start
	ceiling_changed.emit(_ceiling)
	fill_changed.emit(_fill, _ceiling)


func add_fill(amount: float) -> void:
	_fill = clampf(_fill + amount, 0.0, _ceiling)
	fill_changed.emit(_fill, _ceiling)
	if _fill >= _ceiling and not _faint_pending:
		_faint_pending = true
		call_deferred("_faint")


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
	_faint_pending = false
	_fill = 0.0
	var idx: int = _faint_count
	var loss: float = balance.faint_ceiling_loss_overflow
	if idx < balance.faint_ceiling_losses.size():
		loss = balance.faint_ceiling_losses[idx]
	_faint_count += 1
	change_ceiling(-loss)
	fainted.emit()
	# fill_changed уже эмитит change_ceiling — не дублируем.


func apply_dodger_escaped() -> void:
	var s: float = balance.dodger_escaped_base + balance.dodger_escaped_step * float(_missed_this_shift)
	_missed_this_shift += 1
	add_fill(s)


func reset_fill() -> void:
	_fill = 0.0
	_missed_this_shift = 0
	fill_changed.emit(_fill, _ceiling)


func reset() -> void:
	_fill = 0.0
	_faint_count = 0
	_faint_pending = false
	_missed_this_shift = 0
	_ceiling = balance.ceiling_start
	ceiling_changed.emit(_ceiling)
	fill_changed.emit(_fill, _ceiling)
