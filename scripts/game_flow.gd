extends Node

## Тосты исходов. Game Over убран — наказание только через стресс / смену.

@onready var _success: Label = $SuccessLayer/SuccessToast


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_flow")
	if _success:
		_success.visible = false


func show_success(text: String = "Всё правильно") -> void:
	_show_toast(text, Color(0.85, 1.0, 0.75, 1.0))


func show_notice(text: String) -> void:
	_show_toast(text, Color(1.0, 0.78, 0.35, 1.0))


func _show_toast(text: String, color: Color) -> void:
	print(">>> ", text)
	if _success == null:
		return
	_success.text = text
	_success.add_theme_color_override("font_color", color)
	_success.visible = true
	var tree := get_tree()
	if tree:
		await tree.create_timer(2.2).timeout
		if is_instance_valid(_success):
			_success.visible = false
