class_name ElementDefaults

# Default data for newly created elements
static func get_default_data(element_type: String, el_name: String, el_id: String) -> Dictionary:
	var base_data: Dictionary = {"id": el_id, "type": element_type, "name": el_name}
	match element_type:
		"platform":
			base_data.merge({
				"platform_type_actual": "target",
				"position_x": 0.0,
				"position_y": 0.0,
				"altitude": 0.0,
			}, true)
			# Merge defaults for the initial platform subtype (target)
			base_data.merge(get_platform_subtype_defaults("target"), true)
		"pulse":
			base_data.merge({
				"pulse_type_actual": "file",
				"power": 100.0,
				"carrier_frequency": 10_000_000_000.0,
				"pulse_filename": "waveform.csv"
			}, true)
		"timing_source":
			base_data.merge({
				"frequency": 10_000_000.0
			}, true)
		"antenna":
			base_data.merge({
				"antenna_pattern_actual": "isotropic",
				"filename": ""
			}, true)
		_:
			printerr("ElementDefaults: Unknown element type for default data: ", element_type)
	return base_data


# Default properties for specific platform subtypes
static func get_platform_subtype_defaults(platform_subtype: String) -> Dictionary:
	match platform_subtype:
		"monostatic":
			return {
				"monostatic_radar_type": "continuous",
				"monostatic_prf": 1.0,
				"monostatic_window_skip": 0.0,
				"monostatic_window_length": 0.1,
				"monostatic_noise_temp": 0.0,
				"monostatic_nodirect": false,
				"monostatic_nopropagationloss": false,
				"monostatic_antenna_id_ref": "",
				"monostatic_pulse_id_ref": "",
				"monostatic_timing_id_ref": ""
			}
		"transmitter":
			return {
				"transmitter_type_actual": "pulsed",
				"transmitter_prf": 1000.0,
				"transmitter_pulse_id_ref": "",
				"transmitter_antenna_id_ref": "",
				"transmitter_timing_id_ref": ""
			}
		"receiver":
			return {
				"receiver_prf": 1000.0,
				"receiver_window_skip": 0.0,
				"receiver_window_length": 0.1,
				"receiver_noise_temp": 290.0, # Standard ambient temp
				"receiver_nodirect": false,
				"receiver_nopropagationloss": false,
				"receiver_antenna_id_ref": "",
				"receiver_timing_id_ref": ""
			}
		"target":
			return {
				"target_rcs_type_actual": "isotropic",
				"target_rcs_value": 10.0,
				"target_rcs_filename": "",
				"target_rcs_fluctuation_model_type": "constant",
				"target_rcs_fluctuation_value": 1.0, # For 'constant' model
				"target_rcs_fluctuation_k": 1.0      # For 'chisquare'/'gamma' models
			}
	return {}


# Defines which property keys, when changed, should trigger a structural refresh of the LeftSidebarPanel
static func get_structural_refresh_trigger_keys() -> Dictionary:
	return {
		"platform": ["platform_type_actual", "target_rcs_type_actual", "target_rcs_fluctuation_model_type", "transmitter_type_actual"],
		"pulse": ["pulse_type_actual"],
		"antenna": ["antenna_pattern_actual"]
	}


# Helper to clean/prepare platform data when its subtype changes
static func prepare_platform_data_for_subtype_change(existing_data: Dictionary, new_subtype: String) -> Dictionary:

	var new_platform_data: Dictionary = {
		"id": existing_data.id,
		"type": "platform",
		"name": existing_data.name,
		"position_x": existing_data.position_x,
		"position_y": existing_data.position_y,
		"altitude": existing_data.altitude,
		"platform_type_actual": new_subtype
	}

	new_platform_data.merge(get_platform_subtype_defaults(new_subtype), true)
	return new_platform_data
