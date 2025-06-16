class_name World3DView
extends SubViewportContainer

@onready var world_3d_root: Node3D = %world_3d_root


func _ready() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	print("World3DView ready.")


func add_platform_visualization(element_id: String, platform_data: Dictionary) -> void:
	if not is_instance_valid(world_3d_root):
		printerr("World3DView: World3DRoot is not valid.")
		return

	# Check if node already exists, perhaps remove/update instead of error
	if world_3d_root.has_node(element_id):
		printerr("World3DView: Node with id '", element_id, "' already exists. Consider updating or removing first.")
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
	print("World3DView: Added platform visualization for ", element_id)


func update_platform_visualization_position(element_id: String, platform_data: Dictionary) -> void:
	if not is_instance_valid(world_3d_root):
		printerr("World3DView: World3DRoot is not valid for update.")
		return

	var platform_node: Node3D = world_3d_root.get_node_or_null(element_id) as Node3D
	if platform_node:
		var motion_path: Dictionary = platform_data.get("motion_path", {})
		if motion_path.is_empty() or not motion_path.has("waypoints") or (motion_path.waypoints as Array).is_empty():
			printerr("World3DView: Platform '", element_id, "' has no motion path data or waypoints.")
			platform_node.position = Vector3.ZERO # Default to origin
			return

		# For static visualization, use the first waypoint's position.
		var first_waypoint: Dictionary = (motion_path.waypoints as Array)[0]
		var x_fers: float = float(first_waypoint.get("x", 0.0))
		var y_fers: float = float(first_waypoint.get("y", 0.0)) # FERS Y (depth)
		var alt_fers: float = float(first_waypoint.get("altitude", 0.0)) # FERS Altitude (up)

		# FERS X -> Godot X
		# FERS Y -> Godot Z
		# FERS Altitude -> Godot Y
		platform_node.position = Vector3(x_fers, alt_fers, y_fers)
	else:
		printerr("World3DView: Platform 3D node '", element_id, "' not found for update.")


func remove_platform_visualization(element_id: String) -> void:
	if not is_instance_valid(world_3d_root):
		printerr("World3DView: World3DRoot is not valid for removal.")
		return
	var platform_node: Node3D = world_3d_root.get_node_or_null(element_id) as Node3D
	if platform_node:
		platform_node.queue_free()
		print("World3DView: Removed platform visualization for ", element_id)
