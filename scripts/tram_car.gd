extends Node2D

## Прототип коридора: длина = 1.2 ширины экрана, сиденья = жёлтые квадраты.

const SCREEN_W := 1920.0
const SCREEN_H := 1080.0
const LENGTH_SCALE := 1.2
const CORRIDOR_H := 280.0
const WALL := 40.0
const SEAT_SIZE := 56.0
const SEATS_PER_ROW := 8
## Пустые зоны у торцов коридора под будущие входы.
const ENTRANCE_ZONE := 420.0

@onready var _floor: Node2D = $Floor
@onready var _walls: StaticBody2D = $Walls
@onready var _seats_root: Node2D = $Seats
@onready var _spawn: Marker2D = $ConductorSpawn

@export var seat_scene: PackedScene
@export var floor_texture: Texture2D


func _ready() -> void:
	if floor_texture == null:
		floor_texture = load("res://assets/texture/tram/new_floor_two.png") as Texture2D
	var corridor_w := SCREEN_W * LENGTH_SCALE
	var y0 := (SCREEN_H - CORRIDOR_H) * 0.5

	_build_floor(corridor_w, y0)
	_build_walls(corridor_w, y0)
	_build_seats(corridor_w, y0)
	_spawn.position = Vector2(220.0, y0 + CORRIDOR_H * 0.5)


func _build_floor(corridor_w: float, y0: float) -> void:
	for child in _floor.get_children():
		child.queue_free()

	if floor_texture == null:
		push_error("TramCar: не задана floor_texture")
		return

	# Высота модуля = 100% коридора, ширина — auto по пропорциям текстуры.
	var tile_w := float(floor_texture.get_width())
	var tile_h := float(floor_texture.get_height())
	var scale_y := CORRIDOR_H / maxf(tile_h, 1.0)
	var draw_w := tile_w * scale_y

	var x := 0.0
	while x < corridor_w - 0.5:
		var spr := Sprite2D.new()
		spr.texture = floor_texture
		spr.centered = false
		spr.position = Vector2(x, y0)
		spr.scale = Vector2(scale_y, scale_y)
		# Обрезаем последний модуль по правому краю коридора.
		var remain := corridor_w - x
		if remain < draw_w:
			var region_w := remain / scale_y
			spr.region_enabled = true
			spr.region_rect = Rect2(0.0, 0.0, region_w, tile_h)
		_floor.add_child(spr)
		x += draw_w


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

	# Края коридора свободны (входы). Все сиденья — равномерно на оставшемся отрезке.
	var first_x := ENTRANCE_ZONE
	var last_x := corridor_w - ENTRANCE_ZONE
	var step := (last_x - first_x) / float(SEATS_PER_ROW - 1)
	var top_y := y0 + SEAT_SIZE * 0.85
	var bottom_y := y0 + CORRIDOR_H - SEAT_SIZE * 0.85

	for i in SEATS_PER_ROW:
		var x := first_x + step * float(i)
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
