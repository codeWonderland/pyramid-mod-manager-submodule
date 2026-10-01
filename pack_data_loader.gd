class_name PackDataLoader

## Optional per-pack metadata file, sitting alongside the pack's images. Packs
## without one are still perfectly valid, they just carry no tags.
const METADATA_FILE: String = "pack.json"
## Metadata key on each card's texture: the image file it was loaded from. Saving
## writes that file's bytes back rather than re-encoding the texture, so cards
## that weren't touched come out byte-for-byte identical.
const SOURCE_META: StringName = &"source_file"
## How long load_packs_from_folder works before letting a frame draw.
const FRAME_BUDGET_MSEC: int = 50


## Loads the pack at `pack_path`, or null if it has no back. With `faces` false
## only the backs are decoded and the fronts are left in `unloaded_faces` for
## load_faces(), which is far quicker when listing many packs.
static func load_pack_from_path(pack_path: String, faces: bool = true) -> PackData:
	var pack_data = PackData.new()

	pack_data.folder_path = pack_path

	var num_parts = pack_path.get_slice_count("/")
	pack_data.title = pack_path.get_slice("/", num_parts - 1)

	var pack_folder = DirAccess.open(pack_data.folder_path)

	if pack_folder:
		var files := pack_folder.get_files()
		# Numeric order - p1, p2 ... p10 - not the alphabetical p1, p10, p2 the
		# folder lists them in, so each card's place matches its number. Saving
		# numbers cards by their place, so this is what keeps p10's image as p10.
		var sorted := Array(files)
		sorted.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
		files = PackedStringArray(sorted)

		for file_path in files:
			# only image files are actually valid
			if !(
				file_path.ends_with(".png")
				or file_path.ends_with(".jpg")
				or file_path.ends_with(".jpeg")
			):
				continue

			var full_path: String = pack_data.folder_path + "/" + file_path
			if faces or file_path.begins_with("b"):
				_add_card(pack_data, full_path)
			else:
				pack_data.unloaded_faces.append(full_path)

	pack_data.metadata = load_metadata(pack_data.folder_path)
	pack_data.tags = tags_from_metadata(pack_data.metadata)

	if pack_data.backs.size():
		return pack_data

	print("pack does not have proper background:")
	print(pack_data.folder_path)
	return null


## Decodes the card fronts a pack was loaded without. Safe to call on a pack that
## already has them all.
static func load_faces(pack_data: PackData) -> void:
	var pending := pack_data.unloaded_faces
	pack_data.unloaded_faces = []
	for full_path in pending:
		_add_card(pack_data, full_path)


## Whether a pack has at least one primary, loaded or not.
static func has_primaries(pack_data: PackData) -> bool:
	if not pack_data.primaries.is_empty():
		return true
	for full_path in pack_data.unloaded_faces:
		if full_path.get_file().begins_with("p"):
			return true
	return false


static func _add_card(pack_data: PackData, full_path: String) -> void:
	var file_name := full_path.get_file()

	var image: Image = Image.load_from_file(full_path)
	if image == null:
		push_warning("PackDataLoader: couldn't load image %s" % file_name)
		return

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	texture.set_meta(SOURCE_META, full_path)

	if file_name.begins_with("b"):
		pack_data.backs.append(texture)
	elif file_name.begins_with("p"):
		pack_data.primaries.append(texture)
	elif file_name.begins_with("s"):
		pack_data.secondaries.append(texture)
	elif file_name.begins_with("c"):
		pack_data.curses.append(texture)
	else:
		print("No idea what to do with this texture:")
		print(file_name)


## Lists every pack in `folder_path` with only its backs loaded - call load_faces()
## on a pack before using its fronts. Yields a frame now and then so a loading
## animation keeps moving, but not after every pack: at 60 fps a frame per pack
## would add two seconds of waiting for a hundred-odd packs.
static func load_packs_from_folder(folder_path: String, tree: SceneTree) -> Array[PackData]:
	var packs_folder = DirAccess.open(folder_path)
	var packs: Array[PackData] = []
	var last_yield := Time.get_ticks_msec()

	if packs_folder:
		packs_folder.list_dir_begin()
		var pack_path = packs_folder.get_next()
		while pack_path != "":
			if Time.get_ticks_msec() - last_yield > FRAME_BUDGET_MSEC:
				await tree.process_frame
				last_yield = Time.get_ticks_msec()

			var pack_data = load_pack_from_path(folder_path + pack_path, false)

			if pack_data != null and pack_data.backs.size() > 0 and has_primaries(pack_data):
				packs.append(pack_data)

			pack_path = packs_folder.get_next()

	return packs


static func sort_packs(a: PackData, b: PackData) -> bool:
	return a.title < b.title


## Writes a pack's metadata file: `metadata` with its "tags" entry replaced by
## `tags`. Every other field is written back untouched, so a pack record carrying
## more than tags survives an edit. A record left with nothing in it deletes the
## file, so a pack whose tags were all removed reads back as untagged.
static func save_metadata(
	pack_folder_path: String, metadata: Dictionary, tags: Array[String]
) -> bool:
	var metadata_path := pack_folder_path.path_join(METADATA_FILE)

	var record := metadata.duplicate(true)
	if tags.is_empty():
		record.erase("tags")
	else:
		record["tags"] = tags

	# Leave the file alone when nothing in it has changed, so a save that didn't
	# touch the record doesn't show up as a change to it.
	if FileAccess.file_exists(metadata_path) and load_metadata(pack_folder_path) == record:
		return true

	if record.is_empty():
		if FileAccess.file_exists(metadata_path):
			DirAccess.remove_absolute(metadata_path)
		return true

	var file = FileAccess.open(metadata_path, FileAccess.WRITE)
	if file == null:
		push_error(
			(
				"PackDataLoader: couldn't write %s (error %d)"
				% [metadata_path, FileAccess.get_open_error()]
			)
		)
		return false

	file.store_string(JSON.stringify(_whole_numbers(record), "\t") + "\n")
	file.close()
	return true


## Godot reads every JSON number as a float and would write 22 back as 22.0, so a
## record that went through the editor would show every count as changed. Whole
## numbers go back to integers before writing.
static func _whole_numbers(value):
	if value is Dictionary:
		var copy := {}
		for key in value:
			copy[key] = _whole_numbers(value[key])
		return copy
	if value is Array:
		return value.map(func(item): return _whole_numbers(item))
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	return value


## Replaces only the tags in a pack's metadata file, keeping whatever else is
## already there.
static func save_tags(pack_folder_path: String, tags: Array[String]) -> bool:
	return save_metadata(pack_folder_path, load_metadata(pack_folder_path), tags)


## Reads a pack's metadata file as a dictionary. Mod data is user-supplied, so
## every step here warns and falls back to an empty record rather than failing
## the pack: a broken metadata file must never stop a pack from loading.
static func load_metadata(pack_folder_path: String) -> Dictionary:
	var metadata_path := pack_folder_path.path_join(METADATA_FILE)

	if not FileAccess.file_exists(metadata_path):
		return {}

	var file = FileAccess.open(metadata_path, FileAccess.READ)
	if file == null:
		push_warning("PackDataLoader: couldn't open %s" % metadata_path)
		return {}

	# Parse through a JSON instance rather than JSON.parse_string: the static
	# helper raises an engine-level error on malformed input, and a player's
	# hand-edited pack.json should produce our warning, not an engine error.
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning(
			(
				"PackDataLoader: %s is not valid JSON (line %d: %s)"
				% [metadata_path, json.get_error_line(), json.get_error_message()]
			)
		)
		return {}

	if not (json.data is Dictionary):
		push_warning("PackDataLoader: %s is not a JSON object" % metadata_path)
		return {}

	return json.data


## Reads just the tag list out of a pack's metadata file.
static func load_tags(pack_folder_path: String) -> Array[String]:
	return tags_from_metadata(load_metadata(pack_folder_path))


## The cleaned tag list from a metadata record: trimmed, blanks and non-strings
## dropped, and de-duplicated case-insensitively while keeping the capitalisation
## the pack author wrote so the filter list reads the way they intended.
static func tags_from_metadata(metadata: Dictionary) -> Array[String]:
	var tags: Array[String] = []

	if not metadata.has("tags"):
		return tags

	if not (metadata["tags"] is Array):
		push_warning('PackDataLoader: pack metadata "tags" is not a list')
		return tags

	var seen := {}
	for entry in metadata["tags"]:
		if not (entry is String):
			continue

		var tag := (entry as String).strip_edges()
		if tag.is_empty():
			continue

		var key := tag.to_lower()
		if seen.has(key):
			continue

		seen[key] = true
		tags.append(tag)

	return tags
