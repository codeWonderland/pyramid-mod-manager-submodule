class_name PackData extends Resource

var title: String
var folder_path: String
## Free-form tags authored by the pack itself (see PackDataLoader.METADATA_FILE),
## used by the draft screen's filters. Empty for packs that ship no metadata.
var tags: Array[String] = []
var backs: Array[ImageTexture] = []
var primaries: Array[ImageTexture] = []
var secondaries: Array[ImageTexture] = []
var curses: Array[ImageTexture] = []
