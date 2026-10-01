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

	# The list only loads each pack's backs; the editor shows and saves every card.
	PackDataLoader.load_faces(_selected_pack)
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

	pack_data.folder_path = new_folder_path

	if existing_pack_index != -1:
		_packs[existing_pack_index] = pack_data
	else:
		_packs.append(pack_data)

	_packs.sort_custom(PackDataLoader.sort_packs)

	_selected_pack = pack_data

	_save_mod(pack_data)

	# If an edit renamed the pack, its folder moved too. Remove the old one only
	# now: the save copies each untouched card's file from wherever it was.
	if old_folder_path != "" and old_folder_path != new_folder_path:
		var old_dir = DirAccess.open(old_folder_path)
		if old_dir:
			Helpers.delete_recursive(old_dir)

	_clear_packs()
	_build_packs()


func _save_mod(pack_data: PackData) -> void:
	var mods_dir = DirAccess.open(mods_path)
	if mods_dir == null:
		push_error("ModManager: couldn't open mods path %s" % mods_path)
		return

	# Work out every card's file, and read the bytes for each, before writing
	# anything: removing a card renumbers the ones after it, so p3 becomes p2
	# and would otherwise overwrite p2 before p2 had been copied.
	var cards := _planned_card_files(pack_data)

	mods_dir.make_dir_recursive(pack_data.title)
	var written := {}
	for planned in cards:
		var target: String = pack_data.folder_path.path_join(planned.name)
		var unchanged: bool = (
			FileAccess.file_exists(target) and FileAccess.get_file_as_bytes(target) == planned.bytes
		)
		if not unchanged:
			var file := FileAccess.open(target, FileAccess.WRITE)
			if file == null:
				push_error("ModManager: couldn't write %s" % target)
				continue
			file.store_buffer(planned.bytes)
			file.close()
		# Later saves copy from where the card lives now.
		planned.card.set_meta(PackDataLoader.SOURCE_META, target)
		written[planned.name] = true

	_remove_stale_cards(pack_data.folder_path, written)

	# Write the record back from what was loaded into memory, so fields the
	# editor has no controls for survive; clearing every tag on an otherwise
	# empty record simply leaves no metadata file behind.
	PackDataLoader.save_metadata(pack_data.folder_path, pack_data.metadata, pack_data.tags)


## Each card's file in the saved pack. The aim is the smallest possible change,
## so a pull request shows only what the contributor actually did:
## - a card keeps the file it came from - same name, same bytes - so untouched
##   cards don't change at all, and a JPEG stays a JPEG;
## - a new card takes the lowest free number in its category, and only a card
##   with no file behind it is encoded, as a PNG;
## - removing a card just removes its file, leaving a gap - except that a
##   category's number 1 is always filled (the mods repo requires b1 and p1), by
##   moving its highest-numbered card there: one rename rather than a reshuffle.
## The prefix is what PackDataLoader classifies each card by.
func _planned_card_files(pack_data: PackData) -> Array[Dictionary]:
	var planned: Array[Dictionary] = []
	for category in [
		["b", pack_data.backs],
		["p", pack_data.primaries],
		["s", pack_data.secondaries],
		["c", pack_data.curses],
	]:
		planned.append_array(_plan_category(category[0], category[1]))
	return planned


func _plan_category(prefix: String, cards: Array) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	var used := {}

	for card in cards:
		var plan := _card_contents(card)
		var own := _own_number(str(card.get_meta(PackDataLoader.SOURCE_META, "")), prefix)
		if own != -1 and not used.has(own):
			used[own] = true
			plan.number = own
			plans.append(plan)
		else:
			waiting.append(plan)

	for plan in waiting:
		var number := 1
		while used.has(number):
			number += 1
		used[number] = true
		plan.number = number
		plans.append(plan)

	if not plans.is_empty() and not used.has(1):
		var highest := plans[0]
		for plan in plans:
			if plan.number > highest.number:
				highest = plan
		highest.number = 1

	for plan in plans:
		plan.name = "%s%d.%s" % [prefix, plan.number, plan.extension]
	return plans


## A card's bytes and extension: its own file's if it has one, otherwise the
## texture encoded as a PNG.
func _card_contents(card: ImageTexture) -> Dictionary:
	var source := str(card.get_meta(PackDataLoader.SOURCE_META, ""))
	var extension := source.get_extension().to_lower()
	var bytes := PackedByteArray()
	if extension in ["png", "jpg", "jpeg"] and FileAccess.file_exists(source):
		bytes = FileAccess.get_file_as_bytes(source)
	if bytes.is_empty():
		extension = "png"
		bytes = card.get_image().save_png_to_buffer()
	return {"card": card, "extension": extension, "bytes": bytes, "number": 0, "name": ""}


## The number in a card file's name when it is one of this category's own - p7
## for "p7.png" under "p" - or -1 for a new card, or one from another category.
static func _own_number(source: String, prefix: String) -> int:
	var file := source.get_file().to_lower()
	var found := RegEx.create_from_string("^%s([0-9]+)\\.(png|jpe?g)$" % prefix).search(file)
	return int(found.get_string(1)) if found != null else -1


## Removes card images left over from before this save - a card that was deleted,
## or the higher numbers once a category shrank - leaving anything that isn't a
## card image alone.
func _remove_stale_cards(folder_path: String, keep: Dictionary) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return

	var card_file := RegEx.create_from_string("^[bpsc][0-9]+\\.(png|jpe?g)$")
	for file_name in dir.get_files():
		if card_file.search(file_name.to_lower()) != null and not keep.has(file_name):
			dir.remove(file_name)


func _leave_mod_manager() -> void:
	if _pack_editor.visible or _confirm_delete.visible:
		return

	get_tree().change_scene_to_packed(scene_to_return_to)
