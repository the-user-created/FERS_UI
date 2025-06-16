class_name Main
extends Control

# --- ONREADY VARIABLES (Node References) ---
@onready var left_sidebar: Control = %left_sidebar
@onready var right_sidebar: Control = %right_sidebar
@onready var toggle_left_sidebar_button: Button = %toggle_left_sidebar_button
@onready var toggle_right_sidebar_button: Button = %toggle_right_sidebar_button


# --- GODOT VIRTUAL METHODS ---
func _ready() -> void:
	# Connect local UI interaction signals
	toggle_left_sidebar_button.pressed.connect(_on_toggle_left_sidebar_button_pressed)
	toggle_right_sidebar_button.pressed.connect(_on_toggle_right_sidebar_button_pressed)

	# Set initial UI state
	toggle_left_sidebar_button.text = "<" if left_sidebar.visible else ">"
	toggle_right_sidebar_button.text = ">" if right_sidebar.visible else "<"

	# Select default item. RightSidebar listens to SimulationData and will populate itself.
	SimData.call_deferred("set_selected_element_id", "sim_name")


#--- SIGNAL CALLBACKS for local UI---
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
