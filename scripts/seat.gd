class_name Seat
extends Area2D

## Сиденье: спрайт стула + твёрдый блокер + зона E со стороны прохода.

enum Row { TOP, BOTTOM }

@export var facing_right: bool = true
@export var row: Row = Row.TOP
@export var seat_size: float = 72.0
## Место кондуктора: только ГГ, NPC не спавнятся.
@export var conductor_only: bool = false
@export var chair_texture: Texture2D

var occupied_by_player: bool = false
var passenger: Passenger = null

@onready var sit_point: Marker2D = $SitPoint
@onready var stand_point: Marker2D = $StandPoint
@onready var _visual: Sprite2D = $Visual
@onready var _interact: CollisionShape2D = $CollisionShape2D
@onready var _blocker_shape: CollisionShape2D = $Blocker/CollisionShape2D


func _ready() -> void:
	add_to_group("seats")
	# Дальний ряд под ГГ (1), ближний — над ГГ.
	z_as_relative = false
	z_index = 2 if row == Row.BOTTOM else 0
	_setup_visual()
	_setup_points()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1


func _setup_visual() -> void:
	if chair_texture == null:
		chair_texture = load("res://assets/texture/tram/chair.svg") as Texture2D
	if chair_texture:
		_visual.texture = chair_texture
		var tex_w := float(chair_texture.get_width())
		# Масштаб по ширине seat_size; высота остаётся пропорциональной (~1.8×).
		var s := seat_size / maxf(tex_w, 1.0)
		_visual.scale = Vector2(s, s)
		_visual.flip_h = not facing_right
		# Верхний ряд: зеркало по вертикали — спинка к стене, сиденье к проходу.
		_visual.flip_v = row == Row.TOP
		# Место кондуктора чуть теплее, чтобы отличать.
		_visual.modulate = Color(1.12, 0.92, 0.78, 1.0) if conductor_only else Color.WHITE

	# Твёрдое тело = зона сиденья (не весь высокий спрайт).
	if _blocker_shape.shape is RectangleShape2D:
		(_blocker_shape.shape as RectangleShape2D).size = Vector2(seat_size, seat_size)

	# Зона E чуть со стороны прохода, чтобы не нужно было заходить на квадрат.
	var aisle_shift := seat_size * 0.45
	if _interact.shape is RectangleShape2D:
		(_interact.shape as RectangleShape2D).size = Vector2(seat_size + 20.0, seat_size * 0.7)
	if row == Row.BOTTOM:
		_interact.position = Vector2(0, -aisle_shift)
	else:
		_interact.position = Vector2(0, aisle_shift)


func _setup_points() -> void:
	var aisle_offset := seat_size * 0.85
	if row == Row.BOTTOM:
		sit_point.position = Vector2(0, 8)
		stand_point.position = Vector2(0, -aisle_offset)
	else:
		sit_point.position = Vector2(0, -8)
		stand_point.position = Vector2(0, aisle_offset)


func get_sit_global_position() -> Vector2:
	return sit_point.global_position


func get_stand_global_position() -> Vector2:
	return stand_point.global_position


func is_blocked_for_passenger() -> bool:
	return conductor_only or occupied_by_player or passenger != null


func is_free_for_player() -> bool:
	# ГГ садится только на своё место кондуктора.
	return conductor_only and not occupied_by_player and passenger == null


func set_passenger(p: Passenger) -> void:
	if conductor_only:
		return
	passenger = p


func clear_passenger(p: Passenger) -> void:
	if passenger == p:
		passenger = null


func _on_body_entered(body: Node2D) -> void:
	if body is Conductor:
		(body as Conductor).register_nearby_seat(self)


func _on_body_exited(body: Node2D) -> void:
	if body is Conductor:
		(body as Conductor).unregister_nearby_seat(self)
