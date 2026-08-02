extends Node2D

## Прототип коридора: длина = 1.2 ширины экрана, сиденья = жёлтые квадраты.

const SCREEN_W := 1920.0
const SCREEN_H := 1080.0
const LENGTH_SCALE := 1.2
const CORRIDOR_H := 280.0
const WALL := 40.0
const SEAT_SIZE := 56.0
const SEATS_PER_ROW := 8

@onready var _floor: Polygon2D = $Floor
@onready var _walls: StaticBody2D = $Walls
@onready var _seats_root: Node2D = $Seats
@onready var _spawn: Marker2D = $ConductorSpawn

@export var seat_scene: PackedScene


func _ready() -> void:
	var corridor_w := SCREEN_W * LENGTH_SCALE
	var y0 := (SCREEN_H - CORRIDOR_H) * 0.5

	_build_floor(corridor_w, y0)
	_build_walls(corridor_w, y0)
	_build_seats(corridor_w, y0)
	_spawn.position = Vector2(220.0, y0 + CORRIDOR_H * 0.5)


func _build_floor(corridor_w: float, y0: float) -> void:
	_floor.color = Color(0.18, 0.19, 0.22, 1.0)
	_floor.polygon = PackedVector2Array([
		Vector2(0, y0),
		Vector2(corridor_w, y0),
		Vector2(corridor_w, y0 + CORRIDOR_H),
		Vector2(0, y0 + CORRIDOR_H),
	])


func _build_walls(corridor_w: float, y0: float) -> void:
	# Чистим старые шейпы, если сцена перезапускалась в редакторе.
	for child in _walls.get_children():
		child.queue_free()

	_add_wall_rect(Vector2(corridor_w * 0.5, y0 - WALL * 0.5), Vector2(corridor_w + WALL * 2.0, WALL))
	_add_wall_rect(Vector2(corridor_w * 0.5, y0 + CORRIDOR_H + WALL * 0.5), Vector2(corridor_w + WALL * 2.0, WALL))
	_add_wall_rect(Vector2(-WALL * 0.5, y0 + CORRIDOR_H * 0.5), Vector2(WALL, CORRIDOR_H + WALL * 2.0))
	_add_wall_rect(Vector2(corridor_w + WALL * 0.5, y0 + CORRIDOR_H * 0.5), Vector2(WALL, CORRIDOR_H + WALL * 2.0))


func _add_wall_rect(center: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var node := CollisionShape2D.new()
	node.position = center
	node.shape = shape
	_walls.add_child(node)


func _build_seats(corridor_w: float, y0: float) -> void:
	if seat_scene == null:
		push_error("TramCar: не задана seat_scene")
		return

	for child in _seats_root.get_children():
		child.queue_free()

	var margin_x := 160.0
	var usable := corridor_w - margin_x * 2.0
	var step := usable / float(SEATS_PER_ROW - 1)
	var top_y := y0 + SEAT_SIZE * 0.85
	var bottom_y := y0 + CORRIDOR_H - SEAT_SIZE * 0.85

	for i in SEATS_PER_ROW:
		var x := margin_x + step * float(i)
		_spawn_seat(Vector2(x, top_y), Seat.Row.TOP, false)
		# Нижний левый (первый) — место кондуктора.
		_spawn_seat(Vector2(x, bottom_y), Seat.Row.BOTTOM, i == 0)


func _spawn_seat(pos: Vector2, row: Seat.Row, conductor_only: bool = false) -> void:
	var seat: Seat = seat_scene.instantiate() as Seat
	seat.row = row
	seat.facing_right = true
	seat.seat_size = SEAT_SIZE
	seat.conductor_only = conductor_only
	_seats_root.add_child(seat)
	seat.position = pos


func get_spawn_global_position() -> Vector2:
	return _spawn.global_position
