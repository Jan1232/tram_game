class_name DayConfig
extends Resource

@export var start_min: int = 300 # 05:00
@export var end_min: int = 1020 # 17:00
@export var shift_real_seconds: float = 600.0 # реальная длина смены (10 мин)
@export var faint_time_skip_min: int = 180 # прыжок часов за обморок (3 игр-часа)
@export var bands: Array[DayBand] = [] # если пусто — DayManager строит дефолт
