class_name PackRecord

## Rules for a pack's metadata record (pack.json) that the editor applies on save.
## The editor is where records are maintained, so anything that can be worked
## out from the pack itself - card counts, which kinds of challenge it has, ids -
## is worked out here rather than typed, and can't drift from the cards.

const CHALLENGE_TYPES: Array[String] = ["primary", "secondary", "curse"]
## The contributor role that marks a content creator's challenge; any other role
## is the game's developers.
const CREATOR_ROLE: String = "Creator"


## A record id from a name: "Binding of Isaac: Repentance" -> "binding-of-isaac-repentance".
static func slug(text: String) -> String:
	var lowered := text.to_lower().replace("&", "and")
	var out := ""
	for character in lowered:
		var code := character.unicode_at(0)
		var is_alnum := (code >= 48 and code <= 57) or (code >= 97 and code <= 122)
		if is_alnum:
			out += character
		elif not out.ends_with("-"):
			out += "-"
	return out.trim_prefix("-").trim_suffix("-")


## A record's link, or "" unless it's a web address - links open in the player's
## browser, so nothing else is handed to the system.
static func web_link(record: Dictionary, key: String) -> String:
	var value = record.get(key)
	if not (value is String):
		return ""
	var url: String = value.strip_edges()
	if url.begins_with("https://") or url.begins_with("http://"):
		return url
	return ""


## Sets a text field from what was typed, without disturbing a record that didn't
## change: an empty field leaves a missing or null value as it was, and only
## clears a value that had text.
static func set_text(record: Dictionary, key: String, text: String) -> void:
	var clean := text.strip_edges()
	if record.get(key) is String and record[key].strip_edges() == clean:
		return
	if not clean.is_empty():
		record[key] = clean
	elif record.get(key) is String:
		record[key] = ""


## Fills in what the record says about the pack's own cards and challenges:
## the card counts, whether it has developer and creator challenges, its id, and
## an id for each challenge that lacks one. Everything else is left as it is.
static func finalize(record: Dictionary, pack: PackData) -> Dictionary:
	if not (record.get("id") is String and not record["id"].is_empty()):
		var named = record.get("name")
		record["id"] = slug(named if named is String and not named.is_empty() else pack.title)

	if not (record.get("objectives") is Dictionary):
		record["objectives"] = {}
	var objectives: Dictionary = record["objectives"]
	objectives["primary_count"] = pack.primaries.size()
	objectives["secondary_count"] = pack.secondaries.size()
	objectives["has_curse"] = not pack.curses.is_empty()
	objectives["curse_count"] = pack.curses.size()

	var special = record.get("special_challenges")
	if special is Dictionary and special.get("entries") is Array:
		var used := {}
		for entry in special["entries"]:
			if entry is Dictionary and entry.get("id") is String:
				used[entry["id"]] = true

		var has_creator := false
		var has_developer := false
		for entry in special["entries"]:
			if not (entry is Dictionary):
				continue
			if not (entry.get("id") is String and not entry["id"].is_empty()):
				entry["id"] = _free_challenge_id(record["id"], used)
			var contributor = entry.get("contributor")
			var role = contributor.get("role") if contributor is Dictionary else null
			if role is String and not role.is_empty():
				if role == CREATOR_ROLE:
					has_creator = true
				else:
					has_developer = true

		special["creator_available"] = has_creator
		special["developer_available"] = has_developer

	return record


static func _free_challenge_id(record_id: String, used: Dictionary) -> String:
	var number := 1
	while used.has("%s-challenge-%d" % [record_id, number]):
		number += 1
	var chosen := "%s-challenge-%d" % [record_id, number]
	used[chosen] = true
	return chosen
