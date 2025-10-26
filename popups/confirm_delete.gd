class_name ConfirmDelete extends PopupContainer

signal confirm_delete

@onready var _title: Label = %Title
@onready var _texture_rect: TextureRect = %TextureRect
@onready var _cancel: Button = %Cancel
@onready var _delete: Button = %Delete


func _ready() -> void:
	super._ready()

	_cancel.pressed.connect(func(): super._close())
	_delete.pressed.connect(_confirm_delete)


func set_title(text: String) -> void:
	_title.text = text


func set_card_texture(texture: ImageTexture) -> void:
	_texture_rect.texture = texture


func _confirm_delete() -> void:
	self.confirm_delete.emit()
	super._close()
