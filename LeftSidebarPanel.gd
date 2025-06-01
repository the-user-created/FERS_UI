# LeftSidebarPanel.gd
class_name LeftPropertiesPanel
extends ScrollContainer

signal property_changed(element_id: String, property_key: String, new_value: Variant)

@onready var VBox_content: VBoxContainer = $PropertiesVBox

var current_element_id: String
var current_element_data: Dictionary
var main_simulation_data_ref: Dictionary

var file_dialog: FileDialog

func _ready() -> void:
	name = "LeftPropertiesPanel"
	# Minimum size and flags are set in the scene, but can be asserted here
	# custom_minimum_size = Vector2(300, 0)
	# size_flags_horizontal = Control.SIZE_SHRINK_BEGIN 
	# size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Prepare FileDialog for later use
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Open File"
	add_child(file_dialog) # Add to scene tree to make it work
	file_dialog.hide() # Keep it hidden until needed

func clear_panel() -> void:
	for child in VBox_content.get_children():
		child.queue_free()
	current_element_id = ""
	current_element_data = {}

func display_properties(element_id: String, element_data: Dictionary, all_sim_data: Dictionary) -> void:
	clear_panel()
	current_element_id = element_id
	current_element_data = element_data 
	main_simulation_data_ref = all_sim_data

	var element_type: String = element_data.get("type", "")

	# Common "Name" field for modifiable elements (except global ones)
	if element_type != "global_simulation_name" and element_type != "global_simulation_parameters":
		_add_string_editor("Name", "name", element_data.get("name", "Unnamed"), element_id)
		VBox_content.add_child(HSeparator.new())

	match element_type:
		"global_simulation_name":
			_add_string_editor("Simulation Name", "name_value", element_data.get("name_value", "SimName"), element_id)
		"global_simulation_parameters":
			_add_float_editor("Start Time (s)", "start_time", float(element_data.get("start_time", 0.0)), element_id, 0.0)
			_add_float_editor("End Time (s)", "end_time", float(element_data.get("end_time", 1.0)), element_id, 0.0)
			_add_float_editor("Sampling Rate (Hz)", "sampling_rate", float(element_data.get("sampling_rate", 1e6)), element_id, 1.0)
		"platform":
			_populate_platform_properties(element_id, element_data)
		"pulse":
			_populate_pulse_properties(element_id, element_data)
		"timing_source":
			_populate_timing_source_properties(element_id, element_data)
		"antenna":
			_populate_antenna_properties(element_id, element_data)
		_:
			var label = Label.new()
			label.text = "Select an element to see its properties."
			if element_type != "":
				label.text = "No properties to display for type: " + element_type
			VBox_content.add_child(label)

# --- UI Element Creation Helpers ---
func _add_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	VBox_content.add_child(label)
	return label

func _add_string_editor(label_text: String, property_key: String, current_value: String, element_id: String) -> LineEdit:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var line_edit = LineEdit.new()
	line_edit.text = current_value
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.connect("text_changed", Callable(self, "_on_property_value_changed").bind(element_id, property_key, line_edit))
	hbox.add_child(line_edit)
	
	VBox_content.add_child(hbox)
	return line_edit

func _add_float_editor(label_text: String, property_key: String, current_value: float, element_id: String, min_val: float = -1e10, max_val: float = 1e10, step: float = 0.01) -> SpinBox:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var spin_box = SpinBox.new()
	spin_box.min_value = min_val
	spin_box.max_value = max_val
	spin_box.step = step
	spin_box.value = current_value
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_box.connect("value_changed", Callable(self, "_on_property_value_changed").bind(element_id, property_key, spin_box))
	hbox.add_child(spin_box)
	
	VBox_content.add_child(hbox)
	return spin_box

func _add_option_button(label_text: String, property_key: String, options: Array, current_selection_value: Variant, element_id: String) -> OptionButton:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var option_button = OptionButton.new()
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_idx = -1
	for i in range(options.size()):
		var option_item = options[i]
		if typeof(option_item) == TYPE_DICTIONARY: # For {"name": "Display Name", "value": "internal_value"}
			option_button.add_item(option_item.name)
			if option_item.value == current_selection_value:
				selected_idx = i
		else: # For simple string arrays
			option_button.add_item(str(option_item))
			if str(option_item) == str(current_selection_value):
				selected_idx = i
	if selected_idx != -1:
		option_button.select(selected_idx)
	
	option_button.connect("item_selected", Callable(self, "_on_option_button_selected").bind(element_id, property_key, option_button, options))
	hbox.add_child(option_button)
	
	VBox_content.add_child(hbox)
	return option_button

func _add_checkbox(label_text: String, property_key: String, is_checked: bool, element_id: String) -> CheckBox:
	var check_box = CheckBox.new()
	check_box.text = label_text
	check_box.button_pressed = is_checked
	check_box.connect("toggled", Callable(self, "_on_property_value_changed").bind(element_id, property_key, check_box))
	VBox_content.add_child(check_box)
	return check_box

func _add_file_picker(label_text: String, property_key: String, current_path: String, element_id: String, dialog_title: String = "Select File") -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Give some space to label
	hbox.add_child(label)

	var line_edit = LineEdit.new()
	line_edit.text = current_path
	line_edit.editable = false # Or true if manual path entry is desired
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.name = "PathLineEdit" # To find it later
	hbox.add_child(line_edit)

	var button = Button.new()
	button.text = "Browse..."
	button.connect("pressed", Callable(self, "_on_browse_file_pressed").bind(element_id, property_key, line_edit, dialog_title))
	hbox.add_child(button)

	VBox_content.add_child(hbox)
	return hbox

# --- Property Population Methods ---
func _populate_platform_properties(element_id: String, data: Dictionary) -> void:
	var platform_types = [
		{"name": "Monostatic", "value": "monostatic"},
		{"name": "Transmitter", "value": "transmitter"},
		{"name": "Receiver", "value": "receiver"},
		{"name": "Target", "value": "target"}
	]
	_add_option_button("Platform Type", "platform_type_actual", platform_types, data.get("platform_type_actual", "target"), element_id)

	_add_float_editor("Position X (m)", "position_x", float(data.get("position_x", 0.0)), element_id)
	_add_float_editor("Position Y (m)", "position_y", float(data.get("position_y", 0.0)), element_id)
	_add_float_editor("Altitude (m)", "altitude", float(data.get("altitude", 0.0)), element_id)

	VBox_content.add_child(HSeparator.new())
	_add_label("Type-Specific Properties:")

	var actual_platform_type = data.get("platform_type_actual", "target")
	match actual_platform_type:
		"monostatic":
			_add_option_button("Radar Type", "monostatic_radar_type", ["pulsed", "continuous"], data.get("monostatic_radar_type", "continuous"), element_id)
			_add_float_editor("PRF (Hz)", "monostatic_prf", float(data.get("monostatic_prf", "1")), element_id, 0)
			_add_float_editor("Window Skip (s)", "monostatic_window_skip", float(data.get("monostatic_window_skip", "0")), element_id, 0)
			_add_float_editor("Window Length (s)", "monostatic_window_length", float(data.get("monostatic_window_length", "0.1")), element_id, 0)
			_add_float_editor("Noise Temp (K)", "monostatic_noise_temp", float(data.get("monostatic_noise_temp", "0")), element_id, 0)
			_add_checkbox("No Direct Path", "monostatic_nodirect", bool(data.get("monostatic_nodirect", false)), element_id)
			_add_checkbox("No Prop Loss", "monostatic_nopropagationloss", bool(data.get("monostatic_nopropagationloss", false)), element_id)
			_add_dynamic_dropdown("Antenna", "monostatic_antenna_id_ref", "antenna", data.get("monostatic_antenna_id_ref", ""), element_id)
			_add_dynamic_dropdown("Pulse", "monostatic_pulse_id_ref", "pulse", data.get("monostatic_pulse_id_ref", ""), element_id)
			_add_dynamic_dropdown("Timing Src", "monostatic_timing_id_ref", "timing_source", data.get("monostatic_timing_id_ref", ""), element_id)
		"transmitter":
			_add_option_button("Transmitter Type", "transmitter_type_actual", ["pulsed", "continuous"], data.get("transmitter_type_actual", "pulsed"), element_id)
			if data.get("transmitter_type_actual", "pulsed") == "pulsed":
				_add_float_editor("PRF (Hz)", "transmitter_prf", float(data.get("transmitter_prf", "1000")), element_id, 0)
			_add_dynamic_dropdown("Pulse", "transmitter_pulse_id_ref", "pulse", data.get("transmitter_pulse_id_ref", ""), element_id)
			_add_dynamic_dropdown("Antenna", "transmitter_antenna_id_ref", "antenna", data.get("transmitter_antenna_id_ref", ""), element_id)
			_add_dynamic_dropdown("Timing Src", "transmitter_timing_id_ref", "timing_source", data.get("transmitter_timing_id_ref", ""), element_id)
		"receiver":
			_add_float_editor("PRF (Hz)", "receiver_prf", float(data.get("receiver_prf", "1000")), element_id, 0)
			_add_float_editor("Window Skip (s)", "receiver_window_skip", float(data.get("receiver_window_skip", "0")), element_id, 0)
			_add_float_editor("Window Length (s)", "receiver_window_length", float(data.get("receiver_window_length", "0.1")), element_id, 0)
			_add_float_editor("Noise Temp (K)", "receiver_noise_temp", float(data.get("receiver_noise_temp", "290")), element_id, 0)
			_add_checkbox("No Direct Path", "receiver_nodirect", bool(data.get("receiver_nodirect", false)), element_id)
			_add_checkbox("No Prop Loss", "receiver_nopropagationloss", bool(data.get("receiver_nopropagationloss", false)), element_id)
			_add_dynamic_dropdown("Antenna", "receiver_antenna_id_ref", "antenna", data.get("receiver_antenna_id_ref", ""), element_id)
			_add_dynamic_dropdown("Timing Src", "receiver_timing_id_ref", "timing_source", data.get("receiver_timing_id_ref", ""), element_id)
		"target":
			_add_option_button("RCS Type", "target_rcs_type_actual", ["isotropic", "file"], data.get("target_rcs_type_actual", "isotropic"), element_id)
			if data.get("target_rcs_type_actual", "isotropic") == "isotropic":
				_add_float_editor("RCS Value (m^2)", "target_rcs_value", float(data.get("target_rcs_value", "10.0")), element_id)
			else: # "file"
				_add_file_picker("RCS Filename", "target_rcs_filename", data.get("target_rcs_filename", ""), element_id, "Select RCS File")
			
			_add_option_button("Fluctuation Model", "target_rcs_fluctuation_model_type", ["constant", "chisquare", "gamma"], data.get("target_rcs_fluctuation_model_type", "constant"), element_id)
			var fluct_model = data.get("target_rcs_fluctuation_model_type", "constant")
			if fluct_model == "constant":
				_add_float_editor("Fluctuation Value", "target_rcs_fluctuation_value", float(data.get("target_rcs_fluctuation_value", "1.0")), element_id)
			elif fluct_model == "chisquare" or fluct_model == "gamma":
				_add_float_editor("Fluctuation K Param", "target_rcs_fluctuation_k", float(data.get("target_rcs_fluctuation_k", "1")), element_id)

func _populate_pulse_properties(element_id: String, data: Dictionary) -> void:
	_add_option_button("Pulse Type", "pulse_type_actual", ["file", "custom"], data.get("pulse_type_actual", "file"), element_id)
	_add_float_editor("Power (W)", "power", float(data.get("power", 100.0)), element_id)
	_add_float_editor("Carrier Freq (Hz)", "carrier_frequency", float(data.get("carrier_frequency", 10e9)), element_id)
	if data.get("pulse_type_actual", "file") == "file":
		_add_file_picker("Waveform Filename", "pulse_filename", data.get("pulse_filename", ""), element_id, "Select Waveform File")

func _populate_timing_source_properties(element_id: String, data: Dictionary) -> void:
	_add_float_editor("Frequency (Hz)", "frequency", float(data.get("frequency", 1e7)), element_id)

func _populate_antenna_properties(element_id: String, data: Dictionary) -> void:
	var patterns = ["isotropic", "sinc", "gaussian", "squarehorn", "parabolic", "xml", "file"] # Isotropic not in XML schema, but good default
	_add_option_button("Antenna Pattern", "antenna_pattern_actual", patterns, data.get("antenna_pattern_actual", "isotropic"), element_id)
	var pattern = data.get("antenna_pattern_actual", "isotropic")
	if pattern == "xml" or pattern == "file":
		_add_file_picker("Pattern Filename", "filename", data.get("filename", ""), element_id, "Select Antenna Pattern File")

func _add_dynamic_dropdown(label_text: String, property_key: String, item_type_to_list: String, current_selection_id: String, element_id: String) -> OptionButton:
	var items_list = _get_available_elements_of_type(item_type_to_list) 
	
	var options_for_button = []
	options_for_button.append({"name": "None", "value": ""}) 
	for item_dict in items_list:
		options_for_button.append({"name": item_dict.name, "value": item_dict.id})

	# Ensure current_selection_id is a string, defaulting to "" if null
	var current_id_to_select = ""
	if current_selection_id != null: # Check if it's not null
		current_id_to_select = current_selection_id
	
	return _add_option_button(label_text, property_key, options_for_button, current_id_to_select, element_id)

func _get_available_elements_of_type(p_element_type_str: String) -> Array: # Renamed parameter
	var results: Array = []
	if main_simulation_data_ref:
		for key in main_simulation_data_ref:
			var item_data: Dictionary = main_simulation_data_ref[key]
			# Use the new parameter name here
			if item_data.has("type") and item_data.type == p_element_type_str: 
				if item_data.has("id") and item_data.has("name"): # Ensure they have id and name
					results.append({"id": item_data.id, "name": item_data.name})
				else:
					# This might happen for global_simulation_name/parameters if they don't have a "name" field
					# that _add_dynamic_dropdown expects for display. For now, we list items with "id" and "name".
					# If you need to list other types, adjust this logic.
					pass 
	return results

# --- Signal Handlers for Controls ---
func _on_property_value_changed(new_value: Variant, element_id: String, property_key: String, control_node: Control) -> void:
	# For LineEdit, new_value is text. For SpinBox, it's float. For CheckBox, it's bool (toggled state).
	var actual_value = new_value
	if control_node is LineEdit:
		actual_value = control_node.text # text_changed passes the text, but good to be explicit
	elif control_node is SpinBox:
		actual_value = control_node.value
	elif control_node is CheckBox:
		actual_value = control_node.button_pressed

	emit_signal("property_changed", element_id, property_key, actual_value)

func _on_option_button_selected(index: int, element_id: String, property_key: String, option_button: OptionButton, options_array: Array) -> void:
	var selected_value: Variant
	# Check if options_array was an array of dictionaries
	if not options_array.is_empty() and typeof(options_array[0]) == TYPE_DICTIONARY:
		if index >= 0 and index < options_array.size():
			selected_value = options_array[index].value
		else:
			printerr("Invalid index for option button or options_array not in expected format.")
			return
	else: # Simple string array
		if index >= 0 and index < option_button.item_count: # Use item_count if options_array isn't reliable here
			selected_value = option_button.get_item_text(index)
		else:
			printerr("Invalid index for option button.")
			return
			
	emit_signal("property_changed", element_id, property_key, selected_value)

func _on_browse_file_pressed(element_id: String, property_key: String, path_line_edit: LineEdit, dialog_title: String) -> void:
	file_dialog.title = dialog_title
	# The signal connection for file_selected must be specific to this call
	# Disconnect previous if any, or use a more robust system
	if file_dialog.is_connected("file_selected", Callable(self, "_on_file_selected_for_property")):
		file_dialog.disconnect("file_selected", Callable(self, "_on_file_selected_for_property"))
	
	file_dialog.connect("file_selected", Callable(self, "_on_file_selected_for_property").bind(element_id, property_key, path_line_edit), CONNECT_ONE_SHOT)
	file_dialog.popup_centered()

func _on_file_selected_for_property(path: String, element_id: String, property_key: String, path_line_edit: LineEdit) -> void:
	path_line_edit.text = path
	emit_signal("property_changed", element_id, property_key, path)
