class_name TimingSourceEditor
extends BasePropertyEditor

func _rebuild_ui() -> void:
	_add_string_editor("Name", "name", current_element_data.get("name", "Unnamed Timing Source"))
	add_child(HSeparator.new())

	_add_numerical_editor("Frequency (Hz)", "frequency", float(current_element_data.get("frequency", 10_000_000)), true, false)
