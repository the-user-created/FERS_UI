class_name World3DView
extends SubViewportContainer

# --- EXPORTS ---
@export_category("Camera Control")
@export var rotation_speed: float = 0.004
@export var pan_speed: float = 0.01
@export var zoom_speed: float = 1.1

# --- ONREADY VARIABLES ---
@onready var world_3d_root: Node3D = %world_3d_root
@onready var camera: Camera3D = %simulation_3d_viewport.get_node("world_3d_root/main_camera_3d")

# --- CAMERA STATE ---
var _target_position := Vector3.ZERO
var _camera_distance: float = 12.0
var _camera_yaw: float = 0.0 # Rotation around Y-axis
var _camera_pitch: float = deg_to_rad(20.0) # Rotation around X-axis
var _is_rotating: bool = false
var _is_panning: bool = false


func _ready() -> void:
	stretch = true

	# Connect to the global data store to react to data changes.
	SimData.element_added.connect(_on_simulation_data_element_added)
	SimData.element_updated.connect(_on_simulation_data_element_updated)
	SimData.element_removed.connect(remove_platform_visualization)
	SimData.property_preview_updated.connect(_on_simulation_data_property_preview_updated)

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
		update_platform_visualization_properties(element_id, element_data)


func _on_simulation_data_property_preview_updated(element_id: String, property_key: String, new_value: Variant) -> void:
	# This handles live preview updates without a full data object.
	if property_key == "color":
		var platform_node := world_3d_root.get_node_or_null(element_id) as Node3D
		if platform_node:
			var sphere := platform_node.get_node_or_null("Sphere") as CSGSphere3D
			if sphere:
				var mat := sphere.material as StandardMaterial3D
				if mat and new_value is Color:
					mat.albedo_color = new_value


# --- Core Visualization Logic ---
func add_platform_visualization(platform_data: Dictionary) -> void:
	var element_id: String = platform_data.id
	if world_3d_root.has_node(element_id):
		update_platform_visualization_properties(element_id, platform_data)
		return

	# Use a Node3D as the root for the visualization
	var platform_3d_vis_root = Node3D.new()
	platform_3d_vis_root.name = element_id

	# The sphere itself
	var platform_sphere = CSGSphere3D.new()
	platform_sphere.name = "Sphere"
	platform_sphere.radius = 0.5
	var mat = StandardMaterial3D.new()
	platform_sphere.material = mat
	platform_3d_vis_root.add_child(platform_sphere)

	# The name label
	var platform_label = Label3D.new()
	platform_label.name = "NameLabel"
	platform_label.text = platform_data.get("name", "Unnamed")
	platform_label.font_size = 64
	platform_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	platform_label.position.y = 1.0 # Position it above the sphere
	platform_3d_vis_root.add_child(platform_label)

	world_3d_root.add_child(platform_3d_vis_root)
	update_platform_visualization_properties(element_id, platform_data)


func update_platform_visualization_properties(element_id: String, platform_data: Dictionary) -> void:
	var platform_node: Node3D = world_3d_root.get_node_or_null(element_id) as Node3D
	if platform_node:
		# Update position
		var motion_path: Dictionary = platform_data.get("motion_path", {})
		if motion_path.is_empty() or not motion_path.has("waypoints") or (motion_path.waypoints as Array).is_empty():
			platform_node.position = Vector3.ZERO
		else:
			var first_waypoint: Dictionary = (motion_path.waypoints as Array)[0]
			platform_node.position = _get_pos_from_waypoint(first_waypoint)

		# Update color
		var sphere := platform_node.get_node_or_null("Sphere") as CSGSphere3D
		if sphere:
			var mat := sphere.material as StandardMaterial3D
			if mat:
				mat.albedo_color = platform_data.get("color", Color.WHITE)

		# Update name label
		var label := platform_node.get_node_or_null("NameLabel") as Label3D
		if label:
			label.text = platform_data.get("name", "Unnamed")

		# Update motion path visualization
		_update_motion_path_visualization(platform_node, platform_data)
	else:
		printerr("World3DView: Platform 3D node '", element_id, "' not found for update.")


func remove_platform_visualization(element_id: String) -> void:
	var platform_node: Node3D = world_3d_root.get_node_or_null(element_id) as Node3D
	if platform_node:
		platform_node.queue_free()


# --- Motion Path Visualization ---
func _update_motion_path_visualization(platform_node: Node3D, platform_data: Dictionary) -> void:
	var path_node_name := "MotionPath"
	var path_node: Node3D = platform_node.get_node_or_null(path_node_name)

	var motion_path_data: Dictionary = platform_data.get("motion_path", {})
	var waypoints: Array = motion_path_data.get("waypoints", [])
	var interpolation_type: String = motion_path_data.get("interpolation", "static")

	# If not enough points for a path, or interpolation is static, clear existing path and exit.
	if waypoints.size() < 2 or interpolation_type == "static":
		if path_node:
			path_node.queue_free()
		return

	# If path node doesn't exist, create it. Otherwise, clear its children for redraw.
	if not path_node:
		path_node = Node3D.new()
		path_node.name = path_node_name
		platform_node.add_child(path_node)
	else:
		for child in path_node.get_children():
			child.queue_free()

	# --- Path Calculation ---
	var path_points: PackedVector3Array
	var t_start: float = waypoints.front().get("time", 0.0)
	var t_end: float = waypoints.back().get("time", 0.0)
	var duration: float = t_end - t_start
	if duration <= 0: return

	var num_segments := 200 # Increase for smoother curves
	var time_step: float = duration / float(num_segments)

	var dd: Array[Vector3] = []
	if interpolation_type == "cubic":
		dd = _finalize_cubic(waypoints)
		if dd.is_empty(): # Fallback to linear if cubic calculation fails
			interpolation_type = "linear"

	for i in range(num_segments + 1):
		var t: float = t_start + i * time_step
		var pos: Vector3
		match interpolation_type:
			"linear": pos = _get_position_linear(t, waypoints)
			"cubic": pos = _get_position_cubic(t, waypoints, dd)
			_: pos = _get_position_linear(t, waypoints) # Default to linear
		path_points.append(pos)

	# --- Drawing ---
	var mesh_inst := MeshInstance3D.new()
	var imm_mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = platform_data.get("color", Color.WHITE) * 0.9
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat

	imm_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# Draw dotted line by skipping every other segment
	for i in range(0, path_points.size() - 1, 2):
		imm_mesh.surface_add_vertex(path_points[i] - platform_node.position)
		imm_mesh.surface_add_vertex(path_points[i+1] - platform_node.position)
	imm_mesh.surface_end()
	mesh_inst.mesh = imm_mesh
	path_node.add_child(mesh_inst)

	# --- Annotations ---
	for wp in waypoints:
		var wp_data: Dictionary = wp
		var wp_pos: Vector3 = _get_pos_from_waypoint(wp_data)
		var label := Label3D.new()
		label.text = "%ss\n(%.1f, %.1f, %.1f)" % [wp_data.get("time", 0.0), wp_data.get("x", 0.0), wp_data.get("y", 0.0), wp_data.get("altitude", 0.0)]
		label.font_size = 48
		label.outline_size = 6
		label.outline_modulate = Color.BLACK
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = wp_pos - platform_node.position # Position relative to platform node
		path_node.add_child(label)


# --- Interpolation Helpers ---
func _get_pos_from_waypoint(waypoint: Dictionary) -> Vector3:
	var x: float = waypoint.get("x", 0.0)
	var y: float = waypoint.get("y", 0.0)
	var alt: float = waypoint.get("altitude", 0.0)
	# Map FERS coordinates (X, Y-plane, Altitude) to Godot (X, Y-up, Z)
	return Vector3(x, alt, y)


func _find_upper_bound_idx(t: float, waypoints: Array) -> int:
	for i in range(waypoints.size()):
		var wp: Dictionary = waypoints[i]
		if wp.get("time", 0.0) > t:
			return i
	return waypoints.size()


func _get_position_linear(t: float, waypoints: Array) -> Vector3:
	if waypoints.is_empty(): return Vector3.ZERO
	var xrp_idx: int = _find_upper_bound_idx(t, waypoints)

	if xrp_idx == 0: return _get_pos_from_waypoint(waypoints[0])
	if xrp_idx == waypoints.size(): return _get_pos_from_waypoint(waypoints.back())

	var xli_idx: int = xrp_idx - 1
	var p_right: Dictionary = waypoints[xrp_idx]
	var p_left: Dictionary = waypoints[xli_idx]

	var iw: float = p_right.get("time", 0.0) - p_left.get("time", 0.0)
	if iw <= 0.0: return _get_pos_from_waypoint(p_left)

	var rw: float = (p_right.get("time", 0.0) - t) / iw
	var lw: float = 1.0 - rw

	return _get_pos_from_waypoint(p_right) * lw + _get_pos_from_waypoint(p_left) * rw


func _get_position_cubic(t: float, waypoints: Array, dd: Array) -> Vector3:
	if waypoints.is_empty() or dd.is_empty(): return Vector3.ZERO
	var xrp_idx: int = _find_upper_bound_idx(t, waypoints)

	if xrp_idx == 0: return _get_pos_from_waypoint(waypoints[0])
	if xrp_idx == waypoints.size(): return _get_pos_from_waypoint(waypoints.back())

	var xli_idx: int = xrp_idx - 1
	var p_right: Dictionary = waypoints[xrp_idx]
	var p_left: Dictionary = waypoints[xli_idx]

	var xrd_t: float = p_right.get("time", 0.0) - t
	var xld_t: float = t - p_left.get("time", 0.0)
	var iw: float = p_right.get("time", 0.0) - p_left.get("time", 0.0)
	if iw <= 0.0: return _get_pos_from_waypoint(p_left)

	var iws_6: float = (iw * iw) / 6.0
	var a: float = xrd_t / iw
	var b: float = xld_t / iw
	var c: float = (a*a*a - a) * iws_6
	var d: float = (b*b*b - b) * iws_6

	return _get_pos_from_waypoint(p_left) * a + _get_pos_from_waypoint(p_right) * b + dd[xli_idx] * c + dd[xrp_idx] * d


func _safe_vec_div(numerator: Vector3, denominator: Vector3) -> Vector3:
	var x: float = numerator.x / denominator.x if denominator.x != 0.0 else 0.0
	var y: float = numerator.y / denominator.y if denominator.y != 0.0 else 0.0
	var z: float = numerator.z / denominator.z if denominator.z != 0.0 else 0.0
	return Vector3(x, y, z)


func _finalize_cubic(waypoints: Array) -> Array[Vector3]:
	var wp_count: int = waypoints.size()
	if wp_count < 2: return []

	var dd: Array[Vector3]; dd.resize(wp_count)
	var tmp: Array[Vector3]; tmp.resize(wp_count)

	dd[0] = Vector3.ZERO
	dd[wp_count-1] = Vector3.ZERO
	tmp[0] = Vector3.ZERO

	# Forward decomposition loop
	for i in range(1, wp_count - 1):
		var p_curr: Dictionary = waypoints[i]
		var p_prev: Dictionary = waypoints[i-1]
		var p_next: Dictionary = waypoints[i+1]

		var yrd: Vector3 = _get_pos_from_waypoint(p_next) - _get_pos_from_waypoint(p_curr)
		var yld: Vector3 = _get_pos_from_waypoint(p_curr) - _get_pos_from_waypoint(p_prev)
		var xrd: float = p_next.get("time", 0.0) - p_curr.get("time", 0.0)
		var xld: float = p_curr.get("time", 0.0) - p_prev.get("time", 0.0)
		var iw: float = p_next.get("time", 0.0) - p_prev.get("time", 0.0)

		if iw == 0.0: continue

		var si: float = xld / iw
		var p_vec: Vector3 = dd[i-1] * si + Vector3(2.0, 2.0, 2.0)

		var dd_num_vec := Vector3(si-1.0, si-1.0, si-1.0)
		dd[i] = _safe_vec_div(dd_num_vec, p_vec)

		var yrd_div: Vector3 = yrd / xrd if xrd != 0.0 else Vector3.ZERO
		var yld_div: Vector3 = yld / xld if xld != 0.0 else Vector3.ZERO

		var tmp_num_vec: Vector3 = ((yrd_div - yld_div) * (6.0 / iw)) - (tmp[i-1] * si)
		tmp[i] = _safe_vec_div(tmp_num_vec, p_vec)

	# Back-substitution loop
	for i in range(wp_count - 2, -1, -1):
		dd[i] = dd[i] * dd[i+1] + tmp[i]

	return dd


# --- Camera Control ---
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_is_rotating = mouse_event.is_pressed()
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mouse_event.is_pressed()
			get_viewport().set_input_as_handled()
		elif mouse_event.is_pressed():
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_camera_distance = max(0.1, _camera_distance / zoom_speed)
				get_viewport().set_input_as_handled()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_camera_distance *= zoom_speed
				get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if _is_rotating:
			_camera_yaw -= motion_event.relative.x * rotation_speed
			_camera_pitch = clamp(_camera_pitch - motion_event.relative.y * rotation_speed, -PI / 2.0 + 0.01, PI / 2.0 - 0.01)
			get_viewport().set_input_as_handled()
		elif _is_panning:
			# Use camera's basis vectors to pan relative to view
			var right: Vector3 = camera.global_transform.basis.x
			var up: Vector3 = camera.global_transform.basis.y
			_target_position -= right * motion_event.relative.x * pan_speed
			_target_position += up * motion_event.relative.y * pan_speed
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# This ensures that if the mouse button is released outside the viewport,
	# we stop panning/rotating.
	if _is_rotating and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_is_rotating = false
	if _is_panning and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_is_panning = false

	_update_camera_transform()


func _update_camera_transform() -> void:
	if not is_instance_valid(camera):
		return
	camera.transform.basis = Basis() # Reset rotation
	camera.position = _target_position
	camera.rotate_object_local(Vector3.UP, _camera_yaw)
	camera.rotate_object_local(Vector3.RIGHT, _camera_pitch)
	camera.translate_object_local(Vector3(0, 0, _camera_distance))


func focus_on_element(element_id: String) -> void:
	var platform_node: Node3D = world_3d_root.get_node_or_null(element_id) as Node3D
	if not is_instance_valid(platform_node):
		return

	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_target_position", platform_node.position, 0.5)
