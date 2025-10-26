class_name Helpers


static func delete_recursive(folder: DirAccess) -> void:
	var folder_path = folder.get_current_dir(true)

	var files = folder.get_files()
	for file in files:
		folder.remove(file)

	var subfolders = folder.get_directories()
	for subfolder_path in subfolders:
		var full_subfolder_path = folder_path + "/" + subfolder_path
		var subfolder = DirAccess.open(full_subfolder_path)
		Helpers.delete_recursive(subfolder)

	DirAccess.remove_absolute(folder_path)
