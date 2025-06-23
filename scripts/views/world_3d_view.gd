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
	var element_id = platform_data.id
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
			var x_fers: float = float(first_waypoint.get("x", 0.0))
			var y_fers: float = float(first_waypoint.get("y", 0.0))
			var alt_fers: float = float(first_waypoint.get("altitude", 0.0))
			platform_node.position = Vector3(x_fers, alt_fers, y_fers)

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
	else:
		printerr("World3DView: Platform 3D node '", element_id, "' not found for update.")


func remove_platform_visualization(element_id: String) -> void:
	var platform_node: Node3D = world_3d_root.get_node_or_null(element_id) as Node3D
	if platform_node:
		platform_node.queue_free()


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
			var right := camera.global_transform.basis.x
			var up := camera.global_transform.basis.y
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
	var platform_node := world_3d_root.get_node_or_null(element_id) as Node3D
	if not is_instance_valid(platform_node):
		return
	
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_target_position", platform_node.position, 0.5)
