class_name LeftSidebarPanel
extends ScrollContainer

signal property_changed(element_id: String, property_key: String, new_value: Variant)
@onready var vbox_content: VBoxContainer = %properties_vbox
const WaypointEditorScene: PackedScene = preload("res://ui/components/ui_waypoint_editor.tscn")
var current_element_id: String = ""
var current_element_data: Dictionary = {}
var main_simulation_data_ref: Dictionary = {}
var _file_picker_context: Dictionary = {}
var file_dialog: FileDialog
var waypoint_editor: WaypointEditor
var _waypoint_editor_context_key: String = ""


func _ready() -> void:
	if not is_instance_valid(vbox_content):
		vbox_content = find_child("PropertiesVBox") as VBoxContainer
		if not is_instance_valid(vbox_content):
			printerr("LeftSidebarPanel: PropertiesVBox not found!")
			vbox_content = VBoxContainer.new()
			add_child(vbox_content)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Open File"

	file_dialog.connect("file_selected", Callable(self, "_on_file_dialog_file_selected"))
	add_child(file_dialog)
	file_dialog.hide()

	waypoint_editor = WaypointEditorScene.instantiate() as WaypointEditor
	waypoint_editor.waypoints_updated.connect(_on_waypoint_editor_updated)
	add_child(waypoint_editor)

	clear_panel()
	_add_label("Select an element from the Scene Hierarchy to view/edit its properties.")


func clear_panel() -> void:
	for child in vbox_content.get_children():
		child.queue_free()
	current_element_id = ""
	current_element_data = {}


func display_properties(element_id: String, element_data: Dictionary, all_sim_data: Dictionary) -> void:
	if not element_data or element_data.is_empty():
		clear_panel()
		_add_label("No data for selected element." if element_id else "Select an element.")
		return

	clear_panel()
	current_element_id = element_id
	current_element_data = element_data.duplicate(true)
	main_simulation_data_ref = all_sim_data

	var element_type: String = current_element_data.get("type", "")

	if element_type != "global_simulation_name" and element_type != "global_simulation_parameters":
		_add_string_editor("Name", "name", current_element_data.get("name", "Unnamed Element"), element_id)
		vbox_content.add_child(HSeparator.new())

	match element_type:
		"global_simulation_name":
			_add_string_editor("Simulation Name", "name_value", current_element_data.get("name_value", "SimName"), element_id)
		"global_simulation_parameters":
			_add_float_editor("Start Time (s)", "start_time", float(current_element_data.get("start_time", 0.0)), element_id, 0.0)
			_add_float_editor("End Time (s)", "end_time", float(current_element_data.get("end_time", 1.0)), element_id, 0.0)
			_add_float_editor("Sampling Rate (Hz)", "sampling_rate", float(current_element_data.get("sampling_rate", 1_000_000.0)), element_id, 1.0)
		"platform":
			_populate_platform_properties(element_id, current_element_data)
		"pulse":
			_populate_pulse_properties(element_id, current_element_data)
		"timing_source":
			_populate_timing_source_properties(element_id, current_element_data)
		"antenna":
			_populate_antenna_properties(element_id, current_element_data)
		"":
			_add_label("Select an element to see its properties.")
		_:
			_add_label("Properties display not implemented for type: " + element_type)


# --- UI Element Creation Helpers ---
func _add_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	vbox_content.add_child(label)
	return label


func _add_string_editor(label_text: String, property_key: String, current_val: String, el_id: String) -> LineEdit:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var line_edit = LineEdit.new()
	line_edit.text = current_val
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.connect("text_changed", Callable(self, "_on_text_property_changed").bind(el_id, property_key, line_edit))
	hbox.add_child(line_edit)
	vbox_content.add_child(hbox)
	return line_edit


func _add_float_editor(label_text: String, property_key: String, current_val: float, el_id: String, min_v: float = -1000000000000, max_v: float = 1000000000000, stp: float = 0.01) -> SpinBox:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var spin_box = SpinBox.new()
	spin_box.min_value = min_v
	spin_box.max_value = max_v
	spin_box.step = stp
	spin_box.value = current_val
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_box.allow_greater = true
	spin_box.allow_lesser = true
	spin_box.connect("value_changed", Callable(self, "_on_numerical_property_changed").bind(el_id, property_key, spin_box))
	hbox.add_child(spin_box)
	vbox_content.add_child(hbox)
	return spin_box


func _add_float_editor_to_container(container: VBoxContainer, label_text: String, current_val: float, min_v: float = -1000000000000, max_v: float = 1000000000000, stp: float = 0.01) -> SpinBox:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var spin_box = SpinBox.new()
	spin_box.min_value = min_v
	spin_box.max_value = max_v
	spin_box.step = stp
	spin_box.value = current_val
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_box.allow_greater = true
	spin_box.allow_lesser = true
	# Note: The caller is responsible for connecting the "value_changed" signal.
	hbox.add_child(spin_box)
	container.add_child(hbox)
	return spin_box


func _add_option_button(label_text: String, property_key: String, options_arr: Array, current_selection_val: Variant, el_id: String) -> OptionButton:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var option_button = OptionButton.new()
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_idx: int = -1

	for i in range(options_arr.size()):
		var option_item = options_arr[i]
		var item_text: String
		var item_value: Variant

		if typeof(option_item) == TYPE_DICTIONARY and option_item.has("name") and option_item.has("value"):
			item_text = str(option_item.name)
			item_value = option_item.value
		else:
			item_text = str(option_item)
			item_value = option_item

		option_button.add_item(item_text, i)
		option_button.set_item_metadata(i, item_value)

		if item_value == current_selection_val:
			selected_idx = i

	if selected_idx != -1:
		option_button.select(selected_idx)
	elif option_button.item_count > 0:
		pass

	option_button.connect("item_selected", Callable(self, "_on_option_button_item_selected").bind(el_id, property_key, option_button))
	hbox.add_child(option_button)
	vbox_content.add_child(hbox)
	return option_button


func _add_checkbox(label_text: String, property_key: String, is_chk: bool, el_id: String) -> CheckBox:
	var check_box = CheckBox.new()
	check_box.text = label_text
	check_box.button_pressed = is_chk
	check_box.connect("toggled", Callable(self, "_on_checkbox_toggled").bind(el_id, property_key, check_box))
	vbox_content.add_child(check_box)
	return check_box


func _add_file_picker(label_text: String, property_key: String, current_pth: String, el_id: String, dialog_title_str: String = "Select File") -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var line_edit = LineEdit.new()
	line_edit.text = current_pth
	line_edit.editable = false
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.name = property_key + "_PathLineEdit"
	hbox.add_child(line_edit)

	var button = Button.new()
	button.text = "Browse..."

	var context: Dictionary = {
		"element_id": el_id,
		"property_key": property_key,
		"line_edit_node": line_edit,
		"dialog_title": dialog_title_str
	}
	button.connect("pressed", Callable(self, "_on_browse_file_button_pressed").bind(context))
	hbox.add_child(button)
	vbox_content.add_child(hbox)
	return hbox


# --- Property Population Methods ---
func _populate_platform_properties(el_id: String, data: Dictionary) -> void:
	var platform_types_options: Array[Variant] = [
		{"name": "Monostatic", "value": "monostatic"}, {"name": "Transmitter", "value": "transmitter"},
		{"name": "Receiver", "value": "receiver"}, {"name": "Target", "value": "target"}
	]
	_add_option_button("Platform Type", "platform_type_actual", platform_types_options, data.get("platform_type_actual", "target"), el_id)

	vbox_content.add_child(HSeparator.new())
	var motion_label := _add_label("Motion Path"); motion_label.add_theme_font_size_override("font_size", 18)

	var motion_path: Dictionary = data.get("motion_path", {})
	_add_option_button("Interpolation", "motion_path_interpolation", ["static", "linear", "cubic"], motion_path.get("interpolation", "static"), el_id)

	var manage_motion_button := Button.new(); manage_motion_button.text = "Manage Motion Waypoints"
	manage_motion_button.pressed.connect(_on_manage_waypoints_pressed.bind("motion_path", "motion"))
	vbox_content.add_child(manage_motion_button)

	vbox_content.add_child(HSeparator.new())
	var rotation_label := _add_label("Rotation Model"); rotation_label.add_theme_font_size_override("font_size", 18)

	var rotation_model: Dictionary = data.get("rotation_model", {})
	_add_option_button("Rotation Type", "rotation_model_type", [{"name": "Fixed Rate", "value": "fixed"}, {"name": "Waypoint Path", "value": "path"}], rotation_model.get("type", "fixed"), el_id)

	match rotation_model.get("type", "fixed"):
		"fixed":
			var fixed_data: Dictionary = rotation_model.get("fixed_rotation_data", {})
			_add_float_editor("Start Azimuth (deg)", "", float(fixed_data.get("start_azimuth", 0.0)), el_id).connect("value_changed", Callable(self, "_on_fixed_rotation_property_changed").bind(el_id, "start_azimuth"))
			_add_float_editor("Start Elevation (deg)", "", float(fixed_data.get("start_elevation", 0.0)), el_id).connect("value_changed", Callable(self, "_on_fixed_rotation_property_changed").bind(el_id, "start_elevation"))
			_add_float_editor("Azimuth Rate (deg/s)", "", float(fixed_data.get("azimuth_rate", 0.0)), el_id).connect("value_changed", Callable(self, "_on_fixed_rotation_property_changed").bind(el_id, "azimuth_rate"))
			_add_float_editor("Elevation Rate (deg/s)", "", float(fixed_data.get("elevation_rate", 0.0)), el_id).connect("value_changed", Callable(self, "_on_fixed_rotation_property_changed").bind(el_id, "elevation_rate"))
		"path":
			var path_data: Dictionary = rotation_model.get("rotation_path_data", {})
			_add_option_button("Interpolation", "rotation_path_interpolation", ["static", "linear", "cubic"], path_data.get("interpolation", "static"), el_id)
			var manage_rot_button := Button.new(); manage_rot_button.text = "Manage Rotation Waypoints"
			manage_rot_button.pressed.connect(_on_manage_waypoints_pressed.bind("rotation_model", "rotation"))
			vbox_content.add_child(manage_rot_button)

	vbox_content.add_child(HSeparator.new())
	var type_specific_label: Label = _add_label("Type-Specific Properties:")
	type_specific_label.add_theme_font_size_override("font_size", 18)
	var actual_platform_type = data.get("platform_type_actual", "target")
	match actual_platform_type:
		"monostatic": _populate_monostatic_subtype_props(el_id, data)
		"transmitter": _populate_transmitter_subtype_props(el_id, data)
		"receiver": _populate_receiver_subtype_props(el_id, data)
		"target": _populate_target_subtype_props(el_id, data)


func _populate_monostatic_subtype_props(el_id: String, data: Dictionary) -> void:
	_add_option_button("Radar Type", "monostatic_radar_type", ["pulsed", "continuous"], data.get("monostatic_radar_type", "continuous"), el_id)
	_add_float_editor("PRF (Hz)", "monostatic_prf", float(data.get("monostatic_prf", 1.0)), el_id, 0.0)
	_add_float_editor("Window Skip (s)", "monostatic_window_skip", float(data.get("monostatic_window_skip", 0.0)), el_id, 0.0)
	_add_float_editor("Window Length (s)", "monostatic_window_length", float(data.get("monostatic_window_length", 0.1)), el_id, 0.0)
	_add_float_editor("Noise Temp (K)", "monostatic_noise_temp", float(data.get("monostatic_noise_temp", 0.0)), el_id, 0.0)
	_add_checkbox("No Direct Path", "monostatic_nodirect", bool(data.get("monostatic_nodirect", false)), el_id)
	_add_checkbox("No Prop Loss", "monostatic_nopropagationloss", bool(data.get("monostatic_nopropagationloss", false)), el_id)
	_add_dynamic_element_dropdown("Antenna", "monostatic_antenna_id_ref", "antenna", data.get("monostatic_antenna_id_ref", ""), el_id)
	_add_dynamic_element_dropdown("Pulse", "monostatic_pulse_id_ref", "pulse", data.get("monostatic_pulse_id_ref", ""), el_id)
	_add_dynamic_element_dropdown("Timing Src", "monostatic_timing_id_ref", "timing_source", data.get("monostatic_timing_id_ref", ""), el_id)


func _populate_transmitter_subtype_props(el_id: String, data: Dictionary) -> void:
	_add_option_button("Transmitter Type", "transmitter_type_actual", ["pulsed", "continuous"], data.get("transmitter_type_actual", "pulsed"), el_id)
	if data.get("transmitter_type_actual", "pulsed") == "pulsed":
		_add_float_editor("PRF (Hz)", "transmitter_prf", float(data.get("transmitter_prf", 1000.0)), el_id, 0.0)
	# Else for "continuous", PRF might be hidden or disabled. Current logic in Main handles refresh.
	_add_dynamic_element_dropdown("Pulse", "transmitter_pulse_id_ref", "pulse", data.get("transmitter_pulse_id_ref", ""), el_id)
	_add_dynamic_element_dropdown("Antenna", "transmitter_antenna_id_ref", "antenna", data.get("transmitter_antenna_id_ref", ""), el_id)
	_add_dynamic_element_dropdown("Timing Src", "transmitter_timing_id_ref", "timing_source", data.get("transmitter_timing_id_ref", ""), el_id)


func _populate_receiver_subtype_props(el_id: String, data: Dictionary) -> void:
	_add_float_editor("PRF (Hz)", "receiver_prf", float(data.get("receiver_prf", 1000.0)), el_id, 0.0)
	_add_float_editor("Window Skip (s)", "receiver_window_skip", float(data.get("receiver_window_skip", 0.0)), el_id, 0.0)
	_add_float_editor("Window Length (s)", "receiver_window_length", float(data.get("receiver_window_length", 0.1)), el_id, 0.0)
	_add_float_editor("Noise Temp (K)", "receiver_noise_temp", float(data.get("receiver_noise_temp", 290.0)), el_id, 0.0)
	_add_checkbox("No Direct Path", "receiver_nodirect", bool(data.get("receiver_nodirect", false)), el_id)
	_add_checkbox("No Prop Loss", "receiver_nopropagationloss", bool(data.get("receiver_nopropagationloss", false)), el_id)
	_add_dynamic_element_dropdown("Antenna", "receiver_antenna_id_ref", "antenna", data.get("receiver_antenna_id_ref", ""), el_id)
	_add_dynamic_element_dropdown("Timing Src", "receiver_timing_id_ref", "timing_source", data.get("receiver_timing_id_ref", ""), el_id)


func _populate_target_subtype_props(el_id: String, data: Dictionary) -> void:
	_add_option_button("RCS Type", "target_rcs_type_actual", ["isotropic", "file"], data.get("target_rcs_type_actual", "isotropic"), el_id)
	if data.get("target_rcs_type_actual", "isotropic") == "isotropic":
		_add_float_editor("RCS Value (m^2)", "target_rcs_value", float(data.get("target_rcs_value", 10.0)), el_id, 0.0)
	else:
		_add_file_picker("RCS Filename", "target_rcs_filename", data.get("target_rcs_filename", ""), el_id, "Select RCS File (*.csv, *.xml)") # Example filter

	_add_option_button("Fluctuation Model", "target_rcs_fluctuation_model_type", ["constant", "chisquare", "gamma"], data.get("target_rcs_fluctuation_model_type", "constant"), el_id)
	var fluct_model = data.get("target_rcs_fluctuation_model_type", "constant")
	if fluct_model == "constant":
		_add_float_editor("Fluctuation Value", "target_rcs_fluctuation_value", float(data.get("target_rcs_fluctuation_value", 1.0)), el_id)
	elif fluct_model == "chisquare" or fluct_model == "gamma":
		_add_float_editor("Fluctuation K Param", "target_rcs_fluctuation_k", float(data.get("target_rcs_fluctuation_k", 1.0)), el_id, 0.0)


func _populate_pulse_properties(el_id: String, data: Dictionary) -> void:
	_add_option_button("Pulse Type", "pulse_type_actual", ["file", "custom"], data.get("pulse_type_actual", "file"), el_id)
	_add_float_editor("Power (W)", "power", float(data.get("power", 100.0)), el_id, 0.0)
	_add_float_editor("Carrier Freq (Hz)", "carrier_frequency", float(data.get("carrier_frequency", 10_000_000_000.0)), el_id, 0.0)
	if data.get("pulse_type_actual", "file") == "file":
		_add_file_picker("Waveform Filename", "pulse_filename", data.get("pulse_filename", ""), el_id, "Select Waveform File (*.csv)")


func _populate_timing_source_properties(el_id: String, data: Dictionary) -> void:
	_add_float_editor("Frequency (Hz)", "frequency", float(data.get("frequency", 10_000_000.0)), el_id, 1.0)


func _populate_antenna_properties(el_id: String, data: Dictionary) -> void:
	var patterns_opts: Array[Variant] = ["isotropic", "sinc", "gaussian", "squarehorn", "parabolic", "xml", "file"]
	_add_option_button("Antenna Pattern", "antenna_pattern_actual", patterns_opts, data.get("antenna_pattern_actual", "isotropic"), el_id)
	var pattern_type = data.get("antenna_pattern_actual", "isotropic")
	if pattern_type == "xml" or pattern_type == "file":
		_add_file_picker("Pattern Filename", "filename", data.get("filename", ""), el_id, "Select Antenna Pattern File (*.xml, *.csv)")


func _add_dynamic_element_dropdown(label_text: String, property_key: String, item_type_to_list: String, current_selection_id_val: String, el_id: String) -> OptionButton:
	var available_elements: Array = _get_available_elements_by_type(item_type_to_list)
	var options_for_btn: Array[Variant] = [{"name": "None (Select)", "value": ""}]
	for item_dict in available_elements:
		options_for_btn.append({"name": str(item_dict.name), "value": str(item_dict.id)})
	return _add_option_button(label_text, property_key, options_for_btn, current_selection_id_val, el_id)


func _get_available_elements_by_type(target_element_type: String) -> Array:
	var results: Array = []
	if main_simulation_data_ref:
		for key in main_simulation_data_ref:
			var item_data: Dictionary = main_simulation_data_ref[key]
			if item_data.has("type") and item_data.type == target_element_type:
				if item_data.has("id") and item_data.has("name"):
					results.append({"id": item_data.id, "name": item_data.name})
	return results


# --- Signal Callbacks for Property Changes ---
func _on_text_property_changed(new_text: String, el_id: String, prop_key: String, _line_edit_node: LineEdit) -> void:
	emit_signal("property_changed", el_id, prop_key, new_text)


func _on_numerical_property_changed(new_value: float, el_id: String, prop_key: String, _spin_box_node: SpinBox) -> void:
	emit_signal("property_changed", el_id, prop_key, new_value)


func _on_checkbox_toggled(button_pressed_state: bool, el_id: String, prop_key: String, _check_box_node: CheckBox) -> void:
	emit_signal("property_changed", el_id, prop_key, button_pressed_state)


func _on_option_button_item_selected(item_idx: int, el_id: String, prop_key: String, option_button_node: OptionButton) -> void:
	if item_idx >= 0 and item_idx < option_button_node.item_count:
		var selected_value = option_button_node.get_item_metadata(item_idx)
		emit_signal("property_changed", el_id, prop_key, selected_value)
	else:
		printerr("LeftSidebarPanel: Invalid index '", item_idx, "' for OptionButton '", option_button_node.name, "' (Key: ", prop_key, ")")


func _on_browse_file_button_pressed(context: Dictionary) -> void:
	_file_picker_context = context
	file_dialog.title = context.get("dialog_title", "Open File")
	# TODO: Potentially set file filters here: file_dialog.filters = ["*.csv", "*.xml"]
	file_dialog.popup_centered()


func _on_file_dialog_file_selected(path: String) -> void:
	if _file_picker_context.is_empty():
		printerr("LeftSidebarPanel: File selected but _file_picker_context is missing.")
		return

	var line_edit_node: LineEdit = _file_picker_context.get("line_edit_node") as LineEdit
	if is_instance_valid(line_edit_node):
		line_edit_node.text = path

	emit_signal("property_changed",
	_file_picker_context.element_id,
	_file_picker_context.property_key,
	path
	)
	_file_picker_context.clear()


func _on_fixed_rotation_property_changed(new_value: float, el_id: String, prop_key: String) -> void:
	if el_id != current_element_id: return

	var rotation_model: Dictionary = current_element_data.get("rotation_model")
	if rotation_model is Dictionary:
		var fixed_data: Dictionary = rotation_model.get("fixed_rotation_data")
		if fixed_data is Dictionary:
			fixed_data[prop_key] = new_value
			emit_signal("property_changed", el_id, "rotation_model", rotation_model)


func _on_manage_waypoints_pressed(property_key: String, type: String) -> void:
	_waypoint_editor_context_key = property_key
	var waypoints: Array = []
	if property_key == "motion_path":
		waypoints = current_element_data.get(property_key, {}).get("waypoints", [])
	elif property_key == "rotation_model":
		waypoints = current_element_data.get(property_key, {}).get("rotation_path_data", {}).get("waypoints", [])

	waypoint_editor.open_with_data(waypoints, type)


func _on_waypoint_editor_updated(new_waypoints_array: Array) -> void:
	if _waypoint_editor_context_key.is_empty(): return

	var data_to_update: Dictionary
	if _waypoint_editor_context_key == "motion_path":
		data_to_update = current_element_data.get(_waypoint_editor_context_key, {})
		data_to_update["waypoints"] = new_waypoints_array
	elif _waypoint_editor_context_key == "rotation_model":
		data_to_update = current_element_data.get(_waypoint_editor_context_key, {})
		data_to_update.get("rotation_path_data", {})["waypoints"] = new_waypoints_array
	else:
		return

	emit_signal("property_changed", current_element_id, _waypoint_editor_context_key, data_to_update)
