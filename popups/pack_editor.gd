class_name PackEditor extends PopupContainer

signal save_validated(pack_data: PackData)

enum ActionType { ADD, EDIT }

const MOD_MANAGER_CARD: PackedScene = preload(
	"res://source/mod-manager/popups/parts/mod_manager_card.tscn"
)
# Regular expression to validate the filename.
# ^[a-zA-Z0-9 _\-'.]+$
#
# Explanation of the regex:
# ^          : Start of the string
# [          : Start of the character set
#   a-zA-Z0-9 : Alphanumeric characters
#   \s       : Whitespace (equivalent to ' ' - space)
#   \-       : Hyphen (escaped)
#   _        : Underscore
#   '        : Single quote
#   .        : Period/Dot
# ]          : End of the character set
# +          : Matches one or more of the characters in the set
# $          : End of the string
#
# This pattern ensures the ENTIRE string matches the allowed characters.
const FILENAME_REGEX_PATTERN = "^[a-zA-Z0-9\\s_\\-'.]+$"

var action_type: ActionType = ActionType.ADD
var pack_data: PackData = null
var _file_name_regex: RegEx

@onready var _title: Label = %Title
@onready var _pack_name_line_edit: LineEdit = %PackNameLineEdit
@onready var _card_backs: HBoxContainer = %CardBacks
@onready var _add_card_back_button: ModManagerCard = %AddCardBack
@onready var _primary_cards: HBoxContainer = %PrimaryCards
@onready var _add_primary_card_button: ModManagerCard = %AddPrimaryCard
@onready var _secondary_cards: HBoxContainer = %SecondaryCards
@onready var _add_secondary_card_button: ModManagerCard = %AddSecondaryCard
@onready var _curse_cards: HBoxContainer = %CurseCards
@onready var _add_curse_card_button: ModManagerCard = %AddCurseCard
@onready var _file_dialog: FileDialog = %FileDialog
@onready var _confirm_delete: ConfirmDelete = %ConfirmDelete
@onready var _save_button: Button = %Save


func _ready() -> void:
	super._ready()

	match action_type:
		ActionType.ADD:
			_title.text = "Add Pack"
		ActionType.EDIT:
			_title.text = "Edit Pack"

	_pack_name_line_edit.text_changed.connect(_on_pack_name_changed)

	_add_card_back_button.pressed.connect(_select_new_card.bind(_card_backs, _add_card_back_button))
	_add_primary_card_button.pressed.connect(
		_select_new_card.bind(_primary_cards, _add_primary_card_button)
	)
	_add_secondary_card_button.pressed.connect(
		_select_new_card.bind(_secondary_cards, _add_secondary_card_button)
	)
	_add_curse_card_button.pressed.connect(
		_select_new_card.bind(_curse_cards, _add_curse_card_button)
	)

	_save_button.pressed.connect(_validate_save)

	# The RegEx object is compiled once for efficiency.
	# Compile the regular expression when the script starts
	_file_name_regex = RegEx.new()
	var error = _file_name_regex.compile(FILENAME_REGEX_PATTERN)
	if error != OK:
		print("Error compiling regex: ", error)


func open() -> void:
	_reset()

	if pack_data != null:
		_set_initial_pack_data()
	else:
		pack_data = PackData.new()

	show()


func _set_initial_pack_data() -> void:
	_pack_name_line_edit.text = pack_data.title

	for image_texture in pack_data.backs:
		_add_mod_manager_card(_card_backs, _add_card_back_button, image_texture, true)

	for image_texture in pack_data.primaries:
		_add_mod_manager_card(_primary_cards, _add_primary_card_button, image_texture, true)

	for image_texture in pack_data.secondaries:
		_add_mod_manager_card(_secondary_cards, _add_secondary_card_button, image_texture, true)

	for image_texture in pack_data.curses:
		_add_mod_manager_card(_curse_cards, _add_curse_card_button, image_texture, true)


func _on_pack_name_changed(new_name: String) -> void:
	if (_is_valid_file_name(new_name) or new_name == "") and not _confirm_delete.visible:
		pack_data.title = new_name
	else:
		_pack_name_line_edit.text = pack_data.title


func _select_new_card(container: HBoxContainer, add_button: ModManagerCard) -> void:
	if _confirm_delete.visible:
		return

	_file_dialog.file_selected.connect(_on_file_selected.bind(container, add_button))
	_file_dialog.popup_centered()


func _on_file_selected(
	file_path: String, container: HBoxContainer, add_button: ModManagerCard
) -> void:
	_file_dialog.file_selected.disconnect(_on_file_selected.bind(container, add_button))

	var image: Image = Image.load_from_file(file_path)
	var texture: ImageTexture = ImageTexture.create_from_image(image)

	_add_mod_manager_card(container, add_button, texture)


func _add_mod_manager_card(
	container: HBoxContainer,
	add_button: ModManagerCard,
	new_texture: ImageTexture,
	initial_load: bool = false
) -> void:
	container.remove_child(add_button)

	var new_card = MOD_MANAGER_CARD.instantiate()
	new_card.texture = new_texture
	new_card.pressed.connect(_on_card_pressed.bind(container, new_card))
	container.add_child(new_card)

	container.add_child(add_button)

	if initial_load:
		return

	match container:
		_card_backs:
			pack_data.backs.append(new_texture)
		_primary_cards:
			pack_data.primaries.append(new_texture)
		_secondary_cards:
			pack_data.secondaries.append(new_texture)
		_curse_cards:
			pack_data.curses.append(new_texture)


func _on_card_pressed(container: HBoxContainer, card: ModManagerCard) -> void:
	if _confirm_delete.visible:
		return

	_confirm_delete.confirm_delete.connect(_on_delete_confirmed.bind(container, card))
	_confirm_delete.closing.connect(_on_confirm_delete_closing.bind(container, card))
	_confirm_delete.set_card_texture(card.texture)
	_confirm_delete.show()


func _on_delete_confirmed(container: HBoxContainer, card: ModManagerCard) -> void:
	_confirm_delete.confirm_delete.disconnect(_on_delete_confirmed.bind(container, card))
	_confirm_delete.closing.disconnect(_on_confirm_delete_closing.bind(container, card))

	match container:
		_card_backs:
			var index = pack_data.backs.find(card.texture)
			pack_data.backs.remove_at(index)
		_primary_cards:
			var index = pack_data.primaries.find(card.texture)
			pack_data.primaries.remove_at(index)
		_secondary_cards:
			var index = pack_data.secondaries.find(card.texture)
			pack_data.secondaries.remove_at(index)
		_curse_cards:
			var index = pack_data.curses.find(card.texture)
			pack_data.curses.remove_at(index)

	container.remove_child(card)


func _on_confirm_delete_closing(container: HBoxContainer, card: ModManagerCard) -> void:
	_confirm_delete.confirm_delete.disconnect(_on_delete_confirmed.bind(container, card))
	_confirm_delete.closing.disconnect(_on_confirm_delete_closing.bind(container, card))


func _reset() -> void:
	_pack_name_line_edit.text = ""
	_clear_container(_card_backs, _add_card_back_button)
	_clear_container(_primary_cards, _add_primary_card_button)
	_clear_container(_secondary_cards, _add_secondary_card_button)
	_clear_container(_curse_cards, _add_curse_card_button)


func _clear_container(container: HBoxContainer, add_button: ModManagerCard) -> void:
	for child in container.get_children():
		if child != add_button:
			container.remove_child(child)
			child.queue_free()


func _validate_save() -> void:
	if _confirm_delete.visible:
		return

	if pack_data.title != "" and pack_data.backs.size() and pack_data.primaries.size():
		self.save_validated.emit(pack_data)

	super._close()


func _is_valid_file_name(file_name: String) -> bool:
	if file_name.is_empty():
		return false

	# Perform the search using the compiled regex object.
	# The search() method returns a RegExMatch object if it finds a match.
	# If a full match is found, it means the filename is valid.
	return _file_name_regex.search(file_name) != null
