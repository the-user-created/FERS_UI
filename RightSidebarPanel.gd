class_name RightSidebarPanel
extends VBoxContainer

signal element_selected(item_metadata: Dictionary)
signal add_new_element_requested(element_metadata: Dictionary)
@onready var scenario_tree: Tree = $ScenarioTreeContainer/ScenarioTree

# Category items for direct access
var platforms_category_item: TreeItem
var pulses_category_item: TreeItem
var timing_sources_category_item: TreeItem
var antennas_category_item: TreeItem
# Counters for unique ID generation
var platform_id_counter: int = 0
var pulse_id_counter: int = 0
var timing_id_counter: int = 0
var antenna_id_counter: int = 0


func _ready() -> void:
	name = "RightSidebar"

	if not is_instance_valid(scenario_tree):
		printerr("RightSidebarPanel: ScenarioTree node not found! Ensure it exists at path ScenarioTreeContainer/ScenarioTree in RightSidebarPanel.tscn")
		return

	scenario_tree.columns = 1
	scenario_tree.hide_root = true
	scenario_tree.connect("item_selected", Callable(self, "_on_scenario_tree_item_selected"))

	var tree_root: TreeItem = scenario_tree.create_item()

	# --- Permanent Elements ---
	_add_permanent_item(tree_root, "Simulation Name", "sim_name", "global_simulation_name")
	_add_permanent_item(tree_root, "Simulation Parameters", "sim_params", "global_simulation_parameters")

	# --- Modifiable Element Categories ---
	platforms_category_item = _add_category_item(tree_root, "Platforms", "category_platforms")
	pulses_category_item = _add_category_item(tree_root, "Pulses", "category_pulses")
	timing_sources_category_item = _add_category_item(tree_root, "Timing Sources", "category_timing_sources")
	antennas_category_item = _add_category_item(tree_root, "Antennas", "category_antennas")

	platforms_category_item.set_selectable(0, false)
	pulses_category_item.set_selectable(0, false)
	timing_sources_category_item.set_selectable(0, false)
	antennas_category_item.set_selectable(0, false)

	_add_action_button("Add Platform", "_on_add_new_element_pressed", ["platform"])
	_add_action_button("Add Pulse", "_on_add_new_element_pressed", ["pulse"])
	_add_action_button("Add Timing Source", "_on_add_new_element_pressed", ["timing_source"])
	_add_action_button("Add Antenna", "_on_add_new_element_pressed", ["antenna"])


func _add_permanent_item(parent: TreeItem, text: String, id_val: String, type_val: String) -> TreeItem:
	var item: TreeItem = parent.create_child()
	item.set_text(0, text)
	item.set_metadata(0, {"id": id_val, "type": type_val, "name": text})
	return item


# Helper to add category items
func _add_category_item(parent: TreeItem, text: String, type_val: String) -> TreeItem:
	var item: TreeItem = parent.create_child()
	item.set_text(0, text)
	item.set_metadata(0, {"type": type_val})
	item.set_custom_color(0, Color.GRAY)
	return item


func _add_action_button(text: String, method_name: String, binds: Array = []) -> Button:
	var button = Button.new()
	button.text = text
	button.connect("pressed", Callable(self, method_name).bindv(binds))
	add_child(button)
	return button


func _on_scenario_tree_item_selected() -> void:
	var selected_item: TreeItem = scenario_tree.get_selected()
	if selected_item:
		var metadata: Dictionary = selected_item.get_metadata(0)
		# Only emit signal for items that represent actual data elements (have an 'id')
		if metadata and metadata.has("id"):
			emit_signal("element_selected", metadata)


func _on_add_new_element_pressed(element_type_str: String) -> void:
	var item_name_prefix: String
	var item_id: String

	match element_type_str:
		"platform":
			platform_id_counter += 1
			item_id = "platform_%d" % platform_id_counter
			item_name_prefix = "Platform"
		"pulse":
			pulse_id_counter += 1
			item_id = "pulse_%d" % pulse_id_counter
			item_name_prefix = "Pulse"
		"timing_source":
			timing_id_counter += 1
			item_id = "timing_%d" % timing_id_counter
			item_name_prefix = "TimingSource"
		"antenna":
			antenna_id_counter += 1
			item_id = "antenna_%d" % antenna_id_counter
			item_name_prefix = "Antenna"
		_:
			printerr("RightSidebarPanel: Unknown element type to add: ", element_type_str)
			return

	var current_counter_value: int
	match element_type_str:
		"platform": current_counter_value = platform_id_counter
		"pulse": current_counter_value = pulse_id_counter
		"timing_source": current_counter_value = timing_id_counter
		"antenna": current_counter_value = antenna_id_counter

	var item_name: String = "%s_%d" % [item_name_prefix, current_counter_value]

	var metadata_for_main: Dictionary = {
		"type": element_type_str,
		"id": item_id,
		"name": item_name
	}
	emit_signal("add_new_element_requested", metadata_for_main)


func create_and_select_tree_item(item_creation_metadata: Dictionary) -> void:
	var parent_category_item: TreeItem
	var item_type_str: String = item_creation_metadata.get("type", "")

	match item_type_str:
		"platform": parent_category_item = platforms_category_item
		"pulse": parent_category_item = pulses_category_item
		"timing_source": parent_category_item = timing_sources_category_item
		"antenna": parent_category_item = antennas_category_item
		_:
			printerr("RightSidebarPanel: Cannot determine parent TreeItem for type: ", item_type_str)
			return

	if not is_instance_valid(parent_category_item):
		printerr("RightSidebarPanel: Parent category TreeItem is invalid for type: ", item_type_str)
		return

	var item_name_to_display: String = item_creation_metadata.get("name", "Unnamed Item")
	var item_id: String = item_creation_metadata.get("id", "unknown_id_")

	var new_item: TreeItem = parent_category_item.create_child()
	if new_item:
		new_item.set_text(0, item_name_to_display)
		var tree_item_meta: Dictionary = {
			"type": item_type_str,
			"id": item_id,
			"name": item_name_to_display
		}
		new_item.set_metadata(0, tree_item_meta)

		var currently_selected: TreeItem = scenario_tree.get_selected()
		if is_instance_valid(currently_selected):
			currently_selected.deselect(0)

		new_item.select(0)
		scenario_tree.set_selected(new_item, 0)
		scenario_tree.scroll_to_item(new_item, true)
	else:
		printerr("RightSidebarPanel: Failed to create TreeItem for '", item_name_to_display, "'")


func update_item_name(item_id: String, new_name: String) -> void:
	if not is_instance_valid(scenario_tree) or not is_instance_valid(scenario_tree.get_root()):
		printerr("RightSidebarPanel: Scenario tree or root is not available for update_item_name.")
		return

	var item_to_update: TreeItem = _find_item_by_id(item_id, scenario_tree.get_root())
	if is_instance_valid(item_to_update):
		item_to_update.set_text(0, new_name)
		var meta: Variant = item_to_update.get_metadata(0)
		if meta is Dictionary:
			var dict_meta: Dictionary = meta
			dict_meta["name"] = new_name
			item_to_update.set_metadata(0, dict_meta)
		elif meta == null:
			var new_meta_dict: Dictionary = {"id": item_id, "name": new_name}
			printerr("RightSidebarPanel: Warning - item '%s' found by ID had null metadata. Re-creating." % item_id)
			item_to_update.set_metadata(0, new_meta_dict)
		else:
			printerr("RightSidebarPanel: Warning - item '%s' metadata is not a Dictionary." % item_id)


func _find_item_by_id(id_to_find: String, current_item: TreeItem) -> TreeItem:
	if not is_instance_valid(current_item):
		return null

	var metadata: Variant = current_item.get_metadata(0)
	if metadata is Dictionary and metadata.has("id") and metadata.get("id") == id_to_find:
		return current_item

	var child: TreeItem = current_item.get_first_child()
	while is_instance_valid(child):
		var found_in_child: TreeItem = _find_item_by_id(id_to_find, child)
		if is_instance_valid(found_in_child):
			return found_in_child
		child = child.get_next()
	return null


func select_default_item() -> void:
	if is_instance_valid(scenario_tree) and is_instance_valid(scenario_tree.get_root()):
		var first_data_item: TreeItem = scenario_tree.get_root().get_first_child()
		if is_instance_valid(first_data_item):
			# Ensure it's actually selectable (not a category if categories were made selectable)
			if first_data_item.is_selectable(0):
				first_data_item.select(0)
				scenario_tree.set_selected(first_data_item, 0)
			else:
				var next_item: TreeItem = first_data_item.get_next()
				if is_instance_valid(next_item) and next_item.is_selectable(0):
					next_item.select(0)
					scenario_tree.set_selected(next_item, 0)
