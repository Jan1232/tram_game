class_name Passenger
extends Area2D

## Заглушка пассажира на сиденье. E: 1-й раз — обилечить, 2-й — убрать и конец игры.

signal ticketed(passenger: Passenger)
signal removed(passenger: Passenger)
signal game_end_requested(passenger: Passenger)

@export var sprite_scale: float = 0.18
@export var lifetime_min_sec: float = 60.0
@export var lifetime_max_sec: float = 120.0

var seat: Seat = null
var is_ticketed: bool = false

var _lifetime_left: float = 0.0
var _nearby_conductor: Conductor = null

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_lifetime_left = randf_range(lifetime_min_sec, lifetime_max_sec)
	add_to_group("passengers")


func _process(delta: float) -> void:
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		despawn(false)


func setup(on_seat: Seat) -> void:
	seat = on_seat
	var sit := on_seat.get_sit_global_position()
	var stand := on_seat.get_stand_global_position()
	global_position = sit
	# Зона E ближе к проходу, спрайт остаётся на сиденье.
	$CollisionShape2D.position = (stand - sit) * 0.55
	var sprite := _sprite if _sprite != null else get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.flip_h = not on_seat.facing_right
		sprite.scale = Vector2(sprite_scale, sprite_scale)
	# Дальний ряд (TOP) под ГГ, ближний (BOTTOM) над ГГ.
	z_as_relative = false
	z_index = 2 if on_seat.row == Seat.Row.BOTTOM else 0
	on_seat.set_passenger(self)


func interact() -> void:
	if is_ticketed:
		game_end_requested.emit(self)
		despawn(true)
		return
	is_ticketed = true
	# Лёгкая визуальная пометка «проверен».
	var sprite := _sprite if _sprite != null else get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.modulate = Color(0.55, 1.0, 0.55, 1.0)
	ticketed.emit(self)


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
