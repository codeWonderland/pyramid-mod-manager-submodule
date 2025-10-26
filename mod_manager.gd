class_name ModManager extends Control

@export var title: String
@export var mods_path: String
@export var scene_to_return_to: PackedScene

var _packs: Array[PackData]
var _selected_pack: PackData = null

@onready var _back_button: TextureButton = %Back
@onready var _title_label: Label = %Title
@onready var _mods_list: VBoxContainer = %ModsList
@onready var _add_mod_button: TextureButton = %AddMod
@onready var _edit_mod_button: TextureButton = %EditMod
@onready var _delete_mod_button: TextureButton = %DeleteMod
@onready var _pack_editor: PackEditor = %PackEditor
@onready var _confirm_delete: ConfirmDelete = %ConfirmDelete


func _ready() -> void:
	_title_label.text = title

	_packs = await PackDataLoader.load_packs_from_folder(mods_path, get_tree())
	_packs.sort_custom(PackDataLoader.sort_packs)
	_build_packs()

	_add_mod_button.pressed.connect(_add_mod)
	_edit_mod_button.pressed.connect(_edit_mod)
	_delete_mod_button.pressed.connect(_delete_mod)

	_pack_editor.save_validated.connect(_on_pack_saved)

	_confirm_delete.set_title("Are you sure you want to delete this mod?")
	_confirm_delete.confirm_delete.connect(_on_delete_mod_confirmed)

	if scene_to_return_to != null:
		_back_button.pressed.connect(_leave_mod_manager)
	else:
		_back_button.hide()


func _build_packs() -> void:
	for pack_data in _packs:
		var pack_button = Button.new()
		pack_button.text = pack_data.title
		pack_button.pressed.connect(_select_pack.bind(pack_data))
		pack_button.size_flags_horizontal = SIZE_EXPAND_FILL
		pack_button.theme_type_variation = &"SelectableButton"
		_mods_list.add_child(pack_button)


func _clear_packs() -> void:
	for mod in _mods_list.get_children():
		_mods_list.remove_child(mod)
		mod.queue_free()


func _select_pack(pack_data: PackData) -> void:
	if _pack_editor.visible or _confirm_delete.visible:
		return

	_selected_pack = pack_data


func _add_mod() -> void:
	if _pack_editor.visible or _confirm_delete.visible:
		return

	_pack_editor.pack_data = null
	_pack_editor.open()


func _edit_mod() -> void:
	if _pack_editor.visible or _confirm_delete.visible or _selected_pack == null:
		return

	_pack_editor.pack_data = _selected_pack
	_pack_editor.open()


func _delete_mod() -> void:
	if _pack_editor.visible or _confirm_delete.visible or _selected_pack == null:
		return

	_confirm_delete.set_card_texture(_selected_pack.backs[0])
	_confirm_delete.show()


func _on_delete_mod_confirmed() -> void:
	var pack_dir = DirAccess.open(_selected_pack.folder_path)
	Helpers.delete_recursive(pack_dir)

	var pack_index = _packs.find(_selected_pack)
	_packs.remove_at(pack_index)

	for mod in _mods_list.get_children():
		if mod.text == _selected_pack.title:
			_mods_list.remove_child(mod)
			mod.queue_free()

	_selected_pack = null


func _on_pack_saved(pack_data: PackData) -> void:
	var existing_pack_index = -1
	if pack_data.folder_path != "":
		_delete_mod()

		var index = 0
		for pack in _packs:
			if pack.folder_path == pack_data.folder_path:
				existing_pack_index = index

	pack_data.folder_path = mods_path + pack_data.title

	if existing_pack_index != -1:
		_packs[existing_pack_index] = pack_data
	else:
		_packs.append(pack_data)

	_packs.sort_custom(PackDataLoader.sort_packs)

	_selected_pack = pack_data

	_save_mod(pack_data)

	_clear_packs()
	_build_packs()


func _save_mod(pack_data: PackData) -> void:
	var mods_dir = DirAccess.open(mods_path)
	mods_dir.make_dir_recursive(pack_data.title)

	var index = 1
	for card in pack_data.backs:
		_save_image(
			card,
			("{folder_path}/b{index}.png").format(
				{folder_path = pack_data.folder_path, index = index}
			)
		)

	index = 1
	for card in pack_data.primaries:
		_save_image(
			card,
			("{folder_path}/p{index}.png").format(
				{folder_path = pack_data.folder_path, index = index}
			)
		)

	index = 1
	for card in pack_data.secondaries:
		_save_image(
			card,
			("{folder_path}/s{index}.png").format(
				{folder_path = pack_data.folder_path, index = index}
			)
		)

	index = 1
	for card in pack_data.curses:
		_save_image(
			card,
			("{folder_path}/c{index}.png").format(
				{folder_path = pack_data.folder_path, index = index}
			)
		)


func _save_image(card: ImageTexture, file_path: String) -> void:
	var image: Image = card.get_image()
	image.save_png(file_path)


func _leave_mod_manager() -> void:
	if _pack_editor.visible or _confirm_delete.visible:
		return

	get_tree().change_scene_to_packed(scene_to_return_to)
