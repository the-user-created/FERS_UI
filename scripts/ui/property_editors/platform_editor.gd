class_name PlatformEditor
extends BasePropertyEditor

const WaypointEditorScene: PackedScene = preload("res://ui/components/ui_waypoint_editor.tscn")
var waypoint_editor: WaypointEditor
var _waypoint_editor_context_key: String = ""


func _ready() -> void:
	super()
	# Instantiate and manage the WaypointEditor dialog specific to platforms.
	waypoint_editor = WaypointEditorScene.instantiate() as WaypointEditor
	waypoint_editor.waypoints_updated.connect(_on_waypoint_editor_updated)
	add_child(waypoint_editor)


func display_properties(element_id: String, element_data: Dictionary) -> void:
	current_element_id = element_id
	current_element_data = element_data.duplicate(true)

	# Clear any UI from a previously selected element, but preserve the waypoint editor dialog.
	for child in get_children():
		if child != waypoint_editor:
			child.queue_free()

	# Call the virtual method that child classes MUST implement.
	_rebuild_ui()
	_add_delete_button_if_applicable()


func _rebuild_ui() -> void:
	_add_string_editor("Name", "name", current_element_data.get("name", "Unnamed"))
	add_child(HSeparator.new())

	# --- Platform Type ---
	var platform_types = [
		{"name": "Monostatic", "value": "monostatic"}, {"name": "Transmitter", "value": "transmitter"},
		{"name": "Receiver", "value": "receiver"}, {"name": "Target", "value": "target"}
	]
	_add_option_button("Platform Type", "platform_type_actual", platform_types, current_element_data.get("platform_type_actual", "target"))
	add_child(HSeparator.new())

	# --- Motion Path ---
	_add_title_label("Motion Path")
	var motion_path = current_element_data.get("motion_path", {})
	_add_option_button("Interpolation", "motion_path_interpolation", ["static", "linear", "cubic"], motion_path.get("interpolation", "static"))
	var manage_motion_button := Button.new(); manage_motion_button.text = "Manage Motion Waypoints"
	manage_motion_button.pressed.connect(_on_manage_waypoints_pressed.bind("motion_path", "motion"))
	add_child(manage_motion_button)
	add_child(HSeparator.new())

	# --- Rotation Model ---
	_add_title_label("Rotation Model")
	var rotation_model = current_element_data.get("rotation_model", {})
	var rotation_types = [{"name": "Fixed Rate", "value": "fixed"}, {"name": "Waypoint Path", "value": "path"}]
	_add_option_button("Rotation Type", "rotation_model_type", rotation_types, rotation_model.get("type", "fixed"))

	match rotation_model.get("type", "fixed"):
		"fixed":
			var fixed_data = rotation_model.get("fixed_rotation_data", {})
			var az_edit: NumericLineEdit = _add_numerical_editor("Start Azimuth (deg)", "rotation_model.fixed_rotation_data.start_azimuth", float(fixed_data.get("start_azimuth", 0.0)))
			var el_edit: NumericLineEdit = _add_numerical_editor("Start Elevation (deg)", "rotation_model.fixed_rotation_data.start_elevation", float(fixed_data.get("start_elevation", 0.0)))
			var az_rate_edit: NumericLineEdit = _add_numerical_editor("Azimuth Rate (deg/s)", "rotation_model.fixed_rotation_data.azimuth_rate", float(fixed_data.get("azimuth_rate", 0.0)))
			var el_rate_edit: NumericLineEdit = _add_numerical_editor("Elevation Rate (deg/s)", "rotation_model.fixed_rotation_data.elevation_rate", float(fixed_data.get("elevation_rate", 0.0)))

			# Connect to the new nested property helper
			az_edit.text_submitted.connect(func(val): _on_nested_property_changed(val.to_float(), "rotation_model", "fixed_rotation_data.start_azimuth"))
			el_edit.text_submitted.connect(func(val): _on_nested_property_changed(val.to_float(), "rotation_model", "fixed_rotation_data.start_elevation"))
			az_rate_edit.text_submitted.connect(func(val): _on_nested_property_changed(val.to_float(), "rotation_model", "fixed_rotation_data.azimuth_rate"))
			el_rate_edit.text_submitted.connect(func(val): _on_nested_property_changed(val.to_float(), "rotation_model", "fixed_rotation_data.elevation_rate"))

		"path":
			var path_data = rotation_model.get("rotation_path_data", {})
			_add_option_button("Interpolation", "rotation_path_interpolation", ["static", "linear", "cubic"], path_data.get("interpolation", "static"))
			var manage_rot_button := Button.new(); manage_rot_button.text = "Manage Rotation Waypoints"
			manage_rot_button.pressed.connect(_on_manage_waypoints_pressed.bind("rotation_model", "rotation"))
			add_child(manage_rot_button)
	add_child(HSeparator.new())

	# --- Type-Specific Properties ---
	var actual_platform_type = current_element_data.get("platform_type_actual", "target")
	_add_title_label("%s Properties" % actual_platform_type.capitalize())
	match actual_platform_type:
		"monostatic": _populate_monostatic_props()
		"transmitter": _populate_transmitter_props()
		"receiver": _populate_receiver_props()
		"target": _populate_target_props()


func _populate_monostatic_props() -> void:
	_add_option_button("Radar Type", "monostatic_radar_type", ["pulsed", "continuous"], current_element_data.get("monostatic_radar_type", "continuous"))
	_add_numerical_editor("PRF (Hz)", "monostatic_prf", float(current_element_data.get("monostatic_prf", 1.0)), true, false)
	_add_numerical_editor("Window Skip (s)", "monostatic_window_skip", float(current_element_data.get("monostatic_window_skip", 0.0)), true, true)
	_add_numerical_editor("Window Length (s)", "monostatic_window_length", float(current_element_data.get("monostatic_window_length", 0.1)), true, false)
	_add_numerical_editor("Noise Temp (K)", "monostatic_noise_temp", float(current_element_data.get("monostatic_noise_temp", 0.0)), true, false)
	_add_checkbox("No Direct Path", "monostatic_nodirect", bool(current_element_data.get("monostatic_nodirect", false)))
	_add_checkbox("No Prop Loss", "monostatic_nopropagationloss", bool(current_element_data.get("monostatic_nopropagationloss", false)))
	_add_dynamic_element_dropdown("Antenna", "monostatic_antenna_id_ref", "antenna", current_element_data.get("monostatic_antenna_id_ref", ""))
	_add_dynamic_element_dropdown("Pulse", "monostatic_pulse_id_ref", "pulse", current_element_data.get("monostatic_pulse_id_ref", ""))
	_add_dynamic_element_dropdown("Timing Src", "monostatic_timing_id_ref", "timing_source", current_element_data.get("monostatic_timing_id_ref", ""))


func _populate_transmitter_props() -> void:
	_add_option_button("Transmitter Type", "transmitter_type_actual", ["pulsed", "continuous"], current_element_data.get("transmitter_type_actual", "pulsed"))
	if current_element_data.get("transmitter_type_actual", "pulsed") == "pulsed":
		_add_numerical_editor("PRF (Hz)", "transmitter_prf", float(current_element_data.get("transmitter_prf", 1000.0)), true, false)
	_add_dynamic_element_dropdown("Pulse", "transmitter_pulse_id_ref", "pulse", current_element_data.get("transmitter_pulse_id_ref", ""))
	_add_dynamic_element_dropdown("Antenna", "transmitter_antenna_id_ref", "antenna", current_element_data.get("transmitter_antenna_id_ref", ""))
	_add_dynamic_element_dropdown("Timing Src", "transmitter_timing_id_ref", "timing_source", current_element_data.get("transmitter_timing_id_ref", ""))


func _populate_receiver_props() -> void:
	_add_numerical_editor("PRF (Hz)", "receiver_prf", float(current_element_data.get("receiver_prf", 1000.0)), true, false)
	_add_numerical_editor("Window Skip (s)", "receiver_window_skip", float(current_element_data.get("receiver_window_skip", 0.0)), true, true)
	_add_numerical_editor("Window Length (s)", "receiver_window_length", float(current_element_data.get("receiver_window_length", 0.1)), true, false)
	_add_numerical_editor("Noise Temp (K)", "receiver_noise_temp", float(current_element_data.get("receiver_noise_temp", 290.0)), true, false)
	_add_checkbox("No Direct Path", "receiver_nodirect", bool(current_element_data.get("receiver_nodirect", false)))
	_add_checkbox("No Prop Loss", "receiver_nopropagationloss", bool(current_element_data.get("receiver_nopropagationloss", false)))
	_add_dynamic_element_dropdown("Antenna", "receiver_antenna_id_ref", "antenna", current_element_data.get("receiver_antenna_id_ref", ""))
	_add_dynamic_element_dropdown("Timing Src", "receiver_timing_id_ref", "timing_source", current_element_data.get("receiver_timing_id_ref", ""))


func _populate_target_props() -> void:
	_add_option_button("RCS Type", "target_rcs_type_actual", ["isotropic", "file"], current_element_data.get("target_rcs_type_actual", "isotropic"))
	if current_element_data.get("target_rcs_type_actual", "isotropic") == "isotropic":
		_add_numerical_editor("RCS Value (m^2)", "target_rcs_value", float(current_element_data.get("target_rcs_value", 10.0)), true, false)
	else:
		_add_file_picker("RCS Filename", "target_rcs_filename", current_element_data.get("target_rcs_filename", ""), "Select RCS File (*.csv, *.xml)")

	var fluct_model_types = ["constant", "chisquare", "gamma"]
	_add_option_button("Fluctuation Model", "target_rcs_fluctuation_model_type", fluct_model_types, current_element_data.get("target_rcs_fluctuation_model_type", "constant"))
	var fluct_model = current_element_data.get("target_rcs_fluctuation_model_type", "constant")
	if fluct_model == "constant":
		_add_numerical_editor("Fluctuation Value", "target_rcs_fluctuation_value", float(current_element_data.get("target_rcs_fluctuation_value", 1.0)))
	elif fluct_model == "chisquare" or fluct_model == "gamma":
		_add_numerical_editor("Fluctuation K Param", "target_rcs_fluctuation_k", float(current_element_data.get("target_rcs_fluctuation_k", 1.0)), true, false)


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
	var path: String
	if _waypoint_editor_context_key == "motion_path":
		path = "waypoints"
	elif _waypoint_editor_context_key == "rotation_model":
		path = "rotation_path_data.waypoints"
	else:
		return
	_on_nested_property_changed(new_waypoints_array, _waypoint_editor_context_key, path)
