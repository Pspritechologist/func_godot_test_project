@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
## Translation resource that parses Quake map files to generate Godot scenes according to [FuncGodotFGDEntity] definitions. It is also used to export an FGD file for use with Quake map editors.
class_name FuncGodotFGDFile
extends Resource

## [Resource] file used to express a set of [FuncGodotFGDEntity] definitions. Can be exported as an FGD file for use with a Quake map editor. Used in conjunction with a [FuncGodotMapSetting] resource to generate nodes in a [FuncGodotMap] node.

## Builds and exports the FGD file.
@export var export_file: bool:
	get:
		return export_file # TODO Converter40 Non existent get function
	set(new_export_file):
		if new_export_file != export_file:
			do_export_file(model_key_word as bool)

func do_export_file(model_key_supported: bool = true) -> void:
	if Engine.is_editor_hint() and get_fgd_classes().size() > 0:
		var config_folder: String = map_editor_game_config_folder;
		if config_folder.is_empty():
			config_folder = FuncGodotProjectConfig.get_setting(FuncGodotProjectConfig.PROPERTY.MAP_EDITOR_GAME_CONFIG_FOLDER)
		if config_folder.is_empty():
			print("Skipping export: No game config folder")
			return

		if fgd_name == "":
			print("Skipping export: Empty FGD name")

		var fgd_file = config_folder + "/" + fgd_name + ".fgd"

		print("Exporting FGD to ", fgd_file)
		var file_obj := FileAccess.open(fgd_file, FileAccess.WRITE)
		file_obj.store_string(build_class_text(model_key_supported))
		file_obj.close()

@export_group("Map Editor")

## The directory to save the FGD file output to. Overrides the [FuncGodotProjectConfig] setting.
@export_global_dir var map_editor_game_config_folder : String

## Some map editors do not support the "model" key word and require the "studio" key word instead. 
## If you get errors in your map editor, try changing this setting. 
## This setting is overridden when the FGD is built via the Game Config resource.
@export_enum("studio","model") var model_key_word: int = 1

@export_group("FGD")

## FGD output filename without the extension.
@export var fgd_name: String = "FuncGodot"

## Array of [FuncGodotFGDFile] resources to include in FGD file output. All of the entities included with these FuncGodotFGDFile resources will be prepended to the outputted FGD file.
@export var base_fgd_files: Array[Resource] = []

## Array of resources that inherit from [FuncGodotFGDEntityClass]. This array defines the entities that will be added to the exported FGD file and the nodes that will be generated in a [FuncGodotMap].
@export var entity_definitions: Array[Resource] = []

func build_class_text(model_key_supported: bool = true) -> String:
	var res : String = ""

	for base_fgd in base_fgd_files:
		res += base_fgd.build_class_text(model_key_supported)
	
	var entities = get_fgd_classes()
	for ent in entities:
		if ent.func_godot_internal:
			continue
		
		var ent_text = ent.build_def_text(model_key_supported)
		res += ent_text
		if ent != entities[-1]:
			res += "\n"
	return res

## This getter does a little bit of validation. Providing only an array of non-null uniquely-named entity definitions
func get_fgd_classes() -> Array:
	var res : Array = []
	for cur_ent_def_ind in range(entity_definitions.size()):
		var cur_ent_def = entity_definitions[cur_ent_def_ind]
		if cur_ent_def == null:
			continue
		elif not (cur_ent_def is FuncGodotFGDEntityClass):
			printerr("Bad value in entity definition set at position %s! Not an entity defintion." % cur_ent_def_ind)
			continue
		res.append(cur_ent_def)
	return res

func get_entity_definitions() -> Dictionary:
	var res : Dictionary = {}

	for base_fgd in base_fgd_files:
		var fgd_res = base_fgd.get_entity_definitions()
		for key in fgd_res:
			res[key] = fgd_res[key]

	for ent in get_fgd_classes():
		# Skip entities without classnames
		if ent.classname.replace(" ","") == "":
			printerr("Skipping " + ent.get_path() + ": Empty classname")
			continue
		
		if ent is FuncGodotFGDPointClass or ent is FuncGodotFGDSolidClass:
			var entity_def = ent.duplicate()
			var meta_properties := {}
			var class_properties := {}
			var class_property_descriptions := {}

			for base_class in _generate_base_class_list(entity_def):
				for meta_property in base_class.meta_properties:
					meta_properties[meta_property] = base_class.meta_properties[meta_property]

				for class_property in base_class.class_properties:
					class_properties[class_property] = base_class.class_properties[class_property]

				for class_property_desc in base_class.class_property_descriptions:
					class_property_descriptions[class_property_desc] = base_class.class_property_descriptions[class_property_desc]

			for meta_property in entity_def.meta_properties:
				meta_properties[meta_property] = entity_def.meta_properties[meta_property]

			for class_property in entity_def.class_properties:
				class_properties[class_property] = entity_def.class_properties[class_property]

			for class_property_desc in entity_def.class_property_descriptions:
				class_property_descriptions[class_property_desc] = entity_def.class_property_descriptions[class_property_desc]

			entity_def.meta_properties = meta_properties
			entity_def.class_properties = class_properties
			entity_def.class_property_descriptions = class_property_descriptions

			res[ent.classname] = entity_def
	return res

func _generate_base_class_list(entity_def : Resource, visited_base_classes = []) -> Array:
	var base_classes : Array = []

	visited_base_classes.append(entity_def.classname)

	# End recursive search if no more base_classes
	if len(entity_def.base_classes) == 0:
		return base_classes

	# Traverse up to the next level of hierarchy, if not already visited
	for base_class in entity_def.base_classes:
		if not base_class.classname in visited_base_classes:
			base_classes.append(base_class)
			base_classes += _generate_base_class_list(base_class, visited_base_classes)
		else:
			printerr(str("Entity '", entity_def.classname,"' contains cycle/duplicate to Entity '", base_class.classname, "'"))

	return base_classes
