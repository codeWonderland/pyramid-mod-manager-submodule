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
## The card fronts. Empty until PackDataLoader.load_faces() when the pack was
## loaded with only its backs - see unloaded_faces.
var primaries: Array[ImageTexture] = []
var secondaries: Array[ImageTexture] = []
var curses: Array[ImageTexture] = []
## Card-front image files not decoded yet, in the order they load. Decoding every
## card of every pack is most of the time boot spends loading, and most packs are
## never drawn from in a session, so a pack can be listed with just its backs.
var unloaded_faces: PackedStringArray = []
