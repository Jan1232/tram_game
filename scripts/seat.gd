class_name Seat
extends Area2D

## Сиденье: спрайт стула + твёрдый блокер + зона E со стороны прохода.

enum Row { TOP, BOTTOM }

@export var facing_right: bool = true
@export var row: Row = Row.TOP
@export var seat_size: float = 72.0
## Высота спрайта стула в мире; подгоняется под рост ГГ.
@export var chair_height: float = 120.0
## Центр подушки в пикселях исходного SVG (viewBox 79×141).
@export var chair_seat_pixel: Vector2 = Vector2(40, 88)
## Смещение точки посадки относительно подушки (к спинке / на сидушку).
@export var sit_point_offset: Vector2 = Vector2(-10, 4)
## Место кондуктора: только ГГ, NPC не спавнятся.
@export var conductor_only: bool = false
@export var chair_texture: Texture2D

const CHAIR_ART_SIZE := Vector2(79.0, 141.0)

var occupied_by_player: bool = false:
	set(value):
		occupied_by_player = value
		_update_conductor_hint_visible()

var passenger: Passenger = null
var _conductor_hint: Polygon2D = null

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
		var tex_h := float(chair_texture.get_height())
		var s := chair_height / maxf(tex_h, 1.0)
		_visual.scale = Vector2(s, s)
		_visual.flip_h = not facing_right
		_visual.flip_v = false
		_visual.modulate = Color.WHITE

		# Сдвигаем спрайт так, чтобы центр подушки совпал с origin узла (= sit_point).
		var seat_px := Vector2(
			chair_seat_pixel.x / CHAIR_ART_SIZE.x * tex_w,
			chair_seat_pixel.y / CHAIR_ART_SIZE.y * tex_h
		)
		var from_center := seat_px - Vector2(tex_w, tex_h) * 0.5
		if _visual.flip_h:
			from_center.x = -from_center.x
		_visual.position = -from_center * s

	_setup_conductor_hint()

	# Твёрдое тело = зона сиденья (не весь высокий спрайт).
	if _blocker_shape.shape is RectangleShape2D:
		(_blocker_shape.shape as RectangleShape2D).size = Vector2(seat_size, seat_size)

	# Зона E: сиденье + проход + подход спереди (раньше зона была только со стороны прохода).
	var aisle_shift := seat_size * 0.25
	if _interact.shape is RectangleShape2D:
		(_interact.shape as RectangleShape2D).size = Vector2(seat_size * 2.2, seat_size * 1.9)
	if row == Row.BOTTOM:
		_interact.position = Vector2(0, -aisle_shift)
	else:
		_interact.position = Vector2(0, aisle_shift)


func _setup_conductor_hint() -> void:
	if _conductor_hint and is_instance_valid(_conductor_hint):
		_conductor_hint.queue_free()
		_conductor_hint = null
	if not conductor_only:
		return

	# Круг на полу со стороны прохода — не под непрозрачным спрайтом стула.
	var hint := Polygon2D.new()
	hint.name = "ConductorHint"
	hint.z_as_relative = true
	hint.z_index = -1
	var aisle_dir := -1.0 if row == Row.BOTTOM else 1.0
	hint.position = Vector2(0.0, aisle_dir * seat_size * 0.55)
	var radius := seat_size * 0.7
	var pts := PackedVector2Array()
	const SEGMENTS := 28
	for i in SEGMENTS:
		var a := TAU * float(i) / float(SEGMENTS)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	hint.polygon = pts
	hint.color = Color(1.0, 1.0, 1.0, 0.35)
	add_child(hint)
	move_child(hint, 0)
	_conductor_hint = hint
	_update_conductor_hint_visible()


func _update_conductor_hint_visible() -> void:
	if _conductor_hint and is_instance_valid(_conductor_hint):
		_conductor_hint.visible = conductor_only and not occupied_by_player


func _setup_points() -> void:
	var aisle_offset := seat_size * 0.85
	sit_point.position = sit_point_offset
	if row == Row.BOTTOM:
		stand_point.position = Vector2(0, -aisle_offset)
	else:
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
