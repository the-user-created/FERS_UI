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
@onready var rewind_button: Button = %rewind_button
@onready var play_button: Button = %play_button
@onready var pause_button: Button = %pause_button
@onready var step_button: Button = %step_button
@onready var time_label: Label = %time_label
@onready var frame_scene_button: Button = %frame_scene_button


# --- GODOT VIRTUAL METHODS ---
func _ready() -> void:
	# Connect local UI interaction signals
	rewind_button.pressed.connect(SimData.rewind)
	play_button.pressed.connect(SimData.play)
	pause_button.pressed.connect(SimData.pause)
	step_button.pressed.connect(SimData.step)
	toggle_left_sidebar_button.pressed.connect(_on_toggle_left_sidebar_button_pressed)
	toggle_right_sidebar_button.pressed.connect(_on_toggle_right_sidebar_button_pressed)
	frame_scene_button.pressed.connect(world_3d_view.frame_scene_contents)
	right_sidebar.camera_focus_requested.connect(_on_camera_focus_requested)

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
	play_button.disabled = is_playing
	pause_button.disabled = not is_playing


func _on_simulation_time_updated(new_time: float) -> void:
	time_label.text = "Time: %.2fs" % new_time


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
