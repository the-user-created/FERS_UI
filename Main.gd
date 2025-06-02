class_name Main
extends Control

var left_sidebar_panel: LeftSidebarPanel
var world_3d_view: World3DView
var right_sidebar: RightSidebarPanel
var simulation_elements_data: Dictionary = {}


func _ready() -> void:
	call_deferred("_setup_references_and_connections")

	simulation_elements_data["sim_name"] = {
		"id": "sim_name",
		"type": "global_simulation_name",
		"name_value": "Default_FERS_Simulation"
	}

	simulation_elements_data["sim_params"] = {
		"id": "sim_params",
		"type": "global_simulation_parameters",
		"start_time": 0.0,
		"end_time": 1.0,
		"sampling_rate": 1000000.0
	}

	print("Main (Control) scene _ready() completed, deferring further setup.")


func _setup_references_and_connections() -> void:
	var main_layout_node: HBoxContainer = get_node_or_null("MainLayout") as HBoxContainer
	if not is_instance_valid(main_layout_node):
		printerr("Main: MainLayout node not found during deferred setup! Critical error.")
		return

	left_sidebar_panel = main_layout_node.get_node_or_null("LeftSidebar") as LeftSidebarPanel
	world_3d_view = main_layout_node.get_node_or_null("World3DView") as World3DView
	right_sidebar = main_layout_node.get_node_or_null("RightSidebar") as RightSidebarPanel

	if not is_instance_valid(left_sidebar_panel):
		printerr("Main: LeftSidebarPanel node not found during deferred setup!")
		return
	if not is_instance_valid(world_3d_view):
		printerr("Main: World3DView node not found during deferred setup!")
		return
	if not is_instance_valid(right_sidebar):
		printerr("Main: RightSidebarPanel node not found during deferred setup!")
		return

	# Connect signals from Left Sidebar
	left_sidebar_panel.connect("property_changed", Callable(self, "_on_left_sidebar_property_changed"))

	# Connect signals from Right Sidebar
	if right_sidebar.has_signal("element_selected"):
		right_sidebar.connect("element_selected", Callable(self, "_on_right_sidebar_element_selected"))
	else:
		printerr("RightSidebarPanel does not have signal 'element_selected'")

	if right_sidebar.has_signal("add_new_element_requested"):
		right_sidebar.connect("add_new_element_requested", Callable(self, "_on_right_sidebar_add_new_element_requested"))
	else:
		printerr("RightSidebarPanel does not have signal 'add_new_element_requested'")

	# Select default item in RightSidebar
	if right_sidebar and right_sidebar.has_method("select_default_item"):
		right_sidebar.call_deferred("select_default_item")
	else:
		call_deferred("_initial_left_panel_display")

	print("Main (Control) scene: Deferred setup and connections complete.")


func _on_right_sidebar_element_selected(item_metadata: Dictionary) -> void:
	if item_metadata and item_metadata.has("id"):
		var element_id = item_metadata.id
		if simulation_elements_data.has(element_id):
			left_sidebar_panel.display_properties(element_id, simulation_elements_data[element_id], simulation_elements_data)
		else:
			printerr("Main: Selected element ID '", element_id, "' not found in simulation_elements_data.")
			left_sidebar_panel.clear_panel()
	else:
		left_sidebar_panel.clear_panel()


func _on_right_sidebar_add_new_element_requested(new_element_metadata: Dictionary) -> void:
	# print("Main: Add new element requested: ", new_element_metadata) # For debugging

	var element_id: String = new_element_metadata.id
	var element_type: String = new_element_metadata.type
	var element_name: String = new_element_metadata.name

	var new_data_entry: Dictionary = ElementDefaults.get_default_data(element_type, element_name, element_id)

	if new_data_entry.is_empty():
		printerr("Main: Failed to get default data for element type: ", element_type)
		return

	simulation_elements_data[element_id] = new_data_entry
	# print("Main: Created data for '", element_id, "': ", simulation_elements_data[element_id]) # For debugging

	# If it's a platform, delegate 3D visualization to World3DView
	if element_type == "platform":
		if is_instance_valid(world_3d_view):
			world_3d_view.add_platform_visualization(element_id, new_data_entry)
		else:
			printerr("Main: World3DView is not valid when trying to add platform visualization.")

	if right_sidebar and right_sidebar.has_method("create_and_select_tree_item"):
		right_sidebar.call("create_and_select_tree_item", new_element_metadata)
	else:
		printerr("Main: RightSidebarPanel does not have method 'create_and_select_tree_item'")


func _on_left_sidebar_property_changed(element_id: String, property_key: String, new_value: Variant) -> void:
	if not simulation_elements_data.has(element_id):
		printerr("Main: Cannot update property for non-existent element: ", element_id)
		return

	var element_data: Dictionary = simulation_elements_data[element_id]
	element_data[property_key] = new_value
	# print("Main: Updated data for '", element_id, "'. Key: '", property_key, "', New Value: ", new_value) # For debugging

	var name_property_for_type: String = "name"
	if element_data.type == "global_simulation_name":
		name_property_for_type = "name_value"

	if property_key == name_property_for_type:
		if right_sidebar and right_sidebar.has_method("update_item_name"):
			right_sidebar.call("update_item_name", element_id, str(new_value))

	# Handle 3D visualization updates for platforms by delegating to World3DView
	if element_data.type == "platform":
		if property_key.begins_with("position_") or property_key == "altitude":
			if is_instance_valid(world_3d_view):
				world_3d_view.update_platform_visualization_position(element_id, element_data)
			else:
				printerr("Main: World3DView is not valid when trying to update platform visualization.")

	# Check if the changed property requires a structural refresh of the LeftSidebarPanel
	var structural_refresh_keys: Dictionary = ElementDefaults.get_structural_refresh_trigger_keys()
	var keys_for_current_type = structural_refresh_keys.get(element_data.type, [])

	if property_key in keys_for_current_type:
		var data_to_display: Dictionary = element_data
		if element_data.type == "platform" and property_key == "platform_type_actual":
			data_to_display = ElementDefaults.prepare_platform_data_for_subtype_change(element_data, new_value)
			simulation_elements_data[element_id] = data_to_display
		# print("Main: Platform subtype changed for '", element_id, "'. Data reset for new subtype: ", new_value) # For debugging

		left_sidebar_panel.display_properties(element_id, data_to_display, simulation_elements_data)


func _initial_left_panel_display():
	if simulation_elements_data.has("sim_name"):
		left_sidebar_panel.display_properties("sim_name", simulation_elements_data["sim_name"], simulation_elements_data)
	else:
		left_sidebar_panel.clear_panel()
		left_sidebar_panel.call_deferred("_add_label", "Select an element or add one.") 
