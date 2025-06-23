class_name ElementDefaults

# Default data for newly created elements
static func getDefaultData(elementType: String, elName: String, elId: String) -> Dictionary:
	var base_data: Dictionary = {"id": elId, "type": elementType, "name": elName}
	match elementType:
		"platform":
			base_data.merge({
				"color": Color.from_hsv(randf(), 0.8, 1.0),
				"platform_type_actual": "target",
				"motion_path": {
					"interpolation": "static", # static, linear, cubic
					"waypoints": [{"time": 0.0, "x": 0.0, "y": 0.0, "altitude": 0.0}]
				},
				"rotation_model": {
					"type": "fixed", # fixed
					"fixed_rotation_data": {
						"start_azimuth": 0.0, "start_elevation": 0.0,
						"azimuth_rate": 0.0, "elevation_rate": 0.0
					},
					"rotation_path_data": {
						"interpolation": "static", # static, linear, cubic
						"waypoints": [{"time": 0.0, "azimuth": 0.0, "elevation": 0.0}]
					}
				}
			}, true)
			# Merge defaults for the initial platform subtype (target)
			base_data.merge(getPlatformSubtypeDefaults("target"), true)
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
			printerr("ElementDefaults: Unknown element type for default data: ", elementType)
	return base_data


# Default properties for specific platform subtypes
static func getPlatformSubtypeDefaults(platformSubtype: String) -> Dictionary:
	match platformSubtype:
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
static func getStructuralRefreshTriggerKeys() -> Dictionary:
	return {
		"platform": [
		"platform_type_actual", "target_rcs_type_actual",
		"target_rcs_fluctuation_model_type", "transmitter_type_actual",
		"motion_path_interpolation", "rotation_model_type", "rotation_path_interpolation"
		],
		"pulse": ["pulse_type_actual"],
		"antenna": ["antenna_pattern_actual"]
	}


# Helper to clean/prepare platform data when its subtype changes
static func preparePlatformDataForSubtypeChange(existingData: Dictionary, newSubtype: String) -> Dictionary:
	var default_platform_data := getDefaultData("platform", "", "")

	var new_platform_data: Dictionary = {
		"id": existingData.id,
		"type": "platform",
		"name": existingData.name,
		"color": existingData.get("color", Color.from_hsv(randf(), 0.8, 1.0)),
		"motion_path": existingData.get("motion_path", default_platform_data.motion_path),
		"rotation_model": existingData.get("rotation_model", default_platform_data.rotation_model),
		"platform_type_actual": newSubtype
	}

	new_platform_data.merge(getPlatformSubtypeDefaults(newSubtype), true)
	return new_platform_data
