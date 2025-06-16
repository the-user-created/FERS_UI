class_name PulseEditor
extends BasePropertyEditor

func _rebuild_ui() -> void:
	_add_string_editor("Name", "name", current_element_data.get("name", "Unnamed"))
	add_child(HSeparator.new())

	_add_option_button("Pulse Type", "pulse_type_actual", ["file", "custom"], current_element_data.get("pulse_type_actual", "file"))
	_add_numerical_editor("Power (W)", "power", float(current_element_data.get("power", 100.0)), true, false)
	_add_numerical_editor("Carrier Freq (Hz)", "carrier_frequency", float(current_element_data.get("carrier_frequency", 10e9)), true, false)

	if current_element_data.get("pulse_type_actual", "file") == "file":
		_add_file_picker("Waveform Filename", "pulse_filename", current_element_data.get("pulse_filename", ""), "Select Waveform File (*.csv)")
