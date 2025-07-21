# 1. Architectural Overview

The FERS-UI project is built upon a set of modern software design principles to ensure maintainability, scalability, and
robustness. The core philosophy is to create a clear separation of concerns, enable reactive data flow, and promote
component reusability.

## Core Principles

The UI's architecture is guided by the following principles:

* **Centralized State Management (Single Source of Truth):** All simulation configuration data resides in a single,
  accessible location. This prevents data inconsistencies and simplifies debugging by providing one canonical state.
* **Reactive Data Flow:** UI components do not directly communicate with each other. Instead, they interact with the
  central data store. Changes to the data store trigger global signals, which interested UI components listen for and
  react to. This creates a predictable one-way data flow.
* **Component-Based & Reusable UI:** The user interface is composed of small, focused, and interchangeable components.
  This promotes modularity, reduces code duplication, and accelerates development.
* **Data-Driven UI:** The appearance and behavior of the UI dynamically adapt based on the current state of the
  simulation data, rather than being hardcoded. This allows for flexible and intelligent display of properties.
* **Single Responsibility Principle (SRP):** Each script and scene is designed to have one well-defined and limited
  responsibility. This enhances readability, simplifies testing, and makes it easier to extend or modify individual
  parts without affecting others.

## High-Level Component Interaction

The FERS-UI comprises several key architectural layers and components:

1. **Central Data Store:** A global singleton responsible for holding, managing, and validating all simulation
   configuration data. It acts as the intermediary for all data modifications and disseminates changes via signals.
2. **Main Application Layout:** The top-level UI container that orchestrates the overall window layout, manages sidebar
   visibility, and handles global actions like file I/O and simulation playback controls.
3. **Scene Hierarchy Panel:** Displays a tree-like representation of all simulation elements, allowing users to select
   elements for inspection. It reports selection changes to the central data store.
4. **Property Inspector Panel:** Dynamically loads and displays appropriate editor components based on the currently
   selected simulation element. It updates properties by communicating with the central data store.
5. **3D World View:** Renders the interactive 3D environment where simulation elements are visualized. It reacts to data
   changes from the central store to update element positions, orientations, and visual properties in real-time.
6. **Reusable Property Editors:** A set of specialized UI components designed to edit specific types of simulation
   element properties (e.g., platforms, pulses, antennas). They are dynamically instantiated by the Property Inspector.
7. **XML Importer/Exporter:** Modules responsible for translating the internal data model into the FERS-compatible XML
   format for simulation execution, and for parsing FERS XML files back into the internal data model.

This architectural foundation ensures that FERS-UI remains maintainable and extensible as new features and complexities
are introduced.
