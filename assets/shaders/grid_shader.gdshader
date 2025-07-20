shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// Visual properties
uniform vec4 major_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 minor_color : source_color = vec4(0.5, 0.5, 0.5, 0.5);
uniform float line_width : hint_range(0.0, 0.2) = 0.05;

// Grid Spacing & LOD
uniform float major_grid_spacing = 10.0;
uniform float minor_grid_spacing = 1.0;
uniform float fade_factor = 1.0;

// Conceptual Grid Plane
uniform vec3 grid_plane_normal = vec3(0.0, 1.0, 0.0);
uniform float grid_plane_offset = 0.0;

// Varying to pass data from vertex to fragment shader
varying vec3 world_space_direction;

void vertex() {
	// 1. Make the quad cover the entire screen by setting its position in clip space.
	// We use the raw VERTEX coordinates which are (-1,-1) to (1,1) for a 2x2 QuadMesh.
	// We set z to 1.0 for the near plane in Godot's reversed-Z buffer.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);

	// 2. Calculate the direction vector from the camera to the vertex in world space.
	// Unproject the vertex from clip space to world space. We project onto the far plane.
	// For reversed-Z, the far plane is at z=0 in clip space.
	vec4 world_pos_far = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(VERTEX.xy, 0.0, 1.0);
	world_pos_far.xyz /= world_pos_far.w;

	// 3. The direction is the vector from the camera's position to this unprojected point.
	// This vector will be interpolated for each pixel in the fragment shader.
	world_space_direction = world_pos_far.xyz - CAMERA_POSITION_WORLD;
}

// Helper function to draw a smooth, anti-aliased grid line.
float get_line_alpha(float coord, float spacing) {
	// Calculate the width of a pixel in world space for this coordinate.
	float pixel_width = fwidth(coord);
	// Calculate the distance to the nearest grid line.
	float dist_to_line = min(mod(coord, spacing), spacing - mod(coord, spacing));
	// Use smoothstep to create a soft edge over the width of one pixel.
	return 1.0 - smoothstep(
		(line_width / 2.0) - pixel_width,
		(line_width / 2.0) + pixel_width,
		dist_to_line
	);
}

void fragment() {
	// The direction from the vertex shader is interpolated for each fragment.
	// We need to normalize it to get a unit direction vector for the ray.
	vec3 ray_dir = normalize(world_space_direction);

	// --- Ray-Plane Intersection ---
	// Discard pixels where the ray is parallel to the plane to avoid division by zero.
	float denominator = dot(ray_dir, grid_plane_normal);
	if (abs(denominator) < 0.0001) {
		discard;
	}

	// Calculate distance 't' along the ray to the intersection point.
	float t = (grid_plane_offset - dot(CAMERA_POSITION_WORLD, grid_plane_normal)) / denominator;

	// Discard pixels where the intersection is behind the camera.
	if (t < 0.0) {
		discard;
	}

	// Calculate the world-space position of the intersection.
	vec3 world_position = CAMERA_POSITION_WORLD + ray_dir * t;

	// --- Grid Drawing Logic (reused from previous phase) ---
	// Calculate alpha values for major and minor lines using our anti-aliasing function.
	float major_alpha = max(get_line_alpha(world_position.x, major_grid_spacing), get_line_alpha(world_position.z, major_grid_spacing));
	float minor_alpha = max(get_line_alpha(world_position.x, minor_grid_spacing), get_line_alpha(world_position.z, minor_grid_spacing));

	// Apply the LOD fade factor to the minor lines' alpha.
	minor_alpha *= fade_factor;

	// Combine the colors. Start with the minor lines, then blend the major lines on top.
	// We use the alpha from the minor_color uniform.
	vec4 final_color = mix(vec4(minor_color.rgb, minor_alpha * minor_color.a), major_color, major_alpha);

	// If the final alpha is very low, discard the pixel for a small performance boost.
	if (final_color.a < 0.01) {
		discard;
	}

	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
}
