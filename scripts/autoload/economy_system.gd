extends Node

## Autoload EconomySystem. Деньги кампании, штрафы, выговоры.
## Доступ: get_node("/root/EconomySystem")

signal money_changed(amount: int)
signal payout_received(amount: int, reason: String)
signal fine_applied(amount: int, reason: String)
signal fired()

const _BalanceScript = preload("res://resources/economy_balance.gd")

@export var balance: Resource

var _money: int = 0
## Номер завершённых смен (для зарплаты раз в N).
var _shift_index: int = 0
## Упущенные зайцы текущей смены → штраф утром следующей.
var _pending_dodger_escapes: int = 0
## Индексы смен с выговором (скользящее окно 2 смены).
var _reprimands: Array[int] = []
var _is_fired: bool = false
## Последний утренний штраф (для сводки).
var last_morning_fine: int = 0
var last_morning_dodgers: int = 0
var last_food: int = 0
var last_salary: int = 0


func _ready() -> void:
	if balance == null and ResourceLoader.exists("res://data/economy.tres"):
		balance = load("res://data/economy.tres")
	if balance == null:
		balance = _BalanceScript.new()
	_money = balance.advance
	money_changed.emit(_money)


func current_money() -> int:
	return _money


func shift_index() -> int:
	return _shift_index


func is_fired() -> bool:
	return _is_fired


func pending_dodger_escapes() -> int:
	return _pending_dodger_escapes


func add_money(amount: int, reason: String = "") -> void:
	_money += amount
	money_changed.emit(_money)
	if amount > 0:
		payout_received.emit(amount, reason)


func spend(amount: int, reason: String = "") -> bool:
	_money -= amount
	money_changed.emit(_money)
	if amount > 0:
		fine_applied.emit(amount, reason)
	return true


func note_dodger_escaped() -> void:
	_pending_dodger_escapes += 1


func award_dodger_caught() -> void:
	add_money(balance.bonus_dodger_caught, "caught")


func apply_wrong_arrest() -> void:
	spend(balance.fine_wrong_arrest, "wrong_arrest")
	add_reprimand(_shift_index)


func add_reprimand(at_shift: int) -> void:
	_reprimands.append(at_shift)
	_reprimands = _reprimands.filter(func(s: int) -> bool: return at_shift - s < 2)
	if _reprimands.size() >= 3:
		_is_fired = true
		fired.emit()


func reprimand_count() -> int:
	return _reprimands.size()


## Утро следующей смены: штрафы за упущенных вчера.
func apply_morning_fines() -> void:
	last_morning_dodgers = _pending_dodger_escapes
	last_morning_fine = 0
	if _pending_dodger_escapes <= 0:
		return
	last_morning_fine = balance.fine_dodger_escaped * _pending_dodger_escapes
	spend(last_morning_fine, "dodger_fines")
	_pending_dodger_escapes = 0


## Конец смены: еда + зарплата по расписанию.
func settle_shift_end() -> void:
	_shift_index += 1
	last_food = balance.food_per_shift
	spend(last_food, "food")
	last_salary = 0
	if balance.salary_every_shifts > 0 and _shift_index % balance.salary_every_shifts == 0:
		last_salary = balance.salary
		add_money(last_salary, "salary")


func reset() -> void:
	_money = balance.advance
	_shift_index = 0
	_pending_dodger_escapes = 0
	_reprimands.clear()
	_is_fired = false
	last_morning_fine = 0
	last_morning_dodgers = 0
	last_food = 0
	last_salary = 0
	money_changed.emit(_money)
