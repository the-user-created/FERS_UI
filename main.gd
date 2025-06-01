class_name MainScene
extends Node3D

const RightSidebarPanelScene = preload("res://RightSidebarPanel.tscn")
const LeftSidebarPanelScene = preload("res://LeftSidebarPanel.tscn")

var main_layout_container: HBoxContainer
var left_properties_panel: LeftPropertiesPanel
var main_3d_view_container: SubViewportContainer
var right_sidebar: Control

# This dictionary will hold the actual data for your simulation elements
var simulation_elements_data: Dictionary = {}

func _ready() -> void:
	# 1. Create the main layout container
	main_layout_container = HBoxContainer.new()
	main_layout_container.name = "MainLayout"
	main_layout_container.anchor_right = 1.0
	main_layout_container.anchor_bottom = 1.0
	add_child(main_layout_container)

	# 2. Instantiate and Add the Left Properties Panel
	left_properties_panel = LeftSidebarPanelScene.instantiate()
	left_properties_panel.visible = true
	main_layout_container.add_child(left_properties_panel)
	left_properties_panel.connect("property_changed", Callable(self, "_on_left_sidebar_property_changed"))
	left_properties_panel.display_properties("", {}, simulation_elements_data)

	# 3. Create the Main 3D View Container (same as before)
	main_3d_view_container = SubViewportContainer.new()
	main_3d_view_container.name = "Main3DViewContainer"
	main_3d_view_container.stretch = true
	main_3d_view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_3d_view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_layout_container.add_child(main_3d_view_container)

	var sub_viewport = SubViewport.new()
	sub_viewport.name = "Simulation3DViewport"
	sub_viewport.size = Vector2i(1024, 600) 
	main_3d_view_container.add_child(sub_viewport)

	var world_3d_root = Node3D.new()
	world_3d_root.name = "World3DRoot"
	sub_viewport.add_child(world_3d_root)

	var camera = Camera3D.new()
	camera.name = "MainCamera3D"
	world_3d_root.add_child(camera)
	camera.position = Vector3(0, 2, 10)
	camera.look_at(Vector3.ZERO)

	var light = DirectionalLight3D.new()
	light.name = "MainLight3D"
	light.rotate_x(deg_to_rad(-45.0))
	world_3d_root.add_child(light)
	
	var grid_mesh = PlaneMesh.new()
	grid_mesh.size = Vector2(20,20)
	grid_mesh.subdivide_width = 20
	grid_mesh.subdivide_depth = 20
	var grid_mat = StandardMaterial3D.new()
	grid_mat.albedo_color = Color(0.7,0.7,0.7)
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_mat.flags_unshaded = true
	grid_mesh.surface_set_material(0, grid_mat)
	var grid_instance = MeshInstance3D.new()
	grid_instance.mesh = grid_mesh
	grid_instance.rotate_x(deg_to_rad(90))
	world_3d_root.add_child(grid_instance)

	var environment = WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var env_resource = ProceduralSkyMaterial.new()
	environment.environment = Environment.new()
	environment.environment.sky = Sky.new()
	environment.environment.sky.sky_material = env_resource
	world_3d_root.add_child(environment)

	# 4. Instantiate and Add the Right Sidebar Panel
	right_sidebar = RightSidebarPanelScene.instantiate()
	right_sidebar.custom_minimum_size = Vector2(250, 0)
	main_layout_container.add_child(right_sidebar)

	# 5. Connect to signals from the Right Sidebar
	if right_sidebar.has_signal("element_selected"):
		right_sidebar.connect("element_selected", Callable(self, "_on_right_sidebar_element_selected"))
	else:
		printerr("RightSidebarPanel does not have signal 'element_selected'")

	if right_sidebar.has_signal("add_new_element_requested"):
		right_sidebar.connect("add_new_element_requested", Callable(self, "_on_right_sidebar_add_new_element_requested"))
	else:
		printerr("RightSidebarPanel does not have signal 'add_new_element_requested'")

	# --- Initialize Default Simulation Data in the Right Sidebar ---
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
	
	# Select the first item by default
	if right_sidebar and right_sidebar.has_method("select_default_item"):
		right_sidebar.call_deferred("select_default_item")
	else:
		call_deferred("_initial_left_panel_display")

	print("Main scene ready.")

# --- Signal Handlers for Right Sidebar ---
func _on_right_sidebar_element_selected(item_metadata: Dictionary) -> void:
	print("Main: Element selected: ", item_metadata)
	if item_metadata and item_metadata.has("id"):
		var element_id = item_metadata.id
		if simulation_elements_data.has(element_id):
			left_properties_panel.display_properties(element_id, simulation_elements_data[element_id], simulation_elements_data)
		else:
			# This case should ideally not happen if the order is correct
			printerr("Main: Selected element ID '", element_id, "' not found in data (at selection time). This might indicate a timing issue if it's a new item.")
			left_properties_panel.clear_panel()
	else:
		left_properties_panel.clear_panel()

func _on_right_sidebar_add_new_element_requested(new_element_metadata: Dictionary) -> void:
	print("Main: Add new element requested by RightSidebar: ", new_element_metadata)

	var element_id: String = new_element_metadata.id
	var element_type: String = new_element_metadata.type
	var element_name: String = new_element_metadata.name

	# 1. Create and store the actual data for this new element
	var new_data_entry: Dictionary = {
		"id": element_id, # Use the ID from metadata
		"type": element_type,
		"name": element_name
	}

	match element_type:
		"platform":
			new_data_entry["platform_type_actual"] = "target"
			new_data_entry["position_x"] = 0.0
			new_data_entry["position_y"] = 0.0
			new_data_entry["altitude"] = 0.0
			new_data_entry["target_rcs_type_actual"] = "isotropic"
			new_data_entry["target_rcs_value"] = "10.0" 
			new_data_entry["target_rcs_filename"] = ""
			new_data_entry["target_rcs_fluctuation_model_type"] = "constant"
			new_data_entry["target_rcs_fluctuation_value"] = "1.0" 
			new_data_entry["target_rcs_fluctuation_k"] = "1"
			
			_add_platform_3d_visualization(element_id, new_data_entry)

		"pulse":
			new_data_entry["pulse_type_actual"] = "file"
			new_data_entry["power"] = 100.0
			new_data_entry["carrier_frequency"] = 10e9
			new_data_entry["pulse_filename"] = "waveform.csv"
		"timing_source":
			new_data_entry["frequency"] = 1e7
		"antenna":
			new_data_entry["antenna_pattern_actual"] = "isotropic" 
			new_data_entry["filename"] = ""
		_:
			printerr("Main: Unhandled element type for data creation: ", element_type)
			return 

	simulation_elements_data[element_id] = new_data_entry
	print("Main: Created data for '", element_id, "': ", simulation_elements_data[element_id])

	# 2. Tell the RightSidebarPanel to add the item to its tree and select it
	if right_sidebar and right_sidebar.has_method("create_and_select_tree_item"):
		# Pass the original metadata received, which RightSidebarPanel knows how to use
		right_sidebar.call("create_and_select_tree_item", new_element_metadata) 
	else:
		printerr("Main: RightSidebarPanel does not have method 'create_and_select_tree_item'")

# You would also need a function to update the simulation_elements_data
# when properties are changed in the LeftPropertiesPanel, and potentially
# update the RightSidebarPanel's tree item name if the name changed.
func update_element_data(element_id: String, property_name: String, new_value: Variant) -> void:
	if simulation_elements_data.has(element_id):
		var element_data: Dictionary = simulation_elements_data[element_id]
		element_data[property_name] = new_value

		# If name was changed, update the right sidebar display
		if property_name == "name":
			if right_sidebar and right_sidebar.has_method("update_item_name"):
				right_sidebar.call("update_item_name", element_id, new_value)

		# If position was changed for a platform, update 3D view
		if element_data.type == "platform" and (property_name.begins_with("position_") or property_name == "altitude"):
			var platform_node = main_3d_view_container.get_node_or_null("Simulation3DViewport/World3DRoot/" + element_id)
			if platform_node is Node3D:
				var x = element_data.get("position_x", 0.0)
				var y = element_data.get("position_y", 0.0)
				var alt = element_data.get("altitude", 0.0)
				# Your XML uses X, Y, Altitude. In Godot 3D, Y is typically up.
				# Decide on your coordinate system convention for the UI.
				# Assuming UI X,Y are ground plane, UI Altitude is Godot Y.
				platform_node.position = Vector3(x, alt, y) # (FERS X, FERS Alt, FERS Y)
				print("Main: Updated 3D position for ", element_id, " to ", platform_node.position)
	else:
		printerr("Attempted to update non-existent element: ", element_id)

func _on_left_sidebar_property_changed(element_id: String, property_key: String, new_value: Variant) -> void:
	if not simulation_elements_data.has(element_id):
		printerr("Main: Cannot update property for non-existent element: ", element_id)
		return

	var element_data: Dictionary = simulation_elements_data[element_id]
	element_data[property_key] = new_value
	print("Main: Updated ", element_id, ".", property_key, " to ", new_value)

	# Handle side-effects of property changes
	if property_key == "name" and element_data.type != "global_simulation_name":
		if right_sidebar and right_sidebar.has_method("update_item_name"):
			right_sidebar.call("update_item_name", element_id, new_value)

	if element_data.type == "platform":
		if property_key.begins_with("position_") or property_key == "altitude":
			_update_platform_3d_visualization(element_id, element_data)
		
		# If a property changes that requires the LeftPropertiesPanel to rebuild its UI for this element
		# (e.g., platform type, RCS type, pulse type, antenna pattern type)
		var refresh_keys = [
			"platform_type_actual", 
			"target_rcs_type_actual", "target_rcs_fluctuation_model_type",
			"pulse_type_actual", 
			"antenna_pattern_actual",
			"transmitter_type_actual" # For pulsed/continuous option in transmitter
			]
		if property_key in refresh_keys:
			# Re-display properties for the current element with updated data
			left_properties_panel.display_properties(element_id, element_data, simulation_elements_data)
			
	if element_data.type == "pulse" and property_key == "pulse_type_actual":
		left_properties_panel.display_properties(element_id, element_data, simulation_elements_data)
	if element_data.type == "antenna" and property_key == "antenna_pattern_actual":
		left_properties_panel.display_properties(element_id, element_data, simulation_elements_data)

func _add_platform_3d_visualization(element_id: String, platform_data: Dictionary) -> void:
	var platform_3d_vis = CSGBox3D.new() # Simple box for now
	platform_3d_vis.name = element_id
	platform_3d_vis.size = Vector3(1,1,1) # Default size
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.BLUE 
	platform_3d_vis.material = mat
	
	var world_root = main_3d_view_container.get_node_or_null("Simulation3DViewport/World3DRoot")
	if world_root:
		world_root.add_child(platform_3d_vis)
		_update_platform_3d_visualization(element_id, platform_data) # Set initial position
	else:
		printerr("Could not find World3DRoot to add platform visualization.")

func _update_platform_3d_visualization(element_id: String, platform_data: Dictionary) -> void:
	var platform_node = main_3d_view_container.get_node_or_null("Simulation3DViewport/World3DRoot/" + element_id)
	if platform_node is Node3D:
		var x = float(platform_data.get("position_x", 0.0))
		var y_fers = float(platform_data.get("position_y", 0.0)) # FERS Y (ground plane)
		var alt_fers = float(platform_data.get("altitude", 0.0)) # FERS Altitude

		# FERS X -> Godot X
		# FERS Y -> Godot Z (depth)
		# FERS Altitude -> Godot Y (up)
		platform_node.position = Vector3(x, alt_fers, y_fers) 
		print("Main: Updated 3D position for ", element_id, " to FERS (X,Y,Alt): (", x, ",", y_fers, ",", alt_fers, ") Godot: ", platform_node.position)
	else:
		printerr("Main: Platform 3D node not found for update: ", element_id)

func _initial_left_panel_display():
	# This is a fallback or can be used if select_default_item doesn't trigger selection early enough
	if simulation_elements_data.has("sim_name"):
		left_properties_panel.display_properties("sim_name", simulation_elements_data["sim_name"], simulation_elements_data)
	else:
		left_properties_panel.display_properties("", {}, simulation_elements_data)
