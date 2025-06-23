# FERS-UI: A Graphical Interface for the Flexible Extensible Radar Simulator

![MSc Project](https://img.shields.io/badge/Status-MSc%20Project-blue)
![Godot Version](https://img.shields.io/badge/Godot-4.x-478CBF?logo=godot-engine)
![Language](https://img.shields.io/badge/Language-GDScript-yellow)
![License](https://img.shields.io/badge/License-GPL--3.0-blue)

## 1. Introduction

`FERS-UI` is the graphical user interface being developed for the **Flexible Extensible Radar Simulator (FERS)**, a powerful, open-source C++ based signal-level simulation tool. The core FERS engine, originally developed by the Radar Research and Signal Group (RRSG), has recently been modernized to C++20/23, creating a robust and high-performance foundation.

This repository contains the development of a modern GUI for FERS, with the primary goal of dramatically improving its usability, accessibility, and educational value. The UI aims to provide an intuitive, visual way to construct, configure, and visualize complex radar simulation scenarios.

This project is being actively developed as part of a **Master of Science (MSc) in Electrical Engineering** at the University of Cape Town.

---

## 2. Project Status & Technology Choices

### Technology Stack
*   **Engine:** Godot Engine (v4.x)
*   **Language:** GDScript
*   **Core Simulator:** FERS (C++20/23)
*   **Data Interchange Format:** XML (for compatibility with FERS)

### Rationale for Tooling
The choice of development tools is a critical engineering decision, balancing features, performance, and development velocity.

#### Primary Choice: Godot Engine
Godot was selected as the primary development platform for several key reasons:
1.  **Native 3D/2D Rendering:** Godot is a game engine at its core, providing a high-performance, cross-platform rendering pipeline out-of-the-box. This is essential for the planned **3D World Builder** and **Simulation Replay/Animation** features.
2.  **Powerful UI System:** The engine includes a comprehensive set of UI nodes and a container-based layout system, enabling the rapid development of complex, responsive user interfaces like property inspectors and scene hierarchies.
3.  **Rapid Prototyping:** The integrated editor, scene system, and simple GDScript language allow for extremely fast iteration cycles.
4.  **Open Source & Extensible:** Godot's open-source nature aligns with the FERS project. Its C++ extension system (GDExtension) offers a clear path for future deep integration with the FERS C++ backend if required.

#### Secondary Consideration: React + Web Technologies
A web-based UI (e.g., using React, Three.js) is also under consideration as a potential alternative or complementary solution.
*   **Pros:** Ultimate accessibility (no installation required), mature ecosystem for 2D UIs.
*   **Cons:** Significantly more complex to achieve high-performance 3D rendering comparable to a native engine; potential for a less integrated "feel" between the 3D view and the UI controls.

The current development focuses on the Godot implementation, as it provides the most direct path to achieving the project's 3D visualization goals.

---

## 3. Core Features

The UI will provide a complete "workbench" for FERS, from scenario creation to results visualization.

*   [ ] **Visual 3D Scenario Builder:** Interactively place and configure platforms, targets, transmitters, and receivers in a 3D environment.
*   [ ] **Hierarchical Scene View:** A tree view of all elements in the simulation (platforms, antennas, pulses, etc.) for easy selection and organization.
*   [ ] **Dynamic Property Inspector:** A context-sensitive panel to edit the parameters of any selected simulation element, from radar parameters to platform motion waypoints.
*   [ ] **FERS XML Exporter:** Generate a valid FERS XML configuration file from the visual scenario, ready to be run by the core simulator.
*   [ ] **Dynamic Simulation Replay & Animation:** Load FERS output data to visualize target trajectories, platform movements, and other simulation dynamics over time.
*   [ ] **Integrated Asset Editors:** UI-driven tools for creating basic waveforms, defining target RCS, and specifying antenna patterns without needing to edit files manually.

---

## 4. Software Development Practices & Architecture

The project is architected using modern software design principles to ensure it is maintainable, extensible, and robust. The codebase demonstrates a commitment to quality through the following practices:

### a. Centralized State Management (Single Source of Truth)

The UI's architecture is centered around a **`SimulationData` autoload singleton**. This global node acts as the single source of truth for all simulation configuration data.
*   **Decoupling:** UI components do not talk to each other directly. Instead, they modify data in `SimulationData` or react to its signals. For example, the `RightSidebarPanel` (scene hierarchy) tells `SimulationData` that a new element has been selected. `SimulationData` then emits a global `element_selected` signal.
*   **Reactivity:** The `LeftSidebarPanel` (property inspector) listens for this `element_selected` signal and updates itself accordingly. This creates a clean, reactive, and one-way data flow, drastically reducing complexity and bugs.

```gdscript
# in RightSidebarPanel.gd
func _on_scenario_tree_item_selected():
    # ...
    # NOTIFY the central store, don't talk to other UI panels.
    SimData.set_selected_element_id(metadata.id)

# in LeftSidebarPanel.gd
func _ready():
    # LISTEN to the central store for changes.
    SimData.element_selected.connect(_on_simulation_data_element_selected)
```

### b. Component-Based & Reusable UI (Composition over Inheritance)

The UI is built from small, reusable, and single-purpose components.
*   **Property Editors:** The property inspector is not a monolithic script. It uses a factory pattern to dynamically instantiate the correct editor scene (`PulseEditor`, `PlatformEditor`, etc.) based on the selected element's type.
*   **Base Classes:** A `BasePropertyEditor` provides common functionality (like creating string or numerical input fields), which specific editors extend. This follows the DRY (Don't Repeat Yourself) principle.
*   **Custom Controls:** Specialized controls like `NumericLineEdit` encapsulate their own logic (e.g., input validation), making them reusable throughout the project.

### c. Data-Driven UI

The user interface is generated dynamically based on the state of the data in `SimulationData`, not hardcoded.
*   The `PlatformEditor` intelligently shows or hides fields based on the chosen platform type (e.g., `Monostatic` vs. `Target`) or rotation model (`Fixed Rate` vs. `Waypoints`).
*   Dropdowns for linking elements (e.g., assigning an `Antenna` to a `Platform`) are populated at runtime by querying `SimulationData` for all available elements of that type.

### d. Consistent Project Structure & Naming Conventions

The project adheres to Godot community best practices for organization, which greatly improves readability and maintainability.
*   **Folder Structure:** A clear separation between `scenes`, `scripts`, `assets`, and `ui` components.
*   **Naming:** `PascalCase` is used for nodes and class names, while `snake_case` is used for files and functions/variables, as is conventional in the Godot community.

```
/scripts/
├── data/              # Data models and defaults
├── ui/                # Scripts for UI components
│   └── property_editors/
└── views/             # Scripts for main views (e.g., 3D world)
```

### e. Adherence to the Single Responsibility Principle (SRP)

Each script and scene has a well-defined and limited responsibility.
*   `WaypointEditor.gd` is only concerned with managing the waypoint editing dialog.
*   `World3DView.gd` is only responsible for visualizing FERS platforms in the 3D viewport.
*   `SimulationData.gd` only manages the state of the simulation data and does not contain any view logic.

This separation of concerns makes the code easier to understand, debug, and extend.

---

## 5. Getting Started

1.  Ensure you have [Godot Engine (v4.x or later)](https://godotengine.org/download/) installed.
2.  Clone this repository:
    ```bash
    git clone https://github.com/the-user-created/FERS_UI.git
    ```
3.  Open the Godot Engine project manager.
4.  Click "Import" and navigate to the cloned repository folder, then select the `project.godot` file.
5.  Once the project is open in the Godot editor, run the main scene by pressing **F5**.

---

## 6. Development Roadmap

This UI is being developed in tandem with the core FERS MSc research objectives. The high-level roadmap is as follows:

*   **Phase 1: Foundation & Usability:**
    *   Implement the core UI shell (sidebars, 3D view).
    *   Develop the 3D world builder for placing and manipulating platforms.
    *   Create property editors for all major FERS elements (Platforms, Pulses, Antennas, etc.).
    *   Implement a robust XML exporter to generate valid FERS simulation files.
*   **Phase 2: Visualization & Refinement:**
    *   Develop the simulation replay feature to visualize FERS output data.
    *   Integrate in-software asset creation tools (e.g., a simple chirp generator UI).
    *   Refine the user experience and address usability feedback.
*   **Phase 3: Advanced Features & Integration:**
    *   Explore deeper integration with the FERS C++ core.
    *   Implement visualization for more advanced concepts like antenna patterns and clutter.

---

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0). See the [LICENSE](LICENSE) file for details.

## Acknowledgements

*   The core **FERS** simulator was developed by **Marc Brooker** and **Michael Inggs** at the Radar Research and Signal Group (RRSG), University of Cape Town.
*   This UI project builds upon their foundational work and the subsequent modernization efforts.