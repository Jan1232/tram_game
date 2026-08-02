extends Node

## Концовки проверки + короткое «Всё правильно».

@onready var _overlay: CanvasLayer = $GameOverOverlay
@onready var _label: Label = $GameOverOverlay/Center/Panel/Label
@onready var _success: Label = $SuccessLayer/SuccessToast


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_flow")
	if _overlay:
		_overlay.visible = false
	if _success:
		_success.visible = false


func show_success(text: String = "Всё правильно") -> void:
	print(">>> ", text)
	if _success == null:
		return
	_success.text = text
	_success.visible = true
	var tree := get_tree()
	if tree:
		await tree.create_timer(2.2).timeout
		if is_instance_valid(_success):
			_success.visible = false


func show_game_over(reason: String) -> void:
	print(">>> GAME OVER: ", reason)
	get_tree().paused = true
	if _overlay:
		_overlay.visible = true
		_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	if _label:
		_label.text = "Игра окончена\n%s\n\nEnter — заново · Esc — выход" % reason


func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused:
		return
	if event.is_action_pressed("ui_accept"):
		get_tree().paused = false
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()
