# 3. Component-Based UI and Reusability

FERS-UI employs a component-based approach to its user interface, prioritizing reusability and modularity. This
philosophy treats UI elements as self-contained units with clear responsibilities, leading to a more maintainable and
extensible codebase.

## The Philosophy: Composition over Inheritance

Instead of building monolithic UI panels, the interface is constructed from smaller, single-purpose components. This
aligns with the "composition over inheritance" principle, where complex functionality is achieved by assembling simpler
parts rather than extending a large, all-encompassing class.

## Reusable Property Editors

A prime example of this approach is the system for editing simulation element properties:

* **Base Property Editor:** A foundational component provides common functionalities required by all property editors.
  This includes:
    * Standard input fields (text, numerical).
    * Dropdowns for predefined options.
    * Checkboxes for boolean properties.
    * Color pickers.
    * File pickers for file paths.
    * A generic mechanism to inform the central data store about property changes.
    * The ability to dynamically rebuild its UI based on the specific element's data.
      This base ensures consistency in UI elements and interaction patterns across different property types.

* **Specialized Property Editors:** For each distinct type of simulation element (e.g., platforms, pulses, antennas), a
  dedicated editor component extends the base property editor. These specialized editors focus solely on:
    * Arranging the unique properties for their specific element type.
    * Intelligently showing or hiding fields based on internal logic (e.g., displaying `PRF` only for pulsed radar
      types).
    * Handling interactions with complex sub-editors (like the waypoint editor for motion paths).

## Dynamic UI Generation (Factory Pattern)

The Property Inspector panel doesn't hardcode which editor to display. Instead, it uses a dynamic loading mechanism,
akin to a factory pattern:

1. When a user selects an element in the Scene Hierarchy, the Property Inspector receives a signal containing the
   element's unique ID.
2. It queries the central data store for the full data set of that element, including its type (e.g., "platform", "
   pulse").
3. Based on the element's type, it dynamically instantiates the appropriate specialized property editor component (e.g.,
   a "Platform Editor" for a "platform" type, a "Pulse Editor" for a "pulse" type).
4. The newly instantiated editor is then populated with the element's data and displayed in the panel.

## Benefits

* **Modularity:** Each UI component is a self-contained unit, making it easier to understand, test, and debug.
* **Reusability:** Common UI controls and patterns are encapsulated in base classes and helper functions, minimizing
  code duplication across different editors.
* **Extensibility:** Adding support for a new simulation element type involves primarily creating a new specialized
  property editor and registering it with the dynamic loading mechanism. Existing code remains largely untouched.
* **Maintainability:** Changes to a specific property editor or a common UI helper affect only that component, reducing
  the risk of unintended side effects across the application.
* **Consistency:** The use of shared base components and the reactive data flow ensures a consistent user experience
  despite the dynamic nature of the UI.
