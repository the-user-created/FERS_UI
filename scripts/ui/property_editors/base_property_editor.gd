## Base class for all property editor panels.
## Provides common UI-building helpers and data communication logic.
class_name BasePropertyEditor
extends VBoxContainer

# --- Member Variables ---
var current_element_id: String
var current_element_data: Dictionary
# Each editor that needs it will have its own FileDialog instance.
var _file_dialog: FileDialog
var _file_picker_context: Dictionary = {}


# --- Godot Virtual Methods ---
func _ready() -> void:
	# All editors need to react if the data they are showing gets updated elsewhere.
	SimData.element_updated.connect(_on_simulation_data_element_updated)


# --- Public API ---
## Main entry point. Called by LeftSidebarPanel to display properties for an element.
func display_properties(element_id: String, element_data: Dictionary) -> void:
	current_element_id = element_id
	current_element_data = element_data.duplicate(true)

	# Clear any UI from a previously selected element
	for child in get_children():
		child.queue_free()

	# Call the virtual method that child classes MUST implement.
	_rebuild_ui()


# --- Virtual Methods for Children to Implement ---
## Child classes must override this method to build their specific UI.
func _rebuild_ui() -> void:
	# This method should be implemented by inheriting classes.
	# Example: _add_string_editor("Name", "name", current_element_data.get("name"))
	push_warning("BasePropertyEditor._rebuild_ui() was called, but should be overridden by the child class.")


# --- Signal Handlers ---
func _on_simulation_data_element_updated(element_id: String, element_data: Dictionary) -> void:
	# If the updated element is the one we are currently showing, refresh our view.
	if element_id == current_element_id:
		display_properties.call_deferred(element_id, element_data)


func _on_browse_button_pressed(context: Dictionary) -> void:
	if not is_instance_valid(_file_dialog):
		_file_dialog = FileDialog.new()
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.file_selected.connect(_on_file_dialog_file_selected)
		add_child(_file_dialog)

	_file_picker_context = context
	_file_dialog.title = context.get("dialog_title", "Select File")
	_file_dialog.popup_centered()


func _on_file_dialog_file_selected(path: String) -> void:
	if _file_picker_context.is_empty():
		return

	var line_edit_node = _file_picker_context.get("line_edit_node")
	if is_instance_valid(line_edit_node):
		line_edit_node.text = path

	_emit_property_change(_file_picker_context.property_key, path)
	_file_picker_context.clear()


# --- Data Communication ---
## Central function to notify the data store of a change.
func _emit_property_change(property_key: String, new_value: Variant) -> void:
	SimData.update_element_property(current_element_id, property_key, new_value)


## Helper for modifying a value inside a nested dictionary (like 'rotation_model').
func _on_nested_property_changed(new_value: Variant, top_level_key: String, path_to_value: String) -> void:
	# Get a fresh copy of the top-level dictionary.
	var top_level_dict: Dictionary = current_element_data.get(top_level_key, {}).duplicate(true)

	# Traverse the path to set the new value.
	var path_parts: Array = path_to_value.split(".")
	var current_dict_ref = top_level_dict

	for i in range(path_parts.size() - 1):
		var key = path_parts[i]
		if not current_dict_ref.has(key) or not current_dict_ref[key] is Dictionary:
			# Path is invalid, can't proceed.
			printerr("Invalid path in _on_nested_property_changed: ", path_to_value)
			return
		current_dict_ref = current_dict_ref[key]

	current_dict_ref[path_parts.back()] = new_value

	# Emit the change for the entire top-level dictionary.
	_emit_property_change(top_level_key, top_level_dict)


# --- UI Creation Helper Methods (for children to use) ---
func _add_string_editor(label_text: String, property_key: String, current_val: String) -> void:
	var hbox := HBoxContainer.new()
	var label := Label.new(); label.text = label_text + ":"; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var line_edit := LineEdit.new(); line_edit.text = current_val; line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Use text_submitted to avoid sending updates on every keystroke.
	line_edit.text_submitted.connect(_emit_property_change.bind(property_key))
	# Also save when focus is lost.
	line_edit.focus_exited.connect(func(): _emit_property_change(property_key, line_edit.text))
	hbox.add_child(line_edit)
	add_child(hbox)


func _add_numerical_editor(label_text: String, property_key: String, current_val: float, p_allow_float := true, p_allow_negative := true) -> NumericLineEdit:
	var hbox := HBoxContainer.new()
	var label := Label.new(); label.text = label_text + ":"; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var num_edit := NumericLineEdit.new()
	num_edit.allow_float = p_allow_float
	num_edit.allow_negative = p_allow_negative
	num_edit.text = str(current_val)
	num_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# When user presses Enter or focus is lost, convert to float and emit.
	num_edit.text_submitted.connect(func(new_text): _emit_property_change(property_key, new_text.to_float()))
	num_edit.focus_exited.connect(func(): _emit_property_change(property_key, num_edit.text.to_float()))

	hbox.add_child(num_edit)
	add_child(hbox)

	return num_edit  # Return the NumericLineEdit for further customization if needed.


func _add_option_button(label_text: String, property_key: String, options_arr: Array, current_selection_val: Variant) -> void:
	var hbox := HBoxContainer.new()
	var label := Label.new(); label.text = label_text + ":"; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var option_button := OptionButton.new(); option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_idx: int = -1
	for i in range(options_arr.size()):
		var option_item = options_arr[i]; var item_text: String; var item_value: Variant
		if typeof(option_item) == TYPE_DICTIONARY and option_item.has("name") and option_item.has("value"):
			item_text = str(option_item.name); item_value = option_item.value
		else:
			item_text = str(option_item); item_value = option_item
		option_button.add_item(item_text, i); option_button.set_item_metadata(i, item_value)
		if item_value == current_selection_val: selected_idx = i

	if selected_idx != -1: option_button.select(selected_idx)

	option_button.item_selected.connect(
		func(idx): _emit_property_change(property_key, option_button.get_item_metadata(idx))
	)
	hbox.add_child(option_button)
	add_child(hbox)


func _add_checkbox(label_text: String, property_key: String, is_checked: bool) -> void:
	var check_box := CheckBox.new(); check_box.text = label_text; check_box.button_pressed = is_checked
	check_box.toggled.connect(func(is_pressed): _emit_property_change(property_key, is_pressed))
	add_child(check_box)


func _add_title_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	add_child(HSeparator.new())


func _add_dynamic_element_dropdown(label_text: String, property_key: String, item_type_to_list: String, current_selection_id: String) -> void:
	var available_elements: Array = SimData.get_elements_by_type(item_type_to_list)
	var options_for_btn: Array[Variant] = [{"name": "None", "value": ""}]
	for item_dict in available_elements:
		options_for_btn.append({"name": str(item_dict.name), "value": str(item_dict.id)})
	_add_option_button(label_text, property_key, options_for_btn, current_selection_id)


func _add_file_picker(label_text: String, property_key: String, current_path: String, dialog_title: String) -> void:
	var hbox := HBoxContainer.new()
	var label := Label.new(); label.text = label_text + ":"; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var line_edit := LineEdit.new(); line_edit.text = current_path; line_edit.editable = false; line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(line_edit)

	var button := Button.new(); button.text = "Browse..."
	var context := {
		"property_key": property_key,
		"line_edit_node": line_edit,
		"dialog_title": dialog_title
	}
	button.pressed.connect(_on_browse_button_pressed.bind(context))
	hbox.add_child(button)
	add_child(hbox)	
