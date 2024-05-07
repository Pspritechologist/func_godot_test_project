@tool
class_name MapScenePostImportPlugin
extends EditorScenePostImportPlugin

func _get_import_options(path: String) -> void:
	if !path.ends_with(".map"):
		return
		
	add_import_option("map_settings", load("res://addons/func_godot/func_godot_default_map_settings.tres"))
