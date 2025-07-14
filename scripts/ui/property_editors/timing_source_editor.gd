class_name TimingSourceEditor
extends BasePropertyEditor

func _rebuild_ui() -> void:
	_add_string_editor("Name", "name", current_element_data.get("name", "Unnamed Timing Source"))
	add_child(HSeparator.new())

	_add_numerical_editor("Frequency (Hz)", "frequency", float(current_element_data.get("frequency", 10_000_000)), true, false)
	_add_numerical_editor("Frequency Offset (Hz)", "freq_offset", float(current_element_data.get("freq_offset", 0.0)), true, true)
	_add_numerical_editor("Random Freq Offset (Hz)", "random_freq_offset", float(current_element_data.get("random_freq_offset", 0.0)), true, true)
	_add_numerical_editor("Phase Offset (deg)", "phase_offset", float(current_element_data.get("phase_offset", 0.0)), true, true)
	_add_numerical_editor("Random Phase Offset (deg)", "random_phase_offset", float(current_element_data.get("random_phase_offset", 0.0)), true, true)
	_add_checkbox("Sync on Pulse", "synconpulse", bool(current_element_data.get("synconpulse", true)))
	add_child(HSeparator.new())
	_rebuild_noise_ui()

func _rebuild_noise_ui() -> void:
	_add_title_label("Phase Noise Entries")

	var noise_vbox := VBoxContainer.new()
	add_child(noise_vbox)

	var noise_entries: Array = current_element_data.get("noise_entries", []).duplicate()

	if noise_entries.is_empty():
		var no_entries_label := Label.new()
		no_entries_label.text = "No phase noise entries defined."
		no_entries_label.modulate = Color.GRAY
		noise_vbox.add_child(no_entries_label)

	for i in range(noise_entries.size()):
		var entry: Dictionary = noise_entries[i]
		var hbox := HBoxContainer.new()

		var alpha_label := Label.new(); alpha_label.text = "Alpha:"
		hbox.add_child(alpha_label)
		var alpha_spinbox := SpinBox.new()
		alpha_spinbox.min_value = -2; alpha_spinbox.max_value = 2; alpha_spinbox.step = 1
		alpha_spinbox.value = entry.get("alpha", 0)
		alpha_spinbox.value_changed.connect(_on_noise_alpha_changed.bind(i))
		hbox.add_child(alpha_spinbox)

		var weight_label := Label.new(); weight_label.text = "Weight:"
		hbox.add_child(weight_label)
		var weight_edit := NumericLineEdit.new()
		weight_edit.allow_float = true; weight_edit.allow_negative = true
		weight_edit.text = str(entry.get("weight", 0.0))
		weight_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var commit_func = func(text_val): _on_noise_weight_changed(text_val.to_float(), i)
		weight_edit.text_submitted.connect(commit_func)
		weight_edit.focus_exited.connect(func(): commit_func.call(weight_edit.text))
		hbox.add_child(weight_edit)

		var remove_button := Button.new(); remove_button.text = "X"
		remove_button.pressed.connect(_on_remove_noise_entry.bind(i))
		hbox.add_child(remove_button)

		noise_vbox.add_child(hbox)

	var add_button := Button.new(); add_button.text = "Add Noise Entry"
	add_button.pressed.connect(_on_add_noise_entry)
	noise_vbox.add_child(add_button)


func _on_add_noise_entry() -> void:
	var noise_entries: Array = current_element_data.get("noise_entries", []).duplicate(true)
	noise_entries.append({"alpha": 0, "weight": 0.0})
	_emit_property_change("noise_entries", noise_entries)


func _on_remove_noise_entry(index: int) -> void:
	var noise_entries: Array = current_element_data.get("noise_entries", []).duplicate(true)
	if index >= 0 and index < noise_entries.size():
		noise_entries.remove_at(index)
		_emit_property_change("noise_entries", noise_entries)


func _on_noise_alpha_changed(new_value: float, index: int) -> void:
	var noise_entries: Array = current_element_data.get("noise_entries", []).duplicate(true)
	if index >= 0 and index < noise_entries.size():
		noise_entries[index]["alpha"] = int(new_value)
		current_element_data["noise_entries"] = noise_entries # Update local copy before emitting
		_emit_property_change("noise_entries", noise_entries)


func _on_noise_weight_changed(new_value: float, index: int) -> void:
	var noise_entries: Array = current_element_data.get("noise_entries", []).duplicate(true)
	if index >= 0 and index < noise_entries.size():
		noise_entries[index]["weight"] = new_value
		current_element_data["noise_entries"] = noise_entries # Update local copy before emitting
		_emit_property_change("noise_entries", noise_entries)
