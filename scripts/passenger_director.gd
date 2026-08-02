class_name PassengerDirector
extends Node

## Держит 2–5 пассажиров на свободных сиденьях, респавн после ухода.

@export var passenger_scene: PackedScene
@export var min_passengers: int = 2
@export var max_passengers: int = 5
@export var respawn_min_sec: float = 10.0
@export var respawn_max_sec: float = 15.0

var _alive: Array[Passenger] = []
var _respawn_queue: Array[float] = []
var _game_over: bool = false


func _ready() -> void:
	if passenger_scene == null:
		push_error("PassengerDirector: не задана passenger_scene")
		return
	# Нельзя add_child во время разворачивания дерева Main.
	call_deferred("_spawn_initial")


func _spawn_initial() -> void:
	var count := randi_range(min_passengers, max_passengers)
	for _i in count:
		_spawn_one()


func _process(delta: float) -> void:
	if _game_over:
		return
	for i in range(_respawn_queue.size() - 1, -1, -1):
		_respawn_queue[i] -= delta
		if _respawn_queue[i] <= 0.0:
			_respawn_queue.remove_at(i)
			_spawn_one()

	while _alive.size() + _respawn_queue.size() < min_passengers:
		_queue_respawn()


func _spawn_one() -> void:
	if _alive.size() >= max_passengers:
		return
	var seat := _pick_free_seat()
	if seat == null:
		_queue_respawn()
		return

	var p: Passenger = passenger_scene.instantiate() as Passenger
	p.removed.connect(_on_passenger_removed)
	p.game_end_requested.connect(_on_game_end)
	_alive.append(p)
	# Резервируем место до входа в дерево.
	seat.set_passenger(p)
	get_parent().add_child(p)
	p.setup(seat)


func _pick_free_seat() -> Seat:
	var free: Array[Seat] = []
	for node in get_tree().get_nodes_in_group("seats"):
		if node is Seat:
			var s := node as Seat
			if not s.is_blocked_for_passenger():
				free.append(s)
	if free.is_empty():
		return null
	return free[randi() % free.size()]


func _queue_respawn() -> void:
	if _alive.size() + _respawn_queue.size() >= max_passengers:
		return
	_respawn_queue.append(randf_range(respawn_min_sec, respawn_max_sec))


func _on_passenger_removed(passenger: Passenger) -> void:
	_alive.erase(passenger)
	if _game_over:
		return
	_queue_respawn()


func _on_game_end(_passenger: Passenger) -> void:
	_game_over = true
	_respawn_queue.clear()
	get_tree().call_group("game_flow", "on_passenger_game_end")
