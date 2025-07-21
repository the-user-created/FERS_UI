# 4. 3D Scene Visualization

The 3D World View is a critical component of FERS-UI, providing an intuitive, interactive environment to build and
visualize radar simulation scenarios. It dynamically renders and updates simulation elements based on data from the
central data store.

## Dynamic Scene Population and Updates

The 3D view is designed to be fully reactive to changes in the simulation data:

* **Initial Load:** Upon startup or XML import, the 3D view queries the central data store for all existing simulation
  elements (e.g., platforms) and procedurally creates their 3D representations.
* **Real-time Updates:** It continuously listens for signals from the central data store indicating when an element is
  added, updated, or removed.
    * **Additions:** New 3D models are instantiated and placed in the scene.
    * **Updates:** Existing models have their properties (like position, color, scale) adjusted in real-time. This
      includes re-evaluating interpolation curves for motion.
    * **Removals:** 3D models are efficiently removed from the scene when their corresponding data is deleted.
* **Playback Synchronization:** During simulation playback, the 3D view listens to time updates from the central data
  store to precisely animate platform movements and rotations according to their defined paths.

## Interpolation for Motion and Rotation

Simulation elements can have complex motion and rotation profiles, defined by a series of waypoints:

* **Motion Paths:** Platforms move along defined paths, with configurable interpolation types:
    * **Static:** Remains at the first waypoint's position.
    * **Linear:** Moves directly between waypoints at a constant rate.
    * **Cubic:** Provides smooth, continuous curves between waypoints, crucial for realistic movement.
* **Rotation Models:** Elements can have fixed rotation rates or follow a rotational path:
    * **Fixed Rate:** Rotates continuously at a specified azimuth and elevation rate.
    * **Waypoint Path:** Rotates according to a sequence of azimuth and elevation waypoints, using either linear or
      cubic interpolation.

The 3D view dynamically calculates the interpolated position and orientation of each element at the current simulation
time, caching complex calculations (like cubic splines) to optimize performance.

## Adaptive Visuals

To maintain clarity and relevance across varying camera distances and simulation scales, the 3D view implements adaptive
visual features:

* **Dynamic Scaling:** The visual size of elements (e.g., platform spheres, boresight cones) adapts with camera
  distance. This ensures that objects remain visible when zoomed far out, while still reflecting their relative physical
  sizes.
* **Label Sizing:** Information labels (element names, positions) dynamically adjust their pixel size to remain readable
  regardless of zoom level.
* **Boresight Visuals:** Sensor-equipped platforms (transmitters, receivers, monostatic radars) display visual cues
  representing their boresight direction and beamwidth. These cues dynamically adjust in detail (e.g., from a cone to a
  simple line) based on the camera's distance to optimize rendering.

## Advanced Grid Rendering

The Cartesian grid in the 3D view utilizes an advanced screen-space shader technique for efficient and scalable
rendering, rather than relying on a large 3D mesh.

* **Screen-Space Quad:** Instead of drawing a vast, world-aligned mesh, the grid is rendered onto a simple 2D quad that
  is stretched to cover the entire screen by mapping its vertices directly to **Normalized Device Coordinates (NDC)**.
  This bypasses traditional 3D transformations.
* **Ray-Plane Intersection:** For every pixel on this screen-filling quad, the shader calculates a ray extending from
  the camera into the 3D world. It then performs a mathematical intersection test to determine where this ray hits the
  conceptual ground plane (typically `Y=0` in world space).
* **World-Space Grid Logic:** All grid line calculations are performed based on these calculated *world-space*
  intersection points. This means the grid lines are fixed to specific world coordinates (e.g., every 100 meters on the
  X and Z axes), providing a consistent and infinite reference plane.
* **Adaptive Density & Fade:** The grid intelligently adjusts its major and minor line spacing based on camera zoom
  level, and gracefully fades out finer lines at greater distances, preventing visual clutter.

This approach offers significant performance benefits over rendering a traditional 3D grid mesh, especially in
large-scale simulations, as the computational cost is primarily tied to screen resolution rather than the physical
extent of the grid.

## Camera Control and Scene Framing

The 3D view includes intuitive camera controls and utilities:

* **Orbit/Pan/Zoom:** Users can freely navigate the 3D space using standard mouse controls.
* **Keyboard Navigation:** WASD/QE controls allow for direct camera movement.
* **Frame Scene Contents:** A utility to automatically adjust the camera's position and zoom level to encompass all
  active simulation elements within the viewport, providing a quick overview of the entire scenario.
* **Focus on Element:** A feature to instantly move and orient the camera to center on a selected simulation element.
