class_name Passenger
extends Area2D

## Первое E: PAID платит; LIED/FORGOT могут врать «уже оплатил».
## После обилечивания часть теряет билет. Повторные проверки → эскалация скандала.

signal ticketed(passenger: Passenger)
signal removed(passenger: Passenger)
signal outcome(result: String, passenger: Passenger)

enum Kind { PAID, LIED, HONEST_FORGOT }
# PAID — платит при первом контакте
# LIED — заяц, врёт «оплатил» (тебе ещё не платил)
# HONEST_FORGOT — устаревший спавн-тип; «потерял после оплаты тебе» = paid_to_conductor && !can_show_ticket

const LINES_PAY := [
	"Вот.",
	"Держите.",
	"Сейчас.",
	"Да, конечно.",
	"Секунду…",
]

const LINES_CLAIM := [
	"Я уже оплатил.",
	"У меня есть билет.",
	"Платил на входе.",
	"Да я же оплачивал!",
]

const LINES_SHOW_TICKET := [
	"Вот же, смотрите.",
	"Билет при мне.",
	"Держите, проверяйте.",
]

const LINES_NO_TICKET := [
	"Ну… билета нет.",
	"Не могу найти…",
	"Потерял, наверное.",
	"Нет его у меня.",
]

const LINES_SOLD := [
	"Ладно, плачу.",
	"Ок, беру.",
	"Ну раз надо…",
	"Держите тогда.",
]

const LINES_SCANDAL := [
	"Да вы что! Я не буду платить дважды!",
	"Это произвол! Не трогайте меня!",
	"Какой ещё билет?! Отстаньте!",
	"Скандал устроите — вот и всё!",
	"Сколько можно проверять?!",
]

const LINES_COPS_CAUGHT := [
	"Ладно, ладно… не платил.",
	"Эх… попался.",
]

const LINES_LEAVE := [
	"Ну и ладно.",
	"…",
	"Счастливо.",
]

const LINES_REFUSE_PAY := [
	"Нет денег у меня!",
	"Не буду платить, сказал же.",
	"Да отстаньте, не плачу.",
]

@export var sprite_scale: float = 0.18
@export var lifetime_min_sec: float = 60.0
@export var lifetime_max_sec: float = 120.0
@export var speech_duration_sec: float = 2.6
## Шанс потерять билет после того, как оплатил тебе.
@export var lose_ticket_chance: float = 0.25
## Шанс, что не плативший заплатит при «Настоять».
@export var insist_pay_chance: float = 0.5

var seat: Seat = null
var kind: Kind = Kind.PAID
var claims_paid: bool = false
## Реально заплатил кондуктору (не враньё).
var paid_to_conductor: bool = false
## Может показать билет при «Потребовать».
var can_show_ticket: bool = false
## Игрок подтвердил оплату (для +8 повторного запроса).
var verified: bool = false
## Сколько раз подходили с E (1 = первый контакт, 3 = вторая проверка…).
var visit_count: int = 0
## Терминальное состояние (поймали / game over path).
var check_done: bool = false

var _lifetime_left: float = 0.0
var _nearby_conductor: Conductor = null
var _speech_timer: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _speech: Label = $Speech


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_sprite.modulate = Color.WHITE
	_lifetime_left = randf_range(lifetime_min_sec, lifetime_max_sec)
	if _speech:
		_speech.visible = false
	add_to_group("passengers")


func _process(delta: float) -> void:
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		despawn(false)
		return
	if _speech_timer > 0.0:
		_speech_timer -= delta
		if _speech_timer <= 0.0 and _speech:
			_speech.visible = false


func setup(on_seat: Seat) -> void:
	seat = on_seat
	var sit := on_seat.get_sit_global_position()
	var stand := on_seat.get_stand_global_position()
	global_position = sit
	$CollisionShape2D.position = (stand - sit) * 0.55
	var sprite := _sprite if _sprite != null else get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.flip_h = not on_seat.facing_right
		sprite.scale = Vector2(sprite_scale, sprite_scale)
		sprite.modulate = Color.WHITE
	z_as_relative = false
	z_index = 2 if on_seat.row == Seat.Row.BOTTOM else 0
	on_seat.set_passenger(self)


## Не платил тебе → при первом подходе билета быть не может (может только врать).
func is_dodger() -> bool:
	return not paid_to_conductor


## Шанс скандала при «Потребовать»: 3-й визит 50%, 4+ — 90%.
func scandal_chance_on_demand() -> float:
	if visit_count >= 4:
		return 0.9
	if visit_count >= 3:
		return 0.5
	return 0.0


## "done" | "paid" | "claim"
func on_interact() -> String:
	if check_done:
		return "done"
	visit_count += 1
	# Уже платил тебе — «уже оплатил» + меню.
	if paid_to_conductor:
		claims_paid = true
		say(_pick(LINES_CLAIM))
		return "claim"
	# Первый контакт по типу.
	if kind == Kind.PAID:
		collect_fare()
		return "paid"
	claims_paid = true
	say(_pick(LINES_CLAIM))
	return "claim"


func collect_fare() -> void:
	paid_to_conductor = true
	_roll_keeps_ticket()
	say(_pick(LINES_PAY))
	ticketed.emit(self)
	outcome.emit("paid_ok", self)


func _roll_keeps_ticket() -> void:
	# Часть честно потеряет билет к следующей проверке.
	can_show_ticket = randf() >= lose_ticket_chance


func say_show_ticket() -> void:
	say(_pick(LINES_SHOW_TICKET))


func say_no_ticket() -> void:
	say(_pick(LINES_NO_TICKET))


func say_scandal() -> void:
	say(_pick(LINES_SCANDAL))


func rolls_insist_pays() -> bool:
	return randf() < insist_pay_chance


func say_refuse_pay() -> void:
	say(_pick(LINES_REFUSE_PAY))


func mark_sold() -> void:
	paid_to_conductor = true
	verified = true
	_roll_keeps_ticket()
	say(_pick(LINES_SOLD))
	ticketed.emit(self)
	outcome.emit("sold_ticket", self)


func mark_caught_dodger() -> void:
	check_done = true
	say(_pick(LINES_COPS_CAUGHT))
	outcome.emit("caught_dodger", self)
	# Копы уводят — пассажир исчезает с локации.
	despawn(true)


func mark_wrong_arrest() -> void:
	check_done = true
	outcome.emit("wrong_arrest", self)


func mark_dodger_escaped() -> void:
	check_done = true
	say(_pick(LINES_LEAVE))
	outcome.emit("dodger_escaped", self)


func mark_soft_leave() -> void:
	say(_pick(LINES_LEAVE))
	outcome.emit("honest_ok", self)


func mark_verified_ok() -> void:
	# Не закрываем насовсем — можно вернуться (3-й / 4-й визит).
	verified = true
	outcome.emit("verified_ok", self)


func say(text: String) -> void:
	if _speech == null:
		return
	_speech.text = text
	_speech.visible = true
	_speech_timer = speech_duration_sec


func _pick(lines: Array) -> String:
	if lines.is_empty():
		return ""
	return lines[randi() % lines.size()]


func despawn(_ended_by_player: bool = false) -> void:
	if seat and is_instance_valid(seat):
		seat.clear_passenger(self)
	if _nearby_conductor:
		_nearby_conductor.unregister_nearby_passenger(self)
		_nearby_conductor = null
	removed.emit(self)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Conductor:
		_nearby_conductor = body as Conductor
		_nearby_conductor.register_nearby_passenger(self)


func _on_body_exited(body: Node2D) -> void:
	if body is Conductor and _nearby_conductor == body:
		_nearby_conductor.unregister_nearby_passenger(self)
		_nearby_conductor = null
