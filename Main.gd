class_name Main
extends Node3D

const RightSidebarPanelScene: PackedScene = preload("res://RightSidebarPanel.tscn")
const LeftSidebarPanelScene: PackedScene = preload("res://LeftSidebarPanel.tscn")
var main_layout_container: HBoxContainer
var left_sidebar_panel: LeftSidebarPanel
var main_3d_view_container: SubViewportContainer
var right_sidebar: RightSidebarPanel
var simulation_elements_data: Dictionary = {}


func _ready() -> void:
	# 1. Create the main layout container
	main_layout_container = HBoxContainer.new()
	main_layout_container.name = "MainLayout"
	main_layout_container.anchor_right = 1.0
	main_layout_container.anchor_bottom = 1.0
	# If Main.tscn root is changed to Control, this becomes:
	# get_tree().root.add_child(main_layout_container)
	# main_layout_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_layout_container) # Current approach

	# 2. Instantiate and Add the Left Properties Panel
	left_sidebar_panel = LeftSidebarPanelScene.instantiate()
	main_layout_container.add_child(left_sidebar_panel)
	left_sidebar_panel.connect("property_changed", Callable(self, "_on_left_sidebar_property_changed"))

	# 3. Create the Main 3D View Container (no changes here)
	main_3d_view_container = SubViewportContainer.new()
	main_3d_view_container.name = "Main3DViewContainer"
	main_3d_view_container.stretch = true
	main_3d_view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_3d_view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_layout_container.add_child(main_3d_view_container)

	var sub_viewport = SubViewport.new()
	sub_viewport.name = "Simulation3DViewport"
	sub_viewport.size = Vector2i(1024, 600) # TODO: Consider making this dynamic or configurable
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

	var grid_mesh_mat = StandardMaterial3D.new()
	grid_mesh_mat.albedo_color = Color(0.7, 0.7, 0.7)
	grid_mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var grid_mesh = PlaneMesh.new()
	grid_mesh.size = Vector2(20, 20)
	grid_mesh.subdivide_width = 20
	grid_mesh.subdivide_depth = 20
	grid_mesh.surface_set_material(0, grid_mesh_mat)

	var grid_instance = MeshInstance3D.new()
	grid_instance.mesh = grid_mesh
	grid_instance.rotate_x(deg_to_rad(90))
	world_3d_root.add_child(grid_instance)

	var environment = WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var sky_material = ProceduralSkyMaterial.new()
	var env_resource = Environment.new()
	env_resource.sky = Sky.new()
	env_resource.sky.sky_material = sky_material
	environment.environment = env_resource
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

	# Initialize permanent simulation elements data
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

	# Select default item in RightSidebar, which will trigger _on_right_sidebar_element_selected
	if right_sidebar and right_sidebar.has_method("select_default_item"):
		right_sidebar.call_deferred("select_default_item")
	else:
		call_deferred("_initial_left_panel_display")

	print("Main scene ready.")


func _on_right_sidebar_element_selected(item_metadata: Dictionary) -> void:
	print("Main: Element selected: ", item_metadata)
	if item_metadata and item_metadata.has("id"):
		var element_id = item_metadata.id
		if simulation_elements_data.has(element_id):
			left_sidebar_panel.display_properties(element_id, simulation_elements_data[element_id], simulation_elements_data)
		else:
			# This case might happen if an item is in the tree but its data was removed, or a category header.
			printerr("Main: Selected element ID '", element_id, "' not found in simulation_elements_data.")
			left_sidebar_panel.clear_panel()
	else:
		# No valid ID, likely a category header or deselection
		left_sidebar_panel.clear_panel()


func _on_right_sidebar_add_new_element_requested(new_element_metadata: Dictionary) -> void:
	print("Main: Add new element requested: ", new_element_metadata)

	var element_id: String = new_element_metadata.id
	var element_type: String = new_element_metadata.type
	var element_name: String = new_element_metadata.name

	# Use ElementDefaults to get the initial data structure
	var new_data_entry: Dictionary = ElementDefaults.get_default_data(element_type, element_name, element_id)

	if new_data_entry.is_empty():
		printerr("Main: Failed to get default data for element type: ", element_type)
		return

	simulation_elements_data[element_id] = new_data_entry
	print("Main: Created data for '", element_id, "': ", simulation_elements_data[element_id])

	# If it's a platform, add its 3D visualization
	if element_type == "platform":
		_add_platform_3d_visualization(element_id, new_data_entry)

	# Tell the RightSidebarPanel to add the item to its tree and select it
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
	print("Main: Updated data for '", element_id, "'. Key: '", property_key, "', New Value: ", new_value)

	# Update name in RightSidebar if it changed
	var name_property_for_type: String = "name"
	if element_data.type == "global_simulation_name":
		name_property_for_type = "name_value"

	if property_key == name_property_for_type:
		if right_sidebar and right_sidebar.has_method("update_item_name"):
			right_sidebar.call("update_item_name", element_id, str(new_value))

	# Handle 3D visualization updates for platforms
	if element_data.type == "platform":
		if property_key.begins_with("position_") or property_key == "altitude":
			_update_platform_3d_visualization(element_id, element_data)

	# Check if the changed property requires a structural refresh of the LeftSidebarPanel
	var structural_refresh_keys: Dictionary = ElementDefaults.get_structural_refresh_trigger_keys()
	var keys_for_current_type = structural_refresh_keys.get(element_data.type, [])

	if property_key in keys_for_current_type:
		var data_to_display: Dictionary = element_data
		# Special handling for platform type change: reset subtype-specific fields
		if element_data.type == "platform" and property_key == "platform_type_actual":
			data_to_display = ElementDefaults.prepare_platform_data_for_subtype_change(element_data, new_value)
			simulation_elements_data[element_id] = data_to_display
			print("Main: Platform subtype changed for '", element_id, "'. Data reset for new subtype: ", new_value)

		left_sidebar_panel.display_properties(element_id, data_to_display, simulation_elements_data)


func _add_platform_3d_visualization(element_id: String, platform_data: Dictionary) -> void:
	var platform_3d_vis = CSGBox3D.new()
	platform_3d_vis.name = element_id
	platform_3d_vis.size = Vector3(0.5, 0.5, 0.5)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.STEEL_BLUE
	platform_3d_vis.material = mat

	var world_root: Node3D = main_3d_view_container.get_node_or_null("Simulation3DViewport/World3DRoot") as Node3D
	if world_root:
		world_root.add_child(platform_3d_vis)
		_update_platform_3d_visualization(element_id, platform_data)
	else:
		printerr("Main: Could not find World3DRoot to add platform visualization for '", element_id, "'.")


func _update_platform_3d_visualization(element_id: String, platform_data: Dictionary) -> void:
	var platform_node: Node3D = main_3d_view_container.get_node_or_null("Simulation3DViewport/World3DRoot/" + element_id) as Node3D
	if platform_node:
		var x_fers: float = float(platform_data.get("position_x", 0.0))
		var y_fers: float = float(platform_data.get("position_y", 0.0)) # FERS Y (ground plane along Z in Godot)
		var alt_fers: float = float(platform_data.get("altitude", 0.0)) # FERS Altitude (Y in Godot)

		# Coordinate mapping: FERS X -> Godot X, FERS Y -> Godot Z, FERS Altitude -> Godot Y
		platform_node.position = Vector3(x_fers, alt_fers, y_fers)
	else:
		printerr("Main: Platform 3D node '", element_id, "' not found for update.")


func _initial_left_panel_display():
	if simulation_elements_data.has("sim_name"):
		left_sidebar_panel.display_properties("sim_name", simulation_elements_data["sim_name"], simulation_elements_data)
	else:
		left_sidebar_panel.clear_panel()
