shader_type spatial;
// Unshaded so it's not affected by lighting.
// Cull disabled so it's visible from below.
// Blend mix so alpha channel is used for transparency.
render_mode unshaded, cull_disabled, blend_mix;

uniform vec4 major_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 minor_color : source_color = vec4(0.5, 0.5, 0.5, 0.5);
uniform float major_grid_spacing = 10.0;
uniform float minor_grid_spacing = 1.0;
uniform float line_width = 0.05;
uniform float fade_factor = 1.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Helper function to draw a smooth, anti-aliased grid line.
float get_line_alpha(float coord, float spacing) {
	// Calculate the width of a pixel in world space for this coordinate.
	// This is the key to anti-aliasing.
	float pixel_width = fwidth(coord);

	// Calculate the distance to the nearest grid line.
	float dist_to_line = min(mod(coord, spacing), spacing - mod(coord, spacing));

	// Use smoothstep to create a soft edge. The transition from line to empty space
	// will happen over the width of one pixel.
	// This creates a smooth, anti-aliased line instead of a hard, aliased one.
	return 1.0 - smoothstep(
		(line_width / 2.0) - pixel_width,
		(line_width / 2.0) + pixel_width,
		dist_to_line
	);
}

void fragment() {
	// Calculate alpha values for major and minor lines using our anti-aliasing function.
	float major_alpha = max(get_line_alpha(world_position.x, major_grid_spacing), get_line_alpha(world_position.z, major_grid_spacing));
	float minor_alpha = max(get_line_alpha(world_position.x, minor_grid_spacing), get_line_alpha(world_position.z, minor_grid_spacing));

	// Apply the LOD fade factor to the minor lines' alpha.
	minor_alpha *= fade_factor;

	// Combine the colors. Start with the minor lines, then blend the major lines on top.
	vec4 final_color = mix(vec4(minor_color.rgb, minor_alpha), major_color, major_alpha);

	// If the final alpha is very low, discard the pixel for a small performance boost.
	if (final_color.a < 0.01) {
		discard;
	}

	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
}
