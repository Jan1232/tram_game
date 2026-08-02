extends Node

## Простой конец игры (прототип обилечивания).

@onready var _overlay: CanvasLayer = $GameOverOverlay
@onready var _label: Label = $GameOverOverlay/Center/Panel/Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_flow")
	if _overlay:
		_overlay.visible = false


func on_passenger_game_end() -> void:
	get_tree().paused = true
	if _overlay:
		_overlay.visible = true
		_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	if _label:
		_label.text = "Игра окончена\nПовторная проверка пассажира\n\nEnter — заново · Esc — выход"


func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused:
		return
	if event.is_action_pressed("ui_accept"):
		get_tree().paused = false
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()
