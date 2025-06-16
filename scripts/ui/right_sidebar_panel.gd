class_name RightSidebarPanel
extends VBoxContainer

@onready var scenario_tree: Tree = %scenario_tree

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
	# --- Connect to the global data store ---
	SimData.element_added.connect(_on_simulation_data_element_added)
	SimData.element_updated.connect(_on_simulation_data_element_updated)
	SimData.element_removed.connect(_on_simulation_data_element_removed)

	# --- Local Node Setup ---
	scenario_tree.columns = 1
	scenario_tree.hide_root = true
	scenario_tree.item_selected.connect(_on_scenario_tree_item_selected)

	var tree_root: TreeItem = scenario_tree.create_item()

	# Create static categories. The items will be added dynamically.
	_add_permanent_item(tree_root, "Simulation Name", "sim_name", "global_simulation_name")
	_add_permanent_item(tree_root, "Simulation Parameters", "sim_params", "global_simulation_parameters")

	platforms_category_item = _add_category_item(tree_root, "Platforms", "category_platforms")
	pulses_category_item = _add_category_item(tree_root, "Pulses", "category_pulses")
	timing_sources_category_item = _add_category_item(tree_root, "Timing Sources", "category_timing_sources")
	antennas_category_item = _add_category_item(tree_root, "Antennas", "category_antennas")

	# --- Add Element UI ---
	var add_menu_button = MenuButton.new()
	add_menu_button.text = "Add Element"
	var popup_menu = add_menu_button.get_popup()
	popup_menu.add_item("Platform", 0)
	popup_menu.add_item("Pulse", 1)
	popup_menu.add_item("Timing Source", 2)
	popup_menu.add_item("Antenna", 3)
	popup_menu.id_pressed.connect(_on_add_menu_id_pressed)
	add_child(add_menu_button)
	move_child(add_menu_button, 1)


# --- UI Creation Helpers ---
func _add_permanent_item(parent: TreeItem, text: String, id_val: String, type_val: String) -> TreeItem:
	var item: TreeItem = parent.create_child()
	item.set_text(0, text)
	item.set_metadata(0, {"id": id_val, "type": type_val, "name": text})
	return item


func _add_category_item(parent: TreeItem, text: String, type_val: String) -> TreeItem:
	var item: TreeItem = parent.create_child()
	item.set_text(0, text)
	item.set_metadata(0, {"type": type_val})
	item.set_selectable(0, false)
	item.set_custom_color(0, Color.GRAY)
	return item


# --- Local Signal Handlers ---
func _on_scenario_tree_item_selected() -> void:
	var selected_item: TreeItem = scenario_tree.get_selected()
	if selected_item:
		var metadata: Dictionary = selected_item.get_metadata(0)
		if metadata and metadata.has("id"):
			# Instead of emitting a signal, we notify the central data store.
			SimData.set_selected_element_id(metadata.id)


func _on_add_menu_id_pressed(id: int) -> void:
	var element_type_str: String
	var item_name_prefix: String
	var item_id: String
	var current_counter_value: int

	match id:
		0:
			platform_id_counter += 1
			current_counter_value = platform_id_counter
			element_type_str = "platform"
			item_id = "platform_%d" % current_counter_value
			item_name_prefix = "Platform"
		1:
			pulse_id_counter += 1
			current_counter_value = pulse_id_counter
			element_type_str = "pulse"
			item_id = "pulse_%d" % current_counter_value
			item_name_prefix = "Pulse"
		2: # Timing Source
			timing_id_counter += 1
			current_counter_value = timing_id_counter
			element_type_str = "timing_source"
			item_id = "timing_%d" % current_counter_value
			item_name_prefix = "TimingSource"
		3: # Antenna
			antenna_id_counter += 1
			current_counter_value = antenna_id_counter
			element_type_str = "antenna"
			item_id = "antenna_%d" % current_counter_value
			item_name_prefix = "Antenna"
		_:
			printerr("RightSidebarPanel: Unknown element type to add.")
			return

	var item_name: String = "%s_%d" % [item_name_prefix, current_counter_value]

	# Instead of emitting a signal, we call the central data store directly.
	SimData.add_new_element(element_type_str, item_name, item_id)


# --- SimulationData Signal Handlers (This is the reactive part) ---
func _on_simulation_data_element_added(element_data: Dictionary) -> void:
	var parent_category_item: TreeItem
	var item_type_str: String = element_data.type

	match item_type_str:
		"platform": parent_category_item = platforms_category_item
		"pulse": parent_category_item = pulses_category_item
		"timing_source": parent_category_item = timing_sources_category_item
		"antenna": parent_category_item = antennas_category_item
		_:
			# This covers permanent items which are already in the tree.
			return

	var new_item := parent_category_item.create_child()
	new_item.set_text(0, element_data.name)
	new_item.set_metadata(0, {"id": element_data.id, "type": element_data.type, "name": element_data.name})

	# Select the newly created item in the tree
	scenario_tree.set_selected(new_item, 0)
	scenario_tree.scroll_to_item(new_item, true)


func _on_simulation_data_element_updated(element_id: String, element_data: Dictionary) -> void:
	var item_to_update := _find_item_by_id(element_id, scenario_tree.get_root())
	if is_instance_valid(item_to_update):
		var name_prop = element_data.get("name", element_data.get("name_value"))
		item_to_update.set_text(0, str(name_prop))
		var meta: Dictionary = item_to_update.get_metadata(0)
		meta["name"] = str(name_prop)
		item_to_update.set_metadata(0, meta)


func _on_simulation_data_element_removed(element_id: String) -> void:
	var item_to_remove := _find_item_by_id(element_id, scenario_tree.get_root())
	if is_instance_valid(item_to_remove):
		item_to_remove.free() # Removes item from tree


# --- Helper Methods ---
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
