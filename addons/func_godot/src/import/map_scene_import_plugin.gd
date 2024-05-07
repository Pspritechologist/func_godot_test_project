@tool
class_name MapSceneImportPlugin
extends EditorSceneFormatImporter

func _get_extensions( ) -> PackedStringArray:
	return PackedStringArray(['map'])

func _import_scene(path: String, flags: int, options: Dictionary) -> Object:
	var tree = SceneTree.new()

	var map_node := FuncGodotMap.new()
	map_node.local_map_file = path
	map_node.block_until_complete = true
	map_node.print_profiling_data = true
	
	tree.root.add_child(map_node)
	
	map_node.verify_and_build()
	
	tree.root.remove_child(map_node)
	tree.free()

	return map_node