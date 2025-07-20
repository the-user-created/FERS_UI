shader_type spatial;
// Unshaded so it's not affected by lighting.
// Cull disabled so it's visible from below.
// Blend mix so alpha channel is used for transparency.
render_mode unshaded, cull_disabled, blend_mix;

uniform vec4 grid_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float grid_spacing = 10.0;
uniform float line_width = 0.05;

// The vertex's world-space position, passed from the vertex shader.
varying vec3 world_position;

void vertex() {
	// Pass the world-space position of the vertex to the fragment shader.
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The fragment shader is executed on the XZ plane of the quad.
	// We check if the fragment's world position is on a grid line.

	// This calculates distance to the nearest grid line on both X and Z axes.
	float dist_x = min(mod(world_position.x, grid_spacing), grid_spacing - mod(world_position.x, grid_spacing));
	float dist_z = min(mod(world_position.z, grid_spacing), grid_spacing - mod(world_position.z, grid_spacing));

	// The distance to the nearest line (either vertical or horizontal).
	float min_dist = min(dist_x, dist_z);

	// If the distance is less than half the desired line width, this pixel is on a line.
	if (min_dist < line_width / 2.0) {
		ALBEDO = grid_color.rgb;
		ALPHA = grid_color.a;
	} else {
		// Otherwise, discard the pixel to make it fully transparent.
		discard;
	}
}
