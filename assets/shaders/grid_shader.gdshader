shader_type spatial;
// Unshaded so it's not affected by lighting.
// Cull disabled so it's visible from below.
// Blend mix so alpha channel is used for transparency.
render_mode unshaded, cull_disabled, blend_mix;

// --- New uniforms for hierarchy and fading ---
uniform vec4 major_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 minor_color : source_color = vec4(0.5, 0.5, 0.5, 0.5);
uniform float major_grid_spacing = 10.0;
uniform float minor_grid_spacing = 1.0;
uniform float line_width = 0.05;
uniform float fade_factor = 1.0;

// The vertex's world-space position, passed from the vertex shader.
varying vec3 world_position;

void vertex() {
	// Pass the world-space position of the vertex to the fragment shader.
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// --- Hierarchical line logic ---
	// Calculate distance to the nearest major grid line.
	float major_dist_x = min(mod(world_position.x, major_grid_spacing), major_grid_spacing - mod(world_position.x, major_grid_spacing));
	float major_dist_z = min(mod(world_position.z, major_grid_spacing), major_grid_spacing - mod(world_position.z, major_grid_spacing));
	float major_min_dist = min(major_dist_x, major_dist_z);

	if (major_min_dist < line_width / 2.0) {
		// This pixel is on a major line.
		ALBEDO = major_color.rgb;
		ALPHA = major_color.a;
	} else {
		// Calculate distance to the nearest minor grid line.
		float minor_dist_x = min(mod(world_position.x, minor_grid_spacing), minor_grid_spacing - mod(world_position.x, minor_grid_spacing));
		float minor_dist_z = min(mod(world_position.z, minor_grid_spacing), minor_grid_spacing - mod(world_position.z, minor_grid_spacing));
		float minor_min_dist = min(minor_dist_x, minor_dist_z);

		if (minor_min_dist < line_width / 2.0) {
			// This pixel is on a minor line.
			ALBEDO = minor_color.rgb;
			// Use the fade_factor to control the alpha of the minor lines.
			ALPHA = minor_color.a * fade_factor;
		} else {
			// This pixel is not on any line, so make it fully transparent.
			discard;
		}
	}
}
