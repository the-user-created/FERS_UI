class_name World3DView
extends SubViewportContainer


# --- EXPORTS ---
@export_category("Camera Control")
@export var rotation_speed: float = 0.005
@export var pan_speed: float = 0.001 # Multiplied by camera distance for adaptive speed
@export var keyboard_pan_speed: float = 5.0 # m/s
@export var keyboard_orbit_speed: float = 1.5 # rad/s
@export var zoom_speed: float = 1.1
@export_category("Clipping")
@export var min_near_clip: float = 0.1
@export var min_far_clip: float = 1000.0
@export var far_to_altitude_ratio: float = 100.0
@export var near_to_far_ratio: float = 0.001
@export_category("Display")
@export var perceptual_scale_factor: float = 0.04 # Controls perceptual size of labels.
@export var boresight_lod_distance: float = 150.0 # Distance to switch from cone to line
@export var boresight_length: float = 30.0 # Default length for boresight visuals
@export_category("Grid")
@export var show_grid: bool = true
@export var major_grid_color: Color = Color(0.5, 0.5, 0.5, 1.0)
@export var minor_grid_color: Color = Color(0.5, 0.5, 0.5, 0.25)
@export var grid_line_width: float = 0.05

# --- ONREADY VARIABLES ---
@onready var world_3d_root: Node3D = %world_3d_root
@onready var camera: Camera3D = %simulation_3d_viewport.get_node("world_3d_root/main_camera_3d")
@onready var grid_mesh_instance: MeshInstance3D = %world_3d_root.get_node("CartesianGrid")
@onready var grid_labels: Node3D = %world_3d_root.get_node("GridLabels")

# --- CAMERA STATE ---
var _target_position := Vector3.ZERO
var _camera_distance: float = 12.0
var _camera_yaw: float = 0.0 # Rotation around Y-axis
var _camera_pitch: float = deg_to_rad(20.0) # Rotation around X-axis
var _is_rotating: bool = false
var _is_panning: bool = false
# --- CACHING ---
var _cubic_dd_cache: Dictionary = {}
var _cubic_rot_dd_cache: Dictionary = {}
# --- STATE ---
var _last_major_grid_spacing: float = -1.0
var _last_label_update_cam_pos: Vector3 = Vector3.INF
var _has_focus: bool = false
# --- FONT CACHING for label size estimation ---
var _label_font: Font
var _label_font_size: int

func _ready() -> void:
	stretch = true
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(func(): _has_focus = true)
	focus_exited.connect(func(): _has_focus = false)

	# Cache font properties for performance.
	var temp_label_for_font := Label.new()
	_label_font = temp_label_for_font.get_theme_font("font")
	# The font_size in Label3D is set to 48, so we use that for estimations.
	_label_font_size = 48
	temp_label_for_font.queue_free()

	# Connect to the global data store to react to data changes.
	SimData.simulation_time_updated.connect(_update_all_platform_positions)
	SimData.simulation_time_updated.connect(_update_all_platform_orientations)
	SimData.element_added.connect(_on_simulation_data_element_added)
	SimData.element_updated.connect(_on_simulation_data_element_updated)
	SimData.element_removed.connect(remove_platform_visualization)
	SimData.property_preview_updated.connect(_on_simulation_data_property_preview_updated)

	# Populate view with any pre-existing data (e.g. from a loaded file).
	# `call_deferred` ensures the scene tree is fully ready.
	call_deferred("_populate_and_position_initial_platforms")

	# Initialize grid visibility and draw it for the first time
	_setup_grid()
	grid_mesh_instance.visible = show_grid


func _populate_and_position_initial_platforms() -> void:
	var existing_platforms := SimData.get_elements_by_type("platform")
	for platform_data in existing_platforms:
		add_platform_visualization(platform_data)
	_update_all_platform_orientations(SimData.simulation_time)


# --- SimulationData Signal Handlers ---
func _on_simulation_data_element_added(element_data: Dictionary) -> void:
	if element_data.type == "platform":
		add_platform_visualization(element_data)
		_update_all_platform_orientations.call_deferred(SimData.simulation_time)


func _on_simulation_data_element_updated(element_id: String, element_data: Dictionary) -> void:
	if element_data.type == "platform":
		if _cubic_dd_cache.has(element_id):
			_cubic_dd_cache.erase(element_id)
		if _cubic_rot_dd_cache.has(element_id):
			_cubic_rot_dd_cache.erase(element_id)
		# This handles both position changes and other property updates.
		update_platform_visualization_properties(element_id, element_data)
		_update_all_platform_orientations.call_deferred(SimData.simulation_time)
		_update_boresight_visuals.call_deferred(element_id, element_data)


func _on_simulation_data_property_preview_updated(element_id: String, property_key: String, new_value: Variant) -> void:
	# This handles live preview updates without a full data object.
	if property_key == "color":
		var platform_node := world_3d_root.get_node_or_null(element_id) as Node3D
		if platform_node and new_value is Color:
			var sphere := platform_node.get_node_or_null("Sphere") as CSGSphere3D
			if sphere:
				var mat := sphere.material as StandardMaterial3D
				if mat:
					mat.albedo_color = new_value

			var label := platform_node.get_node_or_null("NameLabel") as Label3D
			if label:
				label.modulate = new_value

			var location_label := platform_node.get_node_or_null("LocationLabel") as Label3D
			if location_label:
				location_label.modulate = new_value
		
			# Also update the boresight visuals for live color preview
			_update_boresight_visuals.call_deferred(element_id, SimData.get_element_data(element_id))


# --- Core Visualization Logic ---
func add_platform_visualization(platform_data: Dictionary) -> void:
	var element_id: String = platform_data.id
	if world_3d_root.has_node(element_id):
		# Node already exists, just update it.
		return update_platform_visualization_properties(element_id, platform_data)

	# Use an Area3D as the root for picking via mouse input.
	var platform_3d_vis_root = Area3D.new()
	platform_3d_vis_root.name = element_id
	platform_3d_vis_root.add_to_group("platforms")
	platform_3d_vis_root.input_ray_pickable = true
	platform_3d_vis_root.input_event.connect(_on_platform_input_event.bind(element_id))

	# The sphere itself
	var platform_sphere = CSGSphere3D.new()
	platform_sphere.name = "Sphere"
	platform_sphere.radius = 0.5
	var mat = StandardMaterial3D.new()
	platform_sphere.material = mat
	platform_3d_vis_root.add_child(platform_sphere)

	# The collision shape for picking. Must be a child of the Area3D.
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape" # Naming for easier access during updates
	var sphere_shape = SphereShape3D.new()
	# The collision shape radius should match the visual sphere radius.
	sphere_shape.radius = platform_sphere.radius
	collision_shape.shape = sphere_shape
	platform_3d_vis_root.add_child(collision_shape)

	# The name label
	var platform_label = Label3D.new()
	platform_label.name = "NameLabel"
	platform_label.text = platform_data.get("name", "Unnamed")
	platform_label.font_size = 64
	platform_label.outline_size = 8
	platform_label.outline_modulate = Color.BLACK
	platform_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	platform_label.position.y = 1.0 # Position it above the sphere
	platform_3d_vis_root.add_child(platform_label)

	# The location label
	var location_label = Label3D.new()
	location_label.name = "LocationLabel"
	location_label.text = "Pos: (0.0, 0.0, 0.0)"
	location_label.font_size = 48
	location_label.outline_size = 6
	location_label.outline_modulate = Color.BLACK
	location_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	location_label.position.y = -1.0 # Position it below the sphere
	platform_3d_vis_root.add_child(location_label)

	# --- Boresight Visuals Container ---
	var boresight_visuals = Node3D.new()
	boresight_visuals.name = "BoresightVisuals"
	platform_3d_vis_root.add_child(boresight_visuals)

	# --- Boresight Cone (Beam) ---
	var cone = MeshInstance3D.new()
	cone.name = "BoresightCone"
	cone.mesh = CylinderMesh.new()
	(cone.mesh as CylinderMesh).top_radius = 0.0 # Make it a cone
	var cone_mat = StandardMaterial3D.new()
	cone_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	cone_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED # See inside of cone
	cone.material_override = cone_mat
	boresight_visuals.add_child(cone)

	world_3d_root.add_child(platform_3d_vis_root)
	update_platform_visualization_properties(element_id, platform_data)
	_update_boresight_visuals(element_id, platform_data)


func update_platform_visualization_properties(element_id: String, platform_data: Dictionary) -> void:
	var platform_node: Area3D = world_3d_root.get_node_or_null(element_id) as Area3D
	if platform_node:
		var platform_color = platform_data.get("color", Color.WHITE)
		# Default radius for non-target platforms or targets without isotropic RCS.
		var new_radius := 0.5

		# Update color and scale
		var sphere := platform_node.get_node_or_null("Sphere") as CSGSphere3D
		if sphere:
			var mat := sphere.material as StandardMaterial3D
			if mat:
				mat.albedo_color = platform_color

			# For targets with isotropic RCS, calculate the physically correct radius.
			var is_target: bool = platform_data.get("platform_type_actual") == "target"
			var is_isotropic_rcs: bool = platform_data.get("target_rcs_type_actual") == "isotropic"

			if is_target and is_isotropic_rcs:
				var rcs_value := float(platform_data.get("target_rcs_value", 1.0))
				if rcs_value > 0.0:
					# Calculate the physical radius of a conducting sphere for a given RCS (σ = πR²) -> R = sqrt(σ/π)
					new_radius = sqrt(rcs_value / PI)
		
			sphere.radius = max(0.1, new_radius) # Ensure a minimum visible size
		
			var collision_shape := platform_node.get_node_or_null("CollisionShape") as CollisionShape3D
			if collision_shape and collision_shape.shape is SphereShape3D:
				(collision_shape.shape as SphereShape3D).radius = sphere.radius

		# Update name label
		var label := platform_node.get_node_or_null("NameLabel") as Label3D
		if label:
			label.text = platform_data.get("name", "Unnamed")
			label.modulate = platform_color
			# Position the label just above the sphere's new radius
			label.position.y = sphere.radius + 0.5
	
		var location_label := platform_node.get_node_or_null("LocationLabel") as Label3D
		if location_label:
			location_label.modulate = platform_color
			location_label.position.y = -sphere.radius - 0.5

		# Update motion path visualization
		_update_motion_path_visualization(element_id, platform_data)
	
		# Update position based on current time
		var motion_path_data: Dictionary = platform_data.get("motion_path", {})
		var waypoints: Array = motion_path_data.get("waypoints", [])
		var interp_type: String = motion_path_data.get("interpolation", "static")

		if waypoints.is_empty():
			platform_node.position = Vector3.ZERO
		else:
			var new_pos := Vector3.ZERO
			match interp_type:
				"static": new_pos = _get_pos_from_waypoint(waypoints[0])
				"linear": new_pos = _get_position_linear(SimData.simulation_time, waypoints)
				"cubic":
					var dd := _get_or_calculate_cubic_dd(element_id, waypoints)
					if not dd.is_empty():
						new_pos = _get_position_cubic(SimData.simulation_time, waypoints, dd)
			platform_node.position = new_pos
	
		if location_label:
			# Display position in FERS coordinates (X, Y-Plane, Altitude) which map to Godot's (X, Z, Y)
			location_label.text = "Pos: (%.1f, %.1f, %.1f)" % [platform_node.position.x, platform_node.position.z, platform_node.position.y]
	else:
		printerr("World3DView: Platform 3D node '", element_id, "' not found for update.")

	_update_boresight_visuals(element_id, platform_data)


func remove_platform_visualization(element_id: String) -> void:
	var platform_node: Area3D = world_3d_root.get_node_or_null(element_id) as Area3D
	if platform_node:
		platform_node.queue_free()

	var path_node_name := "MotionPath_%s" % element_id
	var path_node: Node3D = world_3d_root.get_node_or_null(path_node_name)
	if path_node:
		path_node.queue_free()

	if _cubic_dd_cache.has(element_id):
		_cubic_dd_cache.erase(element_id)
	if _cubic_rot_dd_cache.has(element_id):
		_cubic_rot_dd_cache.erase(element_id)


func _update_all_platform_positions(time: float) -> void:
	for child in get_tree().get_nodes_in_group("platforms"):
		var platform_3d_node = child as Area3D
		if not is_instance_valid(platform_3d_node): continue
		var element_id: String = platform_3d_node.name
		var platform_data: Dictionary = SimData.get_element_data(element_id)
		if platform_data.is_empty(): continue

		var motion_path_data: Dictionary = platform_data.get("motion_path", {})
		var waypoints: Array = motion_path_data.get("waypoints", [])
		var interp_type: String = motion_path_data.get("interpolation", "static")

		if waypoints.is_empty():
			platform_3d_node.position = Vector3.ZERO
			continue

		var new_pos := Vector3.ZERO
		match interp_type:
			"static": new_pos = _get_pos_from_waypoint(waypoints[0])
			"linear": new_pos = _get_position_linear(time, waypoints)
			"cubic":
				var dd := _get_or_calculate_cubic_dd(element_id, waypoints)
				if not dd.is_empty():
					new_pos = _get_position_cubic(time, waypoints, dd)
		platform_3d_node.position = new_pos

		var location_label: Label3D = platform_3d_node.get_node_or_null("LocationLabel")
		if location_label:
			# Display position in FERS coordinates (X, Y-Plane, Altitude) which map to Godot's (X, Z, Y)
			location_label.text = "Pos: (%.1f, %.1f, %.1f)" % [new_pos.x, new_pos.z, new_pos.y]


func _update_all_platform_orientations(time: float) -> void:
	for child in get_tree().get_nodes_in_group("platforms"):
		var platform_3d_node = child as Area3D
		if not is_instance_valid(platform_3d_node): continue
		
		var element_id: String = platform_3d_node.name
		var platform_data: Dictionary = SimData.get_element_data(element_id)
		if platform_data.is_empty(): continue

		var is_sensor = platform_data.get("platform_type_actual") in ["monostatic", "transmitter", "receiver"]
		var visuals_node := platform_3d_node.get_node_or_null("BoresightVisuals") as Node3D
		if visuals_node:
			visuals_node.visible = is_sensor
	
		if not is_sensor:
			platform_3d_node.basis = Basis.IDENTITY
			continue

		var rotation_model = platform_data.get("rotation_model", {})
		platform_3d_node.basis = _get_current_rotation(time, rotation_model, element_id)


func _on_platform_input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, element_id: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		SimData.set_selected_element_id(element_id)
		get_viewport().set_input_as_handled()


# --- Boresight and LOD functions ---
func _update_dynamic_view_elements() -> void:
	var adaptive_scale = max(1.0, _camera_distance / boresight_lod_distance)
	var cam_pos = camera.global_position

	for node in get_tree().get_nodes_in_group("platforms"):
		var platform_node = node as Area3D
		if not is_instance_valid(platform_node): continue

		# --- Adaptive Scaling for Visibility at Distance ---
		var sphere := platform_node.get_node_or_null("Sphere") as CSGSphere3D
		if sphere:
			sphere.scale = Vector3.ONE * adaptive_scale

		var collision_shape := platform_node.get_node_or_null("CollisionShape") as CollisionShape3D
		if collision_shape:
			collision_shape.scale = Vector3.ONE * adaptive_scale

		# --- Boresight Scaling ---
		var visuals := platform_node.get_node_or_null("BoresightVisuals")
		if visuals and visuals.visible:
			visuals.scale = Vector3.ONE * adaptive_scale
			var cone := visuals.get_node_or_null("BoresightCone") as MeshInstance3D
			if cone:
				cone.visible = true # Always show the cone

		# --- Per-label Sizing ---
		var distance_to_cam = platform_node.global_position.distance_to(cam_pos)
	
		var name_label: Label3D = platform_node.get_node_or_null("NameLabel")
		if name_label:
			var world_height = distance_to_cam * perceptual_scale_factor
			name_label.pixel_size = world_height / name_label.font_size
	
		var location_label: Label3D = platform_node.get_node_or_null("LocationLabel")
		if location_label:
			# Maintain relative size. Location label is smaller.
			var world_height = (distance_to_cam * perceptual_scale_factor) * (48.0 / 64.0)
			location_label.pixel_size = world_height / location_label.font_size

	for node in get_tree().get_nodes_in_group("motion_paths"):
		var motion_path_node = node as Node3D
		for path_child in motion_path_node.get_children():
			if path_child is Label3D:
				var distance_to_cam = path_child.global_position.distance_to(cam_pos)
				var world_height = (distance_to_cam * perceptual_scale_factor) * (48.0 / 64.0)
				path_child.pixel_size = world_height / path_child.font_size

	if grid_labels.visible:
		for label in grid_labels.get_children():
			var label_3d = label as Label3D
			var distance_to_cam = label_3d.global_position.distance_to(cam_pos)
			# Grid labels are smaller.
			var world_height = (distance_to_cam * perceptual_scale_factor) * (32.0 / 64.0)
			label_3d.pixel_size = world_height / label_3d.font_size


func _get_beamwidth_from_antenna(antenna_data: Dictionary) -> float:
	if antenna_data.is_empty():
		return 10.0 # Default beamwidth if no antenna is linked

	var pattern_type = antenna_data.get("antenna_pattern_actual", "isotropic")
	match pattern_type:
		"isotropic":
			return 360.0 # Effectively no beam
		"gaussian":
			# Assume azscale/elscale are the half-power beamwidths in degrees.
			# A cone is symmetrical, so we use the larger of the two.
			var az_bw = float(antenna_data.get("azscale", 5.0))
			var el_bw = float(antenna_data.get("elscale", 5.0))
			return max(az_bw, el_bw)
		"sinc", "squarehorn", "parabolic", "file", "xml":
			# For these, a precise beamwidth calculation is complex. Use a sensible default.
			return 15.0 
	return 10.0 # Final fallback


func _update_boresight_visuals(element_id: String, platform_data: Dictionary) -> void:
	var platform_node: Area3D = world_3d_root.get_node_or_null(element_id) as Area3D
	if not platform_node: return

	var visuals_node := platform_node.get_node_or_null("BoresightVisuals") as Node3D
	if not visuals_node: return

	var platform_type = platform_data.get("platform_type_actual", "target")
	var is_sensor = platform_type in ["monostatic", "transmitter", "receiver"]
	visuals_node.visible = is_sensor
	if not is_sensor: return

	# --- Get Antenna Data ---
	var antenna_id_ref_key = "%s_antenna_id_ref" % platform_type
	var antenna_id = platform_data.get(antenna_id_ref_key, "")
	var antenna_data = SimData.get_element_data(antenna_id)

	var beam_color = platform_data.get("color", Color.WHITE)

	# --- Update Cone ---
	var cone := visuals_node.get_node_or_null("BoresightCone") as MeshInstance3D
	if cone:
		var beam_angle_deg = _get_beamwidth_from_antenna(antenna_data)
		var cone_radius = boresight_length * tan(deg_to_rad(beam_angle_deg / 2.0))
	
		var cone_mesh := cone.mesh as CylinderMesh
		cone_mesh.height = boresight_length
		cone_mesh.bottom_radius = cone_radius
	
		# CylinderMesh origin is its center. We want the base (top) to be at the platform center.
		# By default, cone points up (+Y). We rotate it to point forward (+Z).
		cone.rotation.x = deg_to_rad(-90)
		cone.position.z = boresight_length / 2.0
	
		var cone_mat := cone.get_active_material(0) as StandardMaterial3D
		cone_mat.albedo_color = beam_color * Color(1,1,1,0.2) # Apply transparency


# --- Motion Path Visualization ---
func _update_motion_path_visualization(element_id: String, platform_data: Dictionary) -> void:
	var path_node_name := "MotionPath_%s" % element_id
	var path_node: Node3D = world_3d_root.get_node_or_null(path_node_name)

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
		path_node.add_to_group("motion_paths")
		world_3d_root.add_child(path_node)
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
		dd = _get_or_calculate_cubic_dd(element_id, waypoints)
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
		imm_mesh.surface_add_vertex(path_points[i])
		imm_mesh.surface_add_vertex(path_points[i+1])
	imm_mesh.surface_end()
	mesh_inst.mesh = imm_mesh
	path_node.add_child(mesh_inst)

	# --- Annotations ---
	for wp in waypoints:
		var wp_data: Dictionary = wp
		var wp_pos: Vector3 = _get_pos_from_waypoint(wp_data)
		var label := Label3D.new()
		label.text = "%ss\n(%.1f, %.1f, %.1f)" % [wp_data.get("time", 0.0), wp_data.get("x", 0.0), wp_data.get("y", 0.0), wp_data.get("altitude", 0.0)]
		label.modulate = platform_data.get("color", Color.WHITE)
		label.font_size = 48
		label.outline_size = 6
		label.outline_modulate = Color.BLACK
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = wp_pos
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


func _get_or_calculate_cubic_dd(element_id: String, waypoints: Array) -> Array:
	if _cubic_dd_cache.has(element_id):
		return _cubic_dd_cache[element_id]

	var dd: Array[Vector3] = _finalize_cubic(waypoints)
	if not dd.is_empty():
		_cubic_dd_cache[element_id] = dd
	return dd


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


# --- Grid Drawing ---
func toggle_grid_visibility(should_show: bool) -> void:
	show_grid = should_show
	if is_instance_valid(grid_mesh_instance):
		grid_mesh_instance.visible = show_grid
	if is_instance_valid(grid_labels):
		grid_labels.visible = should_show


func _setup_grid() -> void:
	if not is_instance_valid(grid_mesh_instance):
		return

	# Create the Grid Plane Geometry
	var plane_mesh := QuadMesh.new()
	# The QuadMesh is on the XY plane by default. For a full-screen shader pass,
	# we only need a simple 2x2 quad, as the vertex shader will handle stretching
	# it to cover the screen. This gives vertex coordinates from -1 to 1.
	plane_mesh.size = Vector2(2, 2)
	grid_mesh_instance.mesh = plane_mesh

	# The rotation is no longer needed as the vertex shader now directly
	# controls the quad's screen position and the grid is conceptually infinite.
	grid_mesh_instance.rotation_degrees = Vector3.ZERO

	# Create and apply shader material
	var grid_shader := load("res://assets/shaders/grid_shader.gdshader")
	var grid_material := ShaderMaterial.new()
	grid_material.shader = grid_shader

	# Set uniforms from the exported script variables
	grid_material.set_shader_parameter("major_color", major_grid_color)
	grid_material.set_shader_parameter("minor_color", minor_grid_color)
	grid_material.set_shader_parameter("line_width", grid_line_width)

	grid_mesh_instance.material_override = grid_material


# --- Rotation Interpolation ---
func _get_current_rotation(time: float, rotation_data: Dictionary, element_id: String) -> Basis:
	var rotation_type = rotation_data.get("type", "fixed")
	var az: float = 0.0
	var el: float = 0.0

	if rotation_type == "fixed":
		var fixed_data = rotation_data.get("fixed_rotation_data", {})
		az = deg_to_rad(fixed_data.get("start_azimuth", 0.0) + fixed_data.get("azimuth_rate", 0.0) * time)
		el = deg_to_rad(fixed_data.get("start_elevation", 0.0) + fixed_data.get("elevation_rate", 0.0) * time)
	else: # path
		var path_data = rotation_data.get("rotation_path_data", {})
		var waypoints = path_data.get("waypoints", [])
		var interp = path_data.get("interpolation", "static")
	
		if not waypoints.is_empty():
			var rot_vec2: Vector2
			match interp:
				"static":
					rot_vec2 = _get_rot_from_waypoint(waypoints[0])
				"linear":
					rot_vec2 = _get_rotation_linear(time, waypoints)
				"cubic":
					var dd_rot = _get_or_calculate_cubic_rot_dd(element_id, waypoints)
					if not dd_rot.is_empty():
						rot_vec2 = _get_rotation_cubic(time, waypoints, dd_rot)
					else: # Fallback
						rot_vec2 = _get_rotation_linear(time, waypoints)
			az = deg_to_rad(rot_vec2.x)
			el = deg_to_rad(rot_vec2.y)

	# Create basis from YXZ Euler angles (Yaw, Pitch, Roll)
	# FERS Azimuth -> Yaw (Y-axis rotation)
	# FERS Elevation -> Pitch (local X-axis rotation)
	return Basis.from_euler(Vector3(el, az, 0), EULER_ORDER_YXZ)


func _get_rot_from_waypoint(waypoint: Dictionary) -> Vector2:
	var az: float = waypoint.get("azimuth", 0.0)
	var el: float = waypoint.get("elevation", 0.0)
	return Vector2(az, el)


func _get_rotation_linear(t: float, waypoints: Array) -> Vector2:
	if waypoints.is_empty(): return Vector2.ZERO
	var xrp_idx: int = _find_upper_bound_idx(t, waypoints)

	if xrp_idx == 0: return _get_rot_from_waypoint(waypoints[0])
	if xrp_idx == waypoints.size(): return _get_rot_from_waypoint(waypoints.back())

	var xli_idx: int = xrp_idx - 1
	var p_right: Dictionary = waypoints[xrp_idx]
	var p_left: Dictionary = waypoints[xli_idx]

	var iw: float = p_right.get("time", 0.0) - p_left.get("time", 0.0)
	if iw <= 0.0: return _get_rot_from_waypoint(p_left)

	var rw: float = (p_right.get("time", 0.0) - t) / iw
	var lw: float = 1.0 - rw

	return _get_rot_from_waypoint(p_right) * lw + _get_rot_from_waypoint(p_left) * rw


func _get_rotation_cubic(t: float, waypoints: Array, dd: Array) -> Vector2:
	if waypoints.is_empty() or dd.is_empty(): return Vector2.ZERO
	var xrp_idx: int = _find_upper_bound_idx(t, waypoints)

	if xrp_idx == 0: return _get_rot_from_waypoint(waypoints[0])
	if xrp_idx == waypoints.size(): return _get_rot_from_waypoint(waypoints.back())

	var xli_idx: int = xrp_idx - 1
	var p_right: Dictionary = waypoints[xrp_idx]
	var p_left: Dictionary = waypoints[xli_idx]

	var xrd_t: float = p_right.get("time", 0.0) - t
	var xld_t: float = t - p_left.get("time", 0.0)
	var iw: float = p_right.get("time", 0.0) - p_left.get("time", 0.0)
	if iw <= 0.0: return _get_rot_from_waypoint(p_left)

	var iws_6: float = (iw * iw) / 6.0
	var a: float = xrd_t / iw
	var b: float = xld_t / iw
	var c: float = (a*a*a - a) * iws_6
	var d: float = (b*b*b - b) * iws_6

	return _get_rot_from_waypoint(p_left) * a + _get_rot_from_waypoint(p_right) * b + dd[xli_idx] * c + dd[xrp_idx] * d


func _get_or_calculate_cubic_rot_dd(element_id: String, waypoints: Array) -> Array:
	if _cubic_rot_dd_cache.has(element_id):
		return _cubic_rot_dd_cache[element_id]

	var dd: Array[Vector2] = _finalize_cubic_rot(waypoints)
	if not dd.is_empty():
		_cubic_rot_dd_cache[element_id] = dd
	return dd


func _safe_vec2_div(numerator: Vector2, denominator: Vector2) -> Vector2:
	var x: float = numerator.x / denominator.x if denominator.x != 0.0 else 0.0
	var y: float = numerator.y / denominator.y if denominator.y != 0.0 else 0.0
	return Vector2(x, y)


func _finalize_cubic_rot(waypoints: Array) -> Array[Vector2]:
	var wp_count: int = waypoints.size()
	if wp_count < 2: return []

	var dd: Array[Vector2]; dd.resize(wp_count)
	var tmp: Array[Vector2]; tmp.resize(wp_count)

	dd[0] = Vector2.ZERO
	dd[wp_count-1] = Vector2.ZERO
	tmp[0] = Vector2.ZERO

	# Forward decomposition loop
	for i in range(1, wp_count - 1):
		var p_curr: Dictionary = waypoints[i]
		var p_prev: Dictionary = waypoints[i-1]
		var p_next: Dictionary = waypoints[i+1]

		var yrd: Vector2 = _get_rot_from_waypoint(p_next) - _get_rot_from_waypoint(p_curr)
		var yld: Vector2 = _get_rot_from_waypoint(p_curr) - _get_rot_from_waypoint(p_prev)
		var xrd: float = p_next.get("time", 0.0) - p_curr.get("time", 0.0)
		var xld: float = p_curr.get("time", 0.0) - p_prev.get("time", 0.0)
		var iw: float = p_next.get("time", 0.0) - p_prev.get("time", 0.0)

		if iw == 0.0: continue

		var si: float = xld / iw
		var p_vec: Vector2 = dd[i-1] * si + Vector2(2.0, 2.0)

		var dd_num_vec := Vector2(si-1.0, si-1.0)
		dd[i] = _safe_vec2_div(dd_num_vec, p_vec)

		var yrd_div: Vector2 = yrd / xrd if xrd != 0.0 else Vector2.ZERO
		var yld_div: Vector2 = yld / xld if xld != 0.0 else Vector2.ZERO

		var tmp_num_vec: Vector2 = ((yrd_div - yld_div) * (6.0 / iw)) - (tmp[i-1] * si)
		tmp[i] = _safe_vec2_div(tmp_num_vec, p_vec)

	# Back-substitution loop
	for i in range(wp_count - 2, -1, -1):
		dd[i] = dd[i] * dd[i+1] + tmp[i]

	return dd


# --- Camera Control ---
func _gui_input(event: InputEvent) -> void:
	# If viewport is focused, consume key events to prevent UI navigation.
	if _has_focus and event is InputEventKey:
		match event.keycode:
			KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E:
				get_viewport().set_input_as_handled()
				return # It's a key event, not a mouse one, so we are done.

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
			var effective_pan_speed = pan_speed * _camera_distance
			_target_position -= right * motion_event.relative.x * effective_pan_speed
			_target_position += up * motion_event.relative.y * effective_pan_speed
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# This ensures that if the mouse button is released outside the viewport,
	# we stop panning/rotating.
	if _is_rotating and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_is_rotating = false
	if _is_panning and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_is_panning = false

	if _has_focus:
		# --- Keyboard Panning (WASDQE) ---
		var pan_input := Vector3.ZERO
		if Input.is_key_pressed(KEY_W): pan_input.z += 1
		if Input.is_key_pressed(KEY_S): pan_input.z -= 1
		if Input.is_key_pressed(KEY_A): pan_input.x -= 1
		if Input.is_key_pressed(KEY_D): pan_input.x += 1
		if Input.is_key_pressed(KEY_E): pan_input.y += 1
		if Input.is_key_pressed(KEY_Q): pan_input.y -= 1

		if is_instance_valid(camera) and pan_input != Vector3.ZERO:
			# Get camera's forward and right vectors on the horizontal plane
			var forward := -camera.global_transform.basis.z.slide(Vector3.UP).normalized()
			var right := camera.global_transform.basis.x.slide(Vector3.UP).normalized()
			var effective_keyboard_pan_speed = keyboard_pan_speed * (_camera_distance / 10.0) * delta
			# Pan on XZ plane
			_target_position += right * pan_input.x * effective_keyboard_pan_speed
			_target_position += forward * pan_input.z * effective_keyboard_pan_speed
			# Pan on Y axis
			_target_position.y += pan_input.y * (keyboard_pan_speed * 0.5) * delta # Make vertical pan less sensitive

		# --- Keyboard Orbiting (Arrow Keys) ---
		var orbit_input := Vector2.ZERO
		if Input.is_key_pressed(KEY_LEFT): orbit_input.x -= 1
		if Input.is_key_pressed(KEY_RIGHT): orbit_input.x += 1
		if Input.is_key_pressed(KEY_UP): orbit_input.y -= 1
		if Input.is_key_pressed(KEY_DOWN): orbit_input.y += 1

		if orbit_input != Vector2.ZERO:
			_camera_yaw += orbit_input.x * keyboard_orbit_speed * delta
			_camera_pitch = clamp(_camera_pitch + orbit_input.y * keyboard_orbit_speed * delta, -PI / 2.0 + 0.01, PI / 2.0 - 0.01)

	# --- Dynamic Clipping Plane Calculation ---
	if is_instance_valid(camera):
		# Calculate Camera Altitude (using distance from focal point)
		var altitude: float = max(1.0, _camera_distance)
	
		# Define a Dynamic Clipping Formula
		var new_far_plane: float = max(min_far_clip, altitude * far_to_altitude_ratio)
		var new_near_plane: float = max(min_near_clip, new_far_plane * near_to_far_ratio)
	
		# Update the Camera's near and far properties
		camera.near = new_near_plane
		camera.far = new_far_plane

	# --- Adaptive Grid Logic ---
	if show_grid and is_instance_valid(grid_mesh_instance):
		var grid_material := grid_mesh_instance.get_material_override() as ShaderMaterial
		if grid_material:
			var camera_dist: float = _camera_distance
		
			# Calculate the current LOD level based on a logarithmic scale of the camera distance.
			# Using log() for natural logarithm, and dividing by log(10.0) to get base-10 log.
			var log_dist: float = log(camera_dist) / log(10.0) if camera_dist > 0.0 else 0.0
		
			# The major grid lines are the primary reference, determined by the integer part of the log.
			var major_spacing_exponent: float = floor(log_dist)
			var major_spacing: float = pow(10.0, major_spacing_exponent)
		
			# The minor grid lines are one level of detail finer.
			var minor_spacing: float = major_spacing / 10.0
		
			# Calculate fade factor for a smooth transition between LODs.
			# The fractional part of the log tells us how far we are between two levels.
			var lod_fraction: float = log_dist - floor(log_dist)
		
			# We want minor lines to be fully visible when a new LOD level starts (fraction is low),
			# and fully faded out just before the next level begins (fraction is high).
			# The range (e.g., 0.5 to 0.9) determines when the fade starts and ends, giving a
			# period where minor lines are solid before they begin to fade.
			var fade_factor: float = 1.0 - smoothstep(0.5, 0.9, lod_fraction)
		
			# Update all shader uniforms
			grid_material.set_shader_parameter("major_grid_spacing", major_spacing)
			grid_material.set_shader_parameter("minor_grid_spacing", minor_spacing)
			grid_material.set_shader_parameter("fade_factor", fade_factor)

			# --- LABEL UPDATE LOGIC ---
			# Check if LOD changed or if camera panned more than one major grid line
			var current_cam_xz_pos = camera.global_position * Vector3(1, 0, 1)
			var camera_pan_dist_sq := current_cam_xz_pos.distance_squared_to(_last_label_update_cam_pos)
			if major_spacing != _last_major_grid_spacing or camera_pan_dist_sq > (major_spacing * major_spacing):
				_update_grid_labels(major_spacing)
				_last_major_grid_spacing = major_spacing
				_last_label_update_cam_pos = current_cam_xz_pos

	_update_dynamic_view_elements()
	_update_camera_transform()


func frame_scene_contents() -> void:
	# Get nodes directly from groups, which is much more efficient than iterating all children.
	var platform_nodes: Array = get_tree().get_nodes_in_group("platforms")
	var path_nodes: Array = get_tree().get_nodes_in_group("motion_paths")

	if platform_nodes.is_empty() and path_nodes.is_empty():
		# Reset to a default view if nothing exists
		var tween_reset := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween_reset.tween_property(self, "_target_position", Vector3.ZERO, 0.5)
		tween_reset.parallel().tween_property(self, "_camera_distance", 12.0, 0.5)
		return

	# Calculate the AABB that encloses all platforms and their motion paths.
	var aabb: AABB
	var has_content := false

	for p_node in platform_nodes:
		var platform_3d_node = p_node as Area3D
		if not is_instance_valid(platform_3d_node): continue
		if not has_content:
			aabb = AABB(platform_3d_node.position, Vector3.ZERO)
			has_content = true
		else:
			aabb = aabb.expand(platform_3d_node.position)

	for path_node_base in path_nodes:
		var path_node = path_node_base as Node3D
		if not is_instance_valid(path_node): continue
		for path_child in path_node.get_children():
			if path_child is MeshInstance3D:
				var child_aabb = path_child.get_aabb()
				if not has_content:
					aabb = child_aabb
					has_content = true
				else:
					aabb = aabb.merge(child_aabb)

	if not has_content: return # Nothing to frame

	var new_target_pos = aabb.get_center()

	# Use a bounding sphere approach for a robust distance calculation.
	var bounding_sphere_radius = aabb.size.length() / 2.0
	if bounding_sphere_radius < 0.01: # Scene content is essentially a single point.
		if not platform_nodes.is_empty():
			return focus_on_element(platform_nodes[0].name)
		else:
			var tween_focus := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween_focus.tween_property(self, "_target_position", new_target_pos, 0.5)
			tween_focus.parallel().tween_property(self, "_camera_distance", 10.0, 0.5)
			return

	# Get the tightest FOV (vertical or horizontal) to ensure the AABB fits.
	var v_fov_rad = deg_to_rad(camera.fov)
	var h_fov_rad = 2 * atan(tan(v_fov_rad / 2) * camera.get_viewport().get_visible_rect().size.aspect())
	var min_fov = min(v_fov_rad, h_fov_rad)

	var new_cam_distance = (bounding_sphere_radius / tan(min_fov / 2.0)) * 1.2 # Add a 20% margin

	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_target_position", new_target_pos, 0.5)
	tween.parallel().tween_property(self, "_camera_distance", new_cam_distance, 0.5)


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

	# A sensible distance to frame a platform of radius 0.5
	var new_camera_distance = 10.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_target_position", platform_node.position, 0.5)
	tween.parallel().tween_property(self, "_camera_distance", new_camera_distance, 0.5)

# --- Grid Label Drawing ---
func _format_distance_label(distance: float) -> String:
	var abs_dist: float = abs(distance)
	if abs_dist < 0.01:
		return "0m"
	
	if abs_dist >= 1000.0:
		return "%.1fkm" % (distance / 1000.0)
	
	return "%.0fm" % distance

func _update_grid_labels(major_spacing: float) -> void:
	# Clear existing labels before regenerating
	for child in grid_labels.get_children():
		child.queue_free()

	if not show_grid or major_spacing <= 0.0:
		return

	# --- Dynamic Label Generation based on Camera Position and Major Grid Spacing ---
	# Find the camera's position projected onto the grid (XZ plane)
	var camera_focus_point := Vector2(camera.global_position.x, camera.global_position.z)

	# Find the closest major grid line to the camera for both axes
	var center_grid_x = round(camera_focus_point.x / major_spacing) * major_spacing
	var center_grid_z = round(camera_focus_point.y / major_spacing) * major_spacing # Vector2.y is world Z

	# Define how many labels to draw in each direction from the center line
	var labels_per_direction = 10

	# Generate X-axis labels
	for i in range(-labels_per_direction, labels_per_direction + 1):
		var x = center_grid_x + (i * major_spacing)
		# Don't create a label at the origin, the axes lines handle that.
		if abs(x) > 0.001:
			var label_pos := Vector3(x, 0, 0)
			var label_text := str(_format_distance_label(x))
			_create_grid_label(label_pos, label_text)

	# Generate Z-axis labels
	for i in range(-labels_per_direction, labels_per_direction + 1):
		var z = center_grid_z + (i * major_spacing)
		if abs(z) > 0.001:
			var label_pos := Vector3(0, 0, z)
			var label_text := str(_format_distance_label(z))
			_create_grid_label(label_pos, label_text)


func _create_grid_label(pos: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.outline_size = 4
	label.outline_modulate = Color.BLACK
	# Use the same color as the major grid lines for consistency
	label.modulate = major_grid_color
	# "Billboard" the label so it always faces the camera
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	grid_labels.add_child(label)
