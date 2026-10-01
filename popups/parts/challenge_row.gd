class_name ChallengeRow extends VBoxContainer

## One developer or creator challenge in the pack editor. Edits a copy of its
## record entry, so fields the row doesn't show (its id, the game it came from)
## are written back untouched.

signal remove_requested

var _entry: Dictionary = {}

@onready var _text: LineEdit = %ChallengeText
@onready var _type: OptionButton = %ChallengeType
@onready var _handle: LineEdit = %ContributorHandle
@onready var _role: LineEdit = %ContributorRole
@onready var _remove: Button = %RemoveChallenge


func _ready() -> void:
	for challenge_type in PackRecord.CHALLENGE_TYPES:
		_type.add_item(challenge_type.capitalize())
	_remove.pressed.connect(func() -> void: self.remove_requested.emit())
	_show()


func set_entry(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	if is_node_ready():
		_show()


## The entry as edited.
func entry() -> Dictionary:
	var out := _entry.duplicate(true)
	PackRecord.set_text(out, "text", _text.text)

	var chosen: String = PackRecord.CHALLENGE_TYPES[maxi(_type.selected, 0)]
	if out.get("type") != chosen:
		out["type"] = chosen

	var contributor: Dictionary = {}
	if out.get("contributor") is Dictionary:
		contributor = out["contributor"]
	PackRecord.set_text(contributor, "handle", _handle.text)
	PackRecord.set_text(contributor, "role", _role.text)
	if not contributor.is_empty():
		out["contributor"] = contributor
	return out


func is_blank() -> bool:
	return _text.text.strip_edges().is_empty()


func _show() -> void:
	_text.text = _text_of(_entry, "text")
	var index := PackRecord.CHALLENGE_TYPES.find(_entry.get("type", "secondary"))
	_type.select(index if index != -1 else 1)

	var contributor = _entry.get("contributor")
	contributor = contributor if contributor is Dictionary else {}
	_handle.text = _text_of(contributor, "handle")
	_role.text = _text_of(contributor, "role")


static func _text_of(record: Dictionary, key: String) -> String:
	var value = record.get(key)
	return value if value is String else ""
