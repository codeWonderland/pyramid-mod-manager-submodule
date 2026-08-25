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
	if pack_dir:
		Helpers.delete_recursive(pack_dir)

	var pack_index = _packs.find(_selected_pack)
	if pack_index != -1:
		_packs.remove_at(pack_index)

	for mod in _mods_list.get_children():
		if mod.text == _selected_pack.title:
			_mods_list.remove_child(mod)
			mod.queue_free()

	_selected_pack = null


func _on_pack_saved(pack_data: PackData) -> void:
	# When editing, the same PackData instance is handed back to us, so we can
	# locate its existing slot by identity. New packs have an empty folder_path.
	var existing_pack_index := _packs.find(pack_data)
	var old_folder_path := pack_data.folder_path
	var new_folder_path := mods_path.path_join(pack_data.title)

	# If an edit renamed the pack, its folder moves too; remove the stale folder
	# so we don't leave an orphaned copy behind.
	if old_folder_path != "" and old_folder_path != new_folder_path:
		var old_dir = DirAccess.open(old_folder_path)
		if old_dir:
			Helpers.delete_recursive(old_dir)

	pack_data.folder_path = new_folder_path

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
	if mods_dir == null:
		push_error("ModManager: couldn't open mods path %s" % mods_path)
		return

	# Recreate the pack folder from scratch so removed cards (or a lower card
	# count after an edit) don't leave stale higher-index images behind.
	var existing = DirAccess.open(pack_data.folder_path)
	if existing:
		Helpers.delete_recursive(existing)
	mods_dir.make_dir_recursive(pack_data.title)

	# Prefixes are what PackDataLoader classifies cards by when reading a pack.
	_save_cards(pack_data.backs, "b", pack_data.folder_path)
	_save_cards(pack_data.primaries, "p", pack_data.folder_path)
	_save_cards(pack_data.secondaries, "s", pack_data.folder_path)
	_save_cards(pack_data.curses, "c", pack_data.folder_path)

	# The folder was recreated from scratch above, so clearing every tag simply
	# leaves no metadata file behind.
	PackDataLoader.save_tags(pack_data.folder_path, pack_data.tags)


## Writes one numbered image per card, 1-based, so a pack with three primaries
## gets p1/p2/p3. Each category previously had its own copy of this loop with a
## counter it never advanced, so every card overwrote the same file and only the
## last one survived; one shared helper keeps that from drifting back.
func _save_cards(cards: Array[ImageTexture], prefix: String, folder_path: String) -> void:
	var index := 1
	for card in cards:
		_save_image(card, "%s/%s%d.png" % [folder_path, prefix, index])
		index += 1


func _save_image(card: ImageTexture, file_path: String) -> void:
	var image: Image = card.get_image()
	image.save_png(file_path)


func _leave_mod_manager() -> void:
	if _pack_editor.visible or _confirm_delete.visible:
		return

	get_tree().change_scene_to_packed(scene_to_return_to)
