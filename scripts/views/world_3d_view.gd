class_name World3DView
extends SubViewportContainer

@onready var world_3d_root: Node3D = %world_3d_root


func _ready() -> void:
	stretch = true

	# Connect to the global data store to react to data changes.
	SimData.element_added.connect(_on_simulation_data_element_added)
	SimData.element_updated.connect(_on_simulation_data_element_updated)
	SimData.element_removed.connect(remove_platform_visualization) # Direct connection

	# Populate view with any pre-existing data (e.g. from a loaded file)
	var existing_platforms := SimData.get_elements_by_type("platform")
	for platform_data in existing_platforms:
		add_platform_visualization(platform_data)


# --- SimulationData Signal Handlers ---
func _on_simulation_data_element_added(element_data: Dictionary) -> void:
	if element_data.type == "platform":
		add_platform_visualization(element_data)


func _on_simulation_data_element_updated(element_id: String, element_data: Dictionary) -> void:
	if element_data.type == "platform":
		# This handles both position changes and other property updates.
		update_platform_visualization_position(element_id, element_data)


# --- Core Visualization Logic ---
func add_platform_visualization(platform_data: Dictionary) -> void:
	var element_id = platform_data.id
	if world_3d_root.has_node(element_id):
		update_platform_visualization_position(element_id, platform_data)
		return

	var platform_3d_vis = CSGBox3D.new()
	platform_3d_vis.name = element_id
	platform_3d_vis.size = Vector3(0.5, 0.5, 0.5)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.STEEL_BLUE
	platform_3d_vis.material = mat

	world_3d_root.add_child(platform_3d_vis)
	update_platform_visualization_position(element_id, platform_data)


func update_platform_visualization_position(element_id: String, platform_data: Dictionary) -> void:
	var platform_node: Node3D = world_3d_root.get_node_or_null(element_id) as Node3D
	if platform_node:
		var motion_path: Dictionary = platform_data.get("motion_path", {})
		if motion_path.is_empty() or not motion_path.has("waypoints") or (motion_path.waypoints as Array).is_empty():
			platform_node.position = Vector3.ZERO
			return

		var first_waypoint: Dictionary = (motion_path.waypoints as Array)[0]
		var x_fers: float = float(first_waypoint.get("x", 0.0))
		var y_fers: float = float(first_waypoint.get("y", 0.0))
		var alt_fers: float = float(first_waypoint.get("altitude", 0.0))

		platform_node.position = Vector3(x_fers, alt_fers, y_fers)
	else:
		printerr("World3DView: Platform 3D node '", element_id, "' not found for update.")


func remove_platform_visualization(element_id: String) -> void:
	var platform_node: Node3D = world_3d_root.get_node_or_null(element_id) as Node3D
	if platform_node:
		platform_node.queue_free()
