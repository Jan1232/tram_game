class_name StressBalance
extends Resource

# --- Потолок (длина шкалы) ---
@export var ceiling_start: float = 100.0
@export var ceiling_min: float = 50.0
@export var ceiling_max: float = 110.0
@export var faint_ceiling_loss: float = 10.0

# --- Посекундная динамика заполнения ---
@export var stand_fatigue: float = 1.0 # +/сек стоя/ходьба/меню
@export var sit_recover: float = 3.0 # −/сек сидя (применяется со знаком минус)

# --- Событийные изменения заполнения (уже со знаком) ---
@export var calm_ticket: float = -2.0 # спокойно обилетил
@export var repeat_ask: float = 8.0 # повторный запрос у проверенного
@export var refuse: float = 12.0 # нет билета / отказ показать
@export var insist_right: float = -5.0 # настоял и был прав
@export var police: float = 25.0 # вызов копов (трамвай встал)
@export var catch_dodger: float = -10.0 # поймал зайца (облегчение)
@export var wrong_arrest: float = 30.0 # ошибочный арест (копы на честного)
@export var dodger_escaped: float = 15.0 # упустил зайца (ушёл)
@export var scandal_leave: float = 12.0 # ушёл после скандала с честным
