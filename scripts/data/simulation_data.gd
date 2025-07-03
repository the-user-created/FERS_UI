# This is an Autoload script. It acts as a global singleton.
# It is the single source of truth for all simulation element data.
class_name SimulationData
extends Node

## Emitted when a new element is successfully added to the data store.
signal element_added(element_data: Dictionary)
## Emitted when an existing element's data is updated.
signal element_updated(element_id: String, element_data: Dictionary)
## Emitted when an element is removed.
signal element_removed(element_id: String)
## Emitted when a property is being changed in real-time for preview purposes, without committing it to the data store.
signal property_preview_updated(element_id: String, property_key: String, new_value: Variant)
## Emitted when a new element is selected in the UI. The payload is the element's ID.
signal element_selected(element_id: String)
## Emitted when the simulation time is updated during playback.
signal simulation_time_updated(new_time: float)
## Emitted when playback starts or stops.
signal playback_state_changed(is_playing: bool)
# The single source of truth for all data.
var _simulation_elements_data: Dictionary = {}
# The ID of the currently selected element.
var _selected_element_id: String = ""
# --- Playback State ---
var simulation_time: float = 0.0
var is_playing: bool = false

var _id_to_name_map: Dictionary = {}

var _id_counters: Dictionary = {
	"platform": 0,
	"pulse": 0,
	"timing_source": 0,
	"antenna": 0,
}


func _ready() -> void:
	# Load initial default data when the simulation starts.
	# This replaces the logic that was in main.gd
	_simulation_elements_data["sim_name"] = {
		"id": "sim_name",
		"type": "global_simulation_name",
		"name_value": "Default_FERS_Simulation"
	}
	_simulation_elements_data["sim_params"] = {
		"id": "sim_params",
		"type": "global_simulation_parameters",
		"start_time": 0.0,
		"end_time": 1.0,
		"sampling_rate": 1000000.0
	}


func _process(delta: float) -> void:
	if is_playing:
		var end_time: float = get_element_data("sim_params").get("end_time", 1.0)
		simulation_time += delta
		if simulation_time >= end_time:
			simulation_time = end_time
			pause() # Stop playback at the end

		emit_signal("simulation_time_updated", simulation_time)


# --- Public API for Data Manipulation ---
func create_new_element(element_type: String) -> void:
	if not _id_counters.has(element_type):
		printerr("SimulationData: Cannot create element of unknown type '%s'" % element_type)
		return

	# Generate a unique ID and name
	_id_counters[element_type] += 1
	var new_id_num = _id_counters[element_type]
	var new_element_id: String = "%s_%d" % [element_type, new_id_num]
	var new_element_name: String = "%s_%d" % [element_type.capitalize(), new_id_num]

	# Get default data
	var new_data_entry: Dictionary = ElementDefaults.getDefaultData(element_type, new_element_name, new_element_id)
	if new_data_entry.is_empty():
		printerr("SimulationData: Failed to get default data for element type: ", element_type)
		return

	# Add to data store and emit signal
	_simulation_elements_data[new_element_id] = new_data_entry
	emit_signal("element_added", new_data_entry)

	# Automatically select the new element
	set_selected_element_id(new_element_id)


func remove_element(element_id: String) -> void:
	if not _simulation_elements_data.has(element_id):
		printerr("SimulationData: Cannot remove non-existent element: ", element_id)
		return

	var element_data: Dictionary = _simulation_elements_data[element_id]
	var deletable_types := ["platform", "pulse", "timing_source", "antenna"]
	if not element_data.get("type") in deletable_types:
		return

	_simulation_elements_data.erase(element_id)

	if _selected_element_id == element_id:
		set_selected_element_id("sim_name")

	emit_signal("element_removed", element_id)


func update_property_for_preview(element_id: String, property_key: String, new_value: Variant) -> void:
	# This method does NOT change the underlying data, it only emits a signal
	# for views that want to display a live preview of a change.
	emit_signal("property_preview_updated", element_id, property_key, new_value)


func update_element_property(element_id: String, property_key: String, new_value: Variant) -> void:
	if not _simulation_elements_data.has(element_id):
		printerr("SimulationData: Cannot update property for non-existent element: ", element_id)
		return

	var element_data: Dictionary = _simulation_elements_data[element_id]
	var old_name = element_data.get("name", "")

	# Special handling for nested properties
	if property_key == "motion_path_interpolation":
		if element_data.has("motion_path") and element_data.motion_path is Dictionary:
			element_data.motion_path.interpolation = new_value
	elif property_key == "rotation_model_type":
		if element_data.has("rotation_model") and element_data.rotation_model is Dictionary:
			element_data.rotation_model.type = new_value
	elif property_key == "rotation_path_interpolation":
		if element_data.has("rotation_model") and element_data.rotation_model.rotation_path_data is Dictionary:
			element_data.rotation_model.rotation_path_data.interpolation = new_value
	else:
		element_data[property_key] = new_value

	# Special handling for platform subtype changes which requires rebuilding the data structure
	var structural_refresh_keys: Dictionary = ElementDefaults.getStructuralRefreshTriggerKeys()
	var keys_for_current_type = structural_refresh_keys.get(element_data.type, [])

	if property_key in keys_for_current_type and element_data.type == "platform" and property_key == "platform_type_actual":
		element_data = ElementDefaults.preparePlatformDataForSubtypeChange(element_data, new_value)
		_simulation_elements_data[element_id] = element_data

	# If the name changed, ensure the original name property is also updated
	if property_key == "name" or (element_data.type == "global_simulation_name" and property_key == "name_value"):
		var current_name = element_data.get("name", element_data.get("name_value", ""))
		if old_name != current_name:
			# The name change is part of the larger update, so we just emit one signal.
			pass

	emit_signal("element_updated", element_id, element_data)


func set_selected_element_id(element_id: String) -> void:
	if _selected_element_id != element_id:
		_selected_element_id = element_id
		emit_signal("element_selected", _selected_element_id)


# --- Public API for Playback Control ---
func toggle_play_pause() -> void:
	if is_playing:
		pause()
	else:
		play()


func play() -> void:
	var end_time: float = get_element_data("sim_params").get("end_time", 1.0)
	# If playback is at the end, rewind before playing.
	if simulation_time >= end_time:
		rewind()

	is_playing = true
	emit_signal("playback_state_changed", is_playing)


func pause() -> void:
	is_playing = false
	emit_signal("playback_state_changed", is_playing)


func rewind() -> void:
	pause()
	var start_time: float = get_element_data("sim_params").get("start_time", 0.0)
	simulation_time = start_time
	emit_signal("simulation_time_updated", simulation_time)


func step() -> void:
	pause()
	var end_time: float = get_element_data("sim_params").get("end_time", 1.0)
	simulation_time = min(simulation_time + (1.0 / 60.0), end_time)
	emit_signal("simulation_time_updated", simulation_time)


func step_back() -> void:
	pause()
	var start_time: float = get_element_data("sim_params").get("start_time", 0.0)
	simulation_time = max(simulation_time - (1.0 / 60.0), start_time)
	emit_signal("simulation_time_updated", simulation_time)


# --- Public API for Data Access ---
func get_element_data(element_id: String) -> Dictionary:
	return _simulation_elements_data.get(element_id, {}).duplicate(true)


func get_elements_by_type(element_type: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for key in _simulation_elements_data:
		var item_data: Dictionary = _simulation_elements_data[key]
		if item_data.has("type") and item_data.type == element_type:
			results.append(item_data)
	return results


# --- XML EXPORT LOGIC ---
func export_as_xml() -> String:
	_build_id_to_name_map()

	var sim_name: String = get_element_data("sim_name").get("name_value", "FERS_Simulation")
	var sim_params: Dictionary = get_element_data("sim_params")
	var pulses: Array[Dictionary] = get_elements_by_type("pulse")
	var timings: Array[Dictionary] = get_elements_by_type("timing_source")
	var antennas: Array[Dictionary] = get_elements_by_type("antenna")
	var platforms: Array[Dictionary] = get_elements_by_type("platform")

	var xml_parts: Array
	xml_parts.append('<?xml version="1.0" encoding="UTF-8"?>')
	xml_parts.append('<simulation name="%s">' % sim_name)
	
	xml_parts.append(_build_parameters_xml(sim_params, "    "))
	for p in pulses: xml_parts.append(_build_pulse_xml(p, "    "))
	for t in timings: xml_parts.append(_build_timing_xml(t, "    "))
	for a in antennas: xml_parts.append(_build_antenna_xml(a, "    "))
	for p in platforms: xml_parts.append(_build_platform_xml(p, "    "))
	
	xml_parts.append('</simulation>')
	return "\n".join(xml_parts)


func _build_id_to_name_map() -> void:
	_id_to_name_map.clear()
	for key in _simulation_elements_data:
		var element_data: Dictionary = _simulation_elements_data[key]
		var name: String = element_data.get("name", "")
		if not name.is_empty():
			_id_to_name_map[key] = name


func _get_name_from_id(element_id: String) -> String:
	return _id_to_name_map.get(element_id, "")


func _build_parameters_xml(data: Dictionary, indent: String) -> String:
	var parts: Array
	parts.append(indent + "<parameters>")
	parts.append(indent + "    <starttime>%s</starttime>" % data.get("start_time", 0.0))
	parts.append(indent + "    <endtime>%s</endtime>" % data.get("end_time", 1.0))
	parts.append(indent + "    <rate>%s</rate>" % data.get("sampling_rate", 1e6))
	parts.append(indent + "</parameters>")
	return "\n".join(parts)


func _build_pulse_xml(data: Dictionary, indent: String) -> String:
	var parts: Array
	var pulse_type: String = data.get("pulse_type_actual", "file")
	var filename_attr := ' filename="%s"' % data.get("pulse_filename", "") if pulse_type == "file" else ""
	
	parts.append(indent + '<pulse name="%s" type="%s"%s>' % [data.get("name", "unnamed"), pulse_type, filename_attr])
	parts.append(indent + "    <power>%s</power>" % data.get("power", 0.0))
	parts.append(indent + "    <carrier>%s</carrier>" % data.get("carrier_frequency", 0.0))
	parts.append(indent + '</pulse>')
	return "\n".join(parts)


func _build_timing_xml(data: Dictionary, indent: String) -> String:
	var parts: Array
	parts.append(indent + '<timing name="%s">' % data.get("name", "unnamed"))
	parts.append(indent + "    <frequency>%s</frequency>" % data.get("frequency", 1e7))
	parts.append(indent + '</timing>')
	return "\n".join(parts)


func _build_antenna_xml(data: Dictionary, indent: String) -> String:
	var pattern: String = data.get("antenna_pattern_actual", "isotropic")
	var filename_attr := ' filename="%s"' % data.get("filename", "") if pattern in ["xml", "file"] else ""
	return indent + '<antenna name="%s" pattern="%s"%s/>' % [data.get("name", "unnamed"), pattern, filename_attr]


func _build_platform_xml(data: Dictionary, indent: String) -> String:
	var parts: Array
	parts.append(indent + '<platform name="%s">' % data.get("name", "unnamed"))
	parts.append(_build_motion_path_xml(data.get("motion_path", {}), indent + "    "))
	parts.append(_build_rotation_xml(data.get("rotation_model", {}), indent + "    "))
	parts.append(_build_platform_subtype_xml(data, indent + "    "))
	parts.append(indent + '</platform>')
	return "\n".join(parts)


func _build_motion_path_xml(data: Dictionary, indent: String) -> String:
	var parts: Array
	parts.append(indent + '<motionpath interpolation="%s">' % data.get("interpolation", "static"))
	for wp in data.get("waypoints", []):
		parts.append(indent + "    <positionwaypoint>")
		parts.append(indent + "        <x>%s</x>" % wp.get("x", 0.0))
		parts.append(indent + "        <y>%s</y>" % wp.get("y", 0.0))
		parts.append(indent + "        <altitude>%s</altitude>" % wp.get("altitude", 0.0))
		parts.append(indent + "        <time>%s</time>" % wp.get("time", 0.0))
		parts.append(indent + "    </positionwaypoint>")
	parts.append(indent + '</motionpath>')
	return "\n".join(parts)


func _build_rotation_xml(data: Dictionary, indent: String) -> String:
	var parts: Array
	if data.get("type", "fixed") == "fixed":
		var fixed = data.get("fixed_rotation_data", {})
		parts.append(indent + "<fixedrotation>")
		parts.append(indent + "    <startazimuth>%s</startazimuth>" % fixed.get("start_azimuth", 0.0))
		parts.append(indent + "    <startelevation>%s</startelevation>" % fixed.get("start_elevation", 0.0))
		parts.append(indent + "    <azimuthrate>%s</azimuthrate>" % fixed.get("azimuth_rate", 0.0))
		parts.append(indent + "    <elevationrate>%s</elevationrate>" % fixed.get("elevation_rate", 0.0))
		parts.append(indent + "</fixedrotation>")
	else: # path
		var path = data.get("rotation_path_data", {})
		parts.append(indent + '<rotationpath interpolation="%s">' % path.get("interpolation", "static"))
		for wp in path.get("waypoints", []):
			parts.append(indent + "    <rotationwaypoint>")
			parts.append(indent + "        <azimuth>%s</azimuth>" % wp.get("azimuth", 0.0))
			parts.append(indent + "        <elevation>%s</elevation>" % wp.get("elevation", 0.0))
			parts.append(indent + "        <time>%s</time>" % wp.get("time", 0.0))
			parts.append(indent + "    </rotationwaypoint>")
		parts.append(indent + '</rotationpath>')
	return "\n".join(parts)


func _build_platform_subtype_xml(data: Dictionary, indent: String) -> String:
	var subtype: String = data.get("platform_type_actual", "target")
	var inst_name: String = data.get("name", "unnamed") + "_inst"
	var parts: Array

	match subtype:
		"monostatic":
			var ant_name = _get_name_from_id(data.get("monostatic_antenna_id_ref", ""))
			var pul_name = _get_name_from_id(data.get("monostatic_pulse_id_ref", ""))
			var tim_name = _get_name_from_id(data.get("monostatic_timing_id_ref", ""))
			var attrs = 'name="%s" type="%s" antenna="%s" pulse="%s" timing="%s"' % [inst_name, data.get("monostatic_radar_type"), ant_name, pul_name, tim_name]
			if data.get("monostatic_nodirect", false): attrs += ' nodirect="true"'
			if data.get("monostatic_nopropagationloss", false): attrs += ' nopropagationloss="true"'
			parts.append(indent + "<monostatic %s>" % attrs)
			parts.append(indent + "    <window_skip>%s</window_skip>" % data.get("monostatic_window_skip"))
			parts.append(indent + "    <window_length>%s</window_length>" % data.get("monostatic_window_length"))
			parts.append(indent + "    <prf>%s</prf>" % data.get("monostatic_prf"))
			parts.append(indent + "    <noise_temp>%s</noise_temp>" % data.get("monostatic_noise_temp"))
			parts.append(indent + "</monostatic>")
		"transmitter":
			var ant_name = _get_name_from_id(data.get("transmitter_antenna_id_ref", ""))
			var pul_name = _get_name_from_id(data.get("transmitter_pulse_id_ref", ""))
			var tim_name = _get_name_from_id(data.get("transmitter_timing_id_ref", ""))
			var attrs = 'name="%s" type="%s" antenna="%s" pulse="%s" timing="%s"' % [inst_name, data.get("transmitter_type_actual"), ant_name, pul_name, tim_name]
			parts.append(indent + '<transmitter %s>' % attrs)
			parts.append(indent + "    <prf>%s</prf>" % data.get("transmitter_prf"))
			parts.append(indent + "</transmitter>")
		"receiver":
			var ant_name = _get_name_from_id(data.get("receiver_antenna_id_ref", ""))
			var tim_name = _get_name_from_id(data.get("receiver_timing_id_ref", ""))
			var attrs = 'name="%s" antenna="%s" timing="%s"' % [inst_name, ant_name, tim_name]
			if data.get("receiver_nodirect", false): attrs += ' nodirect="true"'
			if data.get("receiver_nopropagationloss", false): attrs += ' nopropagationloss="true"'
			parts.append(indent + "<receiver %s>" % attrs)
			parts.append(indent + "    <window_skip>%s</window_skip>" % data.get("receiver_window_skip"))
			parts.append(indent + "    <window_length>%s</window_length>" % data.get("receiver_window_length"))
			parts.append(indent + "    <prf>%s</prf>" % data.get("receiver_prf"))
			parts.append(indent + "    <noise_temp>%s</noise_temp>" % data.get("receiver_noise_temp"))
			parts.append(indent + "</receiver>")
		"target":
			parts.append(indent + '<target name="%s">' % inst_name)
			var rcs_type = data.get("target_rcs_type_actual", "isotropic")
			var filename_attr = ' filename="%s"' % data.get("target_rcs_filename") if rcs_type == "file" else ""
			parts.append(indent + '    <rcs type="%s"%s>' % [rcs_type, filename_attr])
			if rcs_type == "isotropic":
				parts.append(indent + '        <value>%s</value>' % data.get("target_rcs_value"))
			parts.append(indent + '    </rcs>')
			var model_type = data.get("target_rcs_fluctuation_model_type", "constant")
			if model_type != "constant":
				parts.append(indent + '    <model type="%s">' % model_type)
				if model_type != "constant":
					parts.append(indent + '        <k>%s</k>' % data.get("target_rcs_fluctuation_k"))
				parts.append(indent + '    </model>')
			parts.append(indent + '</target>')

	return "\n".join(parts)
