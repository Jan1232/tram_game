class_name PassengerDirector
extends Node

## Спавн/респавн по текущей полосе DayManager (наплыв).

@export var passenger_scene: PackedScene
@export var day_manager: DayManager
## Фолбэк, если DayManager ещё не отдал полосу.
@export var fallback_min_passengers: int = 2
@export var fallback_max_passengers: int = 5
@export var fallback_respawn_min: float = 10.0
@export var fallback_respawn_max: float = 15.0

var _alive: Array[Passenger] = []
var _respawn_queue: Array[float] = []
var _suppress_respawn: bool = false


func _ready() -> void:
	if passenger_scene == null:
		push_error("PassengerDirector: не задана passenger_scene")
		return
	if day_manager == null:
		day_manager = get_node_or_null("../DayManager") as DayManager
	if day_manager:
		day_manager.band_changed.connect(_on_band_changed)
	else:
		# Без DayManager — старый режим.
		call_deferred("_spawn_initial")


func reinit_for_shift() -> void:
	_clear_all()
	_spawn_initial()


func _on_band_changed(_band: DayBand) -> void:
	# Числа читаются лениво; уже сидящие не выгоняются.
	pass


func _band() -> DayBand:
	if day_manager:
		return day_manager.current_band()
	return null


func _min_passengers() -> int:
	var b := _band()
	return b.min_passengers if b else fallback_min_passengers


func _max_passengers() -> int:
	var b := _band()
	return b.max_passengers if b else fallback_max_passengers


func _respawn_min() -> float:
	var b := _band()
	return b.respawn_min if b else fallback_respawn_min


func _respawn_max() -> float:
	var b := _band()
	return b.respawn_max if b else fallback_respawn_max


func _spawn_initial() -> void:
	var count := randi_range(_min_passengers(), _max_passengers())
	for _i in count:
		_spawn_one()


func _process(delta: float) -> void:
	for i in range(_respawn_queue.size() - 1, -1, -1):
		_respawn_queue[i] -= delta
		if _respawn_queue[i] <= 0.0:
			_respawn_queue.remove_at(i)
			_spawn_one()

	while _alive.size() + _respawn_queue.size() < _min_passengers():
		_queue_respawn()


func _spawn_one() -> void:
	if _alive.size() >= _max_passengers():
		return
	var seat := _pick_free_seat()
	if seat == null:
		_queue_respawn()
		return

	var p: Passenger = passenger_scene.instantiate() as Passenger
	p.removed.connect(_on_passenger_removed)
	_assign_kind(p)
	_alive.append(p)
	seat.set_passenger(p)
	get_parent().add_child(p)
	p.setup(seat)
	print("spawn passenger kind=", Passenger.Kind.keys()[p.kind])


func _assign_kind(p: Passenger) -> void:
	if randf() < 0.7:
		p.kind = Passenger.Kind.PAID
	else:
		p.kind = Passenger.Kind.LIED


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
	if _alive.size() + _respawn_queue.size() >= _max_passengers():
		return
	_respawn_queue.append(randf_range(_respawn_min(), _respawn_max()))


func _on_passenger_removed(passenger: Passenger) -> void:
	_alive.erase(passenger)
	if not _suppress_respawn:
		_queue_respawn()


func _clear_all() -> void:
	_suppress_respawn = true
	_respawn_queue.clear()
	for p in _alive.duplicate():
		if is_instance_valid(p):
			p.despawn(false)
	_alive.clear()
	_suppress_respawn = false
