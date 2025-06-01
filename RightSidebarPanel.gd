class_name RightSidebarPanel
extends VBoxContainer

# Signals to notify other parts of the UI
signal element_selected(item_metadata: Dictionary)
signal add_new_element_requested(element_metadata: Dictionary)

# References to key UI elements we'll create
var scenario_tree: Tree
var platforms_category_item: TreeItem
var pulses_category_item: TreeItem
var timing_sources_category_item: TreeItem
var antennas_category_item: TreeItem

# Counters for default naming
var platform_id_counter: int = 0
var pulse_id_counter: int = 0
var timing_id_counter: int = 0
var antenna_id_counter: int = 0

func _ready() -> void:
	name = "RightSidebar"
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 1. SCENE HIERARCHY SECTION
	var scene_hierarchy_label = Label.new()
	scene_hierarchy_label.text = "SCENE HIERARCHY"
	scene_hierarchy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(scene_hierarchy_label)

	scenario_tree = Tree.new()
	scenario_tree.name = "ScenarioTree"
	scenario_tree.columns = 1
	scenario_tree.hide_root = true
	scenario_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL 
	scenario_tree.connect("item_selected", Callable(self, "_on_scenario_tree_item_selected"))
	add_child(scenario_tree)

	var tree_root = scenario_tree.create_item()

	# --- Permanent Elements ---
	var sim_name_item = tree_root.create_child()
	sim_name_item.set_text(0, "Simulation Name")
	sim_name_item.set_metadata(0, {"type": "global_simulation_name", "id": "sim_name"})

	var sim_params_item = tree_root.create_child()
	sim_params_item.set_text(0, "Simulation Parameters")
	sim_params_item.set_metadata(0, {"type": "global_simulation_parameters", "id": "sim_params"})

	# --- Modifiable Element Categories ---
	platforms_category_item = tree_root.create_child()
	platforms_category_item.set_text(0, "Platforms")
	platforms_category_item.set_metadata(0, {"type": "category_platforms"}) 

	pulses_category_item = tree_root.create_child()
	pulses_category_item.set_text(0, "Pulses")
	pulses_category_item.set_metadata(0, {"type": "category_pulses"})

	timing_sources_category_item = tree_root.create_child()
	timing_sources_category_item.set_text(0, "Timing Sources")
	timing_sources_category_item.set_metadata(0, {"type": "category_timing_sources"})

	antennas_category_item = tree_root.create_child()
	antennas_category_item.set_text(0, "Antennas")
	antennas_category_item.set_metadata(0, {"type": "category_antennas"})

	add_child(VSeparator.new())

	# 2. ADD NEW ELEMENT SECTION
	var add_element_label = Label.new()
	add_element_label.text = "ADD NEW ELEMENT"
	add_element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(add_element_label)

	var add_platform_button = Button.new()
	add_platform_button.text = "Add Platform"
	add_platform_button.connect("pressed", Callable(self, "_on_add_new_element_pressed").bind("platform"))
	add_child(add_platform_button)

	var add_pulse_button = Button.new()
	add_pulse_button.text = "Add Pulse"
	add_pulse_button.connect("pressed", Callable(self, "_on_add_new_element_pressed").bind("pulse"))
	add_child(add_pulse_button)

	var add_timing_button = Button.new()
	add_timing_button.text = "Add Timing Source"
	add_timing_button.connect("pressed", Callable(self, "_on_add_new_element_pressed").bind("timing_source"))
	add_child(add_timing_button)

	var add_antenna_button = Button.new()
	add_antenna_button.text = "Add Antenna"
	add_antenna_button.connect("pressed", Callable(self, "_on_add_new_element_pressed").bind("antenna"))
	add_child(add_antenna_button)

func _on_scenario_tree_item_selected() -> void:
	var selected_item: TreeItem = scenario_tree.get_selected()
	if selected_item:
		var metadata: Dictionary = selected_item.get_metadata(0)
		if metadata and metadata.has("type") and metadata.has("id"):
			emit_signal("element_selected", metadata)
		else:
			# This might be a category header without an 'id', which is fine.
			# Or an item where metadata wasn't set correctly.
			# print("Selected item metadata is incomplete or not an element: ", selected_item.get_text(0))
			pass

func _on_add_new_element_pressed(element_type: String) -> void:
	var item_name: String
	var item_id: String
	var metadata_for_main: Dictionary

	match element_type:
		"platform":
			platform_id_counter += 1
			item_id = "platform_%d" % platform_id_counter
			item_name = "Platform_%d" % platform_id_counter
		"pulse":
			pulse_id_counter += 1
			item_id = "pulse_%d" % pulse_id_counter
			item_name = "Pulse_%d" % pulse_id_counter
		"timing_source":
			timing_id_counter += 1
			item_id = "timing_%d" % timing_id_counter
			item_name = "TimingSource_%d" % timing_id_counter
		"antenna":
			antenna_id_counter += 1
			item_id = "antenna_%d" % antenna_id_counter
			item_name = "Antenna_%d" % antenna_id_counter
		_:
			printerr("Unknown element type to add: ", element_type)
			return

	metadata_for_main = {
		"type": element_type, 
		"id": item_id, 
		"name": item_name
		# No need to pass parent_category_node_path anymore
	}
	emit_signal("add_new_element_requested", metadata_for_main)

func create_and_select_tree_item(item_creation_metadata: Dictionary) -> void:
	# Determine the correct parent TreeItem reference based on the type
	var parent_tree_item_ref: TreeItem
	var item_type_str: String = item_creation_metadata.get("type", "")

	match item_type_str:
		"platform": 
			parent_tree_item_ref = platforms_category_item
		"pulse": 
			parent_tree_item_ref = pulses_category_item
		"timing_source": 
			parent_tree_item_ref = timing_sources_category_item
		"antenna": 
			parent_tree_item_ref = antennas_category_item
		_:
			printerr("RightSidebarPanel: Cannot determine parent TreeItem for type: ", item_type_str)
			return
	
	if not parent_tree_item_ref:
		# This should ideally not happen if the category items were created in _ready()
		printerr("RightSidebarPanel: Parent TreeItem reference (e.g., platforms_category_item) is null for type: ", item_type_str)
		return

	var item_name_to_display: String = item_creation_metadata.get("name", "Unnamed Item")
	var new_item = parent_tree_item_ref.create_child()

	if new_item:
		new_item.set_text(0, item_name_to_display)
		# Metadata for the TreeItem itself (what _on_scenario_tree_item_selected expects)
		var tree_item_meta = {
			"type": item_type_str,
			"id": item_creation_metadata.get("id", "unknown_id"),
			"name": item_name_to_display # Store the name here as well, consistent with metadata from _on_add_new_element_pressed
		}
		new_item.set_metadata(0, tree_item_meta)

		var currently_selected = scenario_tree.get_selected()
		if currently_selected:
			currently_selected.deselect(0)
		
		new_item.select(0)
		scenario_tree.scroll_to_item(new_item)
		scenario_tree.set_selected(new_item, 0) # This will trigger _on_scenario_tree_item_selected
	else:
		printerr("RightSidebarPanel: Failed to create TreeItem for ", item_name_to_display)

func update_item_name(item_id: String, new_name: String) -> void:
	# Ensure scenario_tree and its root are valid before proceeding
	if not scenario_tree or not scenario_tree.get_root():
		printerr("RightSidebarPanel: Scenario tree or root is not available for update_item_name.")
		return

	var item_to_update: TreeItem = _find_item_by_id(item_id, scenario_tree.get_root())
	if item_to_update:
		item_to_update.set_text(0, new_name)
		var meta = item_to_update.get_metadata(0)
		if meta and meta.has("name"): # Check if 'name' exists in metadata
			meta["name"] = new_name
			item_to_update.set_metadata(0, meta)
		elif meta: # If meta exists but no 'name', add it
			meta["name"] = new_name
			item_to_update.set_metadata(0, meta)
		# else: meta is null, cannot update name in it.

func _find_item_by_id(id_to_find: String, current_item: TreeItem) -> TreeItem:
	if not current_item:
		return null

	# Check current item's metadata
	var metadata = current_item.get_metadata(0)
	if metadata and metadata.has("id") and metadata.get("id") == id_to_find:
		return current_item

	# Recursively check direct children
	var child = current_item.get_first_child()
	while child:
		var found_in_child = _find_item_by_id(id_to_find, child)
		if found_in_child:
			return found_in_child
		child = child.get_next()
		
	return null

func select_default_item() -> void:
	if scenario_tree and scenario_tree.get_root():
		var first_data_item = scenario_tree.get_root().get_first_child() 
		if first_data_item:
			first_data_item.select(0)
			scenario_tree.set_selected(first_data_item, 0)
