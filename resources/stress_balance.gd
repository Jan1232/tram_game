class_name StressBalance
extends Resource

# --- Потолок (длина шкалы) ---
@export var ceiling_start: float = 100.0
@export var ceiling_min: float = 50.0
@export var ceiling_max: float = 110.0
## Потеря потолка по номеру обморока за кампанию (лавина).
@export var faint_ceiling_losses: Array[float] = [8.0, 10.0, 13.0, 17.0, 22.0]
@export var faint_ceiling_loss_overflow: float = 22.0

# --- Пассив (только сидя) ---
@export var sit_recover: float = 1.0 # −/сек сидя

# --- Событийные изменения заполнения (уже со знаком) ---
@export var calm_ticket: float = -2.0 # спокойно обилетил
@export var repeat_ask: float = 8.0 # повторный запрос у проверенного
@export var refuse: float = 6.0 # нет билета / отказ показать (мягче)
@export var insist_right: float = -5.0 # настоял и был прав (заяц заплатил)
@export var cops_right: float = -30.0 # копы + был прав (поймал зайца) — награда
@export var cops_wrong: float = 18.0 # копы + ошибся (уже платил) — зеркало успеха (−24)
@export var dodger_escaped: float = 12.0 # упустил зайца; давление — в деньгах
@export var scandal_leave: float = 12.0 # ушёл после скандала с честным
