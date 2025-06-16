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
