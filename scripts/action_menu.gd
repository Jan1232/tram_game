class_name ActionMenu
extends CanvasLayer

signal action_chosen(action: String)

@onready var _panel: Control = $Panel
@onready var _vbox: VBoxContainer = $Panel/VBox


func _ready() -> void:
	visible = false


## choices: массив словарей { "id": String, "text": String }
func open_choices(screen_pos: Vector2, choices: Array) -> void:
	_clear_buttons()
	for choice in choices:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 36)
		btn.text = String(choice.get("text", ""))
		var action_id := String(choice.get("id", ""))
		btn.pressed.connect(_choose.bind(action_id))
		_vbox.add_child(btn)
	_panel.position = screen_pos + Vector2(20, -40)
	visible = true


func close() -> void:
	visible = false
	_clear_buttons()


func _clear_buttons() -> void:
	for child in _vbox.get_children():
		child.queue_free()


func _choose(action: String) -> void:
	close()
	action_chosen.emit(action)
