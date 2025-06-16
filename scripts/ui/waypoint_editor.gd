class_name WaypointEditor
extends AcceptDialog

signal waypoints_updated(new_waypoints_array: Array)
@onready var waypoints_vbox: VBoxContainer = %waypoints_vbox
@onready var add_waypoint_button: Button = %add_waypoint_button

# A local copy of the data to work with.
var _current_waypoints: Array = []
# "motion" or "rotation" to determine which fields to show.
var _waypoint_type: String = "motion"


func _ready() -> void:
	# Connect the dialog's built-in "OK" button signal.
	confirmed.connect(_on_confirmed)
	add_waypoint_button.pressed.connect(_on_add_waypoint_pressed)


func open_with_data(waypoints_data: Array, type: String) -> void:
	_current_waypoints = waypoints_data.duplicate(true)
	_waypoint_type = type
	title = "Edit %s Waypoints" % _waypoint_type.capitalize()
	_rebuild_ui()
	popup_centered()


func _rebuild_ui() -> void:
	for child in waypoints_vbox.get_children():
		child.queue_free()

	for i in range(_current_waypoints.size()):
		var waypoint: Dictionary = _current_waypoints[i]
		var hbox := HBoxContainer.new()
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = HBoxContainer.SIZE_EXPAND_FILL

		_create_spinbox(vbox, "Time (s)", waypoint.get("time", 0.0), i, "time")

		# Dynamically create fields based on waypoint type
		if _waypoint_type == "motion":
			_create_spinbox(vbox, "X (m)", waypoint.get("x", 0.0), i, "x")
			_create_spinbox(vbox, "Y (m)", waypoint.get("y", 0.0), i, "y")
			_create_spinbox(vbox, "Altitude (m)", waypoint.get("altitude", 0.0), i, "altitude")
		elif _waypoint_type == "rotation":
			_create_spinbox(vbox, "Azimuth (deg)", waypoint.get("azimuth", 0.0), i, "azimuth")
			_create_spinbox(vbox, "Elevation (deg)", waypoint.get("elevation", 0.0), i, "elevation")

		hbox.add_child(vbox)

		# Add a remove button for all but the first waypoint
		if i > 0:
			var delete_button := Button.new()
			delete_button.text = "X"
			delete_button.size_flags_vertical = VBoxContainer.SIZE_SHRINK_CENTER
			delete_button.pressed.connect(_on_remove_button_pressed.bind(i))
			hbox.add_child(delete_button)

		waypoints_vbox.add_child(hbox)
		waypoints_vbox.add_child(HSeparator.new())


func _create_spinbox(container: VBoxContainer, label_text: String, value: float, index: int, key: String) -> void:
	var hbox := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Label.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var spinbox := SpinBox.new()
	spinbox.min_value = -1000000000000
	spinbox.max_value = 1000000000000
	spinbox.step = 0.01
	spinbox.value = value
	spinbox.allow_lesser = true
	spinbox.allow_greater = true
	spinbox.size_flags_horizontal = SpinBox.SIZE_EXPAND_FILL
	spinbox.value_changed.connect(_on_waypoint_value_changed.bind(index, key))
	hbox.add_child(spinbox)
	container.add_child(hbox)


func _on_waypoint_value_changed(new_value: float, index: int, key: String) -> void:
	if index < _current_waypoints.size():
		_current_waypoints[index][key] = new_value


func _on_add_waypoint_pressed() -> void:
	if _current_waypoints.is_empty(): return
	var last_waypoint: Dictionary = _current_waypoints.back()
	var new_waypoint: Dictionary = last_waypoint.duplicate()
	new_waypoint["time"] = float(last_waypoint.get("time", 0.0)) + 1.0 # Increment time by 1 second for the new waypoint
	_current_waypoints.append(new_waypoint)
	_rebuild_ui()


func _on_remove_button_pressed(index: int) -> void:
	if index < _current_waypoints.size():
		_current_waypoints.remove_at(index)
		_rebuild_ui()


func _on_confirmed() -> void:
	emit_signal("waypoints_updated", _current_waypoints)
