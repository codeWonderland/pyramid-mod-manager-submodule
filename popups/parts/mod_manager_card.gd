class_name ModManagerCard extends TextureRect

signal pressed


func _ready() -> void:
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.is_pressed()
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		self.pressed.emit()
