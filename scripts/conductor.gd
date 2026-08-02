class_name Conductor
extends CharacterBody2D

## Ходьба кондуктора по проходу вагона (WASD / стрелки).
## Посадка: E у свободного сиденья. Вставание: E или WASD (после отпускания клавиш).
## Пассажир: первое E = обилечить; меню только если заявил «уже оплатил».

@export var speed: float = 280.0
@export var frames_per_cycle: int = 20
## Длина шага (px за один gait-цикл). Больше = шире шаг, ноги не семенят.
@export var stride_distance: float = 200.0
@export var min_walk_fps: float = 8.0
@export var max_walk_fps: float = 96.0
## Экранный размер ≈ 512px * sprite_scale. 0.5 → ~256px.
@export var sprite_scale: float = 0.5
@export var sit_fps: float = 24.0

@export_group("Idle")
@export var idle_afk_anim: StringName = &"idle_afk"
@export var idle_fidget_anims: Array[StringName] = [
	&"idle_first",
	&"idle_steps",
	&"idle_neck",
	&"idle_round_neck",
]
## FPS idle-fidgets: ближе к walk (~28), иначе на 12 FPS выглядит дёргано.
@export var idle_fidget_fps: float = 28.0
@export var idle_fidget_min_sec: float = 6.0
@export var idle_fidget_max_sec: float = 14.0

enum AnimState {
	IDLE_AFK,
	IDLE_FIDGET,
	WALK,
	SITTING_DOWN,
	SEATED,
	STANDING_UP,
}

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _action_menu: ActionMenu = get_node_or_null("/root/Main/ActionMenu")

var _anim_state: AnimState = AnimState.IDLE_AFK
var _base_speed_scale: float = 1.0
var _fidget_timer: float = 0.0
var _nearby_seats: Array[Seat] = []
var _nearby_passengers: Array[Passenger] = []
var _current_seat: Seat = null
## После посадки ждём отпускания WASD, иначе удержание сразу рвёт sit.
var _seat_await_release: bool = false
var _pending_passenger: Passenger = null
var _standing_time: float = 0.0

enum CheckPhase { NONE, CLAIM, AFTER_LOST, AFTER_SCANDAL }
var _check_phase: CheckPhase = CheckPhase.NONE


func _ready() -> void:
	add_to_group("conductor")
	_base_speed_scale = _sprite.speed_scale
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_sprite.animation_finished.connect(_on_animation_finished)
	# Слой прохода: над дальним рядом (0), под ближним (2).
	z_as_relative = false
	z_index = 1
	_enter_idle_afk()


func on_shift_start() -> void:
	_standing_time = 0.0
	_clear_check()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_apply_passive_stress(delta)
	match _anim_state:
		AnimState.SITTING_DOWN, AnimState.STANDING_UP:
			velocity = Vector2.ZERO
			if (
				_anim_state == AnimState.STANDING_UP
				and _sprite.animation == &"sit_down"
				and _sprite.frame <= 0
				and not _sprite.is_playing()
			):
				_finish_stand_up()
			move_and_slide()
			return
		AnimState.SEATED:
			velocity = Vector2.ZERO
			_update_seat_release_gate()
			if not _seat_await_release and _wants_stand_by_move():
				_begin_stand_up()
			move_and_slide()
			return
		_:
			pass

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var wants_move := direction.length_squared() > 0.0001

	if wants_move:
		velocity = direction * speed
		_start_walk(direction)
		_sync_walk_fps(velocity.length())
	else:
		velocity = Vector2.ZERO
		if _anim_state == AnimState.WALK:
			_enter_idle_afk()
		elif _anim_state == AnimState.IDLE_AFK:
			_tick_fidget_timer(delta)

	move_and_slide()


func register_nearby_seat(seat: Seat) -> void:
	if seat not in _nearby_seats:
		_nearby_seats.append(seat)


func unregister_nearby_seat(seat: Seat) -> void:
	_nearby_seats.erase(seat)


func register_nearby_passenger(passenger: Passenger) -> void:
	if passenger not in _nearby_passengers:
		_nearby_passengers.append(passenger)


func unregister_nearby_passenger(passenger: Passenger) -> void:
	_nearby_passengers.erase(passenger)
	if _pending_passenger == passenger:
		_clear_check()


func _is_move_held() -> bool:
	return (
		Input.is_action_pressed("move_left")
		or Input.is_action_pressed("move_right")
		or Input.is_action_pressed("move_up")
		or Input.is_action_pressed("move_down")
	)


func _wants_stand_by_move() -> bool:
	return (
		Input.is_action_just_pressed("move_left")
		or Input.is_action_just_pressed("move_right")
		or Input.is_action_just_pressed("move_up")
		or Input.is_action_just_pressed("move_down")
	)


func _update_seat_release_gate() -> void:
	if not _seat_await_release:
		return
	if not _is_move_held():
		_seat_await_release = false


func _nearest_free_seat() -> Seat:
	var best: Seat = null
	var best_d := INF
	for seat in _nearby_seats:
		if seat == null or not is_instance_valid(seat) or not seat.is_free_for_player():
			continue
		var d := global_position.distance_squared_to(seat.global_position)
		if d < best_d:
			best_d = d
			best = seat
	return best


func _nearest_passenger() -> Passenger:
	var best: Passenger = null
	var best_d := INF
	for p in _nearby_passengers:
		if p == null or not is_instance_valid(p):
			continue
		var d := global_position.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _try_interact() -> void:
	match _anim_state:
		AnimState.SEATED:
			if not _seat_await_release:
				_begin_stand_up()
		AnimState.SITTING_DOWN, AnimState.STANDING_UP:
			pass
		_:
			# Приоритет: пассажир, потом свободное сиденье.
			var passenger := _nearest_passenger()
			if passenger:
				_check_passenger(passenger)
				return
			var seat := _nearest_free_seat()
			if seat:
				_begin_sit_down(seat)


func _apply_passive_stress(delta: float) -> void:
	var b := StressSystem.balance
	if b == null:
		return
	if _anim_state == AnimState.SEATED:
		_standing_time = 0.0
		StressSystem.add_fill(-b.sit_recover * delta)
	else:
		_standing_time += delta
		# Включая меню — стоишь, усталость капает.
		StressSystem.add_fill(b.stand_fatigue * delta)


func _check_passenger(p: Passenger) -> void:
	if _pending_passenger != null or _check_phase != CheckPhase.NONE:
		return
	match p.on_interact():
		"paid":
			StressSystem.add_fill(StressSystem.balance.calm_ticket)
		"done":
			pass
		"claim":
			_pending_passenger = p
			_check_phase = CheckPhase.CLAIM
			_ensure_menu_connected()
			_open_claim_menu(p)


func _ensure_menu_connected() -> void:
	if _action_menu and not _action_menu.action_chosen.is_connected(_on_action_chosen):
		_action_menu.action_chosen.connect(_on_action_chosen)


func _passenger_screen_pos(p: Passenger) -> Vector2:
	return get_viewport().get_canvas_transform() * p.global_position


func _open_claim_menu(p: Passenger) -> void:
	if _action_menu == null:
		return
	_action_menu.open_choices(_passenger_screen_pos(p), [
		{"id": "demand", "text": "Потребовать билет"},
		{"id": "insist", "text": "Настоять на оплате"},
		{"id": "leave", "text": "Уйти"},
	])


func _open_after_lost_menu(p: Passenger) -> void:
	if _action_menu == null:
		return
	_action_menu.open_choices(_passenger_screen_pos(p), [
		{"id": "cops", "text": "Вызвать копов"},
		{"id": "leave", "text": "Уйти"},
	])


func _open_scandal_menu(p: Passenger) -> void:
	if _action_menu == null:
		return
	_action_menu.open_choices(_passenger_screen_pos(p), [
		{"id": "cops", "text": "Вызвать копов"},
		{"id": "leave", "text": "Уйти"},
	])


func _on_action_chosen(action: String) -> void:
	var p := _pending_passenger
	if p == null or not is_instance_valid(p):
		_clear_check()
		return

	match _check_phase:
		CheckPhase.CLAIM:
			match action:
				"demand":
					_resolve_demand(p)
				"insist":
					_resolve_insist(p)
				"leave":
					_resolve_leave(p)
				_:
					_clear_check()
		CheckPhase.AFTER_LOST, CheckPhase.AFTER_SCANDAL:
			match action:
				"cops":
					_resolve_cops(p)
				"leave":
					_resolve_leave(p)
				_:
					_clear_check()
		_:
			_clear_check()


func _resolve_demand(p: Passenger) -> void:
	# 3-й визит — 50% скандал, 4+ — 90%.
	var scandal_p := p.scandal_chance_on_demand()
	if scandal_p > 0.0 and randf() < scandal_p:
		p.say_scandal()
		_check_phase = CheckPhase.AFTER_SCANDAL
		_open_scandal_menu(p)
		return
	if p.can_show_ticket:
		p.say_show_ticket()
		if p.verified:
			StressSystem.add_fill(StressSystem.balance.repeat_ask)
		p.mark_verified_ok()
		_finish_success("Всё правильно — билет на месте")
		return
	p.say_no_ticket()
	StressSystem.add_fill(StressSystem.balance.refuse)
	_check_phase = CheckPhase.AFTER_LOST
	_open_after_lost_menu(p)


func _resolve_insist(p: Passenger) -> void:
	if p.paid_to_conductor:
		if p.can_show_ticket:
			p.say_show_ticket()
			p.mark_verified_ok()
			StressSystem.add_fill(StressSystem.balance.insist_right)
			_finish_success("Всё правильно — уже был обилечен")
		else:
			p.say_scandal()
			_check_phase = CheckPhase.AFTER_SCANDAL
			_open_scandal_menu(p)
		return
	# Не платил тебе. Настоять = шанс, что заплатит.
	if p.rolls_insist_pays():
		p.mark_sold()
		StressSystem.add_fill(StressSystem.balance.insist_right)
		_finish_success("Всё правильно — заставил заплатить")
	else:
		p.say_refuse_pay()
		_check_phase = CheckPhase.AFTER_SCANDAL
		_open_scandal_menu(p)


func _resolve_cops(p: Passenger) -> void:
	StressSystem.add_fill(StressSystem.balance.police)
	if p.is_dodger():
		p.mark_caught_dodger()
		StressSystem.add_fill(StressSystem.balance.catch_dodger)
		_finish_success("Всё правильно — поймали зайца")
	else:
		p.mark_wrong_arrest()
		StressSystem.add_fill(StressSystem.balance.wrong_arrest)
		_finish_notice("Копы на человека, который уже платил")


func _resolve_leave(p: Passenger) -> void:
	var from_scandal := _check_phase == CheckPhase.AFTER_SCANDAL
	if p.is_dodger():
		p.mark_dodger_escaped()
		StressSystem.add_fill(StressSystem.balance.dodger_escaped)
		_finish_notice("Заяц проехал бесплатно")
	else:
		if from_scandal:
			StressSystem.add_fill(StressSystem.balance.scandal_leave)
		p.mark_soft_leave()
		_finish_success("Всё правильно — отпустили")


func _flow() -> Node:
	return get_tree().get_first_node_in_group("game_flow")


func _finish_success(text: String) -> void:
	_clear_check()
	var flow := _flow()
	if flow and flow.has_method("show_success"):
		flow.show_success(text)


func _finish_notice(text: String) -> void:
	_clear_check()
	var flow := _flow()
	if flow and flow.has_method("show_notice"):
		flow.show_notice(text)
	elif flow and flow.has_method("show_success"):
		flow.show_success(text)


func _clear_check() -> void:
	_pending_passenger = null
	_check_phase = CheckPhase.NONE
	if _action_menu:
		_action_menu.close()


func _begin_sit_down(seat: Seat) -> void:
	_current_seat = seat
	seat.occupied_by_player = true
	_fidget_timer = 0.0
	_seat_await_release = true
	_anim_state = AnimState.SITTING_DOWN

	velocity = Vector2.ZERO
	global_position = seat.get_sit_global_position()
	_collision.set_deferred("disabled", true)
	z_index = 2 if seat.row == Seat.Row.BOTTOM else 0

	_reset_sprite_scale()
	_sprite.flip_h = not seat.facing_right
	_sprite.speed_scale = absf(_base_speed_scale)
	if _sprite.sprite_frames:
		_sprite.sprite_frames.set_animation_speed(&"sit_down", sit_fps)
	_sprite.play(&"sit_down")


func _begin_stand_up() -> void:
	if _anim_state != AnimState.SEATED and _anim_state != AnimState.SITTING_DOWN:
		return
	_anim_state = AnimState.STANDING_UP
	_seat_await_release = false
	_reset_sprite_scale()
	if _sprite.sprite_frames:
		_sprite.sprite_frames.set_animation_speed(&"sit_down", sit_fps)
	var last_frame := 0
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"sit_down"):
		last_frame = maxi(_sprite.sprite_frames.get_frame_count(&"sit_down") - 1, 0)
	_sprite.speed_scale = -absf(_base_speed_scale)
	_sprite.play(&"sit_down")
	_sprite.set_frame_and_progress(last_frame, 0.0)


func _finish_stand_up() -> void:
	var stand_pos := global_position
	if _current_seat and is_instance_valid(_current_seat):
		stand_pos = _current_seat.get_stand_global_position()
		_current_seat.occupied_by_player = false
	_current_seat = null

	_sprite.speed_scale = absf(_base_speed_scale)
	_collision.set_deferred("disabled", false)
	global_position = stand_pos
	z_index = 1
	_enter_idle_afk()


func _reset_sprite_scale() -> void:
	_sprite.scale = Vector2(sprite_scale, sprite_scale)


func _sync_walk_fps(move_speed: float) -> void:
	if _sprite.sprite_frames == null:
		return
	var dist := maxf(stride_distance, 1.0)
	var cycles_per_second := move_speed / dist
	var fps := cycles_per_second * float(maxi(frames_per_cycle, 1))
	fps = clampf(fps, min_walk_fps, max_walk_fps)
	_sprite.sprite_frames.set_animation_speed(&"walk", fps)
	_sprite.speed_scale = absf(_base_speed_scale)


func _start_walk(direction: Vector2) -> void:
	_anim_state = AnimState.WALK
	_fidget_timer = 0.0
	_reset_sprite_scale()
	_sprite.speed_scale = absf(_base_speed_scale)
	if _sprite.animation != &"walk" or not _sprite.is_playing():
		_sprite.play(&"walk")
	if absf(direction.x) > 0.1:
		_sprite.flip_h = direction.x < 0.0


func _enter_idle_afk() -> void:
	_anim_state = AnimState.IDLE_AFK
	_sprite.speed_scale = absf(_base_speed_scale)
	_reset_sprite_scale()
	_sprite.play(idle_afk_anim)
	_sprite.pause()
	_schedule_next_fidget()


func _schedule_next_fidget() -> void:
	var lo := minf(idle_fidget_min_sec, idle_fidget_max_sec)
	var hi := maxf(idle_fidget_min_sec, idle_fidget_max_sec)
	_fidget_timer = randf_range(lo, hi)


func _tick_fidget_timer(delta: float) -> void:
	if idle_fidget_anims.is_empty():
		return
	_fidget_timer -= delta
	if _fidget_timer <= 0.0:
		_play_random_fidget()


func _play_random_fidget() -> void:
	var available: Array[StringName] = []
	for anim_name in idle_fidget_anims:
		if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim_name):
			available.append(anim_name)
	if available.is_empty():
		_schedule_next_fidget()
		return

	var pick: StringName = available[randi() % available.size()]
	_anim_state = AnimState.IDLE_FIDGET
	_sprite.speed_scale = absf(_base_speed_scale)
	_reset_sprite_scale()
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(pick):
		_sprite.sprite_frames.set_animation_speed(pick, idle_fidget_fps)
	# idle_neck нарисован влево — зеркалим под остальные idle (вправо).
	if pick == &"idle_neck":
		_sprite.flip_h = true
	else:
		# Остальные idle смотрят вправо; не тащим flip от walk/neck.
		_sprite.flip_h = false
	_sprite.play(pick)


func _on_animation_finished() -> void:
	match _anim_state:
		AnimState.IDLE_FIDGET:
			_enter_idle_afk()
		AnimState.SITTING_DOWN:
			_anim_state = AnimState.SEATED
			_sprite.pause()
			_seat_await_release = true
		AnimState.STANDING_UP:
			_finish_stand_up()
		_:
			pass
