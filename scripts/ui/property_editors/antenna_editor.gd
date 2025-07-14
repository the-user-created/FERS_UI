class_name AntennaEditor
extends BasePropertyEditor


func _rebuild_ui() -> void:
	_add_string_editor("Name", "name", current_element_data.get("name", "Unnamed"))
	_add_numerical_editor("Efficiency", "efficiency", float(current_element_data.get("efficiency", 1.0)), true, false)
	add_child(HSeparator.new())

	var patterns_opts: Array[Variant] = ["isotropic", "sinc", "gaussian", "squarehorn", "parabolic", "xml", "file"]
	_add_option_button("Antenna Pattern", "antenna_pattern_actual", patterns_opts, current_element_data.get("antenna_pattern_actual", "isotropic"))

	var pattern_type = current_element_data.get("antenna_pattern_actual", "isotropic")
	
	_add_title_label("Pattern Parameters")

	match pattern_type:
		"sinc":
			_add_numerical_editor("Alpha", "alpha", float(current_element_data.get("alpha", 1.0)))
			_add_numerical_editor("Beta", "beta", float(current_element_data.get("beta", 1.0)))
			_add_numerical_editor("Gamma", "gamma", float(current_element_data.get("gamma", 1.0)))
		"gaussian":
			_add_numerical_editor("Azimuth Scale", "azscale", float(current_element_data.get("azscale", 1.0)), true, false)
			_add_numerical_editor("Elevation Scale", "elscale", float(current_element_data.get("elscale", 1.0)), true, false)
		"squarehorn", "parabolic":
			_add_numerical_editor("Diameter (m)", "diameter", float(current_element_data.get("diameter", 1.0)), true, false)
		"xml", "file":
			_add_file_picker("Pattern Filename", "filename", current_element_data.get("filename", ""), "Select Antenna Pattern File (*.xml, *.csv)")
		"isotropic":
			var label = Label.new()
			label.text = "No parameters for Isotropic pattern."
			label.modulate = Color.GRAY
			add_child(label)
