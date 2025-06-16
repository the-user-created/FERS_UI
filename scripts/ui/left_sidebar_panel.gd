class_name LeftSidebarPanel
extends ScrollContainer

# --- CONSTANTS ---
# Preload all possible property editor scenes.
# This dictionary maps an element type to its dedicated editor scene.
const EDITOR_SCENES: Dictionary = {
	"platform": preload("res://ui/components/property_editors/platform_editor.tscn"),
	"pulse": preload("res://ui/components/property_editors/pulse_editor.tscn"),
	"antenna": preload("res://ui/components/property_editors/antenna_editor.tscn"),
	"timing_source": preload("res://ui/components/property_editors/timing_source_editor.tscn"),
	"global_simulation_name": preload("res://ui/components/property_editors/sim_params_editor.tscn"),
	"global_simulation_parameters": preload("res://ui/components/property_editors/sim_params_editor.tscn"),
}
# --- Node References ---
@onready var vbox_content: VBoxContainer = %properties_vbox

# --- Member Variables ---
var current_editor_instance: Control = null


func _ready() -> void:
	# Connect to the global data store. This is the core of its reactive nature.
	SimData.element_selected.connect(_on_simulation_data_element_selected)

	clear_panel()
	_add_placeholder_label("Select an element from the Scene Hierarchy to view/edit its properties.")


# --- Global Data Store Signal Handlers ---
func _on_simulation_data_element_selected(element_id: String) -> void:
	clear_panel()

	if element_id.is_empty():
		_add_placeholder_label("Select an element to view its properties.")
		return

	var element_data := SimData.get_element_data(element_id)
	if element_data.is_empty():
		_add_placeholder_label("No data for selected element '%s'." % element_id)
		return

	var element_type: String = element_data.get("type", "")

	# The factory logic: find the right scene and instantiate it.
	if EDITOR_SCENES.has(element_type):
		var editor_scene: PackedScene = EDITOR_SCENES[element_type]
		current_editor_instance = editor_scene.instantiate()

		# Add the new editor to the scene tree
		vbox_content.add_child(current_editor_instance)

		# The editor scene's script is expected to have a 'display_properties' method.
		if current_editor_instance.has_method("display_properties"):
			current_editor_instance.display_properties(element_id, element_data)
		else:
			printerr("Editor scene for type '%s' is missing the 'display_properties' method." % element_type)
	else:
		_add_placeholder_label("Property editor not implemented for type: '%s'" % element_type)


# --- Core UI Logic ---
func clear_panel() -> void:
	if is_instance_valid(current_editor_instance):
		current_editor_instance.queue_free()
		current_editor_instance = null

	# Clear any lingering placeholder labels
	for child in vbox_content.get_children():
		child.queue_free()


# --- UI Element Creation Helpers ---
func _add_placeholder_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox_content.add_child(label)
	return label
