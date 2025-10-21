class_name ModManager extends Control

@export var title: String
@export var mods_path: String

var _packs: Array[PackData]
var _selected_pack: PackData = null

@onready var _title_label: Label = %Title
@onready var _mods_list: VBoxContainer = %ModsList
@onready var _add_mod_button: TextureButton = %AddMod
@onready var _edit_mod_button: TextureButton = %EditMod
@onready var _delete_mod_button: TextureButton = %DeleteMod


func _ready() -> void:
	_title_label.text = title

	_packs = await PackLoader.load_packs_from_folder(mods_path)
	_packs.sort_custom(PackLoader.sort_packs)
	_build_pack_options()

	_add_mod_button.pressed.connect(_add_mod)
	_edit_mod_button.pressed.connect(_edit_mod)
	_delete_mod_button.pressed.connect(_delete_mod)


func _build_pack_options() -> void:
	for pack_data in _packs:
		var pack_button = Button.new()
		pack_button.text = pack_data.title
		pack_button.pressed.connect(_select_pack.bind(pack_data))
		pack_button.size_flags_horizontal = SIZE_EXPAND_FILL
		_mods_list.add_child(pack_button)


func _select_pack(pack_data: PackData) -> void:
	_selected_pack = pack_data


func _add_mod() -> void:
	pass


func _edit_mod() -> void:
	pass


func _delete_mod() -> void:
	pass
