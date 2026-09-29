class_name PackData extends Resource

var title: String
var folder_path: String
## Free-form tags authored by the pack itself (see PackDataLoader.METADATA_FILE),
## used by the draft screen's filters. Empty for packs that ship no metadata.
var tags: Array[String] = []
## Everything the pack's metadata file holds, kept as read so that saving a pack
## from the editor writes back fields the editor doesn't know about rather than
## dropping them. `tags` above is the cleaned view of its "tags" entry.
var metadata: Dictionary = {}
var backs: Array[ImageTexture] = []
var primaries: Array[ImageTexture] = []
var secondaries: Array[ImageTexture] = []
var curses: Array[ImageTexture] = []
