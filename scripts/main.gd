class_name Main
extends Control

# --- EXPORT VARIABLES ---
@export var sidebar_width: float = 300.0
@export var sidebar_tween_duration: float = 0.2

# --- ONREADY VARIABLES (Node References) ---
@onready var left_sidebar: Control = %left_sidebar
@onready var right_sidebar: Control = %right_sidebar
@onready var toggle_left_sidebar_button: Button = %toggle_left_sidebar_button
@onready var toggle_right_sidebar_button: Button = %toggle_right_sidebar_button
@onready var world_3d_view: World3DView = %world_3d_view
@onready var reset_button: Button = %reset_button
@onready var step_back_button: Button = %step_back_button
@onready var play_pause_button: Button = %play_pause_button
@onready var step_forward_button: Button = %step_forward_button
@onready var time_label: Label = %time_label
@onready var frame_scene_button: Button = %frame_scene_button
@onready var file_menu_button: MenuButton = %file_menu_button

var export_file_dialog: FileDialog

# --- GODOT VIRTUAL METHODS ---
func _ready() -> void:
	# Connect local UI interaction signals
	reset_button.pressed.connect(SimData.rewind)
	step_back_button.pressed.connect(SimData.step_back)
	play_pause_button.pressed.connect(SimData.toggle_play_pause)
	step_forward_button.pressed.connect(SimData.step)
	toggle_left_sidebar_button.pressed.connect(_on_toggle_left_sidebar_button_pressed)
	toggle_right_sidebar_button.pressed.connect(_on_toggle_right_sidebar_button_pressed)
	frame_scene_button.pressed.connect(world_3d_view.frame_scene_contents)
	right_sidebar.camera_focus_requested.connect(_on_camera_focus_requested)
	
	# Setup File menu and export dialog
	export_file_dialog = FileDialog.new()
	export_file_dialog.title = "Export Simulation to XML"
	export_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_file_dialog.add_filter("*.xml", "XML Simulation File")
	export_file_dialog.file_selected.connect(_on_export_file_selected)
	add_child(export_file_dialog)
	file_menu_button.get_popup().add_item("Export to XML...", 0)
	file_menu_button.get_popup().id_pressed.connect(_on_file_menu_id_pressed)

	# Set initial UI state
	toggle_left_sidebar_button.text = "<" if left_sidebar.visible else ">"
	toggle_right_sidebar_button.text = ">" if right_sidebar.visible else "<"
	_on_playback_state_changed(SimData.is_playing)
	_on_simulation_time_updated(SimData.simulation_time)

	# Connect to SimData signals for playback UI
	SimData.playback_state_changed.connect(_on_playback_state_changed)
	SimData.simulation_time_updated.connect(_on_simulation_time_updated)

	# Select default item. RightSidebar listens to SimulationData and will populate itself.
	SimData.call_deferred("set_selected_element_id", "sim_name")


# --- SIGNAL CALLBACKS for local UI ---
func _on_toggle_left_sidebar_button_pressed() -> void:
	_toggle_sidebar(left_sidebar, toggle_left_sidebar_button, true)


func _on_toggle_right_sidebar_button_pressed() -> void:
	_toggle_sidebar(right_sidebar, toggle_right_sidebar_button, false)


func _on_camera_focus_requested(element_id: String) -> void:
	world_3d_view.focus_on_element(element_id)


func _on_playback_state_changed(is_playing: bool) -> void:
	play_pause_button.text = "Pause" if is_playing else "Play"


func _on_simulation_time_updated(new_time: float) -> void:
	time_label.text = "Time: %.2fs" % new_time


func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		0: # Export to XML
			var sim_name = SimData.get_element_data("sim_name").get("name_value", "simulation")
			export_file_dialog.current_file = "%s.xml" % sim_name.to_snake_case()
			export_file_dialog.popup_centered()


func _on_export_file_selected(path: String) -> void:
	var xml_string: String = SimData.export_as_xml()
	if xml_string.is_empty():
		printerr("Failed to generate XML string.")
		return

	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(xml_string)


# --- PRIVATE HELPER METHODS ---
# Reusable function to handle sidebar animation and visibility.
func _toggle_sidebar(sidebar_node: Control, button_node: Button, is_left_sidebar: bool) -> void:
	var is_currently_visible := sidebar_node.visible
	var target_width: float = 0.0 if is_currently_visible else sidebar_width

	# Ensure sidebar is visible before starting the tween to open it
	if not is_currently_visible:
		sidebar_node.visible = true

	var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sidebar_node, "custom_minimum_size:x", target_width, sidebar_tween_duration)

	# After tween completes, hide the node if its width is 0
	tween.tween_callback(func(): sidebar_node.visible = (target_width > 0))

	# Update button text immediately
	_update_toggle_button_text(button_node, not is_currently_visible, is_left_sidebar)


# Helper to set button text
func _update_toggle_button_text(button_node: Button, is_opening: bool, is_left: bool) -> void:
	if is_left:
		button_node.text = "<" if is_opening else ">"
	else:
		button_node.text = ">" if is_opening else "<"
