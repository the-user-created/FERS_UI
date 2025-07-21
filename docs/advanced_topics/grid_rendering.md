# Advanced Rendering: The Screen-Space World Grid

The Cartesian grid in the FERS-UI 3D viewport is a critical visual aid for scenario building. Its implementation, however, is not a straightforward 3D mesh. A naive approach of using a massive `GridMap` or a scaled `PlaneMesh` would suffer from significant performance, precision, and scalability issues.

Instead, FERS-UI employs a modern, high-performance technique that renders a conceptually infinite, world-space grid using a screen-space shader. This document details the theory and methodology behind this implementation.

## The Core Concept: Decoupling Geometry from Logic

The fundamental principle is to separate the geometry being rendered from the visual logic of the grid itself.

-   **The Geometry:** A simple, static `QuadMesh` that does nothing more than cover the entire screen. It is a canvas, not the grid.
-   **The Logic:** A sophisticated shader that runs for every pixel on this canvas. The shader calculates where each pixel "lands" in the 3D world and then decides if a grid line should be drawn there.

This approach moves the complexity from managing enormous 3D geometry to performing efficient mathematical calculations on the GPU.

---

## Part 1: The Canvas (Godot Scene Setup)

The setup in the Godot scene is deceptively simple.

1.  **`MeshInstance3D` with `QuadMesh`:** A `MeshInstance3D` node is added to the scene. Its `mesh` property is set to a `QuadMesh`.
2.  **Size of (2, 2):** The `QuadMesh` is given a size of `(2, 2)`. This is a deliberate choice. Its vertices are positioned at `(-1, -1)`, `(1, -1)`, `(1, 1)`, and `(-1, 1)`. These coordinates correspond directly to the corners of **Normalized Device Coordinates (NDC)**.

This small, static quad is the only piece of geometry required for the entire infinite grid.

---

## Part 2: The Shader Logic (GPU Implementation)

The heavy lifting is done entirely within the `grid_shader.gdshader`. The process is split between the vertex and fragment shader stages.

### The Vertex Shader: From Mesh to Screen

The vertex shader's primary job is to stretch our small quad to perfectly cover the viewport. It accomplishes this by bypassing all standard 3D transformations.

#### Step 1: Bypassing Transformations into NDC Space

The key line of code is:

```glsl
POSITION = vec4(VERTEX.xy, 1.0, 1.0);
```

-   `VERTEX` is the incoming position of a vertex from our `QuadMesh` (e.g., `(-1, -1, 0)`).
-   `POSITION` is a special output variable that sets the final vertex position in **Clip Space**.
-   By directly assigning to `POSITION`, we instruct the GPU to ignore the mesh's world position, the camera's view, and perspective projection.
-   The `VERTEX.xy` values `(-1, 1)` map directly to the corners of the screen in Normalized Device Coordinates (NDC).

This single line ensures our simple quad becomes a full-screen canvas for the fragment shader.

<!-- TODO: Add diagram illustrating the mapping of the 2x2 QuadMesh vertices to the corners of the screen in NDC space. -->

#### Step 2: Calculating the World-Space View Ray

The vertex shader has a second crucial task: for each vertex, it calculates a vector pointing from the camera's position into the 3D world. This "view ray" will be interpolated and passed to every pixel in the fragment shader.

```glsl
// Un-project the NDC vertex position back to a point in the 3D world.
vec4 world_pos_far = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(VERTEX.xy, 0.0, 1.0);
world_pos_far.xyz /= world_pos_far.w;

// The direction is the vector from the camera to this world point.
world_space_direction = world_pos_far.xyz - CAMERA_POSITION_WORLD;
```

This uses the inverse of the camera's view and projection matrices to reverse the rendering pipeline, effectively asking: "For this specific point on the screen, where would that correspond to in the 3D world?"

<!-- TODO: Add diagram showing the camera, the screen plane (our quad), and view rays shooting out from the camera through the pixel locations towards the far plane. -->

### The Fragment Shader: From Pixel to Grid Line

The fragment shader runs for every single pixel on the screen. Its job is to determine if that pixel lies on a grid line.

#### Step 1: Ray-Plane Intersection

Using the `world_space_direction` vector passed from the vertex shader, the fragment shader first calculates where that pixel's view ray intersects the conceptual ground plane (where Y=0).

```glsl
// Using the incoming ray_dir (interpolated world_space_direction)
// and the camera's position, find the intersection point.
vec3 world_position = CAMERA_POSITION_WORLD + ray_dir * t;
```

This `world_position` gives us the exact `(X, 0, Z)` coordinate in the 3D world that the current pixel is "looking at".

<!-- TODO: Add diagram illustrating the ray-plane intersection. Show the camera's eye, a single view ray, the Y=0 grid plane, and the resulting `world_position` point. -->

#### Step 2: Grid Line Logic

With the `world_position`, drawing the grid becomes a simple mathematical check.

```glsl
// Check distance to the nearest major and minor grid lines on both X and Z axes.
float major_alpha = max(get_line_alpha(world_position.x, major_grid_spacing), get_line_alpha(world_position.z, major_grid_spacing));
float minor_alpha = max(get_line_alpha(world_position.x, minor_grid_spacing), get_line_alpha(world_position.z, minor_grid_spacing));
```

The `get_line_alpha` helper function uses `mod()` to find the distance to the nearest line.

#### Step 3: Anti-Aliasing for Smooth Lines

A simple `if` check would result in harsh, pixelated ("aliased") lines. To create smooth, anti-aliased lines that look good at any angle and resolution, we use `fwidth()` and `smoothstep()`.

```glsl
float get_line_alpha(float coord, float spacing) {
    // fwidth() calculates how much `coord` changes between this pixel and the next.
    // This gives us the size of one pixel in world-space units.
    float pixel_width = fwidth(coord);

    // Calculate distance to the nearest grid line.
    float dist_to_line = min(mod(coord, spacing), spacing - mod(coord, spacing));

    // Create a smooth gradient over the width of one pixel.
    return 1.0 - smoothstep(
        (line_width / 2.0) - pixel_width,
        (line_width / 2.0) + pixel_width,
        dist_to_line
    );
}
```

This function doesn't just return `1.0` (draw) or `0.0` (don't draw). Instead, it returns a gradient value if a pixel is very close to a grid line, effectively "fading" the edge of the line and creating a smooth, anti-aliased appearance.

<!-- TODO: Add a close-up, side-by-side image comparing an aliased grid line with a smoothstepped, anti-aliased grid line. -->

---

## Adaptive Level of Detail (LOD)

A static grid quickly becomes visually cluttered when zoomed out or too sparse when zoomed in. The grid shader solves this by dynamically adjusting its density based on camera distance.

### The Mechanism: Logarithmic Scaling

The logic for this resides in the `World3DView` script's `_process` loop, which updates the shader's uniforms every frame.

1.  **Logarithmic Distance:** The core idea is to use the logarithm of the camera's distance (`log(_camera_distance)`). The logarithm naturally maps exponential changes in distance to linear changes in value, which is perfect for "power-of-10" scaling.

2.  **Major and Minor Spacing:**
    -   The `floor()` of the log distance determines the exponent for the major grid lines (e.g., `10^2 = 100`, `10^3 = 1000`). This causes the grid to snap between levels like 10m, 100m, 1000m, etc.
    -   The minor grid lines are simply one level finer (`major_spacing / 10.0`).

3.  **Smooth Fading:**
    -   To prevent minor lines from abruptly popping in and out of view, we calculate a `fade_factor`.
    -   The fractional part of the log distance (`log_dist - floor(log_dist)`) tells us how "far along" we are to the next LOD level.
    -   We use `smoothstep()` to map this fractional progress to a fade value. As the camera zooms out, the minor grid lines become fully transparent just before the major grid lines snap to the next level of detail.

This combination creates a seamless and intuitive grid that always provides a relevant sense of scale without overwhelming the user.

<!-- TODO: Add a series of three images showing the grid at different zoom levels, demonstrating the adaptive LOD changes and fading minor lines. -->

## Summary of Benefits

This screen-space shader approach provides numerous advantages over traditional geometry-based methods:

-   **Infinite Grid:** The grid is mathematically defined and not limited by the size of a mesh.
-   **High Performance:** The rendering cost is dependent on screen resolution, not the visible area of the grid. It remains constant whether viewing 100 square meters or 100 square kilometers.
-   **Perfect Lines:** The lines are rendered per-pixel, resulting in crisp, clean lines with no Z-fighting or moiré patterns that can occur with 3D geometry.
-   **Adaptive Detail:** The LOD system ensures the grid is always useful and aesthetically pleasing at any zoom level.
-   **Low Memory Footprint:** Requires only a tiny 4-vertex mesh, regardless of the grid's conceptual size.
