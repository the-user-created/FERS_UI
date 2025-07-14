class_name SimParamsEditor
extends BasePropertyEditor

func _rebuild_ui() -> void:
	match current_element_data.type:
		"global_simulation_name":
			_add_title_label("Simulation Name")
			_add_string_editor("Name", "name_value", current_element_data.get("name_value", ""))

		"global_simulation_parameters":
			_add_title_label("Simulation Parameters")
			_add_numerical_editor("Start Time (s)", "start_time", float(current_element_data.get("start_time", 0.0)), true, true)
			_add_numerical_editor("End Time (s)", "end_time", float(current_element_data.get("end_time", 1.0)), true, true)
			_add_numerical_editor("Sampling Rate (Hz)", "sampling_rate", float(current_element_data.get("sampling_rate", 1e6)), true, false)
			add_child(HSeparator.new())
			_add_numerical_editor("Propagation Speed (m/s)", "c", float(current_element_data.get("c", 299792458.0)), true, false)
			_add_numerical_editor("Position Interpolation Rate", "interprate", float(current_element_data.get("interprate", 1000)), false, false)
			_add_numerical_editor("Random Seed", "randomseed", float(current_element_data.get("randomseed", 0)), false, false)
			_add_numerical_editor("ADC Bits", "adc_bits", float(current_element_data.get("adc_bits", 0)), false, false)
			_add_numerical_editor("Oversampling Factor", "oversample", float(current_element_data.get("oversample", 1)), false, false)
			add_child(HSeparator.new())
			_add_title_label("Export Formats")
			var export_data: Dictionary = current_element_data.get("export", {"xml": true, "csv": true, "binary": false})
			_add_checkbox("Export XML", "export.xml", export_data.get("xml", true))
			_add_checkbox("Export CSV", "export.csv", export_data.get("csv", true))
			_add_checkbox("Export Binary", "export.binary", export_data.get("binary", false))
