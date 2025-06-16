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
## Emitted when a new element is selected in the UI. The payload is the element's ID.
signal element_selected(element_id: String)
# The single source of truth for all data.
var _simulation_elements_data: Dictionary = {}
# The ID of the currently selected element.
var _selected_element_id: String = ""


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


# --- Public API for Data Manipulation ---
func add_new_element(element_type: String, element_name: String, element_id: String) -> void:
	var new_data_entry: Dictionary = ElementDefaults.getDefaultData(element_type, element_name, element_id)

	if new_data_entry.is_empty():
		printerr("SimulationData: Failed to get default data for element type: ", element_type)
		return

	_simulation_elements_data[element_id] = new_data_entry
	emit_signal("element_added", new_data_entry)

	# Automatically select the new element
	set_selected_element_id(element_id)


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
