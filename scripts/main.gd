class_name Main
extends Control

# --- ONREADY VARIABLES (Node References) ---
@onready var left_sidebar: LeftSidebarPanel = %left_sidebar
@onready var world_3d_view: World3DView = %world_3d_view
@onready var right_sidebar: RightSidebarPanel = %right_sidebar
@onready var toggle_left_sidebar_button: Button = %toggle_left_sidebar_button
@onready var toggle_right_sidebar_button: Button = %toggle_right_sidebar_button

# --- PUBLIC & PRIVATE VARIABLES ---
var simulation_elements_data: Dictionary = {}


#--- GODOT VIRTUAL METHODS ---
func _ready() -> void:
	# Initial data setup
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

	# Connect signals after nodes are ready
	setup_connections()

	# Set initial UI state
	toggle_left_sidebar_button.text = "<" if left_sidebar.visible else ">"
	toggle_right_sidebar_button.text = ">" if right_sidebar.visible else "<"

	# Select default item in RightSidebar, which will trigger the first property display
	right_sidebar.call_deferred("select_default_item")


#--- PUBLIC & PRIVATE METHODS ---
func setup_connections() -> void:
	# Connect sidebar toggle buttons
	toggle_left_sidebar_button.pressed.connect(_on_toggle_left_sidebar_button_pressed)
	toggle_right_sidebar_button.pressed.connect(_on_toggle_right_sidebar_button_pressed)

	# Connect signals from child components
	left_sidebar.property_changed.connect(_on_left_sidebar_property_changed)
	right_sidebar.element_selected.connect(_on_right_sidebar_element_selected)
	right_sidebar.add_new_element_requested.connect(_on_right_sidebar_add_new_element_requested)

	print("Main scene: Connections established.")


#--- SIGNAL CALLBACKS ---
func _on_toggle_left_sidebar_button_pressed() -> void:
	var target_width: float = 0.0 if left_sidebar.visible else 300.0
	var tween: Tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	if not left_sidebar.visible:
		left_sidebar.visible = true

	tween.tween_property(left_sidebar, "custom_minimum_size:x", target_width, 0.2)
	tween.chain().tween_callback(func(): left_sidebar.visible = (target_width > 0))

	toggle_left_sidebar_button.text = "<" if target_width > 0 else ">"


func _on_toggle_right_sidebar_button_pressed() -> void:
	var target_width: float = 0.0 if right_sidebar.visible else 300.0
	var tween: Tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	if not right_sidebar.visible:
		right_sidebar.visible = true

	tween.tween_property(right_sidebar, "custom_minimum_size:x", target_width, 0.2)
	tween.chain().tween_callback(func(): right_sidebar.visible = (target_width > 0))

	toggle_right_sidebar_button.text = ">" if target_width > 0 else "<"


func _on_right_sidebar_element_selected(item_metadata: Dictionary) -> void:
	if item_metadata and item_metadata.has("id"):
		var element_id = item_metadata.id
		if simulation_elements_data.has(element_id):
			left_sidebar.display_properties(element_id, simulation_elements_data[element_id], simulation_elements_data)
		else:
			printerr("Main: Selected element ID '", element_id, "' not found.")
			left_sidebar.clear_panel()
	else:
		left_sidebar.clear_panel()


func _on_right_sidebar_add_new_element_requested(new_element_metadata: Dictionary) -> void:
	var element_id: String = new_element_metadata.id
	var element_type: String = new_element_metadata.type
	var element_name: String = new_element_metadata.name

	var new_data_entry: Dictionary = ElementDefaults.getDefaultData(element_type, element_name, element_id)

	if new_data_entry.is_empty():
		printerr("Main: Failed to get default data for element type: ", element_type)
		return

	simulation_elements_data[element_id] = new_data_entry

	if element_type == "platform":
		world_3d_view.add_platform_visualization(element_id, new_data_entry)

	right_sidebar.create_and_select_tree_item(new_element_metadata)


func _on_left_sidebar_property_changed(element_id: String, property_key: String, new_value: Variant) -> void:
	if not simulation_elements_data.has(element_id):
		printerr("Main: Cannot update property for non-existent element: ", element_id)
		return

	var element_data: Dictionary = simulation_elements_data[element_id]

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

	var name_property_for_type: String = "name"
	if element_data.type == "global_simulation_name":
		name_property_for_type = "name_value"

	if property_key == name_property_for_type:
		right_sidebar.update_item_name(element_id, str(new_value))

	if element_data.type == "platform" and property_key == "motion_path":
		world_3d_view.update_platform_visualization_position(element_id, element_data)

	# Check for structural refresh
	var structural_refresh_keys: Dictionary = ElementDefaults.getStructuralRefreshTriggerKeys()
	var keys_for_current_type = structural_refresh_keys.get(element_data.type, [])

	if property_key in keys_for_current_type:
		var data_to_display: Dictionary = element_data
		if element_data.type == "platform" and property_key == "platform_type_actual":
			data_to_display = ElementDefaults.preparePlatformDataForSubtypeChange(element_data, new_value)
			simulation_elements_data[element_id] = data_to_display

		left_sidebar.display_properties(element_id, data_to_display, simulation_elements_data)
