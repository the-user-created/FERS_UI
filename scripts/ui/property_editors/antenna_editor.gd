class_name AntennaEditor
extends BasePropertyEditor


func _rebuild_ui() -> void:
	_add_string_editor("Name", "name", current_element_data.get("name", "Unnamed"))
	add_child(HSeparator.new())

	var patterns_opts: Array[Variant] = ["isotropic", "sinc", "gaussian", "squarehorn", "parabolic", "xml", "file"]
	_add_option_button("Antenna Pattern", "antenna_pattern_actual", patterns_opts, current_element_data.get("antenna_pattern_actual", "isotropic"))

	var pattern_type = current_element_data.get("antenna_pattern_actual", "isotropic")
	if pattern_type == "xml" or pattern_type == "file":
		_add_file_picker("Pattern Filename", "filename", current_element_data.get("filename", ""), "Select Antenna Pattern File (*.xml, *.csv)")
