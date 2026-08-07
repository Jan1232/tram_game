extends CanvasLayer

## Параллакс за окнами: город + солнце по дуге + небо по времени смены.
## DayManager.time_changed → солнце/небо. Скорость: set_tram_moving (сейчас 1.0).

const TILE_W := 3072.0

@export var base_speed: float = 90.0
@export var far_tile_w: float = TILE_W
@export var mid_tile_w: float = TILE_W
@export var near_tile_w: float = TILE_W

## Общая линия «земли» (низ спрайта). Подгонка глазом (§5).
@export var ground_y: float = 680.0
@export var far_draw_h: float = 520.0
@export var mid_draw_h: float = 320.0
@export var near_draw_h: float = 360.0
@export var sun_draw_size: float = 96.0

@export var sun_start_pos: Vector2 = Vector2(200, 700)
@export var sun_peak_pos: Vector2 = Vector2(1100, 180)
@export var sun_end_pos: Vector2 = Vector2(1700, 380)

@export var sky_dawn: Color = Color("b8a9a0")
@export var sky_day: Color = Color("aeb7bd")
@export var sky_eve: Color = Color("c2b0a2")

@export var tex_far: Texture2D
@export var tex_mid: Texture2D
@export var tex_near: Texture2D
@export var tex_sun: Texture2D

var _scroll: float = 0.0
var _tram_speed_factor: float = 1.0
var _shift_start_min: float = 300.0
var _shift_end_min: float = 1020.0

@onready var _sky: ColorRect = $Sky
@onready var _sun: Sprite2D = $Sun
@onready var _far: Parallax2D = $ParFar
@onready var _mid: Parallax2D = $ParMid
@onready var _near: Parallax2D = $ParNear
@onready var _far_sprite: Sprite2D = $ParFar/Sprite2D
@onready var _mid_sprite: Sprite2D = $ParMid/Sprite2D
@onready var _near_sprite: Sprite2D = $ParNear/Sprite2D


func _ready() -> void:
	layer = -10
	_setup_textures()
	_setup_parallax()
	_setup_sun()
	call_deferred("_bind_day_manager")
	_update_sky(0.0)
	_on_time_changed(int(_shift_start_min))


func _process(delta: float) -> void:
	_scroll += base_speed * _tram_speed_factor * delta
	# scroll_scale слоёв = 1; параллакс вручную через множители оффсета.
	_far.scroll_offset.x = -_scroll * 0.2
	_mid.scroll_offset.x = -_scroll * 0.6
	_near.scroll_offset.x = -_scroll * 1.2


func set_tram_moving(factor: float) -> void:
	_tram_speed_factor = clampf(factor, 0.0, 1.0)


func _setup_textures() -> void:
	if tex_far == null:
		tex_far = load("res://assets/texture/background/bg_far_city.png") as Texture2D
	if tex_mid == null:
		tex_mid = load("res://assets/texture/background/bg_mid_street.png") as Texture2D
	if tex_near == null:
		tex_near = load("res://assets/texture/background/bg_near_roadside.png") as Texture2D
	if tex_sun == null:
		tex_sun = load("res://assets/texture/background/sun.png") as Texture2D

	_place_layer_sprite(_far_sprite, tex_far, far_draw_h, far_tile_w)
	_place_layer_sprite(_mid_sprite, tex_mid, mid_draw_h, mid_tile_w)
	_place_layer_sprite(_near_sprite, tex_near, near_draw_h, near_tile_w)

	if tex_sun:
		_sun.texture = tex_sun
		var sw := float(tex_sun.get_width())
		var s := sun_draw_size / maxf(sw, 1.0)
		_sun.scale = Vector2(s, s)
		_sun.centered = true


func _place_layer_sprite(spr: Sprite2D, tex: Texture2D, draw_h: float, tile_w: float) -> void:
	if tex == null or spr == null:
		return
	spr.texture = tex
	spr.centered = false
	var th := float(tex.get_height())
	var s := draw_h / maxf(th, 1.0)
	spr.scale = Vector2(s, s)
	# Низ спрайта на ground_y; ширина плитки после масштаба для repeat.
	spr.position = Vector2(0.0, ground_y - draw_h)
	# Обновляем tile width под масштаб (если текстура нативная 3072).
	var scaled_w := tile_w * s
	spr.set_meta("scaled_tile_w", scaled_w)


func _setup_parallax() -> void:
	for node in [_far, _mid, _near]:
		node.ignore_camera_scroll = true
		node.scroll_scale = Vector2(1.0, 1.0)
		node.repeat_times = 3
	_far.repeat_size = Vector2(_scaled_tile(_far_sprite, far_tile_w), 0.0)
	_mid.repeat_size = Vector2(_scaled_tile(_mid_sprite, mid_tile_w), 0.0)
	_near.repeat_size = Vector2(_scaled_tile(_near_sprite, near_tile_w), 0.0)
	_far.z_index = -90
	_mid.z_index = -80
	_near.z_index = -70
	_sky.z_index = -100
	_sun.z_index = -99


func _scaled_tile(spr: Sprite2D, fallback: float) -> float:
	if spr and spr.has_meta("scaled_tile_w"):
		return float(spr.get_meta("scaled_tile_w"))
	return fallback


func _setup_sun() -> void:
	_sun.z_as_relative = false


func _bind_day_manager() -> void:
	var dm := get_tree().get_first_node_in_group("day_manager")
	if dm == null:
		return
	if dm.has_method("current_minutes"):
		_on_time_changed(int(dm.current_minutes()))
	if dm.get("config") != null:
		var cfg = dm.config
		if cfg:
			_shift_start_min = float(cfg.start_min)
			_shift_end_min = float(cfg.end_min)
	if dm.has_signal("time_changed"):
		dm.time_changed.connect(_on_time_changed)


func _on_time_changed(minutes: int) -> void:
	var span := maxf(_shift_end_min - _shift_start_min, 1.0)
	var t: float = clampf((float(minutes) - _shift_start_min) / span, 0.0, 1.0)
	_sun.position = _bezier2(sun_start_pos, sun_peak_pos, sun_end_pos, t)
	_update_sky(t)


func _bezier2(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * a + 2.0 * u * t * b + t * t * c


func _update_sky(t: float) -> void:
	var c: Color
	if t < 0.5:
		c = sky_dawn.lerp(sky_day, t / 0.5)
	else:
		c = sky_day.lerp(sky_eve, (t - 0.5) / 0.5)
	_sky.color = c
