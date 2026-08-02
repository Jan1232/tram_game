class_name StressBalance
extends Resource

# --- Потолок (длина шкалы) ---
@export var ceiling_start: float = 100.0
@export var ceiling_min: float = 50.0
@export var ceiling_max: float = 110.0
@export var faint_ceiling_loss: float = 10.0

# --- Пассив (только сидя) ---
@export var sit_recover: float = 1.0 # −/сек сидя

# --- Событийные изменения заполнения (уже со знаком) ---
@export var calm_ticket: float = -2.0 # спокойно обилетил
@export var repeat_ask: float = 8.0 # повторный запрос у проверенного
@export var refuse: float = 6.0 # нет билета / отказ показать (мягче)
@export var insist_right: float = -5.0 # настоял и был прав (заяц заплатил)
@export var cops_right: float = -30.0 # копы + был прав (поймал зайца) — награда
@export var cops_wrong: float = 30.0 # копы + ошибся (уже платил) — расплата
@export var dodger_escaped: float = 15.0 # упустил зайца (ушёл)
@export var scandal_leave: float = 12.0 # ушёл после скандала с честным
