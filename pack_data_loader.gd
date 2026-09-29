class_name PackDataLoader

## Optional per-pack metadata file, sitting alongside the pack's images. Packs
## without one are still perfectly valid, they just carry no tags.
const METADATA_FILE: String = "pack.json"


static func load_pack_from_path(pack_path: String) -> PackData:
	var pack_data = PackData.new()

	pack_data.folder_path = pack_path

	var num_parts = pack_path.get_slice_count("/")
	pack_data.title = pack_path.get_slice("/", num_parts - 1)

	var pack_folder = DirAccess.open(pack_data.folder_path)

	if pack_folder:
		var files = pack_folder.get_files()

		for file_path in files:
			# only image files are actually valid
			if !(
				file_path.ends_with(".png")
				or file_path.ends_with(".jpg")
				or file_path.ends_with(".jpeg")
			):
				continue

			var image: Image = Image.load_from_file(pack_data.folder_path + "/" + file_path)
			if image == null:
				push_warning("PackDataLoader: couldn't load image %s" % file_path)
				continue

			var texture: ImageTexture = ImageTexture.create_from_image(image)

			if file_path.begins_with("b"):
				pack_data.backs.append(texture)
			elif file_path.begins_with("p"):
				pack_data.primaries.append(texture)
			elif file_path.begins_with("s"):
				pack_data.secondaries.append(texture)
			elif file_path.begins_with("c"):
				pack_data.curses.append(texture)
			else:
				print("No idea what to do with this texture:")
				print(file_path)

	pack_data.metadata = load_metadata(pack_data.folder_path)
	pack_data.tags = tags_from_metadata(pack_data.metadata)

	if pack_data.backs.size():
		return pack_data

	print("pack does not have proper background:")
	print(pack_data.folder_path)
	return null


static func load_packs_from_folder(folder_path: String, tree: SceneTree) -> Array[PackData]:
	var packs_folder = DirAccess.open(folder_path)
	var packs: Array[PackData] = []

	if packs_folder:
		packs_folder.list_dir_begin()
		var pack_path = packs_folder.get_next()
		while pack_path != "":
			await tree.process_frame

			var pack_data = load_pack_from_path(folder_path + pack_path)

			if pack_data != null and pack_data.backs.size() > 0 and pack_data.primaries.size() > 0:
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

	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	return true


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
